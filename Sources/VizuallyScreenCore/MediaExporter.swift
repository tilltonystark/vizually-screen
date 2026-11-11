import AVFoundation

package final class ExportControl: @unchecked Sendable {
    private let lock = NSLock()
    private var cancelled = false
    package init() {}
    package func cancel() { lock.lock();cancelled=true;lock.unlock() }
    package var isCancelled: Bool { lock.lock();defer{lock.unlock()};return cancelled }
}

package enum MediaExporter {
    package static func export(asset: AVAsset, project: Project, quality: VideoQuality, to url: URL,
                               control: ExportControl = ExportControl(), progress: @escaping @Sendable (Double) -> Void = { _ in }) async throws {
        try project.validate(duration: try await asset.load(.duration).seconds)
        if project.padding>0,let background=project.canvasBackground,background.kind == .image,CanvasBackground.loadImage(background.value) == nil {
            throw qualityError("The background image is missing or unreadable. Choose another image or select None.")
        }
        guard let track = try await asset.loadTracks(withMediaType: .video).first else { throw CocoaError(.fileReadCorruptFile) }
        let fps = max(60, Double(try await track.load(.nominalFrameRate)))
        let composition = Renderer.composition(asset: asset, project: project)
        let size = composition.renderSize
        let width = Int(size.width), height = Int(size.height)
        guard width > 0, height > 0 else { throw CocoaError(.fileReadCorruptFile) }
        let reader = try AVAssetReader(asset: asset)
        let range = CMTimeRange(start: CMTime(seconds: project.trimStart, preferredTimescale: 60_000), end: CMTime(seconds: project.trimEnd, preferredTimescale: 60_000))
        reader.timeRange = range
        let video = AVAssetReaderVideoCompositionOutput(videoTracks: [track], videoSettings: [kCVPixelBufferPixelFormatTypeKey as String: quality == .master ? kCVPixelFormatType_32BGRA : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange])
        video.videoComposition = composition; video.alwaysCopiesSampleData = false
        guard reader.canAdd(video) else { throw CocoaError(.fileReadUnknown) }; reader.add(video)
        let writer = try AVAssetWriter(outputURL: url, fileType: quality.fileType)
        defer { if writer.status != .completed { try? FileManager.default.removeItem(at:url) } }
        let settings = quality.videoSettings(width: width,height: height,fps: fps)
        guard writer.canApply(outputSettings: settings, forMediaType: .video) else { throw qualityError("This Mac cannot encode \(quality.name) at \(width) × \(height). Choose another profile; resolution is never silently reduced.") }
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw CocoaError(.fileWriteUnknown) }; writer.add(input)
        var pairs: [(AVAssetReaderOutput, AVAssetWriterInput, Bool)] = [(video,input,true)]
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        if !audioTracks.isEmpty {
            let output = AVAssetReaderAudioMixOutput(audioTracks: audioTracks, audioSettings: [AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 16, AVLinearPCMIsFloatKey: false, AVLinearPCMIsNonInterleaved: false])
            let audioSettings: [String:Any] = quality == .master ? [AVFormatIDKey:kAudioFormatLinearPCM,AVSampleRateKey:48_000,AVNumberOfChannelsKey:2,AVLinearPCMBitDepthKey:16,AVLinearPCMIsFloatKey:false,AVLinearPCMIsBigEndianKey:false,AVLinearPCMIsNonInterleaved:false] : [AVFormatIDKey:kAudioFormatMPEG4AAC,AVSampleRateKey:48_000,AVNumberOfChannelsKey:2,AVEncoderBitRateKey:256_000]
            let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            guard reader.canAdd(output),writer.canAdd(audio) else { throw CocoaError(.fileWriteUnknown) }
            reader.add(output);writer.add(audio);pairs.append((output,audio,false))
        }
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: range.start)
        guard reader.startReading() else { writer.cancelWriting(); throw reader.error ?? CocoaError(.fileReadUnknown) }
        do {
            try await withThrowingTaskGroup(of:Void.self) { group in
                for pair in pairs {
                    group.addTask {
                        while true {
                            try Task.checkCancellation()
                            if control.isCancelled { throw CancellationError() }
                            if writer.status == .failed || writer.status == .cancelled { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                            if !pair.1.isReadyForMoreMediaData { try await Task.sleep(nanoseconds:1_000_000);continue }
                            guard let sample=pair.0.copyNextSampleBuffer() else {
                                if reader.status == .failed { throw reader.error ?? CocoaError(.fileReadUnknown) }
                                pair.1.markAsFinished();return
                            }
                            if pair.2 && (sample.presentationTimeStamp < range.start || sample.presentationTimeStamp >= range.end) { continue }
                            guard pair.1.append(sample) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
                            if pair.2 { progress(min(0.99,max(0,(sample.presentationTimeStamp.seconds-project.trimStart)/(project.trimEnd-project.trimStart)))) }
                        }
                    }
                }
                try await group.waitForAll()
            }
        } catch { reader.cancelReading();writer.cancelWriting();throw error }
        if control.isCancelled { reader.cancelReading();writer.cancelWriting();throw CancellationError() }
        guard reader.status == .completed else { writer.cancelWriting();throw reader.error ?? CocoaError(.fileReadUnknown) }
        writer.endSession(atSourceTime:range.end)
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        if control.isCancelled { try? FileManager.default.removeItem(at:url);throw CancellationError() }
        progress(1)
    }
    package static func qualityError(_ text: String) -> NSError { NSError(domain:"VizuallyScreen.Quality",code:1,userInfo:[NSLocalizedDescriptionKey:text]) }
}
