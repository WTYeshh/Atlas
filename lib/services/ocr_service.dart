import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrService {
  final TextRecognizer? _textRecognizer = kIsWeb ? null : TextRecognizer(script: TextRecognitionScript.latin);

  Future<String?> extractTextFromImage(String imagePath) async {
    if (kIsWeb) {
      print('OCR: Image text recognition is not supported on Web. Stubbing result.');
      return 'Mock OCR Extracted Text: This is a preview run on Web. Real OCR is supported on Android.';
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      print('OCR Input image file does not exist: $imagePath');
      return null;
    }

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final RecognizedText recognizedText = await _textRecognizer!.processImage(inputImage);
      
      if (recognizedText.text.trim().isEmpty) {
        print('OCR: No text found in image.');
        return '';
      }

      return recognizedText.text;
    } catch (e) {
      print('OCR text recognition failed: $e');
      return null;
    }
  }

  void dispose() {
    if (!kIsWeb) {
      _textRecognizer?.close();
    }
  }
}
