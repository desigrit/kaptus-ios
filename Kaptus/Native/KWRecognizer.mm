#import "KWRecognizer.h"
#import <TargetConditionals.h>
#include "whisper.h"
#include <atomic>
#include <algorithm>
#include <thread>

@implementation KWWord
@end
@implementation KWResult
@end
@implementation KWRecognizer {
    whisper_context *_context;
    whisper_vad_context *_vad;
    std::atomic<bool> _cancelled;
}
static NSError *recognitionError(NSInteger code) {
    return [NSError errorWithDomain:@"KaptusRecognition" code:code userInfo:nil];
}
- (nullable instancetype)initWithModelPath:(NSString *)modelPath vadPath:(NSString *)vadPath error:(NSError **)error {
    self = [super init];
    if (self) {
        _cancelled.store(false);
        whisper_context_params params = whisper_context_default_params();
#if TARGET_OS_SIMULATOR
        params.use_gpu = false;
#else
        params.use_gpu = true;
#endif
        _context = whisper_init_from_file_with_params(modelPath.UTF8String, params);
        if (!_context && params.use_gpu) {
            params.use_gpu = false;
            _context = whisper_init_from_file_with_params(modelPath.UTF8String, params);
        }
        whisper_vad_context_params vadParams = whisper_vad_default_context_params();
        vadParams.n_threads = 2;
        vadParams.use_gpu = false;
        _vad = whisper_vad_init_from_file_with_params(vadPath.UTF8String, vadParams);
        if (!_context || !_vad) {
            if (error) *error = recognitionError(1);
            return nil;
        }
    }
    return self;
}
- (void)dealloc {
    if (_context) whisper_free(_context);
    if (_vad) whisper_vad_free(_vad);
}
- (void)cancel { _cancelled.store(true); }
- (void)resetCancellation { _cancelled.store(false); }
static bool shouldAbort(void *context) {
    return static_cast<std::atomic<bool> *>(context)->load();
}
- (nullable KWResult *)transcribeSamples:(NSData *)samples error:(NSError **)error {
    const float *pcm = static_cast<const float *>(samples.bytes);
    const int count = static_cast<int>(samples.length / sizeof(float));
    if (_cancelled.load() || count == 0) { if (error) *error = recognitionError(2); return nil; }
    whisper_vad_params vadParams = whisper_vad_default_params();
    vadParams.threshold = 0.5f;
    vadParams.min_speech_duration_ms = 250;
    whisper_vad_segments *segments = whisper_vad_segments_from_samples(_vad, vadParams, pcm, count);
    if (!segments) { if (error) *error = recognitionError(3); return nil; }
    const bool speech = whisper_vad_segments_n_segments(segments) > 0;
    whisper_vad_free_segments(segments);
    KWResult *result = [KWResult new];
    result.words = @[];
    result.speechDetected = speech;
    if (!speech) return result;

    whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    params.language = "en";
    params.n_threads = std::min(4u, std::max(2u, std::thread::hardware_concurrency()));
    params.translate = false;
    params.no_context = true;
    params.token_timestamps = true;
    params.print_realtime = false;
    params.print_progress = false;
    params.print_timestamps = false;
    params.print_special = false;
    params.suppress_blank = true;
    params.suppress_nst = true;
    params.temperature_inc = 0;
    params.abort_callback = shouldAbort;
    params.abort_callback_user_data = &_cancelled;
    if (whisper_full(_context, params, pcm, count) != 0) {
        if (error) *error = recognitionError(_cancelled.load() ? 2 : 4);
        return nil;
    }
    NSMutableArray<KWWord *> *words = [NSMutableArray array];
    for (int s = 0; s < whisper_full_n_segments(_context); ++s) {
        KWWord *current = nil;
        const double fallbackStart = whisper_full_get_segment_t0(_context, s) / 100.0;
        const double fallbackEnd = whisper_full_get_segment_t1(_context, s) / 100.0;
        for (int t = 0; t < whisper_full_n_tokens(_context, s); ++t) {
            whisper_token_data token = whisper_full_get_token_data(_context, s, t);
            if (token.id >= whisper_token_eot(_context)) continue;
            const char *raw = whisper_token_to_str(_context, token.id);
            NSString *piece = raw ? [NSString stringWithUTF8String:raw] : nil;
            if (!piece.length) continue;
            const BOOL boundary = [[NSCharacterSet whitespaceAndNewlineCharacterSet] characterIsMember:[piece characterAtIndex:0]];
            NSString *clean = [piece stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
            if (!clean.length) continue;
            double start = token.t0 >= 0 ? token.t0 / 100.0 : fallbackStart;
            double end = token.t1 >= token.t0 && token.t1 >= 0 ? token.t1 / 100.0 : fallbackEnd;
            start = std::clamp(start, 0.0, count / 16000.0);
            end = std::clamp(end, start, count / 16000.0);
            if (!current || boundary) {
                current = [KWWord new]; current.text = clean; current.start = start;
                current.end = end; current.confidence = token.p;
                [words addObject:current];
            } else {
                current.text = [current.text stringByAppendingString:clean];
                current.end = std::max(current.end, end);
                current.confidence = std::min(current.confidence, (double)token.p);
            }
        }
    }
    result.words = words;
    return result;
}
@end
