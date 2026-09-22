import Foundation
import CZlib

enum SubtitlePayload {
    static func unpack(_ data: Data) throws -> Data {
        guard data.count <= CaptionParser.maximumBytes else { throw KaptusError.invalidCaptions }
        guard data.starts(with: [0x1f, 0x8b]) else { return data }
        var stream = z_stream()
        guard inflateInit2_(&stream, 15 + 32, ZLIB_VERSION, Int32(MemoryLayout<z_stream>.size)) == Z_OK else { throw KaptusError.invalidCaptions }
        defer { inflateEnd(&stream) }
        return try data.withUnsafeBytes { input in
            stream.next_in = UnsafeMutablePointer(mutating: input.bindMemory(to: UInt8.self).baseAddress)
            stream.avail_in = uInt(data.count)
            var output = Data()
            var chunk = [UInt8](repeating: 0, count: 16_384)
            while true {
                let status = chunk.withUnsafeMutableBytes { buffer -> Int32 in
                    stream.next_out = buffer.bindMemory(to: UInt8.self).baseAddress
                    stream.avail_out = uInt(buffer.count)
                    return inflate(&stream, Z_NO_FLUSH)
                }
                let written = chunk.count - Int(stream.avail_out)
                guard output.count + written <= CaptionParser.maximumBytes else { throw KaptusError.invalidCaptions }
                output.append(contentsOf: chunk.prefix(written))
                if status == Z_STREAM_END { return output }
                guard status == Z_OK, written > 0 || stream.avail_in > 0 else { throw KaptusError.invalidCaptions }
            }
        }
    }
}
