import 'dart:io';
import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:pdf2bitmap/pdf2bitmap.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF to Bitmap Converter',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      home: const PdfConverterPage(),
    );
  }
}

class PdfConverterPage extends StatefulWidget {
  const PdfConverterPage({super.key});

  @override
  State<PdfConverterPage> createState() => _PdfConverterPageState();
}

class _PdfConverterPageState extends State<PdfConverterPage> {
  File? _pdfFile;
  int _pageCount = 0;
  int _currentPage = 0;
  bool _isLoading = false;
  PdfPageImage? _pageImage;
  String? _errorMessage;
  String? _savedImagePath;
  bool _hasPermission = true;
  double _scaleFactor = 2.0; // Default scale factor for rendering

  @override
  void initState() {
    super.initState();
    // _checkAndRequestPermissions();
  }

  Future<void> _checkAndRequestPermissions() async {
    if (Platform.isAndroid) {
      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        final result = await Permission.storage.request();
        setState(() {
          _hasPermission = result.isGranted;
        });
      } else {
        setState(() {
          _hasPermission = storageStatus.isGranted;
        });
      }

      try {
        // Additional permissions for Android 13+
        await Permission.photos.request();
        await Permission.videos.request();
      } catch (e) {
        // These might not be available on all devices, so ignore errors
      }
    } else {
      setState(() {
        _hasPermission = true;
      });
    }
  }

  Future<void> _pickPdfFile() async {
    if (!_hasPermission) {
      setState(() {
        _errorMessage = 'Storage permission not granted';
      });
      _checkAndRequestPermissions();
      return;
    }

    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (result != null && result.files.single.path != null) {
        final pdfPath = result.files.single.path!;

        // Verify file exists and is readable
        final file = File(pdfPath);
        if (!await file.exists()) {
          setState(() {
            _errorMessage = 'File does not exist: $pdfPath';
            _isLoading = false;
          });
          return;
        }

        setState(() {
          _pdfFile = file;
          _pageImage = null;
          _savedImagePath = null;
        });

        try {
          // First, test PDF access to diagnose any potential issues
          final testResult = await Pdf2bitmap.testPdfAccess(
            filePath: _pdfFile!.path,
          );

          log('PDF test results: $testResult');

          if (testResult['canCreatePdfRenderer'] == false) {
            setState(() {
              _errorMessage =
                  'Cannot render PDF: ${testResult['pdfRendererError']}';
              _isLoading = false;
            });
            return;
          }

          final pageCount = await Pdf2bitmap.getPdfPageCount(
            filePath: _pdfFile!.path,
          );

          setState(() {
            _pageCount = pageCount;
            _currentPage = 0;
          });

          if (_pageCount > 0) {
            await _convertCurrentPage();
          }
        } catch (e) {
          setState(() {
            _errorMessage = 'Error loading PDF: $e';
          });
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error picking file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _convertCurrentPage() async {
    if (_pdfFile == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _pageImage = null;
      _savedImagePath = null;
    });

    try {
      // Get the bitmap as in-memory data with high-res rendering
      final pageImage = await Pdf2bitmap.convertPdfPageToBitmap(
        filePath: _pdfFile!.path,
        pageNumber: _currentPage,
        dpi: 300,
        scaleFactor: _scaleFactor,
      );

      setState(() {
        _pageImage = pageImage;
      });

      // Save to a file
      try {
        final tempDir = await getTemporaryDirectory();
        final savePath = '${tempDir.path}/page_${_currentPage}.png';

        // Make sure the directory exists
        Directory(tempDir.path).createSync(recursive: true);

        await Pdf2bitmap.convertPdfPageToBitmap(
          filePath: _pdfFile!.path,
          pageNumber: _currentPage,
          dpi: 300,
          scaleFactor: _scaleFactor,
          savePath: savePath,
        );

        setState(() {
          _savedImagePath = savePath;
        });
      } catch (e) {
        log('Warning: Failed to save image to file: $e', error: e);
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error converting page: $e';
      });
      log('Error converting page: $e', error: e);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _nextPage() {
    if (_currentPage < _pageCount - 1) {
      setState(() {
        _currentPage++;
      });
      _convertCurrentPage();
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      setState(() {
        _currentPage--;
      });
      _convertCurrentPage();
    }
  }

  void _increaseQuality() {
    setState(() {
      _scaleFactor = _scaleFactor + 0.5;
    });
    _convertCurrentPage();
  }

  void _decreaseQuality() {
    if (_scaleFactor > 1.0) {
      setState(() {
        _scaleFactor = _scaleFactor - 0.5;
      });
      _convertCurrentPage();
    }
  }

  Future<void> _saveToDownloads() async {
    if (_pageImage == null || _savedImagePath == null) return;

    try {
      // Get the Downloads directory
      Directory? downloadsDir;

      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
        if (!await downloadsDir.exists()) {
          // Fallback to external storage directory
          final dirs = await getExternalStorageDirectories();
          if (dirs != null && dirs.isNotEmpty) {
            downloadsDir = dirs.first;
          } else {
            throw Exception('Could not find Downloads directory');
          }
        }
      } else {
        // On iOS, use documents directory
        downloadsDir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'pdf_page_${_currentPage + 1}.png';
      final targetPath = '${downloadsDir.path}/$fileName';

      // Copy the file
      await File(_savedImagePath!).copy(targetPath);

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Image saved to $targetPath')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save image: $e')));
    }
  }

  Future<void> _shareImage() async {
    // Add sharing functionality here
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Share functionality would be implemented here'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('PDF to Bitmap Converter'),
        actions: [
          if (_savedImagePath != null)
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: 'Save to Downloads',
              onPressed: _saveToDownloads,
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Custom button with gradient
            GestureDetector(
              onTap: _isLoading ? null : _pickPdfFile,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Colors.blue, Colors.purple],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      spreadRadius: 1,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Center(
                  child: Text(
                    'Select PDF File',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (_pdfFile != null) ...[
              Text(
                'File: ${_pdfFile!.path.split('/').last}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Text('Total Pages: $_pageCount'),
              const SizedBox(height: 8),

              // Page navigation
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed:
                        _currentPage > 0 && !_isLoading ? _previousPage : null,
                  ),
                  Text('Page ${_currentPage + 1} of $_pageCount'),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward),
                    onPressed:
                        _currentPage < _pageCount - 1 && !_isLoading
                            ? _nextPage
                            : null,
                  ),
                ],
              ),

              // Quality control
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.remove),
                    tooltip: 'Decrease quality',
                    onPressed:
                        !_isLoading && _scaleFactor > 1.0
                            ? _decreaseQuality
                            : null,
                  ),
                  Text('Quality: ${_scaleFactor.toStringAsFixed(1)}x'),
                  IconButton(
                    icon: const Icon(Icons.add),
                    tooltip: 'Increase quality',
                    onPressed: !_isLoading ? _increaseQuality : null,
                  ),
                ],
              ),

              const SizedBox(height: 8),
            ],

            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red),
                ),
              )
            else if (_pageImage != null) ...[
              Expanded(
                child: Center(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        if (_pageImage!.bytes != null) ...[
                          Image.memory(
                            _pageImage!.bytes!,
                            width: double.infinity,
                            fit: BoxFit.contain,
                          ),
                          if (_savedImagePath != null) ...[
                            const SizedBox(height: 16),
                            // Action buttons
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Custom button for sharing
                                ElevatedButton.icon(
                                  onPressed: _shareImage,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Share'),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.green,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                // Custom button for saving
                                ElevatedButton.icon(
                                  onPressed: _saveToDownloads,
                                  icon: const Icon(Icons.download),
                                  label: const Text('Save'),
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: Colors.blue,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ],
                    ),
                  ),
                ),
              ),
              Text(
                'Image Size: ${_pageImage!.width}x${_pageImage!.height} pixels (Scale: ${_scaleFactor.toStringAsFixed(1)}x)',
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
