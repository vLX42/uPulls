import AppKit

/// Dev-only: `open build/uPulls.app --args --snapshot /tmp/shots` opens the
/// popover, then writes a PNG per visible window owned by this process.
/// Own windows are captured via the window server when the process is allowed
/// to (Screen Recording granted to whatever launched it) and via
/// `cacheDisplay` otherwise, which renders our own view tree without any
/// permission but skips Core Animation particle content.
@MainActor
enum DebugSnapshot {
    static func capture(to directory: String) {
        let dir = URL(fileURLWithPath: directory)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        var n = 0
        for window in NSApp.windows where window.isVisible {
            guard let view = window.contentView, view.bounds.width > 40, view.bounds.height > 40 else { continue }
            let id = CGWindowID(window.windowNumber)
            var png: Data?
            var method = "windowserver"
            if let cg = CGWindowListCreateImage(.null, .optionIncludingWindow, id, [.boundsIgnoreFraming, .bestResolution]),
               cg.width > 1 {
                // Transparent overlays (fireworks) are unreadable on a white viewer; flatten onto black.
                let flat = NSImage(size: NSSize(width: cg.width, height: cg.height), flipped: false) { rect in
                    if !window.isOpaque { NSColor.black.setFill(); rect.fill() }
                    NSImage(cgImage: cg, size: rect.size).draw(in: rect)
                    return true
                }
                if let tiff = flat.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
                    png = rep.representation(using: .png, properties: [:])
                }
            }
            if png == nil, let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) {
                method = "cacheDisplay"
                view.cacheDisplay(in: view.bounds, to: rep)
                png = rep.representation(using: .png, properties: [:])
            }
            guard let png else {
                NSLog("[uPulls] snapshot: could not capture window %d (%@)", window.windowNumber, String(describing: type(of: window)))
                continue
            }
            n += 1
            let name = String(format: "%02d-%@-%dx%d-%@.png", n, String(describing: type(of: window)),
                              Int(view.bounds.width), Int(view.bounds.height), method)
            try? png.write(to: dir.appendingPathComponent(name))
        }
        NSLog("[uPulls] snapshot: %d window(s) written to %@", n, directory)
    }
}
