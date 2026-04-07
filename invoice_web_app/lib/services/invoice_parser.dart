import 'package:invoice_web_app/models/invoice_data.dart';

class InvoiceParser {
  static InvoiceData parse(String rawText, String filename) {
    return parseWithExtractedData(rawText, filename, null);
  }

  static InvoiceData parseWithExtractedData(
    String rawText,
    String filename,
    Map<String, dynamic>? extractedData,
  ) {
    InvoiceData invoice = InvoiceData(rawText: rawText, filename: filename);

    if (extractedData != null) {
      invoice = _parseExtractedInvoice(extractedData, rawText, filename);
    } else {
      invoice.currencySymbol = _extractCurrencySymbol(rawText);
      invoice.invoiceNumber = _extractInvoiceNumber(rawText);
      invoice.date = _extractDate(rawText);
      invoice.ownerName = _extractBusinessName(rawText);
      invoice.ownerMobile = _extractMobile(rawText);
      invoice.ownerAddress = _extractSellerAddress(rawText);
      invoice.gstin = _extractGSTIN(rawText);
      invoice.billToName = _extractBillToName(rawText);
      invoice.billToMobile = _extractMobile(rawText);
      invoice.billToAddress = '';

      invoice.tables = _extractAllTables(rawText);

      var extractedData = _extractItemsFromTables(invoice.tables);
      invoice.items = extractedData['items'] as List<InvoiceItem>;
      invoice.tableHeaders = extractedData['headers'] as List<String>;

      invoice.subtotal = _extractSubtotal(rawText, invoice.currencySymbol);
      invoice.gstPercentage = _extractGSTPercentage(rawText);
      invoice.total = _extractTotal(rawText, invoice.currencySymbol);
      invoice.authorizedSignature = _extractSignature(rawText);
      invoice.extraFields = _extractExtraFields(rawText);
    }

    return invoice;
  }

  static InvoiceData _parseExtractedInvoice(
    Map<String, dynamic> extractedData,
    String rawText,
    String filename,
  ) {
    InvoiceData invoice = InvoiceData(rawText: rawText, filename: filename);

    invoice.invoiceNumber =
        _getNestedValue(extractedData, ['invoice_details', 'invoice_number']) ??
        '';
    invoice.date =
        _getNestedValue(extractedData, ['invoice_details', 'invoice_date']) ??
        '';

    String? dueDate = _getNestedValue(extractedData, [
      'invoice_details',
      'due_date',
    ]);
    if (dueDate != null && dueDate.isNotEmpty) {
      invoice.extraFields['Due Date'] = dueDate;
    }

    String currency =
        _getNestedValue(extractedData, ['invoice_details', 'currency']) ?? '';
    invoice.currencySymbol = _resolveCurrencySymbol(currency, rawText);

    invoice.ownerName =
        _getNestedValue(extractedData, ['vendor_details', 'name']) ?? '';
    invoice.ownerAddress =
        _getNestedValue(extractedData, ['vendor_details', 'address']) ?? '';
    invoice.ownerMobile =
        _getNestedValue(extractedData, ['vendor_details', 'phone']) ?? '';
    String? vendorEmail = _getNestedValue(extractedData, [
      'vendor_details',
      'email',
    ]);
    if (vendorEmail != null && vendorEmail.isNotEmpty) {
      invoice.extraFields['Email'] = vendorEmail;
    }

    invoice.billToName =
        _getNestedValue(extractedData, ['customer_details', 'name']) ?? '';
    invoice.billToAddress =
        _getNestedValue(extractedData, ['customer_details', 'address']) ?? '';
    invoice.billToMobile =
        _getNestedValue(extractedData, ['customer_details', 'phone']) ?? '';
    String? customerEmail = _getNestedValue(extractedData, [
      'customer_details',
      'email',
    ]);
    if (customerEmail != null && customerEmail.isNotEmpty) {
      invoice.extraFields['Bill To Email'] = customerEmail;
    }

    String? paymentMethod = _getNestedValue(extractedData, [
      'payment_details',
      'payment_method',
    ]);
    String? bankName = _getNestedValue(extractedData, [
      'payment_details',
      'bank_name',
    ]);
    String? accountNumber = _getNestedValue(extractedData, [
      'payment_details',
      'account_number',
    ]);
    String? accountName = _getNestedValue(extractedData, [
      'payment_details',
      'account_name',
    ]);

    if (paymentMethod != null)
      invoice.extraFields['Payment Method'] = paymentMethod;
    if (bankName != null) invoice.extraFields['Bank Name'] = bankName;
    if (accountNumber != null)
      invoice.extraFields['Account Number'] = accountNumber;
    if (accountName != null) invoice.extraFields['Account Name'] = accountName;

    invoice.subtotal = _getDoubleValue(extractedData, ['summary', 'subtotal']);
    invoice.gstPercentage = _getDoubleValue(extractedData, ['summary', 'tax']);
    invoice.total = _getDoubleValue(extractedData, ['summary', 'total']);

    String? notes = _getNestedValue(extractedData, [
      'additional_info',
      'notes',
    ]);
    String? terms = _getNestedValue(extractedData, [
      'additional_info',
      'terms',
    ]);
    if (notes != null && notes.isNotEmpty) invoice.authorizedSignature = notes;
    if (terms != null && terms.isNotEmpty) invoice.extraFields['Terms'] = terms;

    List<dynamic>? lineItems = extractedData['line_items'] as List<dynamic>?;
    if (lineItems != null && lineItems.isNotEmpty) {
      invoice.items = lineItems.map<InvoiceItem>((item) {
        return InvoiceItem(
          description: _getNestedValue(item, ['description']) ?? '',
          quantity: _getIntValue(item, ['quantity']),
          rate: _getDoubleValue(item, ['unit_price']),
          amount: _getDoubleValue(item, ['total']),
        );
      }).toList();

      invoice.tableHeaders = ['#', 'Description', 'Qty', 'Unit Price', 'Total'];
    }

    return invoice;
  }

  static String? _getNestedValue(Map<String, dynamic> data, List<String> keys) {
    dynamic current = data;
    for (String key in keys) {
      if (current is Map<String, dynamic>) {
        current = current[key];
      } else {
        return null;
      }
    }
    return current?.toString();
  }

  static double _getDoubleValue(Map<String, dynamic> data, List<String> keys) {
    dynamic value = _getNestedValue(data, keys);
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0.0;
    }
    return 0.0;
  }

  static int _getIntValue(Map<String, dynamic> data, List<String> keys) {
    dynamic value = _getNestedValue(data, keys);
    if (value == null) return 0;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) {
      return int.tryParse(value.replaceAll(RegExp(r'[^\d]'), '')) ?? 0;
    }
    return 0;
  }

  static String _mapCurrencyToSymbol(String currency) {
    String upperCurrency = currency.toUpperCase();
    if (upperCurrency.contains('USD') || upperCurrency.contains('\$'))
      return '\$';
    if (upperCurrency.contains('INR') ||
        upperCurrency.contains('₹') ||
        upperCurrency.contains('RS') ||
        upperCurrency.contains('RUPEE'))
      return '₹';
    if (upperCurrency.contains('EUR') || upperCurrency.contains('€'))
      return '€';
    if (upperCurrency.contains('GBP') || upperCurrency.contains('£'))
      return '£';
    if (upperCurrency.contains('JPY') ||
        upperCurrency.contains('CNY') ||
        upperCurrency.contains('¥'))
      return '¥';
    return '';
  }

  static String _resolveCurrencySymbol(String currency, String rawText) {
    final normalizedCurrency = _mapCurrencyToSymbol(currency);
    if (normalizedCurrency.isNotEmpty) {
      return normalizedCurrency;
    }
    return _extractCurrencySymbol(rawText);
  }

  static InvoiceData parseWithStructuredData(
    String rawText,
    String filename,
    Map<String, dynamic>? structuredData,
  ) {
    InvoiceData invoice = InvoiceData(rawText: rawText, filename: filename);

    invoice.currencySymbol = _extractCurrencySymbol(rawText);
    invoice.invoiceNumber = _extractInvoiceNumber(rawText);
    invoice.date = _extractDate(rawText);
    invoice.ownerName = _extractBusinessName(rawText);
    invoice.ownerMobile = _extractMobile(rawText);
    invoice.ownerAddress = _extractSellerAddress(rawText);
    invoice.gstin = _extractGSTIN(rawText);
    invoice.billToName = _extractBillToName(rawText);
    invoice.billToMobile = _extractMobile(rawText);
    invoice.billToAddress = '';

    if (structuredData != null && structuredData['tables'] != null) {
      invoice.tables = _parseStructuredTables(structuredData['tables']);
    } else {
      invoice.tables = _extractAllTables(rawText);
    }

    var extractedData = _extractItemsFromTables(invoice.tables);
    invoice.items = extractedData['items'] as List<InvoiceItem>;
    invoice.tableHeaders = extractedData['headers'] as List<String>;

    invoice.subtotal = _extractSubtotal(rawText, invoice.currencySymbol);
    invoice.gstPercentage = _extractGSTPercentage(rawText);
    invoice.total = _extractTotal(rawText, invoice.currencySymbol);
    invoice.authorizedSignature = _extractSignature(rawText);
    invoice.extraFields = _extractExtraFields(rawText);

    return invoice;
  }

  static List<InvoiceTable> _parseStructuredTables(List<dynamic> tablesData) {
    List<InvoiceTable> tables = [];

    for (var tableData in tablesData) {
      if (tableData is Map<String, dynamic>) {
        String title = tableData['table_index'] != null
            ? 'Table ${tableData['table_index']}'
            : 'Data Table';

        List<String> headers = [];
        if (tableData['headers'] is List) {
          headers = (tableData['headers'] as List)
              .map((h) => h.toString())
              .toList();
        }

        List<List<String>> rows = [];
        if (tableData['rows'] is List) {
          for (var row in tableData['rows'] as List) {
            if (row is List) {
              rows.add(row.map((cell) => cell.toString()).toList());
            }
          }
        }

        tables.add(InvoiceTable(title: title, headers: headers, rows: rows));
      }
    }

    return tables;
  }

  static String _extractCurrencySymbol(String text) {
    final upperText = text.toUpperCase();
    if (text.contains('\$') ||
        upperText.contains('USD') ||
        upperText.contains('DOLLAR')) {
      return '\$';
    }
    if (text.contains('₹') ||
        upperText.contains('INR') ||
        upperText.contains('RUPEE') ||
        upperText.contains('RUPEES') ||
        RegExp(r'\bRS\.?\b', caseSensitive: false).hasMatch(text) ||
        _containsRupeePattern(text)) {
      return '₹';
    }
    if (text.contains('€') ||
        upperText.contains('EUR') ||
        upperText.contains('EURO')) {
      return '€';
    }
    if (text.contains('£') ||
        upperText.contains('GBP') ||
        upperText.contains('POUND')) {
      return '£';
    }
    if (text.contains('¥') ||
        upperText.contains('JPY') ||
        upperText.contains('CNY') ||
        upperText.contains('YEN')) {
      return '¥';
    }
    return '';
  }

  static bool _containsRupeePattern(String text) {
    return RegExp(r'Rs\.?\s*\d', caseSensitive: false).hasMatch(text) ||
        RegExp(r'\d+\.?\d*\s*Rs', caseSensitive: false).hasMatch(text);
  }

  static String _extractInvoiceNumber(String text) {
    var patterns = [
      RegExp(r'NO\.\s*([0-9]+)', caseSensitive: false),
      RegExp(r'NO[:\s]+([0-9]+)', caseSensitive: false),
      RegExp(
        r'Invoice\s*(?:No\.?|Number|#|Id)?[:\s]*([A-Z0-9][A-Z0-9\-_/\.]{1,20})',
        caseSensitive: false,
      ),
      RegExp(
        r'\b(?:INV|Invoice|Inv|Bill)[-\s#]*([A-Z0-9\-]{2,15})\b',
        caseSensitive: false,
      ),
      RegExp(
        r'Invoice\s*Number[:\s]*([A-Z0-9][A-Z0-9\-_/\.]{1,15})',
        caseSensitive: false,
      ),
      RegExp(r'\bINV-\s*([A-Z0-9\-]{2,15})\b', caseSensitive: false),
      RegExp(r'#\s*([A-Z0-9][A-Z0-9\-]{1,15})\b'),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String num = match.group(1)!.trim();
        num = num.replaceAll(RegExp(r'^\W+|\W+$'), '');
        if (num.length >= 2 &&
            num.length < 25 &&
            RegExp(r'^[A-Z0-9\-_/\.]+$', caseSensitive: false).hasMatch(num)) {
          String upperNum = num.toUpperCase();
          if (!RegExp(
            r'^(DATE|AMOUNT|TOTAL|EMAIL|PHONE|FROM|TO)$',
            caseSensitive: false,
          ).hasMatch(upperNum)) {
            return upperNum;
          }
        }
      }
    }
    return '';
  }

  static String _extractDate(String text) {
    var patterns = [
      RegExp(r'Invoice\s*Date[:\s]*([A-Za-z\s\d,]+)', caseSensitive: false),
      RegExp(r'Date[:\s]*([A-Za-z\s\d,]+)', caseSensitive: false),
      RegExp(r'(\d{1,2}\s+[A-Za-z]+\s+\d{4})', caseSensitive: false),
      RegExp(r'([A-Za-z]+\s+\d{1,2},?\s+\d{4})', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        String date = match.group(1)!.trim();
        return date;
      }
    }
    return '';
  }

  static String _extractBusinessName(String text) {
    var patterns = [
      RegExp(r'From:\s*\n?([^\n]+)', caseSensitive: false),
      RegExp(r'Seller:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'Company:\s*([^\n]+)', caseSensitive: false),
      RegExp(r'Business\s*Name:\s*([^\n]+)', caseSensitive: false),
      RegExp(
        r'(?:\n|^)([A-Z][A-Za-z0-9\s&\-\.]{3,40})(?:$|\n)',
        caseSensitive: false,
      ),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String name = match.group(1)!.trim();
        name = name.replaceAll(RegExp(r'^\d[\d\s\-.]*'), '').trim();
        name = name.replaceAll(RegExp(r'\s+'), ' ');
        name = name
            .replaceAll(
              RegExp(
                r'^(?:Invoice|To:|From:|Thank|Payment|Total|Sub|Phone|Email|Address|GSTIN)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        if (name.length >= 3 &&
            name.length < 50 &&
            !RegExp(r'^[\d\s\-.]+$').hasMatch(name)) {
          return name;
        }
      }
    }
    return '';
  }

  static String _extractSellerAddress(String text) {
    var patterns = [
      RegExp(r'From:[\s\S]*?(?:To:|Invoice\s*Number)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        String section = match.group(0) ?? '';
        var lines = section.split('\n');
        List<String> addressLines = [];
        bool addressStarted = false;

        for (var line in lines) {
          line = line.trim();
          if (line.toLowerCase().contains('from:')) {
            addressStarted = true;
            continue;
          }
          if (line.toLowerCase().contains('to:') ||
              line.toLowerCase().contains('invoice')) {
            break;
          }
          if (addressStarted && line.isNotEmpty) {
            if (RegExp(r'^[A-Za-z]').hasMatch(line) &&
                !RegExp(r'^[A-Za-z]+@[A-Za-z]').hasMatch(line)) {
              if (!RegExp(r'^\d{5,}').hasMatch(line)) {
                addressLines.add(line);
              }
            }
          }
        }

        if (addressLines.length > 0) {
          addressLines = addressLines.sublist(1);
          return addressLines.join(', ');
        }
      }
    }
    return '';
  }

  static String _extractMobile(String text) {
    var phonePatterns = [
      RegExp(
        r'(?:Phone|Mobile|Tel)[:\s]*([+\d][\d\s\-]{8,15})',
        caseSensitive: false,
      ),
      RegExp(
        r'(?:Phone|Mobile|Tel)\s+([+\d][\d\s\-]{8,15})',
        caseSensitive: false,
      ),
      RegExp(r'\b(\+?\d{1,3}[-.\s]?)?\(?\d{3}\)?[-.\s]?\d{3}[-.\s]?\d{4}\b'),
      RegExp(r'\b\d{10}\b'),
      RegExp(r'\b\d{4}[-.\s]?\d{3}[-.\s]?\d{3}\b'),
    ];

    for (var p in phonePatterns) {
      var m = p.firstMatch(text);
      if (m != null) {
        String phone = m.group(1)?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
        if (phone.isEmpty) {
          phone = m.group(0)?.replaceAll(RegExp(r'[^\d]'), '') ?? '';
        }
        if (phone.length >= 10 && phone.length <= 15) {
          if (phone.length > 10) {
            phone = phone.substring(phone.length - 10);
          }
          return phone;
        }
      }
    }
    return '';
  }

  static String _extractGSTIN(String text) {
    return '';
  }

  static String _extractBillToName(String text) {
    var patterns = [
      RegExp(
        r'Billed?\s*to:?\s*\n?([A-Za-z][A-Za-z0-9\s\-&.]+)',
        caseSensitive: false,
      ),
      RegExp(r'To:?\s*\n?([A-Za-z][A-Za-z0-9\s\-&.]+)', caseSensitive: false),
      RegExp(
        r'Bill\s*To:?\s*([A-Za-z][A-Za-z0-9\s\-&.]+)',
        caseSensitive: false,
      ),
      RegExp(
        r'Customer:?\s*([A-Za-z][A-Za-z0-9\s\-&.]+)',
        caseSensitive: false,
      ),
      RegExp(r'Client:?\s*([A-Za-z][A-Za-z0-9\s\-&.]+)', caseSensitive: false),
      RegExp(
        r'Customer\s*Name:?\s*([A-Za-z][A-Za-z0-9\s\-&.]+)',
        caseSensitive: false,
      ),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String name = match.group(1)!.trim();
        name = name.replaceAll(RegExp(r'^\d[\d\s\-.]*'), '').trim();
        name = name.replaceAll(RegExp(r'\s+'), ' ');
        name = name
            .replaceAll(
              RegExp(
                r'^(?:From:|To:|Email|Phone|Address|Invoice|Total)',
                caseSensitive: false,
              ),
              '',
            )
            .trim();
        if (name.length >= 2 &&
            name.length < 50 &&
            !RegExp(r'^[\d\s\-.]+$').hasMatch(name)) {
          return name;
        }
      }
    }
    return '';
  }

  static List<InvoiceTable> _extractAllTables(String text) {
    List<InvoiceTable> tables = [];

    List<String> sections = text.split(
      RegExp(r'---TABLE[ -]*(?:START|start)?---', caseSensitive: false),
    );

    for (int i = 1; i < sections.length; i++) {
      String section = sections[i];

      var endParts = section.split(
        RegExp(r'---TABLE[ -]*(?:END|end)?---', caseSensitive: false),
      );
      String tableContent = endParts[0].trim();

      if (tableContent.isEmpty) continue;

      List<List<String>> rows = _parseTableRows(tableContent);

      if (rows.isNotEmpty) {
        String title = _determineTableTitle(rows);
        List<String> headers = rows.isNotEmpty ? rows[0] : [];
        List<List<String>> dataRows = rows.length > 1 ? rows.sublist(1) : [];
        int maxCols = headers.length;
        for (var row in dataRows) {
          if (row.length > maxCols) maxCols = row.length;
        }
        headers = _padRow(headers, maxCols);
        dataRows = dataRows.map((r) => _padRow(r, maxCols)).toList();

        tables.add(
          InvoiceTable(title: title, headers: headers, rows: dataRows),
        );
      }
    }

    if (tables.isEmpty) {
      String tableSection = _extractTableSection(text);
      if (tableSection.isNotEmpty) {
        List<List<String>> allRows = _parseTableRows(tableSection);
        if (allRows.isNotEmpty) {
          String title = _determineTableTitle(allRows);
          List<String> headers = allRows.isNotEmpty ? allRows[0] : [];
          List<List<String>> dataRows = allRows.length > 1
              ? allRows.sublist(1)
              : [];
          int maxCols = headers.length;
          for (var row in dataRows) {
            if (row.length > maxCols) maxCols = row.length;
          }
          headers = _padRow(headers, maxCols);
          dataRows = dataRows.map((r) => _padRow(r, maxCols)).toList();
          tables.add(
            InvoiceTable(title: title, headers: headers, rows: dataRows),
          );
        }
      }
    }

    return tables;
  }

  static List<List<String>> _parseTableRows(String content) {
    List<List<String>> rows = [];
    var lines = content.split('\n');
    int maxCols = 0;

    for (var line in lines) {
      line = line.trim();
      if (line.isEmpty) continue;

      List<String> parts;
      if (line.contains('|')) {
        parts = line
            .split('|')
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
      } else {
        parts = line
            .split(RegExp(r'\s{2,}'))
            .map((p) => p.trim())
            .where((p) => p.isNotEmpty)
            .toList();
      }

      if (parts.length >= 1) {
        if (parts.length > maxCols) maxCols = parts.length;
        rows.add(parts);
      }
    }

    for (int i = 0; i < rows.length; i++) {
      rows[i] = _padRow(rows[i], maxCols);
    }

    return rows;
  }

  static String _extractTableSection(String text) {
    List<String> lines = text.split('\n');
    int startIdx = -1;
    int endIdx = lines.length;

    List<String> tableKeywords = [
      'item',
      'qty',
      'quantity',
      'price',
      'amount',
      'rate',
      'total',
      'description',
      'service',
    ];

    for (int i = 0; i < lines.length; i++) {
      String line = lines[i].toLowerCase();
      if (tableKeywords.any((k) => line.contains(k))) {
        if (startIdx == -1) {
          startIdx = i;
        }
      }
      if (startIdx != -1 &&
          (line.contains('sub total') ||
              line.contains('grand total') ||
              line.contains('payment') ||
              line.contains('note:') ||
              line.contains('thank'))) {
        if (endIdx == lines.length) {
          endIdx = i + 1;
        }
      }
    }

    if (startIdx == -1) {
      return text;
    }

    return lines.sublist(startIdx, endIdx).join('\n');
  }

  static List<String> _padRow(List<String> row, int targetLength) {
    List<String> padded = List.from(row);
    while (padded.length < targetLength) {
      padded.add('');
    }
    return padded;
  }

  static String _determineTableTitle(List<List<String>> rows) {
    if (rows.isEmpty) return 'Data Table';

    String firstRow = rows[0].join(' ').toLowerCase();

    if (firstRow.contains('hrs') ||
        firstRow.contains('qty') ||
        firstRow.contains('service')) {
      return 'Line Items';
    }
    if (firstRow.contains('invoice') && firstRow.contains('date')) {
      return 'Invoice Information';
    }
    if (firstRow.contains('sub') && firstRow.contains('total')) {
      return 'Financial Summary';
    }
    if (firstRow.contains('bank') || firstRow.contains('acc')) {
      return 'Bank Details';
    }
    if (firstRow.contains('from') || firstRow.contains('to')) {
      return 'Parties';
    }

    return 'Data Table';
  }

  static Map<String, dynamic> _extractItemsFromTables(
    List<InvoiceTable> tables,
  ) {
    List<InvoiceItem> items = [];
    List<String> headers = [];

    for (var table in tables) {
      if (table.title.toLowerCase().contains('line item') ||
          table.title.toLowerCase().contains('item')) {
        headers = table.headers;

        for (var row in table.rows) {
          if (row.length >= 2) {
            String desc = '';
            int qty = 1;
            double rate = 0;
            double amount = 0;

            for (int i = 0; i < row.length; i++) {
              String cell = row[i].trim();

              if (_isNumeric(cell)) {
                double val = _parseDouble(cell);
                if (cell.contains('\$') || cell.contains('%')) {
                  continue;
                }
                if (rate == 0 && val > 0 && i == row.length - 1) {
                  amount = val;
                } else if (val > 0) {
                  if (rate == 0) rate = val;
                }
              } else if (cell.isNotEmpty && !_isExcluded(cell)) {
                if (desc.isEmpty) {
                  desc = cell;
                } else {
                  desc += ' ' + cell;
                }
              }
            }

            if (amount == 0 && rate > 0) {
              amount = rate * qty;
            }

            if (desc.isNotEmpty && (amount > 0 || rate > 0)) {
              items.add(
                InvoiceItem(
                  description: desc,
                  quantity: qty,
                  rate: rate,
                  amount: amount,
                ),
              );
            }
          }
        }
      }
    }

    return {'items': items, 'headers': headers};
  }

  static bool _isNumeric(String str) {
    String cleaned = str.replaceAll(RegExp(r'[₹$€£¥,\s]'), '');
    cleaned = cleaned.replaceAll(RegExp(r'[A-Za-z]'), '');
    return RegExp(r'^\d+\.?\d*$').hasMatch(cleaned);
  }

  static double _parseDouble(String value) {
    String cleaned = value
        .replaceAll(RegExp(r'[₹$€£¥,\s]'), '')
        .replaceAll(RegExp(r'[A-Za-z]'), '');
    return double.tryParse(cleaned) ?? 0.0;
  }

  static bool _isExcluded(String text) {
    List<String> excluded = [
      'subtotal',
      'total',
      'gst',
      'tax',
      'discount',
      'shipping',
      'payment',
      'amount',
      'balance',
      'thank',
      'page',
      'invoice',
    ];
    return excluded.any((e) => text.toLowerCase().contains(e));
  }

  static double _extractSubtotal(String text, String? currencySymbol) {
    var patterns = [
      RegExp(r'Sub\s*Total[:\s]*[₹$€£¥]?([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'Sub\s*Total[:\s]*([\d,]+\.?\d*)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        return _parseDouble(match.group(1) ?? '0');
      }
    }
    return 0.0;
  }

  static double _extractGSTPercentage(String text) {
    var patterns = [
      RegExp(r'Tax[:\s]*[₹$€£¥]?([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'(\d+(?:\.\d+)?)\s*%', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        if (match.groupCount >= 1) {
          return double.tryParse(match.group(1) ?? '0') ?? 0.0;
        }
      }
    }
    return 0.0;
  }

  static double _extractTotal(String text, String? currencySymbol) {
    var patterns = [
      RegExp(r'Total\s*Due[:\s]*[₹$€£¥]?([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(
        r'Grand\s*Total[:\s]*[₹$€£¥]?([\d,]+\.?\d*)',
        caseSensitive: false,
      ),
      RegExp(r'Total[:\s]*[₹$€£¥]?([\d,]+\.?\d*)', caseSensitive: false),
    ];

    for (var pattern in patterns) {
      var match = pattern.firstMatch(text);
      if (match != null) {
        double val = _parseDouble(match.group(1) ?? '0');
        if (val > 0) return val;
      }
    }
    return 0.0;
  }

  static String? _extractSignature(String text) {
    if (RegExp(
      r'AUTHORIZED\s*SIGNATURE',
      caseSensitive: false,
    ).hasMatch(text)) {
      return 'AUTHORIZED SIGNATURE';
    }
    if (RegExp(r'Thank\s*you', caseSensitive: false).hasMatch(text)) {
      return 'Thank you for your business';
    }
    return null;
  }

  static Map<String, String> _extractExtraFields(String text) {
    Map<String, String> extra = {};

    var fieldPatterns = {
      'Email': RegExp(r'([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})'),
      'Order Number': RegExp(
        r'Order\s*Number[:\s]*(\w+)',
        caseSensitive: false,
      ),
      'Due Date': RegExp(
        r'Due\s*Date[:\s]*([A-Za-z\s\d,]+)',
        caseSensitive: false,
      ),
      'Payment Terms': RegExp(
        r'Payment[:\s]*(.*?)(?:\n|$)',
        caseSensitive: false,
      ),
    };

    for (var entry in fieldPatterns.entries) {
      var match = entry.value.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String val = match.group(1)!.trim();
        if (val.isNotEmpty && val.length < 100) {
          extra[entry.key] = val;
        }
      }
    }

    return extra;
  }
}
