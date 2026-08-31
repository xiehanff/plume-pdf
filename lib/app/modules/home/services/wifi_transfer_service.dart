import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef WifiUploadedFileCallback = Future<void> Function(String filePath);

class WifiTransferService {
  static const int _maxUploadBytes = 512 * 1024 * 1024;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  Directory? _uploadDirectory;
  WifiUploadedFileCallback? _onUploaded;
  String? _address;

  String? get address => _address;
  bool get isRunning => _server != null;

  Future<String> start({required WifiUploadedFileCallback onUploaded}) async {
    if (isRunning && _address != null) {
      return _address!;
    }

    final String ipAddress = await _findLocalIpAddress();
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    final Directory uploadDirectory = Directory(
      path.join(documentsDirectory.path, 'wifi_uploads'),
    );
    await uploadDirectory.create(recursive: true);

    final HttpServer server = await HttpServer.bind(
      InternetAddress.anyIPv4,
      0,
      shared: true,
    );
    _server = server;
    _uploadDirectory = uploadDirectory;
    _onUploaded = onUploaded;
    _address = 'http://$ipAddress:${server.port}';
    _subscription = server.listen(_handleRequest);
    return _address!;
  }

  Future<void> stop() async {
    final StreamSubscription<HttpRequest>? subscription = _subscription;
    final HttpServer? server = _server;
    _subscription = null;
    _server = null;
    _uploadDirectory = null;
    _onUploaded = null;
    _address = null;
    await subscription?.cancel();
    await server?.close(force: true);
  }

  Future<String> _findLocalIpAddress() async {
    final List<NetworkInterface> interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );
    final List<_NetworkAddress> addresses = <_NetworkAddress>[];
    for (final NetworkInterface interface in interfaces) {
      for (final InternetAddress address in interface.addresses) {
        addresses.add(_NetworkAddress(interface.name, address.address));
      }
    }
    if (addresses.isEmpty) {
      throw StateError('没有找到局域网地址，请确认手机已连接 WiFi。');
    }
    addresses.sort(
      (a, b) => _interfaceScore(
        b.interfaceName,
      ).compareTo(_interfaceScore(a.interfaceName)),
    );
    return addresses.first.address;
  }

  int _interfaceScore(String name) {
    final String normalized = name.toLowerCase();
    if (normalized.contains('wlan') || normalized.contains('wifi')) {
      return 3;
    }
    if (normalized == 'en0' || normalized.startsWith('en')) {
      return 2;
    }
    return 1;
  }

  Future<void> _handleRequest(HttpRequest request) async {
    try {
      if (request.method == 'GET' && request.uri.path == '/') {
        await _writeHtml(request.response, _uploadPage);
        return;
      }
      if (request.method == 'GET' && request.uri.path == '/health') {
        await _writeJson(request.response, 200, <String, Object>{'ok': true});
        return;
      }
      if (request.method == 'POST' && request.uri.path == '/upload') {
        await _handleUpload(request);
        return;
      }
      await _writeJson(request.response, 404, <String, Object>{
        'ok': false,
        'message': 'Not found',
      });
    } catch (error) {
      await _writeJson(request.response, 500, <String, Object>{
        'ok': false,
        'message': '服务器错误：$error',
      });
    }
  }

  Future<void> _handleUpload(HttpRequest request) async {
    final String? fileName = _safePdfFileName(
      request.headers.value('x-file-name'),
    );
    if (fileName == null) {
      await _writeJson(request.response, 400, <String, Object>{
        'ok': false,
        'message': '只支持上传 PDF 文件。',
      });
      return;
    }
    if (request.contentLength > _maxUploadBytes) {
      await _writeJson(request.response, 413, <String, Object>{
        'ok': false,
        'message': '文件不能超过 512 MB。',
      });
      return;
    }

    final Directory? uploadDirectory = _uploadDirectory;
    if (uploadDirectory == null) {
      await _writeJson(request.response, 503, <String, Object>{
        'ok': false,
        'message': '传书服务尚未启动。',
      });
      return;
    }

    final String uploadId = DateTime.now().microsecondsSinceEpoch.toString();
    final File temporaryFile = File(
      path.join(uploadDirectory.path, '.$uploadId.upload'),
    );
    final File targetFile = _nextAvailableFile(uploadDirectory, fileName);
    IOSink? sink;
    bool sinkClosed = false;
    try {
      sink = temporaryFile.openWrite();
      int receivedBytes = 0;
      await for (final List<int> chunk in request) {
        receivedBytes += chunk.length;
        if (receivedBytes > _maxUploadBytes) {
          throw const _UploadException('文件不能超过 512 MB。');
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;
      await temporaryFile.rename(targetFile.path);

      await _writeJson(request.response, 200, <String, Object>{
        'ok': true,
        'fileName': fileName,
        'message': '上传成功，手机正在打开文件。',
      });
      final WifiUploadedFileCallback? onUploaded = _onUploaded;
      if (onUploaded != null) {
        unawaited(onUploaded(targetFile.path));
      }
    } catch (error) {
      if (!sinkClosed) {
        await sink?.close();
      }
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (await targetFile.exists()) {
        await targetFile.delete();
      }
      final int statusCode = error is _UploadException ? 413 : 500;
      await _writeJson(request.response, statusCode, <String, Object>{
        'ok': false,
        'message': error.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  String? _safePdfFileName(String? rawFileName) {
    if (rawFileName == null || rawFileName.isEmpty) {
      return null;
    }
    String decodedName;
    try {
      decodedName = Uri.decodeComponent(rawFileName);
    } catch (_) {
      decodedName = rawFileName;
    }
    final String fileName = path.basename(decodedName.replaceAll('\\', '/'));
    if (fileName.isEmpty || path.extension(fileName).toLowerCase() != '.pdf') {
      return null;
    }
    return fileName;
  }

  File _nextAvailableFile(Directory directory, String fileName) {
    final File original = File(path.join(directory.path, fileName));
    if (!original.existsSync()) {
      return original;
    }
    final String stem = path.basenameWithoutExtension(fileName);
    final String extension = path.extension(fileName);
    final String suffix = DateTime.now().millisecondsSinceEpoch.toString();
    return File(path.join(directory.path, '$stem-$suffix$extension'));
  }

  Future<void> _writeHtml(HttpResponse response, String html) async {
    response.headers.contentType = ContentType(
      'text',
      'html',
      charset: 'utf-8',
    );
    response.write(html);
    await response.close();
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object> payload,
  ) async {
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode(payload));
    await response.close();
  }
}

class _NetworkAddress {
  const _NetworkAddress(this.interfaceName, this.address);

  final String interfaceName;
  final String address;
}

class _UploadException implements Exception {
  const _UploadException(this.message);

  final String message;

  @override
  String toString() => message;
}

const String _uploadPage = '''<!doctype html>
<html lang="zh-CN">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Plume PDF · WiFi 传书</title>
  <style>
    :root { color-scheme: dark; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
    * { box-sizing: border-box; }
    body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #262a37; color: #fff; }
    main { width: min(680px, calc(100% - 32px)); padding: 36px; border: 1px solid #ffffff18; border-radius: 24px; background: #343643; box-shadow: 0 24px 60px #0006; }
    h1 { margin: 0 0 10px; font-size: 28px; }
    p { color: #ffffffb3; line-height: 1.6; }
    .drop { margin-top: 28px; padding: 58px 24px; text-align: center; border: 2px dashed #b39ddb; border-radius: 18px; background: #ffffff08; cursor: pointer; transition: .2s; }
    .drop.over, .drop:hover { background: #68668766; }
    .drop strong { display: block; margin-bottom: 8px; font-size: 20px; }
    input { display: none; }
    #status { min-height: 28px; margin-top: 20px; color: #b39ddb; }
    .hint { margin-top: 20px; font-size: 13px; color: #ffffff80; }
  </style>
</head>
<body>
  <main>
    <h1>WiFi 传书</h1>
    <p>请确保电脑和手机连接同一个 WiFi。将 PDF 拖到下面区域，文件会直接传到手机。</p>
    <label class="drop" id="drop">
      <strong>拖动 PDF 到这里</strong>
      <span>或点击选择 PDF 文件</span>
      <input id="file" type="file" accept="application/pdf,.pdf">
    </label>
    <div id="status"></div>
    <div class="hint">只支持 PDF，单个文件最大 512 MB</div>
  </main>
  <script>
    const drop = document.getElementById('drop');
    const input = document.getElementById('file');
    const status = document.getElementById('status');
    input.addEventListener('change', () => input.files.length && upload(input.files[0]));
    ['dragenter', 'dragover'].forEach(name => drop.addEventListener(name, event => { event.preventDefault(); drop.classList.add('over'); }));
    ['dragleave', 'drop'].forEach(name => drop.addEventListener(name, event => { event.preventDefault(); drop.classList.remove('over'); }));
    drop.addEventListener('drop', event => { const file = event.dataTransfer.files[0]; if (file) upload(file); });
    function upload(file) {
      if (!file.name.toLowerCase().endsWith('.pdf')) { status.textContent = '请选择 PDF 文件。'; return; }
      const xhr = new XMLHttpRequest();
      xhr.open('POST', '/upload');
      xhr.setRequestHeader('X-File-Name', encodeURIComponent(file.name));
      xhr.setRequestHeader('Content-Type', 'application/pdf');
      xhr.upload.onprogress = event => {
        if (event.lengthComputable) status.textContent = `正在上传 \${Math.round(event.loaded / event.total * 100)}%`;
      };
      xhr.onload = () => {
        try { const result = JSON.parse(xhr.responseText); status.textContent = result.message || '上传完成。'; }
        catch (_) { status.textContent = xhr.status === 200 ? '上传完成。' : '上传失败。'; }
      };
      xhr.onerror = () => { status.textContent = '连接手机失败，请确认两台设备在同一 WiFi。'; };
      status.textContent = '正在上传…';
      xhr.send(file);
    }
  </script>
</body>
</html>''';
