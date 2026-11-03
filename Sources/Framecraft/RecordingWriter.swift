import AVFoundation
import ScreenCaptureKit
import FramecraftCore

struct CaptureResult {
    let url: URL
    let samples: [CursorSample]?
    let frames: Int
    let dropped: Int
}
final class RecordingWriter: NSObject, SCStreamOutput, @unchecked Sendable {
    let queue=DispatchQueue(label:"Framecraft.capture.writer",qos:.userInitiated)
    private var writer: AVAssetWriter?
    private var video: AVAssetWriterInput?
    private var audio: AVAssetWriterInput?
    private var processor: CaptureFrameProcessor?
    private let quality: VideoQuality
    private let audioEnabled: Bool
    private let url: URL
    private var first: CMTime?
    private var last: CMSampleBuffer?
    private var lastTime=CMTime.invalid
    private var failure: Error?
    private var frames=0,dropped=0
    private var ended=false
    private let onBounds: @Sendable (CGRect) -> Void
    private let onStart: @Sendable (CGSize) -> Void
    init(url: URL, quality: VideoQuality, audioEnabled: Bool,onBounds:@escaping @Sendable (CGRect) -> Void = { _ in },onStart:@escaping @Sendable (CGSize) -> Void) {
        self.url=url;self.quality=quality;self.audioEnabled=audioEnabled;self.onStart=onStart;self.onBounds=onBounds
        super.init()
    }
    private func configure(size:CGSize,at time:CMTime) throws {
        let writer=try AVAssetWriter(outputURL:url,fileType:quality.fileType)
        self.writer=writer
        let settings=quality.videoSettings(width:Int(size.width),height:Int(size.height),fps:60)
        guard writer.canApply(outputSettings:settings,forMediaType:.video) else { throw MediaExporter.qualityError("This Mac cannot record the selected source at its original size. Choose a different quality option.") }
        let video=AVAssetWriterInput(mediaType:.video,outputSettings:settings);video.expectsMediaDataInRealTime=true
        guard writer.canAdd(video) else { throw CocoaError(.fileWriteUnknown) };writer.add(video);self.video=video
        if audioEnabled {
            let audio=AVAssetWriterInput(mediaType:.audio,outputSettings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:48_000,AVNumberOfChannelsKey:2,AVEncoderBitRateKey:256_000]);audio.expectsMediaDataInRealTime=true
            guard writer.canAdd(audio) else { throw CocoaError(.fileWriteUnknown) };writer.add(audio);self.audio=audio
        }
        processor=try CaptureFrameProcessor(size:size,pixelFormat:quality == .master ? kCVPixelFormatType_32BGRA:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        first=time;writer.startSession(atSourceTime:time);onStart(size)
    }
    private func rect(_ value:Any?) -> CGRect? {
        if let rect=value as? CGRect { return rect }
        if let dictionary=value as? [String:Any] { return CGRect(dictionaryRepresentation:dictionary as CFDictionary) }
        return nil
    }
    func stream(_ stream: SCStream,didOutputSampleBuffer sampleBuffer: CMSampleBuffer,of type: SCStreamOutputType) {
        guard !ended,sampleBuffer.isValid,failure == nil else { return }
        let pts=sampleBuffer.presentationTimeStamp
        if type == .screen {
            let info=(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]])?.first
            if let bounds=rect(info?[.screenRect]) { onBounds(bounds) }
            if let status=info?[.status] as? Int,status != SCFrameStatus.complete.rawValue { return }
            guard let buffer=sampleBuffer.imageBuffer else { return }
            let geometry=CaptureFrameGeometry(surfaceSize:CGSize(width:CVPixelBufferGetWidth(buffer),height:CVPixelBufferGetHeight(buffer)),contentRectPoints:rect(info?[.contentRect]),pixelScale:(info?[.scaleFactor] as? NSNumber)?.doubleValue ?? 1,contentScale:(info?[.contentScale] as? NSNumber)?.doubleValue ?? 1)
            do {
                // The first actual frame is authoritative, not a stale picker snapshot.
                if first == nil { try configure(size:geometry.nativeSize,at:pts) }
                guard let video,let processor else { return }
                if lastTime.isValid && pts <= lastTime { return }
                guard video.isReadyForMoreMediaData else { dropped += 1;return }
                let image=try processor.process(buffer,geometry:geometry)
                var description:CMVideoFormatDescription?
                guard CMVideoFormatDescriptionCreateForImageBuffer(allocator:kCFAllocatorDefault,imageBuffer:image,formatDescriptionOut:&description)==noErr,let description else { throw CocoaError(.fileWriteUnknown) }
                var timing=CMSampleTimingInfo(duration:sampleBuffer.duration,presentationTimeStamp:pts,decodeTimeStamp:.invalid)
                var output:CMSampleBuffer?
                guard CMSampleBufferCreateReadyWithImageBuffer(allocator:kCFAllocatorDefault,imageBuffer:image,formatDescription:description,sampleTiming:&timing,sampleBufferOut:&output)==noErr,let output else { throw CocoaError(.fileWriteUnknown) }
                if video.append(output) { last=output;lastTime=pts;frames += 1 }
                else { throw writer?.error ?? CocoaError(.fileWriteUnknown) }
            } catch { failure=error }
        } else if type == .audio,let first,pts >= first,let audio {
            if audio.isReadyForMoreMediaData { if !audio.append(sampleBuffer) { failure=writer?.error ?? CocoaError(.fileWriteUnknown) } }
            else { failure=MediaExporter.qualityError("The audio encoder could not keep up. Try recording again with system audio off.") }
        }
    }
    func finish(cursor: [CursorSample]?,hostEnd: CMTime) async throws -> CaptureResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.ended=true
                if let failure=self.failure { self.writer?.cancelWriting();continuation.resume(throwing:failure);return }
                guard let first=self.first,let last=self.last,let writer=self.writer,let video=self.video else { self.writer?.cancelWriting();continuation.resume(throwing:MediaExporter.qualityError("No video frames arrived. Choose the source again."));return }
                let end=max(self.lastTime+CMTime(value:1,timescale:60),hostEnd)
                let finalPTS=end-CMTime(value:1,timescale:60)
                if finalPTS>self.lastTime {
                    var timing=CMSampleTimingInfo(duration:CMTime(value:1,timescale:60),presentationTimeStamp:finalPTS,decodeTimeStamp:.invalid)
                    var copy: CMSampleBuffer?
                    if CMSampleBufferCreateCopyWithNewTiming(allocator:kCFAllocatorDefault,sampleBuffer:last,sampleTimingEntryCount:1,sampleTimingArray:&timing,sampleBufferOut:&copy)==noErr,let copy,video.isReadyForMoreMediaData { _=video.append(copy) }
                }
                video.markAsFinished();self.audio?.markAsFinished();writer.endSession(atSourceTime:end)
                writer.finishWriting {
                    guard writer.status == .completed else { continuation.resume(throwing:writer.error ?? CocoaError(.fileWriteUnknown));return }
                    let normalized=cursor.map { values in Motion.smooth(values.compactMap { v in let t=v.time-first.seconds;guard t>=0 else { return nil };return CursorSample(time:t,x:v.x,y:v.y,visible:v.visible) }) }
                    continuation.resume(returning:CaptureResult(url:self.url,samples:normalized,frames:self.frames,dropped:self.dropped))
                }
            }
        }
    }
    func cancel() { queue.async { self.ended=true;self.writer?.cancelWriting() } }
}
