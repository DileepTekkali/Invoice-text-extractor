import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final String text;
  final String filename;
  final String status;
  final Map<String, dynamic>? structuredData;
  final String? extractionMethod;

  ApiResponse({
    required this.text,
    required this.filename,
    required this.status,
    this.structuredData,
    this.extractionMethod,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      text: json["text"] ?? "No text extracted",
      filename: json["filename"] ?? "",
      status: json["status"] ?? "unknown",
      structuredData: json["structured_data"],
      extractionMethod: json["extraction_method"],
    );
  }
}

class ApiService {
  static const String baseUrl = "http://localhost:8000";

  static Future<ApiResponse> uploadFile(
    List<int> bytes,
    String fileName,
  ) async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return ApiResponse.fromJson(data);
      } else {
        String errorMsg = "Upload failed";
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
