import Foundation
import AVFoundation
import FramecraftCore

func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Check failed at line \(line)", file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(lhs) == \(rhs)") }
func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double) { precondition(abs(lhs - rhs) <= accuracy, "Expected \(lhs) ≈ \(rhs)") }
func XCTAssertGreaterThan(_ lhs: Int, _ rhs: Int) { precondition(lhs > rhs) }
func XCTAssertThrowsError(_ action: @autoclosure () throws -> Void) { do { try action(); fatalError("Expected validation to throw") } catch {} }
@main
struct FramecraftChecks {
    static func main() async throws {
        let checks = FramecraftChecks()
        checks.testZoomIsContinuousAndReturnsToOriginal()
        try checks.testProjectRoundtripAndValidation()
        try checks.testShortClipAndTrimIntervals()
        try checks.testAppearanceRoundtripAndContrast()
        checks.testMotionAndNativePixels()
        try await checks.testCaptureContentBounds()
        try await checks.testDemoClip()
        try await checks.testActualVideoExport()
        print("PASS: continuous camera/cursor motion, native pixel sizing and padded-frame crop encode/decode, short-clip/trim bounds, model/theme roundtrips and contrast, demo decode, 60 fps trimmed export with audio, cancellation cleanup")
    }
    func testZoomIsContinuousAndReturnsToOriginal() {
        let z = Zoom(start: 2, duration: 3)
        XCTAssertEqual(z.amount(at: 1.99), 0)
        XCTAssertEqual(z.amount(at: 2), 0)
        XCTAssertEqual(z.amount(at: 2.3), 0.5, accuracy: 0.0001)
        XCTAssertEqual(z.amount(at: 3), 1)
        XCTAssertEqual(z.amount(at: 5), 0)
        XCTAssertEqual(z.amount(at: 6), 0)
        let short = Zoom(start: 0, duration: 0.1)
        XCTAssertEqual(short.amount(at: 0.05), 1)
    }
    func testProjectRoundtripAndValidation() throws {
        var p = Project(sourcePath: "/tmp/test.mp4", trimEnd: 8)
        p.zooms = [Zoom(start: 1), Zoom(start: 2, scale: 3)]
        let copy = try JSONDecoder().decode(Project.self, from: JSONEncoder().encode(p))
        XCTAssertEqual(copy.zooms, p.zooms)
        XCTAssertEqual(copy.zoom(at:3).scale,3)
        XCTAssertEqual(copy.zoom(at: 7).scale, 1)
        try copy.validate(duration: 8)
        p.trimStart = 9
        XCTAssertThrowsError(try p.validate(duration: 8))
    }
    func testShortClipAndTrimIntervals() throws {
        for duration in [0.001, 0.04, 0.1, 1, 8] {
            var p = Project(sourcePath: "/tmp/short.mp4", trimEnd: duration)
            p.setTrimStart(duration, duration: duration)
            XCTAssertTrue(p.trimEnd - p.trimStart >= min(0.1, duration) - 0.0000001)
            p.setTrimEnd(-5, duration: duration)
            try p.validate(duration: duration)
            XCTAssertTrue(p.trimStart >= 0 && p.trimEnd <= duration)
            for time in [-10.0, 0, duration, duration + 10] {
                let zoom = p.newZoom(at: time)!
                XCTAssertTrue(zoom.start >= p.trimStart && zoom.duration > 0)
                XCTAssertTrue(zoom.start + zoom.duration <= p.trimEnd + 0.0000001)
                p.zooms = [zoom]
                try p.validate(duration: duration)
            }
            let previous = p.trimStart
            p.setTrimStart(.nan, duration: duration)
            XCTAssertEqual(p.trimStart, previous)
            XCTAssertTrue(p.newZoom(at: .infinity) == nil)
        }
        var invalid = Project(sourcePath: "/tmp/test.mp4", trimEnd: 1)
        invalid.zooms = [Zoom(start: 0.9, duration: 1)]
        XCTAssertThrowsError(try invalid.validate(duration: 1))
        invalid.zooms = [Zoom(start: 0, duration: 0.5)]
        invalid.zooms.append(invalid.zooms[0])
        XCTAssertThrowsError(try invalid.validate(duration: 1))
    }
    func testAppearanceRoundtripAndContrast() throws {
        var appearance = Appearance()
        appearance.accentHue = 281; appearance.canvasLightness = 0.94; appearance.radius = 14; appearance.spacing = 24
        try appearance.validate()
        let copy = try JSONDecoder().decode(Appearance.self, from: JSONEncoder().encode(appearance))
        XCTAssertEqual(copy, appearance)
        for invalid in [Double.nan, .infinity, 229, 301] {
            var value = appearance; value.accentHue = invalid
            XCTAssertThrowsError(try value.validate())
        }
        for invalid in [Double.nan, 0.91, 0.99] {
            var value = appearance; value.canvasLightness = invalid
            XCTAssertThrowsError(try value.validate())
        }
        var invalid = appearance; invalid.radius = 17
        XCTAssertThrowsError(try invalid.validate())
        invalid = appearance; invalid.spacing = 15
        XCTAssertThrowsError(try invalid.validate())
        let white = (1.0, 1.0, 1.0)
        for hue in stride(from: 230.0, through: 300, by: 1) {
            let accent = StudioColor.rgb(0.48, 0.18, hue)
            XCTAssertTrue(StudioColor.contrast(white, accent) >= 4.5)
            for lightness in [0.92, 0.955, 0.98] {
                let canvas = StudioColor.rgb(lightness, 0.003)
                for ink in [0.25, 0.46, 0.51] { XCTAssertTrue(StudioColor.contrast(StudioColor.rgb(ink, 0.008), canvas) >= 4.5) }
                XCTAssertTrue(StudioColor.contrast(accent, canvas) >= 4.5)
            }
        }
    }
    func testMotionAndNativePixels() {
        let size=VideoQuality.nativeSize(points:CGSize(width:2560,height:1440),scale:2)
        XCTAssertEqual(size.0,5120);XCTAssertEqual(size.1,2880)
        XCTAssertEqual(Motion.ease(0.5),0.5,accuracy:0.000001)
        var p=Project(sourcePath:"/tmp/test.mp4",trimEnd:8)
        p.zooms=[Zoom(start:1,duration:4,scale:2,x:0.2),Zoom(start:2,duration:4,scale:3,x:0.8)]
        for time in stride(from:1.0,through:6,by:0.01) {
            let a=p.zoom(at:time),b=p.zoom(at:time+0.00001)
            XCTAssertTrue(abs(a.scale-b.scale)<0.001)
            // Compare camera transforms, which are meaningful even at identity.
            XCTAssertTrue(abs((a.scale-1)*a.x-(b.scale-1)*b.x)<0.001)
        }
        let raw=(0..<240).map { i in CursorSample(time:Double(i)/120,x:0.5+(i%2==0 ? 0.01 : -0.01),y:0.4) }
        let smooth=Motion.smooth(raw)
        XCTAssertTrue(abs(smooth[120].x-0.5)<0.001)
        XCTAssertTrue(Motion.cursor(at:1,samples:smooth) != nil)
        XCTAssertTrue(Motion.cursor(at:3,samples:smooth) == nil)
    }
    func testCaptureContentBounds() async throws {
        let geometry=CaptureFrameGeometry(surfaceSize:CGSize(width:640,height:480),contentRectPoints:CGRect(x:20,y:10,width:160,height:100),pixelScale:2,contentScale:1)
        XCTAssertEqual(geometry.contentRect,CGRect(x:40,y:20,width:320,height:200))
        XCTAssertEqual(geometry.nativeSize,CGSize(width:320,height:200))
        let scaled=CaptureFrameGeometry(surfaceSize:CGSize(width:640,height:480),contentRectPoints:CGRect(x:0,y:0,width:160,height:100),pixelScale:2,contentScale:0.5)
        XCTAssertEqual(scaled.nativeSize,CGSize(width:640,height:400))
        let full=CaptureFrameGeometry(surfaceSize:CGSize(width:3024,height:1964),contentRectPoints:nil,pixelScale:2,contentScale:1)
        XCTAssertEqual(full.nativeSize,CGSize(width:3024,height:1964))
        XCTAssertEqual(Project(sourcePath:"/tmp/source.mp4",trimEnd:1).padding,0)
        var buffer:CVPixelBuffer?
        let attrs=[kCVPixelBufferIOSurfacePropertiesKey as String:[:]] as CFDictionary
        XCTAssertEqual(CVPixelBufferCreate(nil,640,480,kCVPixelFormatType_32BGRA,attrs,&buffer),kCVReturnSuccess)
        let source=buffer!
        CVPixelBufferLockBaseAddress(source,[])
        let data=CVPixelBufferGetBaseAddress(source)!.assumingMemoryBound(to:UInt8.self),stride=CVPixelBufferGetBytesPerRow(source)
        for y in 0..<480 { for x in 0..<640 {
            let i=y*stride+x*4,inside=(40..<360).contains(x) && (20..<220).contains(y)
            data[i]=inside ? 240:0;data[i+1]=inside ? 240:0;data[i+2]=inside ? 240:0;data[i+3]=255
        } }
        CVPixelBufferUnlockBaseAddress(source,[])
        let processor=try CaptureFrameProcessor(size:geometry.nativeSize,pixelFormat:kCVPixelFormatType_32BGRA)
        let cropped=try processor.process(source,geometry:geometry)
        XCTAssertEqual(CVPixelBufferGetWidth(cropped),320);XCTAssertEqual(CVPixelBufferGetHeight(cropped),200)
        CVPixelBufferLockBaseAddress(cropped,[])
        let bytes=CVPixelBufferGetBaseAddress(cropped)!.assumingMemoryBound(to:UInt8.self),row=CVPixelBufferGetBytesPerRow(cropped)
        for (x,y) in [(2,2),(317,2),(2,197),(317,197),(160,100)] { XCTAssertTrue(bytes[y*row+x*4+2]>220) }
        CVPixelBufferUnlockBaseAddress(cropped,[])
        // Encode/decode the crop; edge checks catch persisted padding, not just math.
        let url=FileManager.default.temporaryDirectory.appendingPathComponent("crop-check-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at:url) }
        let writer=try AVAssetWriter(outputURL:url,fileType:.mp4)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:VideoQuality.high.videoSettings(width:320,height:200,fps:60))
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:nil)
        writer.add(input);XCTAssertTrue(writer.startWriting());writer.startSession(atSourceTime:.zero)
        for frame in 0..<12 {
            while !input.isReadyForMoreMediaData { if writer.status == .failed { throw writer.error! };try await Task.sleep(nanoseconds:1_000_000) }
            XCTAssertTrue(adaptor.append(cropped,withPresentationTime:CMTime(value:Int64(frame),timescale:60)))
        }
        input.markAsFinished();await writer.finishWriting();XCTAssertEqual(writer.status,.completed)
        let image=try await AVAssetImageGenerator(asset:AVURLAsset(url:url)).image(at:CMTime(value:3,timescale:60)).image
        XCTAssertEqual(image.width,320);XCTAssertEqual(image.height,200)
        var rgba=[UInt8](repeating:0,count:320*200*4)
        rgba.withUnsafeMutableBytes { storage in
            let context=CGContext(data:storage.baseAddress,width:320,height:200,bitsPerComponent:8,bytesPerRow:1280,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image,in:CGRect(x:0,y:0,width:320,height:200))
        }
        for (x,y) in [(2,2),(317,2),(2,197),(317,197)] { XCTAssertTrue(rgba[(y*320+x)*4]>210) }
    }
    func testDemoClip() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("demo-check-\(UUID().uuidString).mp4")
        defer { try? FileManager.default.removeItem(at: url) }
        try await DemoClip.create(at: url)
        let asset = AVURLAsset(url: url)
        XCTAssertEqual(try await asset.load(.duration).seconds, 8, accuracy: 0.04)
        let demoTrack=try await asset.loadTracks(withMediaType:.video)[0]
        XCTAssertEqual(Double(try await demoTrack.load(.nominalFrameRate)),60,accuracy:0.1)
        let generator = AVAssetImageGenerator(asset: asset)
        let first = try await generator.image(at: CMTime(seconds: 0.2, preferredTimescale: 600)).image
        let last = try await generator.image(at: CMTime(seconds: 7, preferredTimescale: 600)).image
        XCTAssertEqual(first.width, 2560); XCTAssertEqual(first.height, 1440)
        XCTAssertTrue((first.dataProvider!.data! as Data) != (last.dataProvider!.data! as Data))
    }
    func testActualVideoExport() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let inputURL = dir.appendingPathComponent("source.mp4")
        let outputURL = dir.appendingPathComponent("export.mp4")
        let writer = try AVAssetWriter(outputURL: inputURL, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 180])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB, kCVPixelBufferWidthKey as String: 320, kCVPixelBufferHeightKey as String: 180])
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            var buffer: CVPixelBuffer?
            XCTAssertEqual(CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &buffer), kCVReturnSuccess)
            let pixel = buffer!
            CVPixelBufferLockBaseAddress(pixel, [])
            let ptr = CVPixelBufferGetBaseAddress(pixel)!.assumingMemoryBound(to: UInt8.self)
            let row = CVPixelBufferGetBytesPerRow(pixel)
            for y in 0..<180 { for x in 0..<320 { let i = y * row + x * 4; ptr[i] = 255; ptr[i+1] = UInt8(x % 256); ptr[i+2] = UInt8(y); ptr[i+3] = UInt8(frame * 4) } }
            CVPixelBufferUnlockBaseAddress(pixel, [])
            while !input.isReadyForMoreMediaData {
                if writer.status == .failed { throw writer.error! }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            guard adaptor.append(pixel, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)) else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
        }
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        let videoAsset = AVURLAsset(url: inputURL)
        let audioURL=dir.appendingPathComponent("tone.caf")
        let format=AVAudioFormat(standardFormatWithSampleRate:48_000,channels:2)!
        var audioSettings=format.settings;audioSettings[AVLinearPCMIsNonInterleaved]=false
        let file=try AVAudioFile(forWriting:audioURL,settings:audioSettings)
        let buffer=AVAudioPCMBuffer(pcmFormat:format,frameCapacity:96_000)!
        buffer.frameLength=96_000
        for i in 0..<96_000 { let value=Float(sin(Double(i)*2*Double.pi*440/48_000)*0.1);buffer.floatChannelData![0][i]=value;buffer.floatChannelData![1][i]=value }
        try file.write(from:buffer)
        let audioAsset=AVURLAsset(url:audioURL)
        let asset=AVMutableComposition()
        let videoTrack=try await videoAsset.loadTracks(withMediaType:.video)[0]
        let audioTrack=try await audioAsset.loadTracks(withMediaType:.audio)[0]
        try asset.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:2,preferredTimescale:600)),of:videoTrack,at:.zero)
        try asset.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid)!.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:2,preferredTimescale:600)),of:audioTrack,at:.zero)
        var p = Project(sourcePath: inputURL.path, trimStart: 0.25, trimEnd: 1.75)
        p.zooms = [Zoom(start: 0.3, duration: 1.2, scale: 2, x: 0.8, y: 0.2)]
        try await Renderer.export(asset: asset, project: p, to: outputURL)
        let rendered = AVURLAsset(url: outputURL)
        let duration = try await rendered.load(.duration).seconds
        XCTAssertEqual(duration, 1.5, accuracy: 0.04)
        let audioTracks=try await rendered.loadTracks(withMediaType:.audio)
        XCTAssertEqual(audioTracks.count,1)
        let fps=try await rendered.loadTracks(withMediaType:.video)[0].load(.nominalFrameRate)
        XCTAssertEqual(Double(fps),60,accuracy:0.1)
        let control=ExportControl();control.cancel()
        let cancelledURL=dir.appendingPathComponent("cancelled.mp4")
        do { try await MediaExporter.export(asset:asset,project:p,quality:.high,to:cancelledURL,control:control);fatalError("Cancellation was ignored") }
        catch is CancellationError { XCTAssertTrue(!FileManager.default.fileExists(atPath:cancelledURL.path)) }
        let generator = AVAssetImageGenerator(asset: rendered)
        let image = try await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)).image
        XCTAssertEqual(image.width, 320)
        XCTAssertEqual(image.height, 180)
        // Verify export produced more than a container header.
        XCTAssertGreaterThan(try Data(contentsOf: outputURL).count, 1000)
    }
}
