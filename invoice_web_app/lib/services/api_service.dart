import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiResponse {
  final Map<String, dynamic>? invoiceData;
  final String filename;
  final String status;
  final String? extractionMethod;
  final String? rawText;

  ApiResponse({
    this.invoiceData,
    required this.filename,
    required this.status,
    this.extractionMethod,
    this.rawText,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      invoiceData: json["invoice_data"],
      filename: json["filename"] ?? "",
      status: json["status"] ?? "unknown",
      extractionMethod: json["extraction_method"],
      rawText: json["raw_text"],
    );
  }
}

class ApiService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_configuredBaseUrl.isNotEmpty) {
      return _configuredBaseUrl.replaceFirst(RegExp(r'/$'), '');
    }

    if (kIsWeb) {
      final host = Uri.base.host.isNotEmpty ? Uri.base.host : 'localhost';
      final scheme = Uri.base.scheme == 'https' ? 'https' : 'http';
      return Uri(scheme: scheme, host: host, port: 8000).toString();
    }

    return "http://localhost:8000";
  }

  static Future<ApiResponse> uploadFile(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      if (bytes.isEmpty) {
        throw Exception('Selected file is empty.');
      }

      var request = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));
      request.headers['Accept'] = 'application/json';

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      var streamedResponse = await request.send().timeout(
        const Duration(minutes: 2),
      );
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return ApiResponse.fromJson(data);
      } else {
        String errorMsg = "Upload failed (${response.statusCode})";
        try {
          var errorData = jsonDecode(response.body);
          if (errorData['detail'] != null) {
            errorMsg = errorData['detail'];
          }
        } catch (_) {}
        throw Exception(errorMsg);
      }
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception(
          "Cannot connect to server. Make sure the backend is running.",
        );
      }
      rethrow;
    }
  }
}
