import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/invoice_data.dart';

class StorageService {
  static const String _invoicesKey = 'submitted_invoices';
  static SharedPreferences? _prefs;

  static Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  static Future<List<InvoiceData>> getInvoices() async {
    _prefs ??= await SharedPreferences.getInstance();

    final String? data = _prefs!.getString(_invoicesKey);
    if (data == null || data.isEmpty) {
      return [];
    }

    try {
      List<dynamic> jsonList = jsonDecode(data);
      return jsonList.map((json) => _invoiceFromJson(json)).toList();
    } catch (e) {
      return [];
    }
  }

  static Future<void> saveInvoice(InvoiceData invoice) async {
    _prefs ??= await SharedPreferences.getInstance();

    List<InvoiceData> invoices = await getInvoices();
    invoices.insert(0, invoice);

    List<Map<String, dynamic>> jsonList = invoices
        .map((inv) => _invoiceToJson(inv))
        .toList();
    await _prefs!.setString(_invoicesKey, jsonEncode(jsonList));
  }

  static Future<void> deleteInvoice(String id) async {
    _prefs ??= await SharedPreferences.getInstance();

    List<InvoiceData> invoices = await getInvoices();
    invoices.removeWhere((inv) => inv.id == id);

    List<Map<String, dynamic>> jsonList = invoices
        .map((inv) => _invoiceToJson(inv))
        .toList();
    await _prefs!.setString(_invoicesKey, jsonEncode(jsonList));
  }

  static Future<void> clearAll() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _prefs!.remove(_invoicesKey);
  }

  static Map<String, dynamic> _invoiceToJson(InvoiceData invoice) {
    return {
      'id': invoice.id,
      'invoiceNumber': invoice.invoiceNumber,
      'date': invoice.date,
      'ownerName': invoice.ownerName,
      'ownerMobile': invoice.ownerMobile,
      'ownerAddress': invoice.ownerAddress,
      'gstin': invoice.gstin,
      'billToName': invoice.billToName,
      'billToMobile': invoice.billToMobile,
      'billToAddress': invoice.billToAddress,
      'subtotal': invoice.subtotal,
      'gstPercentage': invoice.gstPercentage,
      'total': invoice.total,
      'currencySymbol': invoice.currencySymbol,
      'authorizedSignature': invoice.authorizedSignature,
      'rawText': invoice.rawText,
      'filename': invoice.filename,
      'submittedAt': invoice.submittedAt,
      'extraFields': invoice.extraFields,
      'tableHeaders': invoice.tableHeaders,
      'items': invoice.items
          .map(
            (item) => {
              'description': item.description,
              'quantity': item.quantity,
              'rate': item.rate,
              'amount': item.amount,
              'unit': item.unit,
            },
          )
          .toList(),
      'tables': invoice.tables.map((t) => t.toJson()).toList(),
    };
  }

  static InvoiceData _invoiceFromJson(Map<String, dynamic> json) {
    InvoiceData invoice = InvoiceData(
      id: json['id'] ?? '',
      invoiceNumber: json['invoiceNumber'] ?? '',
      date: json['date'] ?? '',
      ownerName: json['ownerName'] ?? '',
      ownerMobile: json['ownerMobile'] ?? '',
      ownerAddress: json['ownerAddress'] ?? '',
      gstin: json['gstin'] ?? '',
      billToName: json['billToName'] ?? '',
      billToMobile: json['billToMobile'] ?? '',
      billToAddress: json['billToAddress'] ?? '',
      subtotal: (json['subtotal'] ?? 0).toDouble(),
      gstPercentage: (json['gstPercentage'] ?? 0).toDouble(),
      total: (json['total'] ?? 0).toDouble(),
      currencySymbol: json['currencySymbol'],
      authorizedSignature: json['authorizedSignature'],
      rawText: json['rawText'] ?? '',
      filename: json['filename'] ?? '',
      submittedAt: json['submittedAt'] ?? '',
      extraFields: json['extraFields'] != null
          ? Map<String, String>.from(json['extraFields'])
          : {},
      tableHeaders: json['tableHeaders'] != null
          ? List<String>.from(json['tableHeaders'])
          : [],
    );

    if (json['items'] != null) {
      invoice.items = (json['items'] as List)
          .map(
            (item) => InvoiceItem(
              description: item['description'] ?? '',
              quantity: item['quantity'] ?? 0,
              rate: (item['rate'] ?? 0).toDouble(),
              amount: (item['amount'] ?? 0).toDouble(),
              unit: item['unit'],
            ),
          )
          .toList();
    }

    if (json['tables'] != null) {
      invoice.tables = (json['tables'] as List)
          .map(
            (t) => InvoiceTable(
              title: t['title'] ?? '',
              headers: List<String>.from(t['headers'] ?? []),
              rows:
                  (t['rows'] as List?)
                      ?.map((r) => List<String>.from(r))
                      .toList() ??
                  [],
            ),
          )
          .toList();
    }

    return invoice;
  }
}
