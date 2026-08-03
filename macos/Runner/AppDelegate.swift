import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func application(_ sender: NSApplication, openFile filename: String) -> Bool {
    FileOpenChannel.handleOpenFiles([filename])
    return true
  }

  override func application(_ sender: NSApplication, openFiles filenames: [String]) {
    FileOpenChannel.handleOpenFiles(filenames)
    sender.reply(toOpenOrPrint: .success)
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    FileOpenChannel.handleOpenFiles(
      urls.filter { $0.isFileURL }.map(\.path)
    )
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

enum FileOpenChannel {
  private static let channelName = "plume_pdf/file_open"
  private static var channel: FlutterMethodChannel?
  private static var isFlutterReady = false
  private static var pendingFiles: [String] = []

  static func register(with controller: FlutterViewController) {
    let methodChannel = FlutterMethodChannel(
      name: channelName,
      binaryMessenger: controller.engine.binaryMessenger
    )
    methodChannel.setMethodCallHandler { call, result in
      guard call.method == "flutterReady" else {
        result(FlutterMethodNotImplemented)
        return
      }
      isFlutterReady = true
      flushPendingFiles()
      result(nil)
    }
    channel = methodChannel
    flushPendingFiles()
  }

  static func handleOpenFiles(_ filenames: [String]) {
    let pdfFiles = filenames.filter { $0.lowercased().hasSuffix(".pdf") }
    guard !pdfFiles.isEmpty else {
      return
    }
    pendingFiles.append(contentsOf: pdfFiles)
    flushPendingFiles()
  }

  private static func flushPendingFiles() {
    guard isFlutterReady,
          let channel,
          !pendingFiles.isEmpty else {
      return
    }
    let files = pendingFiles
    pendingFiles.removeAll()
    channel.invokeMethod("openFiles", arguments: files)
  }
}
