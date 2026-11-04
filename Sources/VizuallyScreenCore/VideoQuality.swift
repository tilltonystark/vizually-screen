import AVFoundation
import VideoToolbox

package enum VideoQuality: String, Codable, CaseIterable, Identifiable {
    case high, efficient, master
    package var id: String { rawValue }
    package var name: String { switch self { case .high: return "Most compatible"; case .efficient: return "High quality"; case .master: return "Maximum detail" } }
    package var codec: AVVideoCodecType { switch self { case .high: return .h264; case .efficient: return .hevc; case .master: return .proRes4444 } }
    package var fileType: AVFileType { self == .master ? .mov : .mp4 }
    package var fileExtension: String { self == .master ? "mov" : "mp4" }
    package var detail: String { switch self { case .high: return "Plays on the widest range of devices and apps. High-quality H.264 video; files are usually larger than High quality."; case .efficient: return "Recommended for everyday recording and sharing. Sharp video with smaller files, using HEVC. Older apps may need Most compatible."; case .master: return "Keeps the most detail in small text and colors, using ProRes 4444. Best for further editing; files are much larger. This is not a lossless format." } }
    package func bitRate(width: Int, height: Int, fps: Double) -> Int {
        // Per-pixel budget scales with resolution and cadence; no hidden resize.
        Int(min(240_000_000, max(8_000_000, Double(width)*Double(height)*min(120,max(1,fps))*(self == .efficient ? 0.18 : 0.30))))
    }
    package func videoSettings(width: Int, height: Int, fps: Double) -> [String: Any] {
        var settings: [String: Any] = [AVVideoCodecKey: codec, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoColorPropertiesKey: [AVVideoColorPrimariesKey: AVVideoColorPrimaries_ITU_R_709_2, AVVideoTransferFunctionKey: AVVideoTransferFunction_IEC_sRGB, AVVideoYCbCrMatrixKey: AVVideoYCbCrMatrix_ITU_R_709_2]]
        if self != .master {
            var compression: [String: Any] = [AVVideoAverageBitRateKey: bitRate(width: width,height: height,fps: fps), AVVideoExpectedSourceFrameRateKey: fps, AVVideoMaxKeyFrameIntervalDurationKey: 1, AVVideoAllowFrameReorderingKey: false, kVTCompressionPropertyKey_PixelTransferProperties as String:[kVTPixelTransferPropertyKey_DownsamplingMode as String:kVTDownsamplingMode_Average]]
            if self == .high { compression[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel; compression[AVVideoH264EntropyModeKey] = AVVideoH264EntropyModeCABAC }
            else { compression[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel }
            settings[AVVideoCompressionPropertiesKey] = compression
        }
        return settings
    }
    package static func nativeSize(points: CGSize, scale: Double) -> (Int, Int) {
        // Round to a valid even pixel size without imposing a 4K ceiling.
        (max(2, Int((points.width*scale).rounded())/2*2), max(2, Int((points.height*scale).rounded())/2*2))
    }
}
