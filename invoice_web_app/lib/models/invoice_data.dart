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
  Map<String, String> extraFields;
  List<InvoiceTable> tables;

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
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'invoiceNumber': invoiceNumber,
    'date': date,
    'ownerName': ownerName,
    'ownerMobile': ownerMobile,
    'ownerAddress': ownerAddress,
    'gstin': gstin,
    'billToName': billToName,
    'billToMobile': billToMobile,
    'billToAddress': billToAddress,
    'items': items.map((e) => e.toJson()).toList(),
    'tableHeaders': tableHeaders,
    'subtotal': subtotal,
    'gstPercentage': gstPercentage,
    'total': total,
    'currencySymbol': currencySymbol,
    'authorizedSignature': authorizedSignature,
    'rawText': rawText,
    'filename': filename,
    'submittedAt': submittedAt,
    'extraFields': extraFields,
    'tables': tables.map((t) => t.toJson()).toList(),
  };
}

class InvoiceItem {
  String description;
  int quantity;
  double rate;
  double amount;
  String? unit;

  InvoiceItem({
    this.description = '',
    this.quantity = 0,
    this.rate = 0.0,
    this.amount = 0.0,
    this.unit,
  });

  Map<String, dynamic> toJson() => {
    'description': description,
    'quantity': quantity,
    'rate': rate,
    'amount': amount,
    'unit': unit,
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

  Map<String, dynamic> toJson() => {
    'title': title,
    'headers': headers,
    'rows': rows,
  };
}
