import Cocoa
import FlutterMacOS
import Vision

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // 与 lib/app/theme/app_colors.dart 中的 AppColors.scaffoldBg 保持一致
    self.backgroundColor = NSColor(
      red: 38.0 / 255.0,
      green: 42.0 / 255.0,
      blue: 55.0 / 255.0,
      alpha: 1.0
    )

    RegisterGeneratedPlugins(registry: flutterViewController)
    OCRMethodChannel.register(with: flutterViewController)
    FileOpenChannel.register(with: flutterViewController)

    super.awakeFromNib()
  }
}

private enum OCRMethodChannel {
  static let channelName = "plume_pdf/ocr"

  static func register(with controller: FlutterViewController) {
    let channel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    channel.setMethodCallHandler(handle)
  }

  static func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard call.method == "recognizeTextFromImage" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard let arguments = call.arguments as? [String: Any],
          let imageBytes = arguments["imageBytes"] as? FlutterStandardTypedData else {
      result(
        FlutterError(
          code: "INVALID_ARGUMENTS",
          message: "缺少 OCR 图片数据。",
          details: nil
        )
      )
      return
    }
    recognizeText(from: imageBytes.data, result: result)
  }

  static func recognizeText(from data: Data, result: @escaping FlutterResult) {
    guard #available(macOS 10.15, *) else {
      result(
        FlutterError(
          code: "OCR_UNAVAILABLE",
          message: "当前 macOS 版本不支持 Vision OCR。",
          details: nil
        )
      )
      return
    }
    guard let image = NSImage(data: data),
          let cgImage = image.cgImageValue else {
      result(
        FlutterError(
          code: "IMAGE_DECODE_FAILED",
          message: "无法解析框选图片。",
          details: nil
        )
      )
      return
    }

    DispatchQueue.global(qos: .userInitiated).async {
      let request = VNRecognizeTextRequest { request, error in
        if let error {
          DispatchQueue.main.async {
            result(
              FlutterError(
                code: "OCR_REQUEST_FAILED",
                message: error.localizedDescription,
                details: nil
              )
            )
          }
          return
        }
        let observations = request.results as? [VNRecognizedTextObservation] ?? []
        let text = observations
          .compactMap { $0.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines) }
          .filter { !$0.isEmpty }
          .joined(separator: "\n")
        DispatchQueue.main.async {
          result(text)
        }
      }
      request.recognitionLevel = .accurate
      request.usesLanguageCorrection = true
      request.recognitionLanguages = ["zh-Hans", "en-US"]

      let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
      do {
        try handler.perform([request])
      } catch {
        DispatchQueue.main.async {
          result(
            FlutterError(
              code: "OCR_HANDLER_FAILED",
              message: error.localizedDescription,
              details: nil
            )
          )
        }
      }
    }
  }
}

private extension NSImage {
  var cgImageValue: CGImage? {
    var rect = CGRect(origin: .zero, size: size)
    if let cgImage = cgImage(forProposedRect: &rect, context: nil, hints: nil) {
      return cgImage
    }
    guard let tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffRepresentation) else {
      return nil
    }
    return bitmap.cgImage
  }
}
