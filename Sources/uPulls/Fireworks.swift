import AppKit
import QuartzCore

/// Full-screen, click-through overlay that fires a short volley of
/// CAEmitterLayer fireworks and then removes itself.
///
/// Two independent emitters: rockets rising from the bottom (pure eye candy)
/// and bursts popping in the upper half of the screen. Decoupling them keeps
/// the bursts dense and reliable; a chained rocket→burst cell tree leaves the
/// burst timing to chance and mostly fizzles.
/// User-tweakable knobs (Settings → Fireworks). All multipliers on the defaults.
struct FireworksTuning: Codable, Equatable {
    var duration: Double = 3.2     // seconds of launching
    var intensity: Double = 1.0    // rockets + bursts per second
    var sparkSize: Double = 1.0
    var spread: Double = 1.0       // burst radius
    /// Peak brightness in display headroom multiples. 1.0 = plain SDR white,
    /// higher values light the sparks past white on an XDR/HDR display.
    var hdrGain: Double = 3.0

    private enum CodingKeys: String, CodingKey { case duration, intensity, sparkSize, spread, hdrGain }

    init() {}

    init(duration: Double = 3.2, intensity: Double = 1.0, sparkSize: Double = 1.0, spread: Double = 1.0, hdrGain: Double = 3.0) {
        self.duration = duration; self.intensity = intensity; self.sparkSize = sparkSize; self.spread = spread; self.hdrGain = hdrGain
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 3.2
        intensity = try c.decodeIfPresent(Double.self, forKey: .intensity) ?? 1.0
        sparkSize = try c.decodeIfPresent(Double.self, forKey: .sparkSize) ?? 1.0
        spread = try c.decodeIfPresent(Double.self, forKey: .spread) ?? 1.0
        hdrGain = try c.decodeIfPresent(Double.self, forKey: .hdrGain) ?? 3.0
    }
}

@MainActor
enum Fireworks {
    private static var windows: [NSWindow] = []

    /// `backdrop` paints the overlay black: used to take clean promo captures.
    static func launch(_ tuning: FireworksTuning = FireworksTuning(), backdrop: Bool = false) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = screen.frame.size
        let duration = max(1, tuning.duration)

        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = backdrop ? NSColor(calibratedRed: 0.04, green: 0.04, blue: 0.07, alpha: 1) : .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        window.isReleasedWhenClosed = false

        // Flipped view → top-left origin, so "up" is a negative y direction and
        // positive yAcceleration is gravity, matching the usual emitter recipes.
        let view = FlippedView(frame: NSRect(origin: .zero, size: size))
        view.wantsLayer = true
        window.contentView = view

        // Extended-range backing store: without it the window clips everything at white.
        if let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
           let ns = NSColorSpace(cgColorSpace: space) {
            window.colorSpace = ns
        }

        let gain = min(max(1.0, CGFloat(tuning.hdrGain)), headroom(of: screen))
        let rockets = rocketEmitter(size: size, tuning: tuning, gain: 1 + (gain - 1) * 0.55)
        let bursts = burstEmitter(size: size, tuning: tuning, gain: gain)
        if let root = view.layer { enableEDR(root) }
        enableEDR(rockets)
        enableEDR(bursts)
        view.layer?.addSublayer(rockets)
        view.layer?.addSublayer(bursts)
        NSLog("[uPulls] fireworks gain %.2f (screen headroom now %.2f, potential %.2f)",
              gain, screen.maximumExtendedDynamicRangeColorComponentValue,
              screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
        window.orderFrontRegardless()
        windows.append(window)

        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            rockets.birthRate = 0
            bursts.birthRate = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 3) {
            window.orderOut(nil)
            windows.removeAll { $0 === window }
        }
    }

    /// How much brighter than SDR white this screen can currently go.
    /// `maximum…` is what is available right now, `maximumPotential…` is what the
    /// panel could do once EDR content is on screen, which is what we are about to be.
    /// What this panel could reach once EDR content is on screen. The "current"
    /// value sits at 1.0 until such content appears, so it cannot be used as the
    /// ceiling: that would keep EDR from ever engaging.
    static func headroom(of screen: NSScreen?) -> CGFloat {
        guard let screen else { return 1 }
        return max(1, screen.maximumPotentialExtendedDynamicRangeColorComponentValue)
    }

    /// Opt the layer into extended dynamic range and a float backing store, so
    /// component values above 1.0 survive instead of being clipped to white.
    /// Both the modern and the deprecated switch are set: on macOS 26 the new
    /// property alone still tone maps unless tone mapping is turned off too.
    private static func enableEDR(_ layer: CALayer) {
        layer.contentsFormat = .RGBA16Float
        layer.wantsExtendedDynamicRangeContent = true
        if #available(macOS 26.0, *) { layer.preferredDynamicRange = .high }
        if #available(macOS 15.0, *) { layer.toneMapMode = .never }
    }

    private static let palette: [NSColor] = [
        NSColor(calibratedRed: 1.00, green: 0.42, blue: 0.42, alpha: 1),
        NSColor(calibratedRed: 1.00, green: 0.80, blue: 0.30, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.90, blue: 0.60, alpha: 1),
        NSColor(calibratedRed: 0.45, green: 0.70, blue: 1.00, alpha: 1),
        NSColor(calibratedRed: 0.85, green: 0.55, blue: 1.00, alpha: 1),
    ]

    private static func baseEmitter(size: CGSize) -> CAEmitterLayer {
        let e = CAEmitterLayer()
        e.frame = CGRect(origin: .zero, size: size)
        e.renderMode = .additive
        e.emitterShape = .rectangle   // `.line` never releases its particles on macOS
        e.beginTime = CACurrentMediaTime()
        return e
    }

    private static func rocketEmitter(size: CGSize, tuning: FireworksTuning, gain: CGFloat) -> CAEmitterLayer {
        let e = baseEmitter(size: size)
        e.emitterPosition = CGPoint(x: size.width / 2, y: size.height)
        e.emitterSize = CGSize(width: size.width * 0.7, height: 2)
        e.emitterCells = palette.map { color in
            let dot = sprite(color, gain: gain)
            let rocket = CAEmitterCell()
            rocket.contents = dot
            rocket.birthRate = Float(0.9 * tuning.intensity)
            rocket.lifetime = 1.1
            rocket.velocity = size.height * 0.75
            rocket.velocityRange = size.height * 0.15
            rocket.emissionLongitude = -.pi / 2
            rocket.emissionRange = .pi / 12
            rocket.yAcceleration = size.height * 0.3
            rocket.scale = 0.3 * tuning.sparkSize
            rocket.scaleSpeed = -0.15
            rocket.alphaSpeed = -0.7

            // No trail sub-cell: a parent cell with an image plus an image-bearing child
            // makes Core Animation draw the parent as a flat square (verified on macOS 26).
            return rocket
        }
        return e
    }

    private static func burstEmitter(size: CGSize, tuning: FireworksTuning, gain: CGFloat) -> CAEmitterLayer {
        let e = baseEmitter(size: size)
        e.emitterPosition = CGPoint(x: size.width / 2, y: size.height * 0.32)
        e.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.36)
        e.emitterCells = palette.map { color in
            let dot = sprite(color, gain: gain)
            // Invisible, near-instant shell: its lifetime × spark birthRate = sparks per burst.
            let shell = CAEmitterCell()
            shell.birthRate = Float(0.5 * tuning.intensity)
            shell.lifetime = 0.04
            shell.velocity = 0

            let spark = CAEmitterCell()
            spark.contents = dot
            spark.birthRate = 2200          // × 0.04 s ≈ 90 sparks
            spark.lifetime = 1.4
            spark.lifetimeRange = 0.5
            spark.velocity = size.height * 0.26 * tuning.spread
            spark.velocityRange = size.height * 0.1 * tuning.spread
            spark.emissionRange = .pi * 2
            spark.yAcceleration = size.height * 0.1
            spark.scale = 0.3 * tuning.sparkSize
            spark.scaleRange = 0.1 * tuning.sparkSize
            spark.scaleSpeed = -0.1
            spark.alphaSpeed = -0.8
            spark.spin = 2

            shell.emitterCells = [spark]
            return shell
        }
        return e
    }

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// One soft radial dot per palette colour, drawn as a half-float image in
    /// extended linear Display P3 with premultiplied components above 1.0.
    /// The brightness has to live in the image: a CGColor tint on the emitter
    /// cell does not make Core Animation treat the layer as HDR (measured).
    private static func sprite(_ color: NSColor, gain: CGFloat) -> CGImage? {
        let side = 64
        guard let space = CGColorSpace(name: CGColorSpace.extendedLinearDisplayP3),
              let p3 = color.usingColorSpace(.displayP3) else { return nil }
        func linear(_ c: CGFloat) -> Float { Float(c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)) }
        let rgb = (linear(p3.redComponent), linear(p3.greenComponent), linear(p3.blueComponent))
        let peak = Float(max(1, gain))

        var px = [Float16](repeating: 0, count: side * side * 4)
        let c = Float(side) / 2
        for y in 0..<side {
            for x in 0..<side {
                let d = min(1, sqrt(pow(Float(x) + 0.5 - c, 2) + pow(Float(y) + 0.5 - c, 2)) / c)
                let alpha = max(0, 1 - d) * max(0, 1 - d)       // soft falloff
                let f = alpha * peak                             // premultiplied, so > 1 in the core
                let i = (y * side + x) * 4
                px[i + 0] = Float16(rgb.0 * f)
                px[i + 1] = Float16(rgb.1 * f)
                px[i + 2] = Float16(rgb.2 * f)
                px[i + 3] = Float16(alpha * Float(p3.alphaComponent))
            }
        }
        let info = CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder16Little.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        return px.withUnsafeMutableBytes { buf in
            CGContext(data: buf.baseAddress, width: side, height: side, bitsPerComponent: 16,
                      bytesPerRow: side * 8, space: space, bitmapInfo: info)?.makeImage()
        }
    }
}
