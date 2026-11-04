import Foundation
import AVFoundation
import CoreText
import VizuallyScreenCore
import ImageIO
import UniformTypeIdentifiers

@main struct QualityBenchmark {
    static func main() async throws {
        if CommandLine.arguments.count>2,CommandLine.arguments[1] == "--inspect" {
            let url=URL(fileURLWithPath:CommandLine.arguments[2]),asset=AVURLAsset(url:URL(fileURLWithPath:CommandLine.arguments[2]))
            var videos:[[String:Any]]=[]
            for track in try await asset.loadTracks(withMediaType:.video) {
                let size=try await track.load(.naturalSize),descriptions=try await track.load(.formatDescriptions)
                let subtype=CMFormatDescriptionGetMediaSubType(descriptions[0])
                let codec=String(bytes:[UInt8((subtype>>24)&255),UInt8((subtype>>16)&255),UInt8((subtype>>8)&255),UInt8(subtype&255)],encoding:.ascii) ?? "unknown"
                videos.append(["width":size.width,"height":size.height,"fps":try await track.load(.nominalFrameRate),"codec":codec,"estimatedBitrate":try await track.load(.estimatedDataRate)])
            }
            let report:[String:Any]=["file":url.lastPathComponent,"duration":try await asset.load(.duration).seconds,"video":videos,"audioTracks":try await asset.loadTracks(withMediaType:.audio).count]
            print(String(data:try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]),encoding:.utf8)!)
            return
        }
        let directory=URL(fileURLWithPath:CommandLine.arguments.dropFirst().first ?? "/tmp/vizually-screen-quality")
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        let source=directory.appendingPathComponent("reference.mov")
        if !FileManager.default.fileExists(atPath:source.path) { try await makeSource(source) }
        let asset=AVURLAsset(url:source)
        var p=Project(sourcePath:source.path,trimEnd:2);p.padding=0
        var reports: [[String:Any]]=[]
        let motionOnly=CommandLine.arguments.contains("--motion-only")
        for name in motionOnly ? []:["legacy-preset","high","efficient","master"] {
            let quality=VideoQuality(rawValue:name) ?? .high
            let output=directory.appendingPathComponent("\(name).\(quality.fileExtension)")
            let reuse=CommandLine.arguments.contains("--measure-only")
            if !reuse,FileManager.default.fileExists(atPath:output.path) { try FileManager.default.removeItem(at:output) }
            if reuse { } else if name == "legacy-preset" {
                let exporter=AVAssetExportSession(asset:asset,presetName:AVAssetExportPresetHighestQuality)!
                exporter.videoComposition=Renderer.composition(asset:asset,project:p)
                try await exporter.export(to:output,as:.mp4)
            } else { try await MediaExporter.export(asset:asset,project:p,quality:quality,to:output) }
            let result=try await measure(reference:asset,candidate:AVURLAsset(url:output),name:name,directory:directory)
            reports.append(result);print(result)
        }
        let timeline=AVMutableComposition()
        let sourceTrack=try await asset.loadTracks(withMediaType:.video)[0]
        let track=timeline.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid)!
        for i in 0..<4 { try track.insertTimeRange(CMTimeRange(start:.zero,duration:CMTime(seconds:2,preferredTimescale:600)),of:sourceTrack,at:CMTime(seconds:Double(i*2),preferredTimescale:600)) }
        var motionProject=Project(sourcePath:source.path,trimEnd:8)
        motionProject.cursorSamples=(0...960).map { i in
            let t=Double(i)/120
            let x=t<1 ? 0.15:t<1.35 ? 0.15+(t-1)/0.35*0.55:t<4 ? 0.7:t<4.4 ? 0.7-(t-4)/0.4*0.4:0.3
            return CursorSample(time:t,x:x,y:t<4.4 ? 0.35:0.65)
        }
        motionProject.zooms=AutoFocus.suggest(samples:motionProject.cursorSamples!,start:0,end:8)
        for (name,setting) in [("motion-recorded",PointerSmoothing.original),("motion-demo",.extraSmooth)] {
            motionProject.pointerSmoothing=setting
            let motionURL=directory.appendingPathComponent("\(name).mp4")
            if FileManager.default.fileExists(atPath:motionURL.path) { try FileManager.default.removeItem(at:motionURL) }
            try await MediaExporter.export(asset:timeline,project:motionProject,quality:.high,to:motionURL)
        }
        print("Motion: 8 seconds, \(motionProject.zooms.count) editable auto-focus regions, recorded and extra-smooth pointer variants")
        if motionOnly { return }
        let report: [String:Any]=["date":"2026-11-03","scope":"Synthetic SDR 1920x1080 screen-detail encode/decode; not live capture or competitor comparison", "reference":"ProRes 4444, 60fps, two seconds; decoded source is reference", "results":reports]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:directory.appendingPathComponent("quality-report.json"))
        print("Report: \(directory.appendingPathComponent("quality-report.json").path)")
    }
    static let width=1920,height=1080
    static func pattern(_ time:Double) -> CGImage {
        let c=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        c.setFillColor(CGColor(gray:1,alpha:1));c.fill(CGRect(x:0,y:0,width:width,height:height))
        c.translateBy(x:0,y:CGFloat(height));c.scaleBy(x:1,y:-1);c.setShouldAntialias(true)
        func text(_ value:String,_ x:CGFloat,_ y:CGFloat,_ size:CGFloat,_ color:CGColor) {
            let string=NSAttributedString(string:value,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):CTFontCreateWithName("HelveticaNeue" as CFString,size,nil),NSAttributedString.Key(kCTForegroundColorAttributeName as String):color])
            c.saveGState();c.translateBy(x:x,y:y+size);c.scaleBy(x:1,y:-1);c.textPosition = .zero;c.textMatrix = .identity;CTLineDraw(CTLineCreateWithAttributedString(string),c);c.restoreGState()
        }
        let ink=CGColor(gray:0.08,alpha:1),red=CGColor(red:0.85,green:0.08,blue:0.10,alpha:1),blue=CGColor(red:0.04,green:0.18,blue:0.9,alpha:1)
        text("VizuallyScreen screen-detail calibration · 1920 × 1080 · 60 fps",40,24,24,ink)
        for row in 0..<24 {
            let size=CGFloat([10,12,14,16][row%4]), y=80+CGFloat(row)*24
            text("AaBb 0123456789 · fine text should stay readable · const pixel = 1;",40,y,size,row%3==0 ? red:row%3==1 ? blue:ink)
        }
        for i in 0..<256 {
            c.setFillColor(i%2==0 ? ink:CGColor(gray:1,alpha:1));c.fill(CGRect(x:1100+i,y:100,width:1,height:256))
            c.setFillColor(i%2==0 ? red:blue);c.fill(CGRect(x:1100+i,y:390,width:1,height:200))
        }
        for i in 0..<8 { c.setFillColor(CGColor(gray:CGFloat(i)/7,alpha:1));c.fill(CGRect(x:40+i*100,y:760,width:100,height:100)) }
        let x=900+sin(time*4)*150
        c.setFillColor(blue);c.fill(CGRect(x:x,y:650,width:180,height:90))
        text("Moving panel",CGFloat(x)+10,675,18,CGColor(gray:1,alpha:1))
        c.setStrokeColor(ink);c.setLineWidth(1)
        for i in 0..<12 { c.move(to:CGPoint(x:40,y:900+i*3));c.addLine(to:CGPoint(x:900,y:900+i*3));c.strokePath() }
        return c.makeImage()!
    }
    static func makeSource(_ url:URL) async throws {
        let writer=try AVAssetWriter(outputURL:url,fileType:.mov)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:VideoQuality.master.videoSettings(width:width,height:height,fps:60))
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
        writer.add(input);guard writer.startWriting() else { throw writer.error! };writer.startSession(atSourceTime:.zero)
        for frame in 0..<120 {
            while !input.isReadyForMoreMediaData { if writer.status == .failed { throw writer.error! };try await Task.sleep(nanoseconds:1_000_000) }
            var buffer:CVPixelBuffer?;CVPixelBufferPoolCreatePixelBuffer(nil,adaptor.pixelBufferPool!,&buffer)
            let b=buffer!;CVPixelBufferLockBaseAddress(b,[])
            let context=CGContext(data:CVPixelBufferGetBaseAddress(b),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(b),space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Little.rawValue|CGImageAlphaInfo.premultipliedFirst.rawValue)!
            context.draw(pattern(Double(frame)/60),in:CGRect(x:0,y:0,width:width,height:height));CVPixelBufferUnlockBaseAddress(b,[])
            guard adaptor.append(b,withPresentationTime:CMTime(value:Int64(frame),timescale:60)) else { throw writer.error! }
        }
        input.markAsFinished();await writer.finishWriting();guard writer.status == .completed else { throw writer.error! }
    }
    static func pixels(_ image:CGImage) -> [UInt8] {
        let width=image.width,height=image.height
        var data=[UInt8](repeating:0,count:width*height*4)
        data.withUnsafeMutableBytes { bytes in
            let c=CGContext(data:bytes.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            c.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        }
        return data
    }
    static func measure(reference:AVAsset,candidate:AVAsset,name:String,directory:URL) async throws -> [String:Any] {
        let a=AVAssetImageGenerator(asset:reference),b=AVAssetImageGenerator(asset:candidate)
        a.requestedTimeToleranceBefore = .zero;a.requestedTimeToleranceAfter = .zero;b.requestedTimeToleranceBefore = .zero;b.requestedTimeToleranceAfter = .zero
        var error=0.0,textError=0.0,count=0,textCount=0
        for (index,t) in [0.25,0.75,1.25,1.75].enumerated() {
            let time=CMTime(seconds:t,preferredTimescale:600)
            let ref=try await a.image(at:time).image, image=try await b.image(at:time).image
            guard image.width==width,image.height==height else { throw MediaExporter.qualityError("Unexpected resized output") }
            let pa=pixels(ref),pb=pixels(image)
            for y in 0..<height { for x in 0..<width { for channel in 0..<3 { let i=(y*width+x)*4+channel;let d=Double(pa[i])-Double(pb[i]);error+=d*d;count+=1; } } }
            let textRect=CGRect(x:35,y:75,width:840,height:600)
            let ta=pixels(ref.cropping(to:textRect)!),tb=pixels(image.cropping(to:textRect)!)
            for base in stride(from:0,to:ta.count,by:4) { for channel in 0..<3 { let d=Double(ta[base+channel])-Double(tb[base+channel]);textError+=d*d;textCount+=1 } }
            if index==0 {
                for (label,full) in [(name,image),("reference",ref)] {
                    let destination=CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(label)-full.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
                    CGImageDestinationAddImage(destination,full,nil);CGImageDestinationFinalize(destination)
                    let detail=CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(label)-detail.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
                    CGImageDestinationAddImage(detail,full.cropping(to:CGRect(x:35,y:75,width:840,height:360))!,nil);CGImageDestinationFinalize(detail)
                }
                let crop=image.cropping(to:CGRect(x:35,y:75,width:840,height:360))!
                let destination=CGImageDestinationCreateWithURL(directory.appendingPathComponent("\(name)-text.png") as CFURL,UTType.png.identifier as CFString,1,nil)!
                CGImageDestinationAddImage(destination,crop,nil);CGImageDestinationFinalize(destination)
            }
        }
        let video=try await candidate.loadTracks(withMediaType:.video)[0]
        let descriptions=try await video.load(.formatDescriptions)
        let code=CMFormatDescriptionGetMediaSubType(descriptions[0])
        let codec=String(bytes:[UInt8((code>>24)&255),UInt8((code>>16)&255),UInt8((code>>8)&255),UInt8(code&255)],encoding:.ascii) ?? "unknown"
        let reader=try AVAssetReader(asset:candidate),output=AVAssetReaderTrackOutput(track:video,outputSettings:nil);reader.add(output);reader.startReading()
        var times:[Double]=[]
        while let sample=output.copyNextSampleBuffer() { if CMSampleBufferGetNumSamples(sample)>0 { times.append(sample.presentationTimeStamp.seconds) } }
        times.sort()
        let frames=times.count
        var maxGap=0.0
        for i in 1..<times.count { maxGap=max(maxGap,times[i]-times[i-1]) }
        return ["profile":name,"codec":codec,"duration":try await candidate.load(.duration).seconds,"firstPTS":times.first ?? 0,"lastPTS":times.last ?? 0,"width":width,"height":height,"fps":try await video.load(.nominalFrameRate),"frames":frames,"maxFrameGapMs":maxGap*1000,"actualBitrateMbps":Double(try await video.load(.estimatedDataRate))/1_000_000,"rgbPSNR":10*log10(255*255/max(0.000001,error/Double(count))),"textROI_PSNR":10*log10(255*255/max(0.000001,textError/Double(textCount)))]
    }
}
