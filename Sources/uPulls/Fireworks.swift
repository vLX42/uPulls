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
}

@MainActor
enum Fireworks {
    private static var windows: [NSWindow] = []

    static func launch(_ tuning: FireworksTuning = FireworksTuning()) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let size = screen.frame.size
        let duration = max(1, tuning.duration)

        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.isOpaque = false
        window.backgroundColor = .clear
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

        let dot = particleImage()
        let rockets = rocketEmitter(size: size, dot: dot, tuning: tuning)
        let bursts = burstEmitter(size: size, dot: dot, tuning: tuning)
        view.layer?.addSublayer(rockets)
        view.layer?.addSublayer(bursts)
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

    private static func rocketEmitter(size: CGSize, dot: CGImage?, tuning: FireworksTuning) -> CAEmitterLayer {
        let e = baseEmitter(size: size)
        e.emitterPosition = CGPoint(x: size.width / 2, y: size.height)
        e.emitterSize = CGSize(width: size.width * 0.7, height: 2)
        e.emitterCells = palette.map { color in
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
            rocket.alphaSpeed = -0.6
            rocket.color = color.cgColor

            let trail = CAEmitterCell()
            trail.contents = dot
            trail.birthRate = 60
            trail.lifetime = 0.35
            trail.velocity = 20
            trail.emissionRange = .pi * 2
            trail.scale = 0.18
            trail.scaleSpeed = -0.4
            trail.alphaSpeed = -2.5
            trail.color = color.withAlphaComponent(0.7).cgColor
            rocket.emitterCells = [trail]
            return rocket
        }
        return e
    }

    private static func burstEmitter(size: CGSize, dot: CGImage?, tuning: FireworksTuning) -> CAEmitterLayer {
        let e = baseEmitter(size: size)
        e.emitterPosition = CGPoint(x: size.width / 2, y: size.height * 0.32)
        e.emitterSize = CGSize(width: size.width * 0.7, height: size.height * 0.36)
        e.emitterCells = palette.map { color in
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
            spark.scale = 0.22 * tuning.sparkSize
            spark.scaleRange = 0.08 * tuning.sparkSize
            spark.scaleSpeed = -0.1
            spark.alphaSpeed = -0.8
            spark.spin = 2
            spark.color = color.withAlphaComponent(0.85).cgColor
            spark.redRange = 0.1
            spark.greenRange = 0.1
            spark.blueRange = 0.1

            shell.emitterCells = [spark]
            return shell
        }
        return e
    }

    private final class FlippedView: NSView {
        override var isFlipped: Bool { true }
    }

    /// Soft radial dot used for every particle.
    private static func particleImage() -> CGImage? {
        let side = 32
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { rect in
            let gradient = NSGradient(colors: [NSColor.white, NSColor.white.withAlphaComponent(0)])
            gradient?.draw(in: NSBezierPath(ovalIn: rect), relativeCenterPosition: .zero)
            return true
        }
        return image.cgImage(forProposedRect: nil, context: nil, hints: nil)
    }
}
