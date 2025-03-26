# PDF to Bitmap

A Flutter plugin that converts PDF files to high-quality bitmap images on Android devices.

## Features

- Convert PDF pages to bitmap images with customizable resolution
- Retrieve page count from PDF documents
- Save rendered images to files or receive as in-memory data
- Support for scaling and quality control
- Diagnostic tools to identify PDF access issues
- Works reliably on older Android devices (Android 7+)

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  pdf2bitmap: 
```

## Usage

### Basic Usage

```dart
import 'package:pdf2bitmap/pdf2bitmap.dart';

// Get PDF page count
final pageCount = await Pdf2bitmap.getPdfPageCount(
  filePath: '/path/to/document.pdf',
);

// Convert a PDF page to bitmap
final pageImage = await Pdf2bitmap.convertPdfPageToBitmap(
  filePath: '/path/to/document.pdf',
  pageNumber: 0, // 0-based index for pages
  dpi: 300,
  scaleFactor: 2.0, // Higher values = better quality but larger images
);

// Display the image
if (pageImage.bytes != null) {
  Image.memory(pageImage.bytes!);
}
```

### Saving to a File

```dart
// Convert and save to file
await Pdf2bitmap.convertPdfPageToBitmap(
  filePath: '/path/to/document.pdf',
  pageNumber: 0,
  dpi: 300,
  scaleFactor: 2.0,
  savePath: '/path/to/output.png',
);
```

### Testing PDF Access

For diagnosing issues with PDF files, you can use the test method:

```dart
final testResults = await Pdf2bitmap.testPdfAccess(
  filePath: '/path/to/document.pdf',
);

// Check results
if (testResults['fileExists'] == true && 
    testResults['canRead'] == true && 
    testResults['canCreatePdfRenderer'] == true) {
  print('PDF is accessible and can be rendered');
} else {
  print('PDF access issues: $testResults');
}
```

## Image Quality

The `scaleFactor` parameter controls the quality of the rendered image:

- `1.0`: Standard quality, original PDF dimensions
- `2.0`: Double resolution (default)
- `3.0+`: Higher quality, but increases memory usage and processing time

## API Reference

### `getPdfPageCount`

```dart
static Future<int> getPdfPageCount({required String filePath})
```

Returns the number of pages in a PDF document.

### `convertPdfPageToBitmap`

```dart
static Future<PdfPageImage> convertPdfPageToBitmap({
  required String filePath,
  int pageNumber = 0,
  int dpi = 300,
  double scaleFactor = 2.0,
  String? savePath,
})
```

Converts a PDF page to a bitmap image. If `savePath` is provided, the image will be saved to that location.

### `testPdfAccess`

```dart
static Future<Map<String, dynamic>> testPdfAccess({
  required String filePath,
})
```

Tests if a PDF file can be accessed and identifies any issues.

### `renderSimpleBitmap`

```dart
static Future<PdfPageImage> renderSimpleBitmap({
  int width = 300,
  int height = 300,
})
```

Generates a simple test bitmap (without PDF) for testing purposes.

## PdfPageImage Class

The `PdfPageImage` class represents a rendered PDF page image with metadata:

```dart
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
}
```

## Example

See the `example` folder for a complete example app that demonstrates how to:

- Select a PDF file
- Navigate through pages
- Adjust rendering quality
- Save images to device storage

## Limitations

- Currently only supports Android platforms
- Large PDF files with complex content may require more memory
- For very large pages, consider using a lower `scaleFactor` to avoid memory issues

## License

```
MIT License

Copyright (c) 2025 PDF2Bitmap Contributors

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```