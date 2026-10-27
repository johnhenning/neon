// Render the legacy macOS icon canvas without altering the supplied artwork.
// Usage: swift render_app_icon.swift source.png destination.png
import AppKit
import QuartzCore

let input = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(input as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      let context = CGContext(data: nil, width: 1024, height: 1024,
                              bitsPerComponent: 8, bytesPerRow: 0,
                              space: CGColorSpace(name: CGColorSpace.sRGB)!,
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
else { fatalError("Cannot load artwork or create icon canvas") }

// Legacy .icns icons need their own inset and mask (macOS 14+ target).
let layer = CALayer()
layer.frame = CGRect(x: 100, y: 100, width: 824, height: 824)
layer.cornerRadius = 185
layer.cornerCurve = .continuous
layer.masksToBounds = true
layer.contents = image
layer.contentsGravity = .resizeAspectFill
let root = CALayer()
root.frame = CGRect(x: 0, y: 0, width: 1024, height: 1024)
root.addSublayer(layer)
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -10), blur: 18,
                  color: CGColor(gray: 0, alpha: 0.22))
context.beginTransparencyLayer(auxiliaryInfo: nil)
root.render(in: context)
context.endTransparencyLayer()
context.restoreGState()
guard let rendered = context.makeImage(),
      let destination = CGImageDestinationCreateWithURL(output as CFURL, "public.png" as CFString, 1, nil)
else { fatalError("Cannot write icon") }
CGImageDestinationAddImage(destination, rendered, nil)
precondition(CGImageDestinationFinalize(destination), "Cannot finish icon PNG")
