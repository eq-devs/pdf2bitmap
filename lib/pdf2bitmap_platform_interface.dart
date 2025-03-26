import 'pdf2bitmap_method_channel.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
// pdf2bitmap_platform_interface.dart

abstract class Pdf2bitmapPlatform extends PlatformInterface {
  /// Constructs a Pdf2bitmapPlatform.
  Pdf2bitmapPlatform() : super(token: _token);

  static final Object _token = Object();

  static Pdf2bitmapPlatform _instance = MethodChannelPdf2bitmap();

  /// The default instance of [Pdf2bitmapPlatform] to use.
  ///
  /// Defaults to [MethodChannelPdf2bitmap].
  static Pdf2bitmapPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [Pdf2bitmapPlatform] when
  /// they register themselves.
  static set instance(Pdf2bitmapPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  Future<String?> getPlatformVersion() {
    throw UnimplementedError('platformVersion() has not been implemented.');
  }

  Future<Map<dynamic, dynamic>> convertPdfPageToBitmap({
    required String filePath,
    required int pageNumber,
    required int dpi,
    String? savePath,
  }) {
    throw UnimplementedError(
      'convertPdfPageToBitmap() has not been implemented.',
    );
  }

  Future<int> getPdfPageCount({required String filePath}) {
    throw UnimplementedError('getPdfPageCount() has not been implemented.');
  }
}
