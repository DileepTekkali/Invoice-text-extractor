class InvoiceData {
  String id;
  String invoiceNumber;
  String date;
  String ownerName;
  String ownerMobile;
  String ownerAddress;
  String gstin;
  String billToName;
  String billToMobile;
  String billToAddress;
  List<InvoiceItem> items;
  List<String> tableHeaders;
  double subtotal;
  double gstPercentage;
  double total;
  String? currencySymbol;
  String? authorizedSignature;
  String rawText;
  String filename;
  String submittedAt;
  Map<String, dynamic> extraFields;
  List<InvoiceTable> tables;

  Map<String, dynamic> seller;
  Map<String, dynamic> customer;
  Map<String, dynamic> paymentInfo;
  Map<String, dynamic> additionalDetails;
  String? dueDate;
  String? status;
  double tax;
  Map<String, dynamic> taxBreakdown;
  double discount;

  InvoiceData({
    this.id = '',
    this.invoiceNumber = '',
    this.date = '',
    this.ownerName = '',
    this.ownerMobile = '',
    this.ownerAddress = '',
    this.gstin = '',
    this.billToName = '',
    this.billToMobile = '',
    this.billToAddress = '',
    this.items = const [],
    this.tableHeaders = const [],
    this.subtotal = 0.0,
    this.gstPercentage = 0.0,
    this.total = 0.0,
    this.currencySymbol,
    this.authorizedSignature,
    this.rawText = '',
    this.filename = '',
    this.submittedAt = '',
    this.extraFields = const {},
    this.tables = const [],
    this.seller = const {},
    this.customer = const {},
    this.paymentInfo = const {},
    this.additionalDetails = const {},
    this.dueDate,
    this.status,
    this.tax = 0.0,
    this.taxBreakdown = const {},
    this.discount = 0.0,
  });

  factory InvoiceData.fromJson(Map<String, dynamic> json) {
    final seller = json['seller'] as Map<String, dynamic>? ?? {};
    final customer = json['customer'] as Map<String, dynamic>? ?? {};
    final paymentInfo = json['payment_info'] as Map<String, dynamic>? ?? {};
    final additionalDetails =
        json['additional_details'] as Map<String, dynamic>? ?? {};
    final extraFields = json['extra_fields'] as Map<String, dynamic>? ?? {};
    final taxBreakdown = json['tax_breakdown'] as Map<String, dynamic>? ?? {};

    List<InvoiceItem> items = [];
    if (json['line_items'] != null) {
      items = (json['line_items'] as List)
          .map((item) => InvoiceItem.fromJson(item as Map<String, dynamic>))
          .toList();
    }

    List<InvoiceTable> tables = [];
    if (json['tables'] != null) {
      tables = (json['tables'] as List)
          .map((table) => InvoiceTable.fromJson(table as Map<String, dynamic>))
          .toList();
    }

    double subtotalVal = (json['subtotal'] as num?)?.toDouble() ?? 0.0;

    double gstPercentage = 0.0;
    if (json['gst_percentage'] != null) {
      gstPercentage = (json['gst_percentage'] as num).toDouble();
    } else if (taxBreakdown['cgst'] != null && subtotalVal > 0) {
      final cgst = (taxBreakdown['cgst'] as num?)?.toDouble() ?? 0;
      final sgst = (taxBreakdown['sgst'] as num?)?.toDouble() ?? 0;
      gstPercentage = ((cgst + sgst) / subtotalVal) * 100;
    }

    String submittedAt = '';
    if (json['created_at'] != null) {
      submittedAt = json['created_at'].toString();
    }

    return InvoiceData(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      invoiceNumber: json['invoice_number']?.toString() ?? '',
      date: json['date']?.toString() ?? json['invoice_date']?.toString() ?? '',
      ownerName:
          seller['business_name']?.toString() ??
          seller['owner_name']?.toString() ??
          '',
      ownerMobile:
          seller['mobile_number']?.toString() ??
          seller['phone_number']?.toString() ??
          '',
      ownerAddress: seller['business_address']?.toString() ?? '',
      gstin: seller['gst_number']?.toString() ?? '',
      billToName: customer['customer_name']?.toString() ?? '',
      billToMobile: customer['phone_number']?.toString() ?? '',
      billToAddress: customer['customer_address']?.toString() ?? '',
      items: items,
      tableHeaders: tables.isNotEmpty ? tables.first.headers : [],
      subtotal: subtotalVal,
      gstPercentage: gstPercentage,
      total:
          (json['total_amount'] as num?)?.toDouble() ??
          (json['total'] as num?)?.toDouble() ??
          0.0,
      currencySymbol: json['currency']?.toString() ?? '₹',
      authorizedSignature: json['authorized_signature']?.toString(),
      rawText: json['raw_text']?.toString() ?? '',
      filename: json['filename']?.toString() ?? '',
      submittedAt: submittedAt,
      extraFields: extraFields,
      tables: tables,
      seller: seller,
      customer: customer,
      paymentInfo: paymentInfo,
      additionalDetails: additionalDetails,
      dueDate: json['due_date']?.toString(),
      status: json['status']?.toString(),
      tax: (json['tax'] as num?)?.toDouble() ?? 0.0,
      taxBreakdown: taxBreakdown,
      discount: (json['discount'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoice_number': invoiceNumber,
    'date': date,
    'owner_name': ownerName,
    'owner_mobile': ownerMobile,
    'owner_address': ownerAddress,
    'gstin': gstin,
    'bill_to_name': billToName,
    'bill_to_mobile': billToMobile,
    'bill_to_address': billToAddress,
    'items': items.map((e) => e.toJson()).toList(),
    'table_headers': tableHeaders,
    'subtotal': subtotal,
    'gst_percentage': gstPercentage,
    'total': total,
    'currency_symbol': currencySymbol,
    'authorized_signature': authorizedSignature,
    'raw_text': rawText,
    'filename': filename,
    'submitted_at': submittedAt,
    'extra_fields': extraFields,
    'tables': tables.map((t) => t.toJson()).toList(),
  };
}

class InvoiceItem {
  String description;
  int quantity;
  double rate;
  double amount;
  String? unit;
  String? hsnSac;
  double? taxRate;
  String? itemNumber;

  InvoiceItem({
    this.description = '',
    this.quantity = 0,
    this.rate = 0.0,
    this.amount = 0.0,
    this.unit,
    this.hsnSac,
    this.taxRate,
    this.itemNumber,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> json) {
    return InvoiceItem(
      description: json['description']?.toString() ?? '',
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      rate: (json['rate'] as num?)?.toDouble() ?? 0.0,
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      unit: json['unit']?.toString(),
      hsnSac: json['hsn_sac']?.toString(),
      taxRate: (json['tax_rate'] as num?)?.toDouble(),
      itemNumber: json['item_number']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'rate': rate,
    'amount': amount,
    'unit': unit,
    'hsn_sac': hsnSac,
    'tax_rate': taxRate,
    'item_number': itemNumber,
  };
}

class InvoiceTable {
  String title;
  List<String> headers;
  List<List<String>> rows;

  InvoiceTable({
    this.title = '',
    this.headers = const [],
    this.rows = const [],
  });

  factory InvoiceTable.fromJson(Map<String, dynamic> json) {
    List<List<String>> rows = [];
    if (json['rows'] != null) {
      rows = (json['rows'] as List).map((row) {
        if (row is List) {
          return row.map((cell) => cell.toString()).toList();
        }
        return <String>[];
      }).toList();
    }

    return InvoiceTable(
      title: json['title']?.toString() ?? json['table_name']?.toString() ?? '',
      headers: json['headers'] != null
          ? (json['headers'] as List).map((h) => h.toString()).toList()
          : [],
      rows: rows,
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'headers': headers,
    'rows': rows,
  };
}
