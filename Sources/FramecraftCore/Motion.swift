import Foundation

package struct CursorSample: Codable, Equatable {
    package var time: Double
    package var x: Double
    package var y: Double
    package var visible: Bool
    package init(time: Double, x: Double, y: Double, visible: Bool = true) { self.time=time;self.x=x;self.y=y;self.visible=visible }
}
package enum Motion {
    package static func ease(_ t: Double) -> Double { let t = min(1,max(0,t)); return t*t*t*(t*(t*6-15)+10) }
    package static func smooth(_ samples: [CursorSample]) -> [CursorSample] {
        // Offline, symmetric 24ms Gaussian: removes hand jitter without delaying the pointer.
        samples.enumerated().map { index, value in
            guard value.visible else { return value }
            var sx=0.0, sy=0.0, weight=0.0
            let range=max(0,index-12)...min(samples.count-1,index+12)
            for i in range {
                let other=samples[i], dt=other.time-value.time
                guard other.visible, abs(dt)<0.072 else { continue }
                let w=exp(-0.5*pow(dt/0.024,2)); sx += other.x*w;sy += other.y*w;weight += w
            }
            return CursorSample(time:value.time,x:sx/max(weight,0.001),y:sy/max(weight,0.001),visible:true)
        }
    }
    package static func cursor(at time: Double, samples: [CursorSample]) -> CursorSample? {
        guard let first=samples.first, let last=samples.last, time>=first.time, time<=last.time else { return nil }
        var low=0,high=samples.count-1
        while low<high { let mid=(low+high)/2; if samples[mid].time<time { low=mid+1 } else { high=mid } }
        let b=samples[low], a=samples[max(0,low-1)]
        guard a.visible,b.visible else { return nil }
        let t=min(1,max(0,(time-a.time)/max(0.000001,b.time-a.time)))
        return CursorSample(time:time,x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t)
    }
}
