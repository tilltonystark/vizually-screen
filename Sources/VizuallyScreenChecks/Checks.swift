import Foundation
import AVFoundation
import CoreImage
import VizuallyScreenCore

func XCTAssertTrue(_ value: Bool, file: StaticString = #file, line: UInt = #line) { precondition(value, "Check failed at line \(line)", file: file, line: line) }
func XCTAssertEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(lhs) == \(rhs)") }
func XCTAssertEqual(_ lhs: Double, _ rhs: Double, accuracy: Double) { precondition(abs(lhs - rhs) <= accuracy, "Expected \(lhs) ≈ \(rhs)") }
func XCTAssertGreaterThan(_ lhs: Int, _ rhs: Int) { precondition(lhs > rhs) }
func XCTAssertThrowsError(_ action: @autoclosure () throws -> Void) { do { try action(); fatalError("Expected validation to throw") } catch {} }
@main
struct VizuallyScreenChecks {
    static func main() async throws {
        let checks = VizuallyScreenChecks()
        checks.testZoomIsContinuousAndReturnsToOriginal()
        try checks.testProjectRoundtripAndValidation()
        try checks.testShortClipAndTrimIntervals()
        try checks.testAppearanceRoundtripAndContrast()
        checks.testCaptureArea()
        checks.testMotionAndNativePixels()
        try checks.testAutomaticFocusAndMotion()
        try checks.testCanvasBackgrounds()
        try checks.testRecordingCatalog()
        try await checks.testCaptureContentBounds()
        try await checks.testDemoClip()
        try await checks.testActualVideoExport()
        print("PASS: continuous camera/cursor motion, native pixel sizing and padded-frame crop encode/decode, short-clip/trim bounds, model/theme roundtrips and contrast, demo decode, 60 fps trimmed export with audio, cancellation cleanup")
    }
    func testCaptureArea() {
        let size=CGSize(width:1512,height:982)
        let forward=CaptureArea.selection(from:CGPoint(x:31.2,y:40.4),to:CGPoint(x:620.9,y:390.7),displaySize:size,pixelScale:2)!
        let reverse=CaptureArea.selection(from:CGPoint(x:620.9,y:390.7),to:CGPoint(x:31.2,y:40.4),displaySize:size,pixelScale:2)!
        XCTAssertEqual(forward,reverse)
        XCTAssertEqual(forward,CGRect(x:32,y:41,width:588,height:349))
        XCTAssertEqual(VideoQuality.nativeSize(points:forward.size,scale:2).0,1176)
        let edge=CaptureArea.selection(from:CGPoint(x:-20,y:-30),to:CGPoint(x:3000,y:2000),displaySize:size,pixelScale:1)!
        XCTAssertEqual(edge,CGRect(origin:.zero,size:size))
        let global=CaptureArea.globalBounds(local:forward,display:CGRect(x:-1512,y:200,width:1512,height:982))
        XCTAssertEqual(global.origin,CGPoint(x:-1480,y:241))
        XCTAssertEqual((global.midX-global.minX)/global.width,0.5,accuracy:0.0001)
        let appKit=CaptureArea.appKitBounds(local:forward,displayFrame:CGRect(x:-1512,y:200,width:1512,height:982))
        XCTAssertEqual(appKit,CGRect(x:-1480,y:792,width:588,height:349))
        for area in [appKit,CGRect(x:0,y:0,width:1512,height:982),CGRect(x:100,y:-1080,width:400,height:300)] {
            let strips=CaptureArea.indicatorStrips(around:area)
            XCTAssertEqual(strips.count,4)
            for strip in strips { XCTAssertTrue(strip.width > 0 && strip.height > 0);XCTAssertTrue(strip.intersection(area).isNull || strip.intersection(area).isEmpty) }
            XCTAssertEqual(strips[0].maxX,area.minX-1,accuracy:0.0001)
            XCTAssertEqual(strips[1].minX,area.maxX+1,accuracy:0.0001)
        }
        XCTAssertTrue(CaptureArea.selection(from:.zero,to:CGPoint(x:2,y:3),displaySize:size,pixelScale:2) == nil)
        XCTAssertTrue(CaptureArea.selection(from:CGPoint(x:Double.nan,y:0),to:.zero,displaySize:size,pixelScale:2) == nil)
        XCTAssertTrue(CaptureArea.selection(from:.zero,to:CGPoint(x:100,y:100),displaySize:size,pixelScale:0) == nil)
    }
    func testRecordingCatalog() throws {
        let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
        defer { try? FileManager.default.removeItem(at:root) }
        let source=root.appendingPathComponent("test.mov")
        try Data([0]).write(to:source)
        var project=Project(sourcePath:source.path,trimEnd:8)
        project.zooms=[Zoom(start:1)]
        let edit=root.appendingPathComponent("custom-edit.vizually.json")
        try JSONEncoder().encode(project).write(to:edit)
        let missing=RecordingReference(sourcePath:"/missing/recording.mov",updated:.distantFuture)
        let found=RecordingCatalog.scan(roots:[root],recent:[missing,missing])
        XCTAssertEqual(found.count,2)
        XCTAssertEqual(found[0].sourcePath,missing.sourcePath)
        XCTAssertEqual(found[1].projectPath,edit.resolvingSymlinksInPath().path)
        let restored=try JSONDecoder().decode(Project.self,from:Data(contentsOf:URL(fileURLWithPath:found[1].projectPath!)))
        XCTAssertEqual(restored.zooms,project.zooms)
        XCTAssertEqual(RecordingCatalog.scan(roots:[root.appendingPathComponent("absent")],recent:[]).count,0)
    }
    func testZoomIsContinuousAndReturnsToOriginal() {
        let z = Zoom(start: 2, duration: 3)
        XCTAssertEqual(z.amount(at: 1.99), 0)
        XCTAssertEqual(z.amount(at: 2), 0)
        XCTAssertEqual(z.amount(at: 2.3), Motion.ease(0.3/0.85), accuracy: 0.0001)
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
    func testAutomaticFocusAndMotion() throws {
        let samples=(0...960).map { i -> CursorSample in
            let t=Double(i)/120
            let x=t<1 ? 0.15:t<1.35 ? 0.15+(t-1)/0.35*0.55:t<4 ? 0.7:t<4.4 ? 0.7-(t-4)/0.4*0.4:0.3
            return CursorSample(time:t,x:x,y:t<4.4 ? 0.35:0.65)
        }
        let suggested=AutoFocus.suggest(samples:samples,start:0,end:8)
        XCTAssertTrue(suggested.count>=2)
        XCTAssertTrue(suggested.allSatisfy { $0.automatic == true && $0.start>=0 && $0.start+$0.duration<=8 })
        XCTAssertTrue(suggested.contains { abs($0.x-0.7)<0.06 })
        XCTAssertTrue(suggested.contains { abs($0.x-0.3)<0.06 })
        let manual=Zoom(start:0,duration:4,x:0.2)
        let merged=AutoFocus.merge(suggested,with:[manual,Zoom(start:5,duration:1,automatic:true)])
        XCTAssertTrue(merged.contains { $0.id == manual.id })
        XCTAssertTrue(!merged.filter { $0.automatic == true }.contains { $0.start<4 })
        let idle=(0...240).map { CursorSample(time:Double($0)/120,x:0.5,y:0.5) }
        XCTAssertTrue(AutoFocus.suggest(samples:idle,start:0,end:2).isEmpty)
        let jitter=(0...1200).map { i in CursorSample(time:Double(i)/120,x:0.5+sin(Double(i)*0.4)*0.005,y:0.5) }
        XCTAssertTrue(AutoFocus.suggest(samples:jitter,start:0,end:10).isEmpty)
        let smoothed=Motion.smooth(samples,sigma:0.1)
        func peakAcceleration(_ values:[CursorSample]) -> Double {
            (1..<values.count-1).map { abs(values[$0+1].x-2*values[$0].x+values[$0-1].x) }.max()!
        }
        XCTAssertTrue(peakAcceleration(smoothed)<peakAcceleration(samples)*0.3)
        for t in stride(from:1.0,through:1.35,by:0.001) {
            let point=Motion.cursor(at:t,samples:smoothed)!
            XCTAssertTrue((0.15...0.7).contains(point.x))
        }
        var p=Project(sourcePath:"/tmp/test.mp4",trimEnd:8)
        p.cursorSamples=samples;p.pointerSmoothing = .extraSmooth;p.zooms=suggested
        try p.validate(duration:8)
        let copy=try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(copy.pointerSmoothing,.extraSmooth);XCTAssertEqual(copy.zooms,suggested)
        let state=RenderState(p)
        XCTAssertTrue(peakAcceleration(state.project.cursorSamples!)<peakAcceleration(samples)*0.3)
        p.pointerSmoothing = .original;state.update(p)
        XCTAssertEqual(state.project.cursorSamples,samples)
    }
    func testCanvasBackgrounds() throws {
        let rect=CGRect(x:0,y:0,width:320,height:180)
        let context=CIContext()
        for preset in BackgroundPreset.all {
            let background=CanvasBackground(kind:.gradient,value:preset.id)
            XCTAssertTrue(background.isValid)
            XCTAssertEqual(background.render(in:rect,image:nil).extent,rect)
        }
        XCTAssertTrue(!CanvasBackground(kind:.solid,value:"invalid").isValid)
        var p=Project(sourcePath:"/tmp/source.mp4",trimEnd:1)
        p.canvasBackground=CanvasBackground(kind:.solid,value:"22AA55")
        let copy=try JSONDecoder().decode(Project.self,from:JSONEncoder().encode(p))
        XCTAssertEqual(copy.canvasBackground,p.canvasBackground)
        let path=FileManager.default.temporaryDirectory.appendingPathComponent("background-check-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at:path) }
        try context.writePNGRepresentation(of:CIImage(color:CIColor(red:0.1,green:0.2,blue:0.9)).cropped(to:CGRect(x:0,y:0,width:80,height:50)),to:path,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)!)
        let background=CanvasBackground(kind:.image,value:path.path)
        XCTAssertTrue(background.isValid)
        let image=background.render(in:rect,image:CanvasBackground.loadImage(path.path))
        XCTAssertEqual(image.extent,rect)
        var pixels=[UInt8](repeating:0,count:320*180*4)
        pixels.withUnsafeMutableBytes { context.render(image,toBitmap:$0.baseAddress!,rowBytes:1280,bounds:rect,format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB)) }
        XCTAssertTrue(pixels[2]>180 && pixels[2]>pixels[0])
        let video=URL(fileURLWithPath:"/tmp/recording.mp4")
        XCTAssertEqual(ProjectFiles.candidates(for:video).map(\.lastPathComponent),["recording.vizually.json","recording.framecraft.json"])
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
            data[i]=inside ? 240:0;data[i+1]=inside ? 240:140;data[i+2]=inside ? 240:255;data[i+3]=255
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
        for (x,y) in [(0,0),(319,0),(0,199),(319,199),(2,2),(317,2),(2,197),(317,197)] {
            for channel in 0..<3 { XCTAssertTrue(rgba[(y*320+x)*4+channel]>210) }
        }
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
        p.padding=0.1;p.canvasBackground=CanvasBackground(kind:.solid,value:"22AA55")
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
        var rgba=[UInt8](repeating:0,count:320*180*4)
        rgba.withUnsafeMutableBytes { storage in
            CIContext().render(CIImage(cgImage:image),toBitmap:storage.baseAddress!,rowBytes:1280,bounds:CGRect(x:0,y:0,width:320,height:180),format:.RGBA8,colorSpace:CGColorSpace(name:CGColorSpace.sRGB))
        }
        for (x,y) in [(3,3),(316,3),(3,176),(316,176)] { let i=(y*320+x)*4;XCTAssertTrue(rgba[i+1]>rgba[i]+40 && rgba[i+1]>rgba[i+2]+30) }
        // Verify export produced more than a container header.
        XCTAssertGreaterThan(try Data(contentsOf: outputURL).count, 1000)
    }
}
