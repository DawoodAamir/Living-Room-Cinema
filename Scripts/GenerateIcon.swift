import AppKit

func render(width: Int, height: Int, foreground: Bool, background: Bool, path: String) throws {
  let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8,
    samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0,
    bitsPerPixel: 0)!
  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
  if background {
    NSColor(calibratedRed: 0.04, green: 0.13, blue: 0.17, alpha: 1).setFill()
    NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()
  }
  if foreground {
    let w = CGFloat(width)
    let h = CGFloat(height)
    NSColor(calibratedRed: 0.91, green: 0.73, blue: 0.44, alpha: 1).setStroke()
    let screen = NSBezierPath(
      roundedRect: NSRect(x: w * 0.24, y: h * 0.23, width: w * 0.52, height: h * 0.55),
      xRadius: h * 0.05, yRadius: h * 0.05)
    screen.lineWidth = h * 0.035
    screen.stroke()
    NSColor(calibratedRed: 0.91, green: 0.73, blue: 0.44, alpha: 1).setFill()
    let play = NSBezierPath()
    play.move(to: NSPoint(x: w * 0.46, y: h * 0.36))
    play.line(to: NSPoint(x: w * 0.46, y: h * 0.65))
    play.line(to: NSPoint(x: w * 0.61, y: h * 0.505))
    play.close()
    play.fill()
  }
  NSGraphicsContext.restoreGraphicsState()
  try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: path))
}
let root = "Resources/Assets.xcassets/App Icon & Top Shelf Image.brandassets"
for (name, w, h) in [("App Icon", 400, 240), ("App Icon - App Store", 1280, 768)] {
  for layer in ["Front", "Back"] {
    try render(
      width: w, height: h, foreground: layer == "Front", background: layer == "Back",
      path: "\(root)/\(name).imagestack/\(layer).imagestacklayer/Content.imageset/Image.png")
  }
}
try render(
  width: 1920, height: 720, foreground: true, background: true,
  path: "\(root)/Top Shelf Image.imageset/Image.png")
