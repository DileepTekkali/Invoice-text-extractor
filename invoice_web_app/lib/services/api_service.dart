import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiResponse {
  final String text;
  final String filename;
  final String status;
  final Map<String, dynamic>? structuredData;
  final String? extractionMethod;
  final String? invoiceId;
  final Map<String, dynamic>? invoice;

  ApiResponse({
    required this.text,
    required this.filename,
    required this.status,
    this.structuredData,
    this.extractionMethod,
    this.invoiceId,
    this.invoice,
  });

  factory ApiResponse.fromJson(Map<String, dynamic> json) {
    return ApiResponse(
      text: json["text"] ?? "No text extracted",
      filename: json["filename"] ?? "",
      status: json["status"] ?? "unknown",
      structuredData: json["structured_data"],
      extractionMethod: json["extraction_method"],
      invoiceId: json["invoice_id"],
      invoice: json["invoice"],
    );
  }
}

class InvoiceStats {
  final int totalInvoices;
  final double totalAmount;
  final double totalTax;
  final double avgAmount;

  InvoiceStats({
    required this.totalInvoices,
    required this.totalAmount,
    required this.totalTax,
    required this.avgAmount,
  });

  factory InvoiceStats.fromJson(Map<String, dynamic> json) {
    return InvoiceStats(
      totalInvoices: json["total_invoices"] ?? 0,
      totalAmount: (json["total_amount"] ?? 0).toDouble(),
      totalTax: (json["total_tax"] ?? 0).toDouble(),
      avgAmount: (json["avg_amount"] ?? 0).toDouble(),
    );
  }
}

class ApiService {
  static const String baseUrl =
      "https://invoice-text-extractor-e3q8.onrender.com";
      // "http://localhost:8000";

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

  static Future<Map<String, dynamic>> getInvoices({
    int page = 1,
    int limit = 50,
    String? search,
  }) async {
    try {
      var url = '$baseUrl/invoices?page=$page&limit=$limit';
      if (search != null && search.isNotEmpty) {
        url += '&search=${Uri.encodeComponent(search)}';
      }

      var response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception("Failed to load invoices");
      }
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception("Cannot connect to server");
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> getInvoiceById(String id) async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/invoices/$id'));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception("Failed to load invoice");
      }
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception("Cannot connect to server");
      }
      rethrow;
    }
  }

  static Future<Map<String, dynamic>?> updateInvoice(
    String id,
    Map<String, dynamic> data,
  ) async {
    try {
      var response = await http.put(
        Uri.parse('$baseUrl/invoices/$id'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(data),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else if (response.statusCode == 404) {
        return null;
      } else {
        throw Exception("Failed to update invoice");
      }
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception("Cannot connect to server");
      }
      rethrow;
    }
  }

  static Future<bool> deleteInvoice(String id) async {
    try {
      var response = await http.delete(Uri.parse('$baseUrl/invoices/$id'));

      return response.statusCode == 200;
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception("Cannot connect to server");
      }
      rethrow;
    }
  }

  static Future<InvoiceStats> getStats() async {
    try {
      var response = await http.get(Uri.parse('$baseUrl/stats'));

      if (response.statusCode == 200) {
        return InvoiceStats.fromJson(jsonDecode(response.body));
      } else {
        throw Exception("Failed to load stats");
      }
    } catch (e) {
      if (e.toString().contains("SocketException") ||
          e.toString().contains("Connection refused")) {
        throw Exception("Cannot connect to server");
      }
      rethrow;
    }
  }
}
