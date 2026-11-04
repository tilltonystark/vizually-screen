import Foundation

package struct CursorSample: Codable, Equatable {
    package var time: Double
    package var x: Double
    package var y: Double
    package var visible: Bool
    package init(time: Double, x: Double, y: Double, visible: Bool = true) { self.time=time;self.x=x;self.y=y;self.visible=visible }
}
package enum PointerSmoothing: String, Codable, CaseIterable, Identifiable {
    case original, smooth, extraSmooth
    package var id:String { rawValue }
    package var name:String { switch self { case .original:return "Recorded";case .smooth:return "Smooth";case .extraSmooth:return "Extra smooth" } }
    package var sigma:Double { switch self { case .original:return 0;case .smooth:return 0.055;case .extraSmooth:return 0.10 } }
}
package enum Motion {
    package static func ease(_ t: Double) -> Double { let t = min(1,max(0,t)); return t*t*t*(t*(t*6-15)+10) }
    package static func smooth(_ samples: [CursorSample], sigma:Double = 0.024) -> [CursorSample] {
        guard sigma>0,!samples.isEmpty else { return samples }
        // Symmetric offline filtering eases sharp turns without a causal lag.
        // Bound neighborhoods by timestamps, not an assumed sample frequency.
        var left=0,right=0
        return samples.enumerated().map { index,value in
            while left<index,samples[left].time<value.time-sigma*3 { left += 1 }
            right=max(right,index)
            while right+1<samples.count,samples[right+1].time<=value.time+sigma*3 { right += 1 }
            guard value.visible else { return value }
            var sx=0.0,sy=0.0,weight=0.0
            // Do not smooth across a visibility break or an interrupted sample stream.
            var lo=index,hi=index
            while lo>left,samples[lo-1].visible,samples[lo].time-samples[lo-1].time<0.1 { lo -= 1 }
            while hi<right,samples[hi+1].visible,samples[hi+1].time-samples[hi].time<0.1 { hi += 1 }
            for i in lo...hi {
                let other=samples[i],dt=other.time-value.time
                let w=exp(-0.5*pow(dt/sigma,2));sx += other.x*w;sy += other.y*w;weight += w
            }
            return CursorSample(time:value.time,x:sx/max(weight,0.001),y:sy/max(weight,0.001),visible:true)
        }
    }
    package static func cursor(at time: Double, samples: [CursorSample]) -> CursorSample? {
        guard let first=samples.first, let last=samples.last, time>=first.time, time<=last.time+0.1 else { return nil }
        if time>=last.time { return last.visible ? last:nil }
        var low=0,high=samples.count-1
        while low<high { let mid=(low+high)/2; if samples[mid].time<time { low=mid+1 } else { high=mid } }
        let b=samples[low], a=samples[max(0,low-1)]
        guard a.visible,b.visible else { return nil }
        guard b.time-a.time<0.15 else { return nil }
        let previous=samples[max(0,low-2)],next=samples[min(samples.count-1,low+1)]
        let duration=max(0.000001,b.time-a.time),t=min(1,max(0,(time-a.time)/duration))
        func interpolate(_ key:KeyPath<CursorSample,Double>) -> Double {
            let slope=(b[keyPath:key]-a[keyPath:key])/duration
            func tangent(_ before:CursorSample,_ point:CursorSample,_ after:CursorSample) -> Double {
                guard before.visible,after.visible,point.time>before.time,after.time>point.time else { return slope }
                let left=(point[keyPath:key]-before[keyPath:key])/(point.time-before.time)
                let right=(after[keyPath:key]-point[keyPath:key])/(after.time-point.time)
                guard left*right>0 else { return 0 }
                return 2*left*right/(left+right)
            }
            let m0=tangent(previous,a,b)*duration,m1=tangent(a,b,next)*duration
            let value=(2*t*t*t-3*t*t+1)*a[keyPath:key]+(t*t*t-2*t*t+t)*m0+(-2*t*t*t+3*t*t)*b[keyPath:key]+(t*t*t-t*t)*m1
            return min(max(a[keyPath:key],b[keyPath:key]),max(min(a[keyPath:key],b[keyPath:key]),value))
        }
        return CursorSample(time:time,x:interpolate(\.x),y:interpolate(\.y))
    }
}
