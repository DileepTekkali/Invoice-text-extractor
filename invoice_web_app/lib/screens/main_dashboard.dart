import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../models/invoice_data.dart';
import '../services/storage_service.dart';
import '../services/api_service.dart';
import '../services/invoice_parser.dart';
import '../widgets/app_scanner_animation.dart';

class MainDashboard extends StatefulWidget {
  final bool openUploadOnStart;

  const MainDashboard({super.key, this.openUploadOnStart = false});

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
    if (widget.openUploadOnStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _showUploadOptions();
        }
      });
    }
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);

    await StorageService.init();
    List<InvoiceData> invoices = await StorageService.getInvoices();

    if (!mounted) {
      return;
    }
    setState(() {
      _invoices = invoices;
      _filteredInvoices = invoices;
      _isLoading = false;
      _applySortAndFilter();
    });
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
    String symbol = currencySymbol ?? '';
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
          await StorageService.saveInvoice(invoice);
          await _loadInvoices();
          if (!mounted || !dialogContext.mounted) {
            return;
          }
          Navigator.of(dialogContext).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invoice ${invoice.invoiceNumber.isNotEmpty ? invoice.invoiceNumber : "submitted"} processed successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        },
        onError: (error) {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
          if (mounted) {
            _showErrorDialog(error);
          }
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
          border: Border.all(color: color.withAlpha(77)),
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
              await StorageService.deleteInvoice(invoice.id);
              await _loadInvoices();
              if (!context.mounted) {
                return;
              }
              Navigator.pop(context);
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(const SnackBar(content: Text('Invoice deleted')));
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
                color: const Color(0xFF667eea).withAlpha(26),
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
                ? const Center(
                    child: AppScannerAnimation(
                      width: 320,
                      height: 240,
                      title: 'Loading invoices',
                      subtitle: 'Preparing your saved invoice list.',
                    ),
                  )
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
        bool isSmallScreen = constraints.maxWidth < 900;

        if (isSmallScreen) {
          return _buildInvoiceCards();
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(13),
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

  Widget _buildInvoiceCards() {
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _filteredInvoices.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final invoice = _filteredInvoices[index];
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(13),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF667eea).withAlpha(26),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Color(0xFF667eea),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice.invoiceNumber.isNotEmpty
                                ? invoice.invoiceNumber
                                : 'Invoice',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(invoice.date),
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      _formatCurrency(invoice.total, invoice.currencySymbol),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInvoiceCardRow(
                  'Customer',
                  invoice.billToName.isNotEmpty ? invoice.billToName : '-',
                ),
                _buildInvoiceCardRow(
                  'Seller',
                  invoice.ownerName.isNotEmpty ? invoice.ownerName : '-',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _viewInvoiceDetails(invoice),
                      icon: const Icon(Icons.visibility, size: 18),
                      label: const Text('View'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _confirmDelete(invoice),
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildInvoiceCardRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 76,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
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
  String _statusCaption = 'Preparing your file for invoice validation.';
  InvoiceData? _parsedInvoice;

  String _formatUploadError(Object error) {
    String message = error.toString().replaceFirst('Exception: ', '').trim();
    if (message.contains('422') ||
        message.toLowerCase().contains('not a valid invoice') ||
        message.toLowerCase().contains('proper invoice')) {
      return 'The uploaded file is not a valid invoice. Please upload a proper invoice PDF or image.';
    }
    if (message.contains('SocketException') ||
        message.contains('Connection refused')) {
      return 'Cannot connect to the server. Please make sure the backend is running.';
    }
    return message;
  }

  @override
  void initState() {
    super.initState();
    _processFile();
  }

  Future<void> _processFile() async {
    try {
      setState(() {
        _status = 'Uploading ${widget.file.name}';
        _statusCaption = 'Sending the document to the invoice processing flow.';
      });

      final fileBytes = widget.file.bytes;
      if (fileBytes == null || fileBytes.isEmpty) {
        throw Exception(
          'Selected file could not be read. Please reselect the file and try again.',
        );
      }
      if (fileBytes.length > 10 * 1024 * 1024) {
        throw Exception('Please upload a file smaller than 10 MB.');
      }

      setState(() {
        _status = 'Validating invoice structure';
        _statusCaption =
            'Checking whether the uploaded PDF or image is a real invoice.';
      });

      ApiResponse apiResponse = await ApiService.uploadFile(
        fileBytes,
        widget.file.name,
      );

      if (apiResponse.invoiceData == null) {
        throw Exception('No invoice data received from server');
      }

      setState(() {
        _status = 'Extracting invoice fields';
        _statusCaption =
            'Reading text, totals, vendor details, customer details, and line items.';
      });

      _parsedInvoice = InvoiceParser.parseWithExtractedData(
        apiResponse.rawText ?? "",
        widget.file.name,
        apiResponse.invoiceData,
      );
      _parsedInvoice!.id = DateTime.now().millisecondsSinceEpoch.toString();
      _parsedInvoice!.submittedAt = DateTime.now().toIso8601String();

      setState(() {
        _isProcessing = false;
        _status = 'Processing complete!';
        _statusCaption = 'Your invoice has been validated and extracted.';
      });

      await Future.delayed(const Duration(milliseconds: 500));
      widget.onComplete(_parsedInvoice!);
    } catch (e) {
      widget.onError(_formatUploadError(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 460;
    final dialogWidth = (mediaQuery.size.width - (isCompact ? 24 : 48))
        .clamp(280.0, 420.0)
        .toDouble();
    final animationWidth = (dialogWidth - (isCompact ? 40 : 64))
        .clamp(220.0, 320.0)
        .toDouble();

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isCompact ? 12 : 24,
        vertical: isCompact ? 16 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 420,
          maxHeight: mediaQuery.size.height * 0.88,
        ),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 20 : 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_isProcessing) ...[
                AppScannerAnimation(
                  width: animationWidth,
                  height: isCompact ? 220 : 240,
                  title: 'Scanning invoice',
                  subtitle:
                      'Validation, OCR, and structured extraction in progress',
                ),
                const SizedBox(height: 18),
                _buildFileNameChip(widget.file.name),
                const SizedBox(height: 14),
                Text(
                  _status,
                  style: TextStyle(
                    fontSize: isCompact ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _statusCaption,
                  style: TextStyle(color: Colors.grey[600], height: 1.5),
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
                    '${_parsedInvoice!.currencySymbol ?? ""}${_parsedInvoice!.total.toStringAsFixed(2)}',
                  ),
                  _buildInfoRow(
                    'Items',
                    '${_parsedInvoice!.items.length} items',
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileNameChip(String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F7FD),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFD7E4F5)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insert_drive_file_outlined, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 320) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.grey[600])),
                const SizedBox(height: 4),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label, style: TextStyle(color: Colors.grey[600])),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class InvoiceDetailsDialog extends StatelessWidget {
  final InvoiceData invoice;

  const InvoiceDetailsDialog({super.key, required this.invoice});

  String _formatCurrency(double amount, String? currencySymbol) {
    String symbol = currencySymbol ?? invoice.currencySymbol ?? '';
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
    final mediaQuery = MediaQuery.of(context);
    final isSmallScreen = mediaQuery.size.width < 720;

    return Dialog(
      insetPadding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 40,
        vertical: isSmallScreen ? 12 : 24,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: 900,
          maxHeight: mediaQuery.size.height * 0.92,
        ),
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
                              color: Colors.white.withAlpha(204),
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
              child: ListView(
                padding: const EdgeInsets.all(24),
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
                    _buildRow('Submitted', _formatDate(invoice.submittedAt)),
                  ]),
                  const SizedBox(height: 16),
                  _buildCompanyInfo(),
                  const SizedBox(height: 16),
                  _buildCustomerInfo(),
                  if (invoice.extraFields.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSection(
                      'Additional Information',
                      invoice.extraFields.entries
                          .where(
                            (e) => ![
                              'Due Date',
                              'Payment Terms',
                              'Email',
                              'Phone',
                              'PO Number',
                              'Order Number',
                              'Bill To Email',
                            ].contains(e.key),
                          )
                          .map((e) => _buildRow(e.key, e.value))
                          .toList(),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _buildSection('Financial Summary', [
                    _buildRow(
                      'Subtotal',
                      _formatCurrency(invoice.subtotal, invoice.currencySymbol),
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
                      _formatCurrency(invoice.total, invoice.currencySymbol),
                      isBold: true,
                    ),
                  ]),
                  if (invoice.items.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildItemsSection(),
                  ],
                  if (invoice.tables.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildTablesSection(),
                  ],
                  if (invoice.authorizedSignature != null &&
                      invoice.authorizedSignature!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSection('Signature', [
                      _buildRow(
                        'Authorized Signature',
                        invoice.authorizedSignature!,
                      ),
                    ]),
                  ],
                  if (invoice.rawText.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildSection('Raw Extracted Text', [
                      _buildRow('Content', invoice.rawText),
                    ]),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanyInfo() {
    return _buildSection('From (Seller)', [
      _buildRow('Business Name', invoice.ownerName),
      _buildRow('Address', invoice.ownerAddress),
      _buildRow('Phone', invoice.ownerMobile),
      _buildRow('Email', invoice.extraFields['Email'] ?? '-'),
      _buildRow('GSTIN', invoice.gstin),
    ]);
  }

  Widget _buildCustomerInfo() {
    return _buildSection('Bill To (Customer)', [
      _buildRow('Customer Name', invoice.billToName),
      _buildRow('Address', invoice.billToAddress),
      _buildRow('Phone', invoice.billToMobile),
      _buildRow('Email', invoice.extraFields['Bill To Email'] ?? '-'),
      _buildRow('PO Number', invoice.extraFields['PO Number'] ?? '-'),
    ]);
  }

  Widget _buildItemsSection() {
    return _buildSection(
      'Items (${invoice.items.length})',
      invoice.items.asMap().entries.map((entry) {
        final item = entry.value;
        return _buildSubsectionCard('Item ${entry.key + 1}', [
          _buildRow('Description', item.description),
          _buildRow('Quantity', '${item.quantity} ${item.unit ?? ""}'.trim()),
          _buildRow('Rate', _formatCurrency(item.rate, invoice.currencySymbol)),
          _buildRow(
            'Amount',
            _formatCurrency(item.amount, invoice.currencySymbol),
            isBold: true,
          ),
        ]);
      }).toList(),
    );
  }

  Widget _buildTablesSection() {
    return _buildSection(
      'Extracted Tables (${invoice.tables.length})',
      invoice.tables.asMap().entries.map((entry) {
        final table = entry.value;
        final rows = <Widget>[
          if (table.headers.isNotEmpty)
            _buildRow('Headers', table.headers.join(' | ')),
        ];

        rows.addAll(
          table.rows.asMap().entries.map(
            (rowEntry) => _buildRow(
              'Row ${rowEntry.key + 1}',
              rowEntry.value.join(' | '),
            ),
          ),
        );

        return _buildSubsectionCard(
          table.title.isNotEmpty ? table.title : 'Table ${entry.key + 1}',
          rows,
        );
      }).toList(),
    );
  }

  Widget _buildSubsectionCard(String title, List<Widget> children) {
    final filteredChildren = children.where((child) {
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

    if (filteredChildren.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          ...filteredChildren,
        ],
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
        title.toLowerCase().contains('bill')) {
      return Icons.person;
    }
    if (title.toLowerCase().contains('financial')) {
      return Icons.account_balance_wallet;
    }
    if (title.toLowerCase().contains('item')) return Icons.list_alt;
    if (title.toLowerCase().contains('signature')) return Icons.verified;
    if (title.toLowerCase().contains('additional')) return Icons.info;
    return Icons.info;
  }

  Widget _buildRow(String label, String value, {bool isBold = false}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                    fontSize: isBold ? 16 : 14,
                    color: isBold ? const Color(0xFF667eea) : Colors.black,
                  ),
                ),
              ],
            ),
          );
        }

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
      },
    );
  }
}
