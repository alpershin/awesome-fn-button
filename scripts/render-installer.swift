import AppKit

let arguments = CommandLine.arguments
guard arguments.count == 3, let fist = NSImage(contentsOfFile: arguments[1]) else {
    fatalError("Usage: swift render-installer.swift <fist.png> <output-directory>")
}
let output = URL(fileURLWithPath: arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
let canvas = NSSize(width: 720, height: 420)

func rgb(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat) -> NSColor {
    NSColor(srgbRed: red / 255, green: green / 255, blue: blue / 255, alpha: 1)
}

func text(_ value: String, y: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (value as NSString).draw(in: NSRect(x: 30, y: y, width: 660, height: size + 12), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

func render(scale: Int) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
                                  pixelsWide: 720 * scale, pixelsHigh: 420 * scale,
                                  bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                  isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
    rgb(244, 245, 246).setFill()
    NSRect(origin: .zero, size: canvas).fill()

    text("Install Awesome Fn Button", y: 326, size: 25, weight: .bold, color: rgb(48, 42, 48))
    text("Drag the app into Applications", y: 296, size: 16, weight: .regular, color: rgb(113, 105, 110))

    for x in [CGFloat(89), CGFloat(479)] {
        let pad = NSBezierPath(roundedRect: NSRect(x: x, y: 100, width: 152, height: 176), xRadius: 30, yRadius: 30)
        NSColor.white.withAlphaComponent(0.7).setFill()
        pad.fill()
        rgb(232, 213, 199).withAlphaComponent(0.65).setStroke()
        pad.lineWidth = 1
        pad.stroke()
    }
    let fit = min(220 / fist.size.width, 170 / fist.size.height)
    let fitted = NSSize(width: fist.size.width * fit, height: fist.size.height * fit)
    fist.draw(in: NSRect(x: 360 - fitted.width / 2, y: 205 - fitted.height / 2,
                        width: fitted.width, height: fitted.height))

    NSGraphicsContext.restoreGraphicsState()
    bitmap.size = canvas
    return bitmap
}

let representations = [render(scale: 1), render(scale: 2)]
guard let tiff = NSBitmapImageRep.representationOfImageReps(in: representations, using: .tiff, properties: [:]),
      let png = representations[1].representation(using: .png, properties: [:]) else {
    fatalError("Could not encode installer artwork")
}
try tiff.write(to: output.appendingPathComponent("background.tiff"))
try png.write(to: output.appendingPathComponent("background-preview.png"))
