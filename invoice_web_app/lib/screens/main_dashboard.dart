import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/invoice_data.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/invoice_parser.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  List<InvoiceData> _invoices = [];
  List<InvoiceData> _filteredInvoices = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortAscending = false;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    try {
      final response = await ApiService.getInvoices(
        search: _searchQuery.isNotEmpty ? _searchQuery : null,
      );
      final List<dynamic> invoicesList = response['invoices'] ?? [];
      List<InvoiceData> invoices = invoicesList
          .map((json) => InvoiceData.fromJson(json))
          .toList();

      setState(() {
        _invoices = invoices;
        _filteredInvoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _invoices = [];
        _filteredInvoices = [];
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading invoices: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _applySortAndFilter() {
    List<InvoiceData> result = List.from(_invoices);

    if (_searchQuery.isNotEmpty) {
      result = result.where((inv) {
        String query = _searchQuery.toLowerCase();
        return inv.invoiceNumber.toLowerCase().contains(query) ||
            inv.ownerName.toLowerCase().contains(query) ||
            inv.billToName.toLowerCase().contains(query) ||
            inv.gstin.toLowerCase().contains(query) ||
            inv.date.toLowerCase().contains(query) ||
            (inv.extraFields['Email']?.toLowerCase().contains(query) ??
                false) ||
            (inv.extraFields['Phone']?.toLowerCase().contains(query) ?? false);
      }).toList();
    }

    result.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'invoice':
          comparison = a.invoiceNumber.compareTo(b.invoiceNumber);
          break;
        case 'customer':
          comparison = a.billToName.compareTo(b.billToName);
          break;
        case 'amount':
          comparison = a.total.compareTo(b.total);
          break;
        case 'date':
        default:
          comparison = a.submittedAt.compareTo(b.submittedAt);
      }
      return _sortAscending ? comparison : -comparison;
    });

    setState(() => _filteredInvoices = result);
  }

  String _formatCurrency(double amount, String? currencySymbol) {
    String symbol = currencySymbol ?? '₹';
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  Future<void> _pickAndUpload(String type) async {
    FilePickerResult? picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: type == 'pdf' ? ['pdf'] : ['jpg', 'jpeg', 'png'],
      withData: true,
    );

    if (picked != null && picked.files.isNotEmpty) {
      _showUploadDialog(picked.files.first);
    }
  }

  void _showUploadDialog(PlatformFile file) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => UploadProgressDialog(
        file: file,
        onComplete: (invoice) async {
          await _loadInvoices();
          if (mounted) {
            Navigator.of(dialogContext).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invoice ${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : "submitted"} processed successfully!',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        onError: (error) {
          Navigator.of(dialogContext).pop();
          _showErrorDialog(error);
        },
      ),
    );
  }

  void _showErrorDialog(String error) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: Colors.red[700],
                size: 48,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Failed',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[700]),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Please upload a valid invoice PDF or image.',
                      style: TextStyle(color: Colors.orange[700], fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showUploadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Upload Invoice',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.picture_as_pdf,
                    label: 'PDF',
                    color: Colors.red,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUpload('pdf');
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildUploadOption(
                    icon: Icons.image,
                    label: 'Image',
                    color: Colors.blue,
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndUpload('image');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _viewInvoiceDetails(InvoiceData invoice) {
    showDialog(
      context: context,
      builder: (context) => InvoiceDetailsDialog(invoice: invoice),
    );
  }

  void _confirmDelete(InvoiceData invoice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              await ApiService.deleteInvoice(invoice.id);
              await _loadInvoices();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Invoice deleted')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF667eea).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.receipt_long, color: Color(0xFF667eea)),
            ),
            const SizedBox(width: 12),
            const Text(
              'Invoice Dashboard',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.grey),
            onPressed: _loadInvoices,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildSearchAndSortBar(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredInvoices.isEmpty
                ? _buildEmptyState()
                : _buildInvoiceTable(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showUploadOptions,
        backgroundColor: const Color(0xFF667eea),
        icon: const Icon(Icons.add),
        label: const Text('Upload Invoice'),
      ),
    );
  }

  Widget _buildSearchAndSortBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 600) {
            return Column(
              children: [
                TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applySortAndFilter();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(child: _buildSortDropdown()),
                    IconButton(
                      icon: Icon(
                        _sortAscending
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                      ),
                      onPressed: () {
                        setState(() => _sortAscending = !_sortAscending);
                        _applySortAndFilter();
                      },
                    ),
                  ],
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  onChanged: (value) {
                    _searchQuery = value;
                    _applySortAndFilter();
                  },
                  decoration: InputDecoration(
                    hintText: 'Search by invoice number, customer, GSTIN...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              SizedBox(width: 180, child: _buildSortDropdown()),
              IconButton(
                icon: Icon(
                  _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                ),
                onPressed: () {
                  setState(() => _sortAscending = !_sortAscending);
                  _applySortAndFilter();
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSortDropdown() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: _sortBy,
          isExpanded: true,
          items: const [
            DropdownMenuItem(value: 'date', child: Text('Sort by Date')),
            DropdownMenuItem(
              value: 'invoice',
              child: Text('Sort by Invoice #'),
            ),
            DropdownMenuItem(
              value: 'customer',
              child: Text('Sort by Customer'),
            ),
            DropdownMenuItem(value: 'amount', child: Text('Sort by Amount')),
          ],
          onChanged: (value) {
            setState(() => _sortBy = value!);
            _applySortAndFilter();
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty ? 'No invoices found' : 'No invoices yet',
            style: TextStyle(fontSize: 20, color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? 'Try a different search term'
                : 'Upload your first invoice to get started',
            style: TextStyle(color: Colors.grey[500]),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _showUploadOptions,
              icon: const Icon(Icons.add),
              label: const Text('Upload Invoice'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF667eea),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceTable() {
    return LayoutBuilder(
      builder: (context, constraints) {
        bool isSmallScreen = constraints.maxWidth < 600;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SingleChildScrollView(
                scrollDirection: isSmallScreen
                    ? Axis.horizontal
                    : Axis.vertical,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    const Color(0xFF667eea).withAlpha(26),
                  ),
                  columnSpacing: isSmallScreen ? 20.0 : 40.0,
                  horizontalMargin: isSmallScreen ? 10.0 : 20.0,
                  columns: const [
                    DataColumn(
                      label: Text(
                        '#',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Invoice #',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Date',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Customer',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Seller',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Total',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Actions',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: _filteredInvoices.asMap().entries.map((entry) {
                    final index = entry.key;
                    final invoice = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(
                          InkWell(
                            onTap: () => _viewInvoiceDetails(invoice),
                            child: Text(
                              invoice.invoiceNumber.isNotEmpty
                                  ? invoice.invoiceNumber
                                  : '-',
                              style: const TextStyle(
                                color: Color(0xFF667eea),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        DataCell(Text(_formatDate(invoice.date))),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              invoice.billToName.isNotEmpty
                                  ? invoice.billToName
                                  : '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 100),
                            child: Text(
                              invoice.ownerName.isNotEmpty
                                  ? invoice.ownerName
                                  : '-',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            _formatCurrency(
                              invoice.total,
                              invoice.currencySymbol,
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        DataCell(
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.visibility, size: 20),
                                color: Colors.blue,
                                onPressed: () => _viewInvoiceDetails(invoice),
                                tooltip: 'View Details',
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete, size: 20),
                                color: Colors.red,
                                onPressed: () => _confirmDelete(invoice),
                                tooltip: 'Delete',
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class UploadProgressDialog extends StatefulWidget {
  final PlatformFile file;
  final Function(InvoiceData) onComplete;
  final Function(String) onError;

  const UploadProgressDialog({
    super.key,
    required this.file,
    required this.onComplete,
    required this.onError,
  });

  @override
  State<UploadProgressDialog> createState() => _UploadProgressDialogState();
}

class _UploadProgressDialogState extends State<UploadProgressDialog> {
  bool _isProcessing = true;
  String _status = 'Uploading...';
  InvoiceData? _parsedInvoice;

  @override
  void initState() {
    super.initState();
    _processFile();
  }

  Future<void> _processFile() async {
    try {
      setState(() => _status = 'Processing ${widget.file.name}...');

      ApiResponse apiResponse = await ApiService.uploadFile(
        widget.file.bytes!,
        widget.file.name,
      );

      String rawText = apiResponse.text;
      Map<String, dynamic>? structuredData = apiResponse.structuredData;

      setState(() => _status = 'Parsing invoice data...');

      if (apiResponse.invoice != null) {
        _parsedInvoice = InvoiceData.fromJson(apiResponse.invoice!);
      } else {
        _parsedInvoice = InvoiceParser.parseWithStructuredData(
          rawText,
          widget.file.name,
          structuredData,
        );
        _parsedInvoice!.submittedAt = DateTime.now().toIso8601String();
      }

      setState(() {
        _isProcessing = false;
        _status = 'Processing complete!';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      widget.onComplete(_parsedInvoice!);
    } catch (e) {
      String errorMsg = e.toString();
      if (errorMsg.contains('422')) {
        errorMsg =
            'The uploaded file does not appear to be a valid invoice. Please upload a proper invoice document.';
      } else if (errorMsg.contains('SocketException') ||
          errorMsg.contains('Connection refused')) {
        errorMsg =
            'Cannot connect to the server. Please make sure the backend is running.';
      }
      widget.onError(errorMsg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        padding: const EdgeInsets.all(32),
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isProcessing) ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                _status,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green[50],
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_circle,
                  color: Colors.green[600],
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Invoice Processed!',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (_parsedInvoice != null) ...[
                _buildInfoRow(
                  'Invoice #',
                  _parsedInvoice!.invoiceNumber.isNotEmpty
                      ? _parsedInvoice!.invoiceNumber
                      : '-',
                ),
                _buildInfoRow(
                  'Customer',
                  _parsedInvoice!.billToName.isNotEmpty
                      ? _parsedInvoice!.billToName
                      : '-',
                ),
                _buildInfoRow(
                  'Total',
                  '${_parsedInvoice!.currencySymbol ?? "₹"}${_parsedInvoice!.total.toStringAsFixed(2)}',
                ),
                _buildInfoRow('Items', '${_parsedInvoice!.items.length} items'),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class InvoiceDetailsDialog extends StatelessWidget {
  final InvoiceData invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  String _formatCurrency(double amount, String? currencySymbol) {
    String symbol = currencySymbol ?? invoice.currencySymbol ?? '₹';
    final formatter = NumberFormat.currency(symbol: symbol, decimalDigits: 2);
    return formatter.format(amount);
  }

  String _formatDate(String dateStr) {
    if (dateStr.isEmpty) return '-';
    try {
      return DateFormat('dd MMM yyyy').format(DateTime.parse(dateStr));
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 1000, maxHeight: 800),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: Color(0xFF667eea),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt, color: Colors.white),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.invoiceNumber.isNotEmpty
                              ? invoice.invoiceNumber
                              : 'Invoice Details',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (invoice.ownerName.isNotEmpty)
                          Text(
                            invoice.ownerName,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 700;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSection('Invoice Information', [
                          _buildRow('Invoice Number', invoice.invoiceNumber),
                          _buildRow('Date', _formatDate(invoice.date)),
                          _buildRow(
                            'Due Date',
                            invoice.extraFields['Due Date'] ?? '-',
                          ),
                          _buildRow(
                            'Payment Terms',
                            invoice.extraFields['Payment Terms'] ?? '-',
                          ),
                          _buildRow(
                            'Submitted',
                            _formatDate(invoice.submittedAt),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        if (isWide)
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(child: _buildCompanyInfo()),
                              const SizedBox(width: 16),
                              Expanded(child: _buildCustomerInfo()),
                            ],
                          )
                        else ...[
                          _buildCompanyInfo(),
                          const SizedBox(height: 16),
                          _buildCustomerInfo(),
                        ],
                        if (invoice.extraFields.isNotEmpty ||
                            invoice.additionalDetails.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSection(
                            'Additional Information',
                            _buildDynamicFields(),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _buildSection('Financial Summary', [
                          _buildRow(
                            'Subtotal',
                            _formatCurrency(
                              invoice.subtotal,
                              invoice.currencySymbol,
                            ),
                          ),
                          if (invoice.gstPercentage > 0)
                            _buildRow(
                              'GST (${invoice.gstPercentage}%)',
                              _formatCurrency(
                                invoice.subtotal * invoice.gstPercentage / 100,
                                invoice.currencySymbol,
                              ),
                            ),
                          _buildRow(
                            'Total Amount',
                            _formatCurrency(
                              invoice.total,
                              invoice.currencySymbol,
                            ),
                            isBold: true,
                          ),
                        ]),
                        if (invoice.items.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildItemsSection(isWide),
                        ],
                        if (invoice.tables.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildTablesSection(context, invoice.tables),
                        ],
                        if (invoice.authorizedSignature != null) ...[
                          const SizedBox(height: 16),
                          _buildSection('Signature', [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.verified,
                                    color: Colors.green,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    invoice.authorizedSignature!,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]),
                        ],
                        if (invoice.rawText.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _buildSection('Raw Extracted Text', [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey[900],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(
                                invoice.rawText,
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 12,
                                  color: Colors.green,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    List<Widget> rows = [];

    final seller = invoice.seller;
    if (seller.isNotEmpty) {
      seller.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          String displayKey = key
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ');
          rows.add(_buildRow(displayKey, value.toString()));
        }
      });
    }

    if (rows.isEmpty) {
      rows.add(_buildRow('Business Name', invoice.ownerName));
      rows.add(_buildRow('Address', invoice.ownerAddress));
      rows.add(_buildRow('Phone', invoice.ownerMobile));
      rows.add(_buildRow('GSTIN', invoice.gstin));
    }

    return _buildSection('From (Seller)', rows);
  }

  Widget _buildCustomerInfo() {
    List<Widget> rows = [];

    final customer = invoice.customer;
    if (customer.isNotEmpty) {
      customer.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          String displayKey = key
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ');
          rows.add(_buildRow(displayKey, value.toString()));
        }
      });
    }

    if (rows.isEmpty) {
      rows.add(_buildRow('Customer Name', invoice.billToName));
      rows.add(_buildRow('Address', invoice.billToAddress));
      rows.add(_buildRow('Phone', invoice.billToMobile));
    }

    return _buildSection('Bill To (Customer)', rows);
  }

  List<Widget> _buildDynamicFields() {
    List<Widget> rows = [];

    final excludedKeys = [
      'due_date',
      'due Date',
      'payment_terms',
      'payment Terms',
      'email',
      'Email',
      'phone',
      'phone_number',
      'phone Number',
      'po_number',
      'po Number',
      'order_number',
      'order Number',
    ];

    final addExcludedKeys = [
      'notes',
      'terms_and_conditions',
      'terms and conditions',
    ];

    if (invoice.additionalDetails.isNotEmpty) {
      invoice.additionalDetails.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          String displayKey = key
              .replaceAll('_', ' ')
              .split(' ')
              .map((word) {
                if (word.isEmpty) return word;
                return word[0].toUpperCase() + word.substring(1);
              })
              .join(' ');
          rows.add(_buildRow(displayKey, value.toString()));
        }
      });
    }

    if (invoice.extraFields.isNotEmpty) {
      invoice.extraFields.forEach((key, value) {
        if (value != null && value.toString().isNotEmpty) {
          String lowerKey = key.toLowerCase().replaceAll('_', ' ');
          bool shouldExclude = excludedKeys.any(
            (excluded) => lowerKey.contains(excluded.toLowerCase()),
          );
          if (!shouldExclude) {
            String displayKey = key
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) {
                  if (word.isEmpty) return word;
                  return word[0].toUpperCase() + word.substring(1);
                })
                .join(' ');
            rows.add(_buildRow(displayKey, value.toString()));
          }
        }
      });
    }

    return rows;
  }

  Widget _buildItemsSection(bool isWide) {
    List<String> columnHeaders = invoice.tableHeaders.isNotEmpty
        ? invoice.tableHeaders
        : ['#', 'Description', 'Qty', 'Rate', 'Amount'];

    return _buildSection('Items (${invoice.items.length})', [
      Container(
        margin: const EdgeInsets.only(top: 8),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStatePropertyAll<Color>(
                const Color(0xFF667eea).withAlpha(26),
              ),
              columnSpacing: 20.0,
              columns: columnHeaders
                  .map(
                    (header) => DataColumn(
                      label: Text(
                        header,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  )
                  .toList(),
              rows: invoice.items.asMap().entries.map((entry) {
                final item = entry.value;
                final headerCount = columnHeaders.length;
                List<String> rowData = List.generate(headerCount, (i) {
                  switch (i) {
                    case 0:
                      return '${entry.key + 1}';
                    case 1:
                      return item.description;
                    case 2:
                      return '${item.quantity} ${item.unit ?? ""}';
                    case 3:
                      return _formatCurrency(item.rate, invoice.currencySymbol);
                    case 4:
                      return _formatCurrency(
                        item.amount,
                        invoice.currencySymbol,
                      );
                    default:
                      return '';
                  }
                });
                return DataRow(
                  cells: rowData
                      .map(
                        (cell) => DataCell(
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 150),
                            child: Text(
                              cell,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _buildTablesSection(BuildContext context, List<InvoiceTable> tables) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Extracted Tables',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '${tables.length} table(s) found in this invoice',
          style: TextStyle(color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),
        ...tables.asMap().entries.map((entry) {
          return _buildExpandableTable(context, entry.key, entry.value);
        }),
      ],
    );
  }

  Widget _buildExpandableTable(
    BuildContext context,
    int index,
    InvoiceTable table,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          key: PageStorageKey('table_$index'),
          tilePadding: const EdgeInsets.symmetric(
            horizontal: 16.0,
            vertical: 8.0,
          ),
          childrenPadding: const EdgeInsets.all(16.0),
          leading: Container(
            padding: const EdgeInsets.all(8.0),
            decoration: BoxDecoration(
              color: const Color(0xFF667eea).withAlpha(26),
              borderRadius: BorderRadius.circular(8.0),
            ),
            child: const Icon(
              Icons.table_chart,
              color: Color(0xFF667eea),
              size: 24,
            ),
          ),
          title: Text(
            table.title.isNotEmpty ? table.title : 'Table ${index + 1}',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16.0),
          ),
          subtitle: Text(
            '${table.rows.length} row(s), ${table.headers.length} column(s)',
            style: TextStyle(color: Colors.grey[600], fontSize: 12.0),
          ),
          children: [_buildTableContent(table)],
        ),
      ),
    );
  }

  Widget _buildTableContent(InvoiceTable table) {
    if (table.headers.isEmpty || table.rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          'No data available',
          style: TextStyle(color: Colors.grey[500]),
        ),
      );
    }

    int numCols = table.headers.length;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              color: const Color(0xFF667eea),
              padding: const EdgeInsets.symmetric(
                vertical: 12.0,
                horizontal: 8.0,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40.0,
                    child: const Text(
                      '#',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        fontSize: 12.0,
                      ),
                    ),
                  ),
                  ...table.headers.asMap().entries.map((entry) {
                    return Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          fontSize: 12.0,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }),
                ],
              ),
            ),
            ...table.rows.asMap().entries.map((entry) {
              int rowIdx = entry.key;
              List<String> row = entry.value;
              bool isOdd = rowIdx.isOdd;

              return Container(
                color: isOdd ? Colors.grey[50] : Colors.white,
                padding: const EdgeInsets.symmetric(
                  vertical: 10.0,
                  horizontal: 8.0,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40.0,
                      child: Text(
                        '${rowIdx + 1}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w500,
                          fontSize: 12.0,
                        ),
                      ),
                    ),
                    ...List.generate(numCols, (colIdx) {
                      String cellValue = colIdx < row.length ? row[colIdx] : '';
                      return Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: Text(
                            cellValue,
                            style: const TextStyle(fontSize: 12.0),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    List<Widget> filteredChildren = children.where((child) {
      if (child is Padding) {
        final paddingChild = child.child;
        if (paddingChild is Row && paddingChild.children.isNotEmpty) {
          final lastChild = paddingChild.children.last;
          if (lastChild is Expanded) {
            final expandedChild = lastChild.child;
            if (expandedChild is Text) {
              return expandedChild.data != null &&
                  expandedChild.data != '-' &&
                  expandedChild.data!.isNotEmpty;
            }
          }
        }
      }
      return true;
    }).toList();

    if (filteredChildren.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getSectionIcon(title),
                size: 20,
                color: const Color(0xFF667eea),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...filteredChildren,
        ],
      ),
    );
  }

  IconData _getSectionIcon(String title) {
    if (title.toLowerCase().contains('invoice')) return Icons.receipt;
    if (title.toLowerCase().contains('from')) return Icons.store;
    if (title.toLowerCase().contains('customer') ||
        title.toLowerCase().contains('bill'))
      return Icons.person;
    if (title.toLowerCase().contains('financial'))
      return Icons.account_balance_wallet;
    if (title.toLowerCase().contains('item')) return Icons.list_alt;
    if (title.toLowerCase().contains('signature')) return Icons.verified;
    if (title.toLowerCase().contains('additional')) return Icons.info;
    return Icons.info;
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: isBold ? const Color(0xFF667eea) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
