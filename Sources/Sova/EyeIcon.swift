import AppKit

/// The menu bar eye, drawn once into template images (no animation, no redraws).
/// Closed: solid lens, lashes below. Open: lens outline, pupil with a highlight, lashes above.
/// The geometry is the Insomnia app icon's, on a 24-unit grid with y pointing down.
enum EyeIcon {
    @MainActor static let closed = draw(open: false)
    @MainActor static let open = draw(open: true)

    private static let left = CGPoint(x: 1.5, y: 12)
    private static let right = CGPoint(x: 22.5, y: 12)

    /// A point on the upper lid, `t` from 0 (left corner) to 1 (right corner).
    private static func lid(_ t: CGFloat) -> CGPoint {
        let (c1, c2) = (CGPoint(x: 7, y: 4.5), CGPoint(x: 17, y: 4.5))
        let u = 1 - t
        let (a, b, c, d) = (u * u * u, 3 * u * u * t, 3 * u * t * t, t * t * t)
        return CGPoint(x: a * left.x + b * c1.x + c * c2.x + d * right.x, y: a * left.y + b * c1.y + c * c2.y + d * right.y)
    }

    private static func draw(open: Bool) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return false }
            ctx.scaleBy(x: size / 24, y: size / 24)
            ctx.setFillColor(NSColor.black.cgColor)
            ctx.setStrokeColor(NSColor.black.cgColor)
            ctx.setLineWidth(1.5)
            ctx.setLineCap(.round)

            ctx.move(to: left)
            ctx.addCurve(to: right, control1: CGPoint(x: 7, y: 4.5), control2: CGPoint(x: 17, y: 4.5))
            ctx.addCurve(to: left, control1: CGPoint(x: 17, y: 19.5), control2: CGPoint(x: 7, y: 19.5))
            ctx.closePath()
            if open { ctx.strokePath() } else { ctx.fillPath() }

            if open {
                ctx.fillEllipse(in: CGRect(x: 8, y: 8, width: 8, height: 8))
                ctx.setBlendMode(.clear)
                ctx.fillEllipse(in: CGRect(x: 14 - 1.4, y: 10 - 1.4, width: 2.8, height: 2.8))
                ctx.setBlendMode(.normal)
            }

            // Five lashes along the outward normal of the upper lid; mirrored below the lens for the closed eye.
            for fraction in [0.2, 0.35, 0.5, 0.65, 0.8] as [CGFloat] {
                var (lo, hi): (CGFloat, CGFloat) = (0, 1)
                for _ in 0..<30 {
                    let mid = (lo + hi) / 2
                    if lid(mid).x < left.x + (right.x - left.x) * fraction { lo = mid } else { hi = mid }
                }
                let t = (lo + hi) / 2
                let (a, b, base) = (lid(t - 0.01), lid(t + 0.01), lid(t))
                let length = hypot(b.x - a.x, b.y - a.y)
                let normal = CGPoint(x: (b.y - a.y) / length, y: -(b.x - a.x) / length)
                func point(_ distance: CGFloat) -> CGPoint {
                    let y = base.y + normal.y * distance
                    return CGPoint(x: base.x + normal.x * distance, y: open ? y : 24 - y)
                }
                ctx.move(to: point(2.25))
                ctx.addLine(to: point(5))
                ctx.strokePath()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
