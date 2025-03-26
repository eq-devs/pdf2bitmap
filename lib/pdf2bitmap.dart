import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart';
// lib/pdf2bitmap.dart

class Pdf2bitmap {
  static const MethodChannel _channel = MethodChannel('com.eq.pdf2bitmap');

  /// Get the platform version
  static Future<String?> getPlatformVersion() async {
    final version = await _channel.invokeMethod<String>('getPlatformVersion');
    return version;
  }

  /// Test PDF file access and identify issues
  static Future<Map<String, dynamic>> testPdfAccess({
    required String filePath,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'testPdfAccess',
        {'filePath': filePath},
      );

      // Convert to Dart map
      return result.map((key, value) => MapEntry(key.toString(), value));
    } on PlatformException catch (e) {
      throw PdfConversionException(
        code: e.code,
        message: e.message ?? 'Unknown error occurred',
        details: e.details,
      );
    }
  }

  /// Generate a simple test bitmap without PDF
  static Future<PdfPageImage> renderSimpleBitmap({
    int width = 300,
    int height = 300,
  }) async {
    try {
      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'renderSimpleBitmap',
        {'width': width, 'height': height},
      );

      return PdfPageImage.fromMap(result);
    } on PlatformException catch (e) {
      throw PdfConversionException(
        code: e.code,
        message: e.message ?? 'Unknown error occurred',
        details: e.details,
      );
    }
  }

  /// Convert a PDF page to a bitmap image
  ///
  /// [filePath] - The absolute path to the PDF file
  /// [pageNumber] - The page number to convert (0-based index)
  /// [dpi] - The resolution for the output image (default: 300)
  /// [savePath] - Optional path to save the bitmap directly to a file
  ///
  /// Returns a [PdfPageImage] object containing the image data and metadata
  // static Future<PdfPageImage> convertPdfPageToBitmap({
  //   required String filePath,
  //   int pageNumber = 0,
  //   int dpi = 300,
  //   String? savePath,
  // }) async {
  //   try {
  //     final Map<String, dynamic> args = {
  //       'filePath': filePath,
  //       'pageNumber': pageNumber,
  //       'dpi': dpi,
  //       'savePath': savePath,
  //     };

  //     final Map<dynamic, dynamic> result = await _channel.invokeMethod(
  //       'convertPdfToBitmap',
  //       args,
  //     );

  //     return PdfPageImage.fromMap(result);
  //   } on PlatformException catch (e) {
  //     throw PdfConversionException(
  //       code: e.code,
  //       message: e.message ?? 'Unknown error occurred',
  //       details: e.details,
  //     );
  //   }
  // }

  // /// Get the number of pages in a PDF document
  // ///
  // /// [filePath] - The absolute path to the PDF file
  // ///
  // /// Returns the number of pages in the PDF
  static Future<int> getPdfPageCount({required String filePath}) async {
    try {
      final int pageCount = await _channel.invokeMethod('getPdfPageCount', {
        'filePath': filePath,
      });

      return pageCount;
    } on PlatformException catch (e) {
      throw PdfConversionException(
        code: e.code,
        message: e.message ?? 'Unknown error occurred',
        details: e.details,
      );
    }
  }

  /// Convert a PDF page to a bitmap image
  ///
  /// [filePath] - The absolute path to the PDF file
  /// [pageNumber] - The page number to convert (0-based index)
  /// [dpi] - The resolution for the output image (default: 300)
  /// [scaleFactor] - Scale factor for the output image (default: 2.0)
  /// [savePath] - Optional path to save the bitmap directly to a file
  ///
  /// Returns a [PdfPageImage] object containing the image data and metadata
  static Future<PdfPageImage> convertPdfPageToBitmap({
    required String filePath,
    int pageNumber = 0,
    int dpi = 300,
    double scaleFactor = 2.0,
    String? savePath,
  }) async {
    try {
      final Map<String, dynamic> args = {
        'filePath': filePath,
        'pageNumber': pageNumber,
        'dpi': dpi,
        'scaleFactor': scaleFactor,
        'savePath': savePath,
      };

      final Map<dynamic, dynamic> result = await _channel.invokeMethod(
        'convertPdfToBitmap',
        args,
      );

      return PdfPageImage.fromMap(result);
    } on PlatformException catch (e) {
      throw PdfConversionException(
        code: e.code,
        message: e.message ?? 'Unknown error occurred',
        details: e.details,
      );
    }
  }
}

/// Class representing a converted PDF page image with metadata
class PdfPageImage {
  /// The image data as a Uint8List (null if saved to file)
  final Uint8List? bytes;

  /// The path to the saved image file (null if returned as bytes)
  final String? filePath;

  /// The width of the image in pixels
  final int width;

  /// The height of the image in pixels
  final int height;

  /// Total number of pages in the PDF document (may be null for test images)
  final int? pageCount;

  PdfPageImage({
    this.bytes,
    this.filePath,
    required this.width,
    required this.height,
    this.pageCount,
  });

  /// Create a PdfPageImage from a map returned by the platform channel
  factory PdfPageImage.fromMap(Map<dynamic, dynamic> map) {
    Uint8List? bytes;
    String? filePath;

    if (map.containsKey('base64Image')) {
      final String base64Image = map['base64Image'] as String;
      bytes = base64Decode(base64Image);
    } else if (map.containsKey('filePath')) {
      filePath = map['filePath'] as String;
    }

    return PdfPageImage(
      bytes: bytes,
      filePath: filePath,
      width: map['width'] as int,
      height: map['height'] as int,
      pageCount: map.containsKey('pageCount') ? map['pageCount'] as int : null,
    );
  }
}

/// Exception thrown when a PDF conversion error occurs
class PdfConversionException implements Exception {
  /// Error code
  final String code;

  /// Error message
  final String message;

  /// Additional details about the error
  final dynamic details;

  PdfConversionException({
    required this.code,
    required this.message,
    this.details,
  });

  @override
  String toString() => 'PdfConversionException($code): $message';
}
