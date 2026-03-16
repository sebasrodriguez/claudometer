import AppKit

/// Renders a single vertical fill bar as an NSImage for the menu bar.
/// Shows session usage, filling from bottom to top.
struct BarRenderer {

    static func render(percent: Double?) -> NSImage {
        let barWidth: CGFloat = 10
        let barHeight: CGFloat = 16
        let cornerRadius: CGFloat = 3.5

        let image = NSImage(size: NSSize(width: barWidth, height: barHeight), flipped: false) { rect in
            let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)

            // Track background
            NSColor.white.withAlphaComponent(0.15).setFill()
            path.fill()

            // Dark border for visibility
            NSColor.black.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.5
            path.stroke()

            // Active fill from bottom
            guard let pct = percent, pct > 0 else { return true }
            let fillHeight = rect.height * min(pct, 100.0) / 100.0
            let fillRect = CGRect(x: 0, y: 0, width: rect.width, height: fillHeight)

            NSGraphicsContext.current?.cgContext.saveGState()
            path.addClip()

            // Bright white/blue fill — high contrast on dark menu bar
            NSColor(red: 0.30, green: 0.75, blue: 1.0, alpha: 1.0).setFill()
            NSBezierPath(rect: fillRect).fill()

            NSGraphicsContext.current?.cgContext.restoreGState()

            return true
        }

        image.isTemplate = false
        return image
    }
}
