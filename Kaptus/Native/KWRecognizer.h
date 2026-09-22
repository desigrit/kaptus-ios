#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface KWWord : NSObject
@property (nonatomic, copy) NSString *text;
@property (nonatomic) double start;
@property (nonatomic) double end;
@property (nonatomic) double confidence;
@end
@interface KWResult : NSObject
@property (nonatomic, copy) NSArray<KWWord *> *words;
@property (nonatomic) BOOL speechDetected;
@end
@interface KWRecognizer : NSObject
- (nullable instancetype)initWithModelPath:(NSString *)modelPath vadPath:(NSString *)vadPath error:(NSError **)error;
- (nullable KWResult *)transcribeSamples:(NSData *)samples error:(NSError **)error NS_SWIFT_NAME(transcribe(_:));
- (void)cancel;
- (void)resetCancellation;
@end
NS_ASSUME_NONNULL_END
