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
    private let writer: AVAssetWriter
    private let video: AVAssetWriterInput
    private let audio: AVAssetWriterInput?
    private let url: URL
    private var first: CMTime?
    private var last: CMSampleBuffer?
    private var lastTime=CMTime.invalid
    private var failure: Error?
    private var frames=0,dropped=0
    private var ended=false
    private let onBounds: @Sendable (CGRect) -> Void
    private let onStart: @Sendable () -> Void
    init(url: URL, quality: VideoQuality, width: Int,height: Int, audioEnabled: Bool,onBounds:@escaping @Sendable (CGRect) -> Void = { _ in },onStart:@escaping @Sendable () -> Void) throws {
        self.url=url;self.onStart=onStart;self.onBounds=onBounds
        writer=try AVAssetWriter(outputURL:url,fileType:quality.fileType)
        let settings=quality.videoSettings(width:width,height:height,fps:60)
        guard writer.canApply(outputSettings:settings,forMediaType:.video) else { throw MediaExporter.qualityError("The selected encoder cannot record \(width) × \(height). Choose Editing master or another source; Framecraft does not reduce resolution silently.") }
        video=AVAssetWriterInput(mediaType:.video,outputSettings:settings);video.expectsMediaDataInRealTime=true
        guard writer.canAdd(video) else { throw CocoaError(.fileWriteUnknown) };writer.add(video)
        if audioEnabled {
            let a=AVAssetWriterInput(mediaType:.audio,outputSettings:[AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:48_000,AVNumberOfChannelsKey:2,AVEncoderBitRateKey:256_000]);a.expectsMediaDataInRealTime=true
            guard writer.canAdd(a) else { throw CocoaError(.fileWriteUnknown) };writer.add(a);audio=a
        } else { audio=nil }
        super.init()
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
    }
    func stream(_ stream: SCStream,didOutputSampleBuffer sampleBuffer: CMSampleBuffer,of type: SCStreamOutputType) {
        guard !ended,sampleBuffer.isValid,failure == nil else { return }
        let pts=sampleBuffer.presentationTimeStamp
        if type == .screen {
            if let info=(CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]])?.first {
                if let rect=info[.screenRect] as? CGRect { onBounds(rect) }
                else if let dictionary=info[.screenRect] as? [String:Any],let rect=CGRect(dictionaryRepresentation:dictionary as CFDictionary) { onBounds(rect) }
            }
            if let attachments=CMSampleBufferGetSampleAttachmentsArray(sampleBuffer,createIfNecessary:false) as? [[SCStreamFrameInfo:Any]],let status=attachments.first?[.status] as? Int,status != SCFrameStatus.complete.rawValue { return }
            guard sampleBuffer.imageBuffer != nil else { return }
            if first == nil { first=pts;writer.startSession(atSourceTime:pts);onStart() }
            if lastTime.isValid && pts <= lastTime { return }
            guard video.isReadyForMoreMediaData else { dropped += 1;return }
            if video.append(sampleBuffer) { last=sampleBuffer;lastTime=pts;frames += 1 }
            else { failure=writer.error ?? CocoaError(.fileWriteUnknown) }
        } else if type == .audio,let first,pts >= first,let audio {
            if audio.isReadyForMoreMediaData { if !audio.append(sampleBuffer) { failure=writer.error ?? CocoaError(.fileWriteUnknown) } }
            else { failure=MediaExporter.qualityError("The audio encoder could not keep up. Recording stopped to avoid silently losing audio.") }
        }
    }
    func finish(cursor: [CursorSample]?,hostEnd: CMTime) async throws -> CaptureResult {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                self.ended=true
                guard let first=self.first,let last=self.last else { self.writer.cancelWriting();continuation.resume(throwing:MediaExporter.qualityError("No video frames arrived. Select the source again using the macOS picker."));return }
                if let failure=self.failure { self.writer.cancelWriting();continuation.resume(throwing:failure);return }
                // Preserve the held final frame when a static screen emits no new frames.
                let end=max(self.lastTime+CMTime(value:1,timescale:60),hostEnd)
                let finalPTS=end-CMTime(value:1,timescale:60)
                if finalPTS>self.lastTime {
                    var timing=CMSampleTimingInfo(duration:CMTime(value:1,timescale:60),presentationTimeStamp:finalPTS,decodeTimeStamp:.invalid)
                    var copy: CMSampleBuffer?
                    if CMSampleBufferCreateCopyWithNewTiming(allocator:kCFAllocatorDefault,sampleBuffer:last,sampleTimingEntryCount:1,sampleTimingArray:&timing,sampleBufferOut:&copy)==noErr,let copy,self.video.isReadyForMoreMediaData { _=self.video.append(copy) }
                }
                self.video.markAsFinished();self.audio?.markAsFinished();self.writer.endSession(atSourceTime:end)
                self.writer.finishWriting {
                    guard self.writer.status == .completed else { continuation.resume(throwing:self.writer.error ?? CocoaError(.fileWriteUnknown));return }
                    let normalized=cursor.map { values in Motion.smooth(values.compactMap { v in let t=v.time-first.seconds;guard t>=0 else { return nil };return CursorSample(time:t,x:v.x,y:v.y,visible:v.visible) }) }
                    continuation.resume(returning:CaptureResult(url:self.url,samples:normalized,frames:self.frames,dropped:self.dropped))
                }
            }
        }
    }
    func cancel() { queue.async { self.ended=true;self.writer.cancelWriting() } }
}
