import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_data.dart';
import 'main_dashboard.dart';

class DashboardScreen extends StatefulWidget {
  final InvoiceData invoice;

  const DashboardScreen({super.key, required this.invoice});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _showMoreDetails = false;
  bool _isSubmitted = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    setState(() {
      _isSubmitted = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Invoice data submitted successfully!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String _formatCurrency(double amount) {
    final formatter = NumberFormat.currency(
      symbol: widget.invoice.currencySymbol ?? '',
      decimalDigits: 2,
    );
    return formatter.format(amount);
  }

  String _formatPercentage(double value) {
    if (value == value.truncateToDouble()) {
      return value.toStringAsFixed(0);
    }
    return value.toStringAsFixed(2);
  }

  void _openMainDashboard({bool openUploadOnStart = false}) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => MainDashboard(openUploadOnStart: openUploadOnStart),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _openMainDashboard,
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.check_circle,
                color: Colors.green[600],
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Invoice Scanner Dashboard',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: _isSubmitted ? _buildSubmittedView() : _buildReviewView(),
      ),
    );
  }

  Widget _buildReviewView() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 720;

        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              color: Colors.white,
              child: isSmallScreen
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.invoice.invoiceNumber.isNotEmpty
                              ? widget.invoice.invoiceNumber
                              : 'Invoice',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'File: ${widget.invoice.filename}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                _openMainDashboard(openUploadOnStart: true),
                            icon: const Icon(Icons.add),
                            label: const Text('New Invoice'),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.invoice.invoiceNumber.isNotEmpty
                                    ? widget.invoice.invoiceNumber
                                    : 'Invoice',
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'File: ${widget.invoice.filename}',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () =>
                              _openMainDashboard(openUploadOnStart: true),
                          icon: const Icon(Icons.add),
                          label: const Text('New Invoice'),
                        ),
                      ],
                    ),
            ),
            Container(
              color: Colors.white,
              child: TabBar(
                controller: _tabController,
                isScrollable: isSmallScreen,
                labelColor: const Color(0xFF667eea),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF667eea),
                indicatorSize: TabBarIndicatorSize.tab,
                tabs: const [
                  Tab(text: 'Overview', icon: Icon(Icons.info_outline)),
                  Tab(text: 'Items', icon: Icon(Icons.list_alt)),
                  Tab(text: 'Raw Data', icon: Icon(Icons.code)),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildOverviewTab(),
                  _buildItemsTab(),
                  _buildRawDataTab(),
                ],
              ),
            ),
            _buildActionButtons(),
          ],
        );
      },
    );
  }

  Widget _buildOverviewTab() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 720;
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (isSmallScreen) ...[
                _buildSellerCard(),
                const SizedBox(height: 16),
                _buildBuyerCard(),
              ] else ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: _buildSellerCard()),
                    const SizedBox(width: 16),
                    Expanded(child: _buildBuyerCard()),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildFinancialSummary(),
              const SizedBox(height: 16),
              if (_showMoreDetails) _buildAdditionalDetails(),
              Center(
                child: TextButton.icon(
                  onPressed: () =>
                      setState(() => _showMoreDetails = !_showMoreDetails),
                  icon: Icon(
                    _showMoreDetails ? Icons.expand_less : Icons.expand_more,
                  ),
                  label: Text(
                    _showMoreDetails ? 'Show Less' : 'View More Details',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSellerCard() {
    return _buildCard('Seller Information', Icons.store, [
      _buildInfoRow(
        'Business Name',
        widget.invoice.ownerName.isNotEmpty
            ? widget.invoice.ownerName
            : 'Not detected',
      ),
      _buildInfoRow(
        'Mobile',
        widget.invoice.ownerMobile.isNotEmpty
            ? widget.invoice.ownerMobile
            : 'Not detected',
      ),
      _buildInfoRow(
        'Address',
        widget.invoice.ownerAddress.isNotEmpty
            ? widget.invoice.ownerAddress
            : 'Not detected',
      ),
      _buildInfoRow(
        'GSTIN',
        widget.invoice.gstin.isNotEmpty ? widget.invoice.gstin : 'Not detected',
      ),
    ]);
  }

  Widget _buildBuyerCard() {
    return _buildCard('Buyer Information', Icons.person, [
      _buildInfoRow(
        'Customer Name',
        widget.invoice.billToName.isNotEmpty
            ? widget.invoice.billToName
            : 'Not detected',
      ),
      _buildInfoRow(
        'Mobile',
        widget.invoice.billToMobile.isNotEmpty
            ? widget.invoice.billToMobile
            : 'Not detected',
      ),
      _buildInfoRow(
        'Address',
        widget.invoice.billToAddress.isNotEmpty
            ? widget.invoice.billToAddress
            : 'Not detected',
      ),
    ]);
  }

  Widget _buildCard(String title, IconData icon, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF667eea)),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 420;

        if (isNarrow) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
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
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFinancialSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.account_balance_wallet, color: Color(0xFF667eea)),
              SizedBox(width: 8),
              Text(
                'Financial Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow(
            'Subtotal',
            _formatCurrency(widget.invoice.subtotal),
          ),
          if (widget.invoice.gstPercentage > 0) ...[
            const Divider(),
            _buildSummaryRow(
              'GST (${_formatPercentage(widget.invoice.gstPercentage)}%)',
              _formatCurrency(
                widget.invoice.subtotal * widget.invoice.gstPercentage / 100,
              ),
            ),
          ],
          const Divider(),
          _buildSummaryRow(
            'Total Amount',
            _formatCurrency(widget.invoice.total),
            isTotal: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isTotal ? 18 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? Colors.black : Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: isTotal ? 20 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w600,
              color: isTotal ? const Color(0xFF667eea) : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdditionalDetails() {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Additional Details',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            'Invoice Date',
            widget.invoice.date.isNotEmpty
                ? widget.invoice.date
                : 'Not detected',
          ),
          _buildInfoRow(
            'Invoice Number',
            widget.invoice.invoiceNumber.isNotEmpty
                ? widget.invoice.invoiceNumber
                : 'Not detected',
          ),
          if (widget.invoice.authorizedSignature != null)
            _buildInfoRow('Signature', widget.invoice.authorizedSignature!),
          _buildInfoRow('Total Items', '${widget.invoice.items.length}'),
        ],
      ),
    );
  }

  Widget _buildItemsTab() {
    if (widget.invoice.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No items detected',
              style: TextStyle(color: Colors.grey[600], fontSize: 18),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmallScreen = constraints.maxWidth < 720;

        if (isSmallScreen) {
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.invoice.items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = widget.invoice.items[index];
              return Container(
                padding: const EdgeInsets.all(16),
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
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Item ${index + 1}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF667eea),
                      ),
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow('Description', item.description),
                    _buildInfoRow('Qty', '${item.quantity}'),
                    _buildInfoRow('Rate', _formatCurrency(item.rate)),
                    _buildInfoRow('Amount', _formatCurrency(item.amount)),
                  ],
                ),
              );
            },
          );
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
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: WidgetStatePropertyAll<Color>(
                    const Color(0xFF667eea).withAlpha(26),
                  ),
                  columns: const [
                    DataColumn(
                      label: Text(
                        '#',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Description',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Qty',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Rate',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    DataColumn(
                      label: Text(
                        'Amount',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  rows: widget.invoice.items.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return DataRow(
                      cells: [
                        DataCell(Text('${index + 1}')),
                        DataCell(Text(item.description)),
                        DataCell(Text('${item.quantity}')),
                        DataCell(Text(_formatCurrency(item.rate))),
                        DataCell(Text(_formatCurrency(item.amount))),
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

  Widget _buildRawDataTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[900],
          borderRadius: BorderRadius.circular(16),
        ),
        child: SelectableText(
          widget.invoice.rawText,
          style: const TextStyle(
            fontFamily: 'monospace',
            fontSize: 13,
            color: Colors.green,
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(20),
      color: Colors.white,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            onPressed: () => _openMainDashboard(openUploadOnStart: true),
            icon: const Icon(Icons.refresh),
            label: const Text('Upload New'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
          ElevatedButton.icon(
            onPressed: _handleSubmit,
            icon: const Icon(Icons.check),
            label: const Text('Submit Invoice'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF667eea),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmittedView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 64,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Invoice Submitted Successfully!',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  _buildSubmittedTable(),
                  const SizedBox(height: 32),
                  ElevatedButton.icon(
                    onPressed: () =>
                        _openMainDashboard(openUploadOnStart: true),
                    icon: const Icon(Icons.add),
                    label: const Text('Process Another Invoice'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF667eea),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 32,
                        vertical: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubmittedTable() {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: const BoxDecoration(
              color: Color(0xFF667eea),
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Field',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Value',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          _buildTableRow('Invoice Number', widget.invoice.invoiceNumber),
          _buildTableRow('Date', widget.invoice.date),
          _buildTableRow('Seller', widget.invoice.ownerName),
          _buildTableRow('GSTIN', widget.invoice.gstin),
          _buildTableRow('Customer', widget.invoice.billToName),
          _buildTableRow('Items Count', '${widget.invoice.items.length}'),
          _buildTableRow('Subtotal', _formatCurrency(widget.invoice.subtotal)),
          if (widget.invoice.gstPercentage > 0)
            _buildTableRow(
              'GST (${_formatPercentage(widget.invoice.gstPercentage)}%)',
              _formatCurrency(
                widget.invoice.subtotal * widget.invoice.gstPercentage / 100,
              ),
            ),
          _buildTableRow(
            'Total',
            _formatCurrency(widget.invoice.total),
            isHighlighted: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTableRow(
    String field,
    String value, {
    bool isHighlighted = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
      decoration: BoxDecoration(
        color: isHighlighted ? const Color(0xFF667eea).withAlpha(26) : null,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              field,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value.isNotEmpty ? value : '-',
              style: TextStyle(
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.normal,
                color: isHighlighted ? const Color(0xFF667eea) : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
