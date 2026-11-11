import CoreGraphics

/// Crop coordinates are normalized against the upright source, with a top-left origin.
package struct VideoCrop: Codable, Equatable {
    package let x: Double
    package let y: Double
    package let width: Double
    package let height: Double

    package init(_ rect: CGRect) {
        x = rect.minX; y = rect.minY; width = rect.width; height = rect.height
    }

    package var rect: CGRect { CGRect(x: x, y: y, width: width, height: height) }
    package var isValid: Bool {
        [x,y,width,height].allSatisfy(\.isFinite) && x >= 0 && y >= 0 &&
        width >= 0.01 && height >= 0.01 && x + width <= 1.00000001 && y + height <= 1.00000001
    }

    // Core Image uses bottom-left coordinates. Even output dimensions keep 4:2:0 encoders happy.
    package func pixelRect(in size: CGSize) -> CGRect {
        let left = min(size.width - 2, max(0, (x * size.width).rounded()))
        let bottom = min(size.height - 2, max(0, ((1 - y - height) * size.height).rounded()))
        let w = max(2, floor(min(size.width - left, (width * size.width).rounded()) / 2) * 2)
        let h = max(2, floor(min(size.height - bottom, (height * size.height).rounded()) / 2) * 2)
        return CGRect(x: left, y: bottom, width: w, height: h)
    }
}
