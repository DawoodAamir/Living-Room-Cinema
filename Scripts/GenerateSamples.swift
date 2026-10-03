import AVFoundation
import AppKit
import CoreVideo

@main struct SampleGenerator {
  static func main() async throws {
    for name in ["Orbit", "Tidal"] {
      let url = URL(fileURLWithPath: "Resources/Samples/\(name).mp4")
      if FileManager.default.fileExists(atPath: url.path) {
        try FileManager.default.removeItem(at: url)
      }
      let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
      let input = AVAssetWriterInput(
        mediaType: .video,
        outputSettings: [
          AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 960, AVVideoHeightKey: 540,
        ])
      let attributes: [String: any Sendable] = [
        kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
        kCVPixelBufferWidthKey as String: 960, kCVPixelBufferHeightKey as String: 540,
        kCVPixelBufferCGImageCompatibilityKey as String: true,
        kCVPixelBufferCGBitmapContextCompatibilityKey as String: true,
      ]
      let receiver = writer.inputPixelBufferReceiver(
        for: input,
        pixelBufferAttributes: CVPixelBufferCreationAttributes(
          CVPixelBufferAttributes(rawAttributes: attributes))!)
      try writer.start()
      writer.startSession(atSourceTime: .zero)
      for frame in 0..<720 {
        var optional: CVPixelBuffer?
        CVPixelBufferCreate(
          nil, 960, 540, kCVPixelFormatType_32ARGB, attributes as CFDictionary, &optional)
        let buffer = optional!
        CVPixelBufferLockBaseAddress(buffer, [])
        let context = CGContext(
          data: CVPixelBufferGetBaseAddress(buffer), width: 960, height: 540, bitsPerComponent: 8,
          bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)!
        context.setFillColor(CGColor(red: 0.04, green: 0.09, blue: 0.13, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 960, height: 540))
        let t = Double(frame) / 30
        if name == "Orbit" {
          for index in 0..<5 {
            let radius = Double(70 + index * 38)
            context.setStrokeColor(CGColor(red: 0.18, green: 0.32, blue: 0.37, alpha: 1))
            context.setLineWidth(2)
            context.strokeEllipse(
              in: CGRect(x: 480 - radius, y: 270 - radius, width: radius * 2, height: radius * 2))
            let angle = t * (0.24 + Double(index) * 0.07) + Double(index)
            context.setFillColor(
              CGColor(red: 0.88, green: 0.68 + Double(index) * 0.035, blue: 0.42, alpha: 1))
            context.fillEllipse(
              in: CGRect(
                x: 480 + cos(angle) * radius - 12, y: 270 + sin(angle) * radius - 12, width: 24,
                height: 24))
          }
        } else {
          for row in 0..<14 {
            context.beginPath()
            for x in stride(from: 0, through: 960, by: 8) {
              let y = Double(row) * 38 + sin(Double(x) / 130 + t + Double(row) * 0.27) * 25
              if x == 0 {
                context.move(to: CGPoint(x: Double(x), y: y))
              } else {
                context.addLine(to: CGPoint(x: Double(x), y: y))
              }
            }
            context.setStrokeColor(
              CGColor(red: 0.25, green: 0.55 + Double(row) * 0.02, blue: 0.62, alpha: 1))
            context.setLineWidth(5)
            context.strokePath()
          }
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        try await receiver.append(
          CVReadOnlyPixelBuffer(unsafeBuffer: buffer),
          with: CMTime(value: Int64(frame), timescale: 30))
      }
      receiver.finish()
      await writer.finishWriting()
      guard writer.status == .completed else {
        throw writer.error ?? NSError(domain: "Sample", code: 2)
      }
    }
  }
}
