import Foundation

/// Deterministic pointer-dwell suggestions. No click or eye-gaze data is inferred.
package enum AutoFocus {
    package static func merge(_ suggestions:[Zoom],with existing:[Zoom]) -> [Zoom] {
        let manual=existing.filter { $0.automatic != true }
        return manual+suggestions.filter { suggestion in
            !manual.contains { $0.start<suggestion.start+suggestion.duration && suggestion.start<$0.start+$0.duration }
        }
    }
    package static func suggest(samples:[CursorSample],start:Double,end:Double) -> [Zoom] {
        guard end-start>=1,samples.count>2 else { return [] }
        let prepared=Motion.smooth(samples,sigma:0.08)
        var visits:[(start:Double,end:Double,x:Double,y:Double)]=[]
        var began:Double?,last:CursorSample?,sx=0.0,sy=0.0,count=0
        var travelled=0.0
        var origin:CursorSample?
        func finish(_ time:Double) {
            if let began,time-began>=0.65,count>0,travelled>=0.06 {
                visits.append((began,time,sx/Double(count),sy/Double(count)))
            }
            began=nil;sx=0;sy=0;count=0
        }
        // Bound analysis to 10Hz regardless of the captured sample frequency.
        for t in stride(from:start,through:end,by:0.1) {
            guard let point=Motion.cursor(at:t,samples:prepared) else { finish(t);last=nil;continue }
            if origin == nil { origin=point }
            if let previous=last {
                let distance=hypot(point.x-previous.x,point.y-previous.y)
                if let origin { travelled=max(travelled,hypot(point.x-origin.x,point.y-origin.y)) }
                let speed=distance/max(0.001,point.time-previous.time)
                let centerDistance=count>0 ? hypot(point.x-sx/Double(count),point.y-sy/Double(count)):0
                if speed>0.32 || centerDistance>0.055 { finish(previous.time) }
                if speed<=0.32 {
                    if began == nil { began=t }
                    sx += point.x;sy += point.y;count += 1
                }
            }
            last=point
        }
        finish(min(end,last?.time ?? end))
        var result:[Zoom]=[]
        for visit in visits {
            let from=max(start,visit.start-0.5),to=min(end,visit.end+0.7)
            if let previous=result.last,hypot(previous.x-visit.x,previous.y-visit.y)<0.09,from-(previous.start+previous.duration)<1.2 {
                result[result.count-1].duration=to-previous.start
                continue
            }
            guard to-from>=1 else { continue }
            result.append(Zoom(start:from,duration:to-from,scale:1.65,x:visit.x,y:visit.y,automatic:true))
        }
        return result
    }
}
