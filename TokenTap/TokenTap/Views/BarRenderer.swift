import AppKit

/// Renders a single vertical fill bar as an NSImage for the menu bar.
/// Color changes based on usage thresholds: blue (normal), amber (warning), red (critical).
struct BarRenderer {

    static func render(
        percent: Double?,
        warningThreshold: Double = 80,
        criticalThreshold: Double = 90
    ) -> NSImage {
        let barWidth: CGFloat = 10
        let barHeight: CGFloat = 16
        let cornerRadius: CGFloat = 3.5

        let fillColor = colorForPercent(percent, warning: warningThreshold, critical: criticalThreshold)

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

            fillColor.setFill()
            NSBezierPath(rect: fillRect).fill()

            NSGraphicsContext.current?.cgContext.restoreGState()

            return true
        }

        image.isTemplate = false
        return image
    }

    private static func colorForPercent(_ percent: Double?, warning: Double, critical: Double) -> NSColor {
        guard let pct = percent else { return NSColor(red: 0.30, green: 0.75, blue: 1.0, alpha: 1.0) }
        if pct >= critical { return NSColor(red: 0.95, green: 0.20, blue: 0.20, alpha: 1.0) }
        if pct >= warning { return NSColor(red: 0.85, green: 0.65, blue: 0.0, alpha: 1.0) }
        return NSColor(red: 0.30, green: 0.75, blue: 1.0, alpha: 1.0)
    }
}
