import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'pdf2bitmap_platform_interface.dart';
// pdf2bitmap_method_channel.dart


/// An implementation of [Pdf2bitmapPlatform] that uses method channels.
class MethodChannelPdf2bitmap extends Pdf2bitmapPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('com.eq.pdf2bitmap');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<Map<dynamic, dynamic>> convertPdfPageToBitmap({
    required String filePath,
    required int pageNumber,
    required int dpi,
    String? savePath,
  }) async {
    final Map<String, dynamic> args = {
      'filePath': filePath,
      'pageNumber': pageNumber,
      'dpi': dpi,
      'savePath': savePath,
    };

    final result = await methodChannel.invokeMethod<Map<dynamic, dynamic>>(
      'convertPdfToBitmap',
      args,
    );
    return result!;
  }

  @override
  Future<int> getPdfPageCount({required String filePath}) async {
    final pageCount = await methodChannel.invokeMethod<int>('getPdfPageCount', {
      'filePath': filePath,
    });
    return pageCount!;
  }
}
