import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:plume_pdf/app/modules/home/services/wifi_transfer_service.dart';

void main() {
  group('WifiTransferService', () {
    test('requires session token and stores sanitized PDF', () async {
      final Directory uploadDirectory = await Directory.systemTemp.createTemp(
        'plume_wifi_transfer_',
      );
      final HttpClient client = HttpClient();
      final Completer<String> uploaded = Completer<String>();
      final WifiTransferService service = WifiTransferService(
        bindAddressOverride: InternetAddress.loopbackIPv4,
        uploadDirectoryOverride: uploadDirectory,
        sessionTokenOverride: 'test-token',
      );
      addTearDown(() async {
        client.close(force: true);
        await service.stop();
        if (await uploadDirectory.exists()) {
          await uploadDirectory.delete(recursive: true);
        }
      });

      final Uri address = Uri.parse(
        await service.start(
          onUploaded: (String filePath) async {
            if (!uploaded.isCompleted) {
              uploaded.complete(filePath);
            }
          },
        ),
      );
      expect(address.path, '/test-token');

      final HttpClientRequest rootRequest = await client.getUrl(
        address.replace(path: '/'),
      );
      final HttpClientResponse rootResponse = await rootRequest.close();
      expect(rootResponse.statusCode, HttpStatus.notFound);
      await rootResponse.drain<void>();

      final HttpClientRequest pageRequest = await client.getUrl(address);
      final HttpClientResponse pageResponse = await pageRequest.close();
      expect(pageResponse.statusCode, HttpStatus.ok);
      final String page = await utf8.decoder.bind(pageResponse).join();
      expect(page, contains('/test-token/upload'));

      final List<int> pdfBytes = utf8.encode('%PDF-1.7\nminimal test');
      final HttpClientRequest uploadRequest = await client.postUrl(
        address.replace(path: '${address.path}/upload'),
      );
      uploadRequest.headers.set(
        'x-file-name',
        Uri.encodeComponent('../safe-name.pdf'),
      );
      uploadRequest.contentLength = pdfBytes.length;
      uploadRequest.add(pdfBytes);
      final HttpClientResponse uploadResponse = await uploadRequest.close();
      expect(uploadResponse.statusCode, HttpStatus.ok);
      await uploadResponse.drain<void>();

      final String uploadedPath = await uploaded.future.timeout(
        const Duration(seconds: 2),
      );
      expect(path.dirname(uploadedPath), uploadDirectory.path);
      expect(path.basename(uploadedPath), 'safe-name.pdf');
      expect(await File(uploadedPath).exists(), isTrue);
    });

    test('rejects a fake PDF even when extension is pdf', () async {
      final Directory uploadDirectory = await Directory.systemTemp.createTemp(
        'plume_wifi_transfer_',
      );
      final HttpClient client = HttpClient();
      bool callbackCalled = false;
      final WifiTransferService service = WifiTransferService(
        bindAddressOverride: InternetAddress.loopbackIPv4,
        uploadDirectoryOverride: uploadDirectory,
        sessionTokenOverride: 'test-token',
      );
      addTearDown(() async {
        client.close(force: true);
        await service.stop();
        if (await uploadDirectory.exists()) {
          await uploadDirectory.delete(recursive: true);
        }
      });

      final Uri address = Uri.parse(
        await service.start(
          onUploaded: (_) async {
            callbackCalled = true;
          },
        ),
      );
      final List<int> bytes = utf8.encode('definitely not a PDF');
      final HttpClientRequest request = await client.postUrl(
        address.replace(path: '${address.path}/upload'),
      );
      request.headers.set('x-file-name', Uri.encodeComponent('fake.pdf'));
      request.contentLength = bytes.length;
      request.add(bytes);
      final HttpClientResponse response = await request.close();
      expect(response.statusCode, HttpStatus.badRequest);
      await response.drain<void>();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(callbackCalled, isFalse);
      expect(
        uploadDirectory.listSync().whereType<File>().where(
          (File file) => path.extension(file.path) == '.pdf',
        ),
        isEmpty,
      );
    });

    test('stop cancels a start that has not bound the server yet', () async {
      final Directory uploadDirectory = await Directory.systemTemp.createTemp(
        'plume_wifi_transfer_',
      );
      final Completer<void> beforeBindEntered = Completer<void>();
      final Completer<void> releaseBind = Completer<void>();
      final WifiTransferService service = WifiTransferService(
        bindAddressOverride: InternetAddress.loopbackIPv4,
        uploadDirectoryOverride: uploadDirectory,
        sessionTokenOverride: 'test-token',
        beforeBind: () async {
          if (!beforeBindEntered.isCompleted) {
            beforeBindEntered.complete();
          }
          await releaseBind.future;
        },
      );
      addTearDown(() async {
        await service.stop();
        if (await uploadDirectory.exists()) {
          await uploadDirectory.delete(recursive: true);
        }
      });

      final Future<String> startFuture = service.start(onUploaded: (_) async {});
      final Future<void> expectation = expectLater(
        startFuture,
        throwsA(isA<StateError>()),
      );
      await beforeBindEntered.future;
      final Future<void> stopFuture = service.stop();
      releaseBind.complete();
      await stopFuture;
      await expectation;
      expect(service.isRunning, isFalse);
      expect(service.address, isNull);
    });
  });
}
