import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../../theme/app_colors.dart';
import '../controllers/home_controller.dart';
import '../services/wifi_transfer_service.dart';

class MobileWifiTransferView extends GetView<HomeController> {
  const MobileWifiTransferView({super.key});

  @override
  Widget build(BuildContext context) {
    return _WifiTransferPage(homeController: controller);
  }
}

class _WifiTransferPage extends StatefulWidget {
  const _WifiTransferPage({required this.homeController});

  final HomeController homeController;

  @override
  State<_WifiTransferPage> createState() => _WifiTransferPageState();
}

class _WifiTransferPageState extends State<_WifiTransferPage> {
  late final WifiTransferService _service;
  String? _address;
  String? _errorMessage;
  String? _uploadedFileName;
  bool _starting = true;

  @override
  void initState() {
    super.initState();
    _service = WifiTransferService();
    unawaited(_startServer());
  }

  @override
  void dispose() {
    unawaited(_service.stop());
    super.dispose();
  }

  Future<void> _startServer() async {
    setState(() {
      _starting = true;
      _errorMessage = null;
    });
    try {
      final String address = await _service.start(onUploaded: _handleUploaded);
      if (!mounted) {
        return;
      }
      setState(() {
        _address = address;
        _starting = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _starting = false;
        _errorMessage = error.toString().replaceFirst('Bad state: ', '');
      });
    }
  }

  Future<void> _handleUploaded(String filePath) async {
    if (mounted) {
      setState(() {
        _uploadedFileName = filePath.split('/').last;
      });
    }
    await widget.homeController.openFilePath(filePath);
    if (mounted) {
      Get.back<void>();
    }
  }

  Future<void> _copyAddress() async {
    final String? address = _address;
    if (address == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: address));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('地址已复制')));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffoldBg,
      appBar: AppBar(
        title: const Text('WiFi 传书'),
        backgroundColor: AppColors.scaffoldBg,
        surfaceTintColor: Colors.transparent,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              const Icon(Icons.wifi, size: 64, color: AppColors.accentBright),
              const SizedBox(height: 20),
              const Text(
                '从电脑传 PDF 到手机',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                '让电脑和手机连接同一个 WiFi，然后用电脑浏览器访问下面的地址。',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, height: 1.5),
              ),
              const SizedBox(height: 28),
              _buildAddressCard(),
              const SizedBox(height: 20),
              _buildInstructionsCard(),
              if (_uploadedFileName != null) ...<Widget>[
                const SizedBox(height: 16),
                Text(
                  '已收到：$_uploadedFileName',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.accentBright),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    if (_starting) {
      return const _TransferCard(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('正在启动传书服务…'),
          ],
        ),
      );
    }
    if (_errorMessage != null) {
      return _TransferCard(
        child: Column(
          children: <Widget>[
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.errorSoft),
            ),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _startServer, child: const Text('重试')),
          ],
        ),
      );
    }
    return _TransferCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          const Text(
            '请在电脑浏览器打开',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          SelectableText(
            _address!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.accentBright,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _copyAddress,
            icon: const Icon(Icons.copy, size: 18),
            label: const Text('复制地址'),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return const _TransferCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '使用方法',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 12),
          Text(
            '1. 在电脑浏览器打开上面的地址\n'
            '2. 将 .pdf 文件拖到网页上传区域\n'
            '3. 上传完成后，手机会自动打开 PDF',
            style: TextStyle(color: AppColors.textSecondary, height: 1.7),
          ),
        ],
      ),
    );
  }
}

class _TransferCard extends StatelessWidget {
  const _TransferCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: child,
    );
  }
}
