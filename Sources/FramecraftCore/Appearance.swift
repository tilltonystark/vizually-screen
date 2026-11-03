import Foundation

package struct Appearance: Codable, Equatable {
    package var accentHue: Double = 265
    package var canvasLightness: Double = 0.955
    package var radius: Double = 10
    package var spacing: Double = 20
    package init() {}
    package func validate() throws {
        guard accentHue.isFinite, (230...300).contains(accentHue), canvasLightness.isFinite,
              (0.92...0.98).contains(canvasLightness), radius.isFinite, (6...16).contains(radius),
              spacing.isFinite, (16...28).contains(spacing) else {
            throw NSError(domain: "Appearance", code: 1, userInfo: [NSLocalizedDescriptionKey: "Appearance values are outside their supported ranges."])
        }
    }
}

package enum StudioColor {
    // OKLCH authoring → gamut-mapped sRGB for the native drawing system.
    package static func rgb(_ lightness: Double, _ chroma: Double = 0, _ hue: Double = 265) -> (Double, Double, Double) {
        func linear(_ c: Double) -> (Double, Double, Double) {
            let a = c * cos(hue * .pi / 180), b = c * sin(hue * .pi / 180)
            let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
            let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
            let s = pow(lightness - 0.0894841775 * a - 1.291485548 * b, 3)
            return (4.0767416621*l - 3.3077115913*m + 0.2309699292*s,
                    -1.2684380046*l + 2.6097574011*m - 0.3413193965*s,
                    -0.0041960863*l - 0.7034186147*m + 1.707614701*s)
        }
        var c = chroma
        var v = linear(c)
        for _ in 0..<100 {
            if min(v.0, v.1, v.2) >= -0.000001 && max(v.0, v.1, v.2) <= 1.000001 { break }
            c *= 0.95; v = linear(c)
        }
        func gamma(_ x: Double) -> Double { let x = max(0, min(1, x)); return x <= 0.0031308 ? 12.92*x : 1.055*pow(x, 1/2.4)-0.055 }
        return (gamma(v.0), gamma(v.1), gamma(v.2))
    }
    package static func contrast(_ a: (Double, Double, Double), _ b: (Double, Double, Double)) -> Double {
        func luminance(_ v: (Double, Double, Double)) -> Double {
            func linear(_ n: Double) -> Double { n <= 0.04045 ? n / 12.92 : pow((n + 0.055) / 1.055, 2.4) }
            return 0.2126*linear(v.0) + 0.7152*linear(v.1) + 0.0722*linear(v.2)
        }
        let x = luminance(a), y = luminance(b)
        return (max(x,y)+0.05)/(min(x,y)+0.05)
    }
}
