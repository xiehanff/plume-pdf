import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

typedef WifiUploadedFileCallback = Future<void> Function(String filePath);

class WifiTransferService {
  WifiTransferService({
    InternetAddress? bindAddressOverride,
    Directory? uploadDirectoryOverride,
    Future<void> Function()? beforeBind,
  }) : _bindAddressOverride = bindAddressOverride,
       _uploadDirectoryOverride = uploadDirectoryOverride,
       _beforeBind = beforeBind;

  static const int _maxUploadBytes = 512 * 1024 * 1024;

  // 固定端口让地址可以手动输入；被占用时降级为系统分配的随机端口。
  static const int _preferredPort = 8080;

  final InternetAddress? _bindAddressOverride;
  final Directory? _uploadDirectoryOverride;
  final Future<void> Function()? _beforeBind;

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _subscription;
  Directory? _uploadDirectory;
  WifiUploadedFileCallback? _onUploaded;
  String? _address;
  Future<String>? _startFuture;
  int _generation = 0;

  String? get address => _address;
  bool get isRunning => _server != null;

  Future<String> start({required WifiUploadedFileCallback onUploaded}) {
    final String? currentAddress = _address;
    if (isRunning && currentAddress != null) {
      return Future<String>.value(currentAddress);
    }

    final Future<String>? pendingStart = _startFuture;
    if (pendingStart != null) {
      return pendingStart;
    }

    final int generation = _generation;
    late final Future<String> future;
    future = _startInternal(
      onUploaded: onUploaded,
      generation: generation,
    ).whenComplete(() {
      if (identical(_startFuture, future)) {
        _startFuture = null;
      }
    });
    _startFuture = future;
    return future;
  }

  Future<String> _startInternal({
    required WifiUploadedFileCallback onUploaded,
    required int generation,
  }) async {
    final String ipAddress =
        _bindAddressOverride?.address ?? await _findLocalIpAddress();
    final Directory uploadDirectory =
        _uploadDirectoryOverride ?? await _defaultUploadDirectory();
    await uploadDirectory.create(recursive: true);

    await _beforeBind?.call();
    _throwIfStartCancelled(generation);

    final InternetAddress bindAddress =
        _bindAddressOverride ?? InternetAddress(ipAddress);
    HttpServer server;
    try {
      server = await HttpServer.bind(bindAddress, _preferredPort);
    } on SocketException {
      server = await HttpServer.bind(bindAddress, 0);
    }
    if (generation != _generation) {
      await server.close(force: true);
      throw StateError('传书服务启动已取消。');
    }

    _server = server;
    _uploadDirectory = uploadDirectory;
    _onUploaded = onUploaded;
    _address = 'http://$ipAddress:${server.port}';
    _subscription = server.listen(_handleRequest);
    return _address!;
  }

  Future<void> stop() async {
    _generation++;
    final Future<String>? pendingStart = _startFuture;
    final StreamSubscription<HttpRequest>? subscription = _subscription;
    final HttpServer? server = _server;

    _subscription = null;
    _server = null;
    _uploadDirectory = null;
    _onUploaded = null;
    _address = null;

    await subscription?.cancel();
    await server?.close(force: true);

    if (pendingStart != null) {
      try {
        await pendingStart;
      } catch (_) {
        // stop() 取消了正在进行的 start() 时，等待其完成清理即可。
      }
    }
  }

  void _throwIfStartCancelled(int generation) {
    if (generation != _generation) {
      throw StateError('传书服务启动已取消。');
    }
  }

  Future<Directory> _defaultUploadDirectory() async {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return Directory(path.join(documentsDirectory.path, 'wifi_uploads'));
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
      final String requestPath = request.uri.path;
      if (request.method == 'GET' &&
          (requestPath == '/' || requestPath == '/index.html')) {
        await _writeHtml(
          request.response,
          _uploadPage.replaceAll('__UPLOAD_PATH__', '/upload'),
        );
        return;
      }
      if (request.method == 'GET' && requestPath == '/health') {
        await _writeJson(request.response, 200, <String, Object>{'ok': true});
        return;
      }
      if (request.method == 'POST' && requestPath == '/upload') {
        await _handleUpload(request);
        return;
      }
      await _writeNotFound(request.response);
    } catch (error) {
      try {
        await _writeJson(request.response, 500, <String, Object>{
          'ok': false,
          'message': '服务器错误：$error',
        });
      } catch (_) {
        // 客户端已断开或响应已关闭时无需再次写回错误。
      }
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

    final String uploadId =
        '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(1 << 32)}';
    final File temporaryFile = File(
      path.join(uploadDirectory.path, '.$uploadId.upload'),
    );
    IOSink? sink;
    bool sinkClosed = false;
    File? committedFile;
    try {
      sink = temporaryFile.openWrite();
      int receivedBytes = 0;
      await for (final List<int> chunk in request) {
        receivedBytes += chunk.length;
        if (receivedBytes > _maxUploadBytes) {
          throw const _UploadException(
            '文件不能超过 512 MB。',
            statusCode: 413,
          );
        }
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sinkClosed = true;

      if (!await _hasPdfHeader(temporaryFile)) {
        throw const _UploadException(
          '文件内容不是有效的 PDF。',
          statusCode: 400,
        );
      }

      final File targetFile = _nextAvailableFile(uploadDirectory, fileName);
      committedFile = await temporaryFile.rename(targetFile.path);

      await _writeJson(request.response, 200, <String, Object>{
        'ok': true,
        'fileName': path.basename(committedFile.path),
        'message': '上传成功，手机正在打开文件。',
      });
      final WifiUploadedFileCallback? onUploaded = _onUploaded;
      if (onUploaded != null) {
        unawaited(onUploaded(committedFile.path));
      }
    } catch (error) {
      if (!sinkClosed) {
        await sink?.close();
      }
      if (await temporaryFile.exists()) {
        await temporaryFile.delete();
      }
      if (committedFile != null && await committedFile.exists()) {
        await committedFile.delete();
      }
      final int statusCode = error is _UploadException
          ? error.statusCode
          : 500;
      await _writeJson(request.response, statusCode, <String, Object>{
        'ok': false,
        'message': error.toString().replaceFirst('Exception: ', ''),
      });
    }
  }

  Future<bool> _hasPdfHeader(File file) async {
    final RandomAccessFile randomAccessFile = await file.open();
    try {
      final List<int> header = await randomAccessFile.read(5);
      return header.length == 5 &&
          header[0] == 0x25 &&
          header[1] == 0x50 &&
          header[2] == 0x44 &&
          header[3] == 0x46 &&
          header[4] == 0x2D;
    } finally {
      await randomAccessFile.close();
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
    final String suffix = DateTime.now().microsecondsSinceEpoch.toString();
    return File(path.join(directory.path, '$stem-$suffix$extension'));
  }

  Future<void> _writeNotFound(HttpResponse response) {
    return _writeJson(response, 404, <String, Object>{
      'ok': false,
      'message': 'Not found',
    });
  }

  Future<void> _writeHtml(HttpResponse response, String html) async {
    response.headers.contentType = ContentType(
      'text',
      'html',
      charset: 'utf-8',
    );
    _setNoStoreHeaders(response);
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
    _setNoStoreHeaders(response);
    response.write(jsonEncode(payload));
    await response.close();
  }

  void _setNoStoreHeaders(HttpResponse response) {
    response.headers.set(HttpHeaders.cacheControlHeader, 'no-store');
    response.headers.set('X-Content-Type-Options', 'nosniff');
    response.headers.set('Referrer-Policy', 'no-referrer');
  }
}

class _NetworkAddress {
  const _NetworkAddress(this.interfaceName, this.address);

  final String interfaceName;
  final String address;
}

class _UploadException implements Exception {
  const _UploadException(this.message, {required this.statusCode});

  final String message;
  final int statusCode;

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
    <p>请确保电脑和手机连接同一个受信任的 WiFi。将 PDF 拖到下面区域，文件会直接传到手机。</p>
    <label class="drop" id="drop">
      <strong>拖动 PDF 到这里</strong>
      <span>或点击选择 PDF 文件</span>
      <input id="file" type="file" accept="application/pdf,.pdf">
    </label>
    <div id="status"></div>
    <div class="hint">只支持 PDF，单个文件最大 512 MB；关闭手机传书页面后本次地址立即失效。</div>
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
      xhr.open('POST', '__UPLOAD_PATH__');
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