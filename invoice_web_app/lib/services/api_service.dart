import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:8000";

  static Future<String> uploadFile(List<int> bytes, String fileName) async {
    try {
      var request = http.MultipartRequest("POST", Uri.parse("$baseUrl/upload"));

      request.files.add(
        http.MultipartFile.fromBytes('file', bytes, filename: fileName),
      );

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        return data["text"] ?? "No text extracted";
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
