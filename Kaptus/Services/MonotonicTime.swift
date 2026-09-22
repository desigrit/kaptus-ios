import Foundation
import Darwin

enum MonotonicTime {
    private static let scale: Double = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return Double(info.numer) / Double(info.denom) / 1_000_000_000
    }()
    static var now: Double { Double(mach_continuous_time()) * scale }
    static func seconds(hostTime: UInt64) -> Double { Double(hostTime) * scale }
}
