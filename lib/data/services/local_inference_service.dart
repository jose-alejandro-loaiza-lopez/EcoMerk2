import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

class LocalInferenceService {
  static OnnxRuntime? _ort;
  static OrtSession? _session;
  static bool _initialized = false;

  static const String _modelAsset = 'assets/models/mobilenet_v3.onnx';
  static const int _inputSize = 224;
  static const List<double> _mean = [0.485, 0.456, 0.406];
  static const List<double> _std = [0.229, 0.224, 0.225];

  static Future<void> init() async {
    if (_initialized) return;
    try {
      _ort = OnnxRuntime();
      _session = await _ort!.createSessionFromAsset(
        _modelAsset,
        options: OrtSessionOptions(),
      );

      final inputInfo = await _session!.getInputInfo();
      final outputInfo = await _session!.getOutputInfo();
      debugPrint('=== ONNX Model Info ===');
      debugPrint('Inputs: $inputInfo');
      debugPrint('Outputs: $outputInfo');

      _initialized = true;
    } catch (e) {
      debugPrint('LocalInferenceService.init: $e');
      rethrow;
    }
  }

  static Future<bool> hasProtein(String imageUrl) async {
    if (!_initialized) await init();
    if (_session == null) {
      throw StateError('ONNX session not initialized');
    }

    final bytes = await _downloadImage(imageUrl);
    if (bytes.isEmpty) throw Exception('Empty image downloaded');

    final inputTensor = await _preprocess(bytes);

    try {
      final inputName = _session!.inputNames.isNotEmpty
          ? _session!.inputNames.first
          : 'input';
      final outputs = await _session!.run({inputName: inputTensor});
      final outputName = _session!.outputNames.isNotEmpty
          ? _session!.outputNames.first
          : 'output';
      final outputTensor = outputs[outputName]!;
      final logits = await outputTensor.asFlattenedList();

      debugPrint('=== Inference result ===');
      debugPrint('Input name used: $inputName');
      debugPrint('Output name used: $outputName');
      debugPrint('Logits (${logits.length} values): $logits');

      final bool result =
          logits.length >= 2 && (logits[0] as num) > (logits[1] as num);
      debugPrint('hasProtein => $result');

      await inputTensor.dispose();
      for (final t in outputs.values) {
        await t.dispose();
      }

      return result;
    } catch (e) {
      await inputTensor.dispose();
      debugPrint('LocalInferenceService inference: $e');
      rethrow;
    }
  }

  static Future<Uint8List> _downloadImage(String url) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) {
      throw Exception('Image download failed: ${response.statusCode}');
    }
    return response.bodyBytes;
  }

  static Future<OrtValue> _preprocess(Uint8List raw) async {
    final decoded = img.decodeImage(raw);
    if (decoded == null) throw Exception('Failed to decode image');

    final resized = img.copyResize(decoded, width: _inputSize, height: _inputSize);

    final floatData = Float32List(1 * 3 * _inputSize * _inputSize);
    final area = _inputSize * _inputSize;

    for (int y = 0; y < _inputSize; y++) {
      for (int x = 0; x < _inputSize; x++) {
        final pixel = resized.getPixel(x, y);
        final r = pixel.r / 255.0;
        final g = pixel.g / 255.0;
        final b = pixel.b / 255.0;

        final idx = y * _inputSize + x;
        floatData[0 * area + idx] = (r - _mean[0]) / _std[0];
        floatData[1 * area + idx] = (g - _mean[1]) / _std[1];
        floatData[2 * area + idx] = (b - _mean[2]) / _std[2];
      }
    }

    return OrtValue.fromList(floatData, [1, 3, _inputSize, _inputSize]);
  }

  static Future<void> dispose() async {
    await _session?.close();
    _session = null;
    _ort = null;
    _initialized = false;
  }
}
