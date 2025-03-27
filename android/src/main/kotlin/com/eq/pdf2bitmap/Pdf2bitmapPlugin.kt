

package com.eq.pdf2bitmap

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Matrix
import android.graphics.pdf.PdfRenderer
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.ByteArrayOutputStream
import java.io.File
import java.io.FileOutputStream
import android.util.Base64
import java.io.IOException

/** Pdf2bitmapPlugin */
class Pdf2bitmapPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel : MethodChannel
    private lateinit var context: Context
    private val TAG = "Pdf2bitmapPlugin"

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "com.eq.pdf2bitmap")
        context = flutterPluginBinding.applicationContext
        channel.setMethodCallHandler(this)
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "testPdfAccess" -> {
                try {
                    val filePath = call.argument<String>("filePath")

                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "File path cannot be null", null)
                        return
                    }

                    val response = mutableMapOf<String, Any>()

                    // Test file existence
                    val file = File(filePath)
                    response["fileExists"] = file.exists()

                    if (file.exists()) {
                        response["fileSize"] = file.length()
                        response["canRead"] = file.canRead()

                        // Try to open file descriptor
                        try {
                            val parcelFileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                            response["canOpenFileDescriptor"] = true

                            // Try to create PDF renderer
                            try {
                                val pdfRenderer = PdfRenderer(parcelFileDescriptor)
                                response["canCreatePdfRenderer"] = true
                                response["pageCount"] = pdfRenderer.pageCount
                                pdfRenderer.close()
                            } catch (e: Exception) {
                                response["canCreatePdfRenderer"] = false
                                response["pdfRendererError"] = e.message ?: "Unknown error"
                            }

                            parcelFileDescriptor.close()
                        } catch (e: Exception) {
                            response["canOpenFileDescriptor"] = false
                            response["fileDescriptorError"] = e.message ?: "Unknown error"
                        }
                    }

                    result.success(response)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in testPdfAccess", e)
                    result.error("TEST_ERROR", "Error testing PDF access: ${e.message}", e.stackTraceToString())
                }
            }
            "renderSimpleBitmap" -> {
                // Just generate a simple test bitmap without any PDF involved
                try {
                    val width = call.argument<Int>("width") ?: 300
                    val height = call.argument<Int>("height") ?: 300

                    val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
                    val canvas = Canvas(bitmap)

                    // Fill with white background
                    canvas.drawColor(Color.WHITE)

                    // Convert to base64
                    val outputStream = ByteArrayOutputStream()
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, outputStream)
                    val imageBytes = outputStream.toByteArray()
                    val base64Image = Base64.encodeToString(imageBytes, Base64.NO_WRAP)

                    val response = hashMapOf<String, Any>(
                        "base64Image" to base64Image,
                        "width" to width,
                        "height" to height
                    )

                    result.success(response)
                } catch (e: Exception) {
                    Log.e(TAG, "Error in renderSimpleBitmap", e)
                    result.error("BITMAP_ERROR", "Error rendering simple bitmap: ${e.message}", e.stackTraceToString())
                }
            }
            "convertPdfToBitmap" -> {
    try {
        val filePath = call.argument<String>("filePath")
        val pageNumber = call.argument<Int>("pageNumber") ?: 0
        val dpi = call.argument<Int>("dpi") ?: 300
        val scaleFactor = call.argument<Double>("scaleFactor")?.toFloat() ?: 2.0f
        val savePath = call.argument<String>("savePath")

        if (filePath == null) {
            result.error("INVALID_ARGUMENTS", "File path cannot be null", null)
            return
        }

        Log.d(TAG, "Converting PDF: $filePath, page: $pageNumber, dpi: $dpi, scale: $scaleFactor")

        val file = File(filePath)
        if (!file.exists()) {
            result.error("FILE_NOT_FOUND", "PDF file not found at path: $filePath", null)
            return
        }

        if (!file.canRead()) {
            result.error("PERMISSION_ERROR", "Cannot read file (permission denied): $filePath", null)
            return
        }

        var parcelFileDescriptor: ParcelFileDescriptor? = null
        var pdfRenderer: PdfRenderer? = null
        var page: PdfRenderer.Page? = null
        var bitmap: Bitmap? = null

        try {
            // Open the PDF file
            parcelFileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
            pdfRenderer = PdfRenderer(parcelFileDescriptor)

            if (pageNumber >= pdfRenderer.pageCount || pageNumber < 0) {
                throw IOException("Invalid page number: $pageNumber, total pages: ${pdfRenderer.pageCount}")
            }

            // Open the page
            page = pdfRenderer.openPage(pageNumber)

            // Calculate dimensions based on scale factor
            val width = (page.width * scaleFactor).toInt()
            val height = (page.height * scaleFactor).toInt()

            // Create bitmap with ARGB_8888 for best quality
            bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bitmap)
            canvas.drawColor(Color.WHITE)

            // Apply scaling matrix
            val matrix = Matrix()
            matrix.setScale(scaleFactor, scaleFactor)

            // Render the page with the matrix
            page.render(bitmap, null, matrix, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)

            // Create a copy of the bitmap to ensure it won't be recycled prematurely
            val resultBitmap = bitmap.copy(bitmap.config?: Bitmap.Config.ARGB_8888, true)

            // Determine where to save the bitmap
            val outputFilePath = if (savePath != null) {
                savePath
            } else {
                // Create a temp file in the cache directory
                val fileName = "page_${pageNumber}_${System.currentTimeMillis()}.png"
                val cacheDir = context.cacheDir
                File(cacheDir, fileName).absolutePath
            }

            // Save the bitmap to the file
            val outputFile = File(outputFilePath)
            
            // Ensure parent directory exists
            outputFile.parentFile?.mkdirs()
            
            FileOutputStream(outputFile).use { out ->
                resultBitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
            }

            // Create response with bitmap file path and metadata
            val response = hashMapOf<String, Any>(
                "filePath" to outputFilePath, // This is the path to the saved bitmap
                "originalPdfPath" to filePath, // Original PDF path
                "width" to width,
                "height" to height,
                "pageCount" to pdfRenderer.pageCount
            )

            Log.d(TAG, "Bitmap saved to: $outputFilePath")
            result.success(response)

            // Clean up the result bitmap after it's been processed
            resultBitmap.recycle()
        } catch (e: Exception) {
            Log.e(TAG, "Error converting PDF", e)
            result.error("CONVERSION_ERROR", "Error converting PDF: ${e.message}", e.stackTraceToString())
        } finally {
            try {
                // Close resources in finally block to ensure cleanup
                page?.close()
                pdfRenderer?.close()
                parcelFileDescriptor?.close()

                // We can safely recycle the original bitmap
                bitmap?.recycle()
            } catch (e: Exception) {
                Log.e(TAG, "Error closing resources: ${e.message}", e)
            }
        }
    } catch (e: Exception) {
        Log.e(TAG, "Unexpected error", e)
        result.error("UNEXPECTED_ERROR", "Unexpected error: ${e.message}", e.stackTraceToString())
    }
}
            "getPdfPageCount" -> {
                try {
                    val filePath = call.argument<String>("filePath")

                    if (filePath == null) {
                        result.error("INVALID_ARGUMENTS", "File path cannot be null", null)
                        return
                    }

                    Log.d(TAG, "Getting page count for: $filePath")

                    val file = File(filePath)
                    if (!file.exists()) {
                        result.error("FILE_NOT_FOUND", "PDF file not found at path: $filePath", null)
                        return
                    }

                    if (!file.canRead()) {
                        result.error("PERMISSION_ERROR", "Cannot read file (permission denied): $filePath", null)
                        return
                    }

                    var parcelFileDescriptor: ParcelFileDescriptor? = null
                    var pdfRenderer: PdfRenderer? = null

                    try {
                        parcelFileDescriptor = ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY)
                        pdfRenderer = PdfRenderer(parcelFileDescriptor)
                        val pageCount = pdfRenderer.pageCount

                        result.success(pageCount)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting page count", e)
                        result.error("PDF_ERROR", "Error getting PDF page count: ${e.message}", e.stackTraceToString())
                    } finally {
                        pdfRenderer?.close()
                        parcelFileDescriptor?.close()
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Unexpected error", e)
                    result.error("UNEXPECTED_ERROR", "Unexpected error: ${e.message}", e.stackTraceToString())
                }
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
}