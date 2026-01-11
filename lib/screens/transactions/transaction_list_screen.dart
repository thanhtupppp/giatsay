import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';
import '../../widgets/ui/dialogs.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final _transactionRepo = TransactionRepository();

  DateTime _startDate = DateTime.now().subtract(const Duration(days: 30));
  DateTime _endDate = DateTime.now();

  Map<String, double> _summary = {'income': 0, 'expense': 0, 'balance': 0};
  List<Transaction> _transactions = [];
  bool _isLoading = true;

  // Form State
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _descController = TextEditingController();
  String _selectedType = 'income'; // 'income' or 'expense'
  String? _selectedCategory;
  DateTime _selectedDate = DateTime.now();
  bool _isSubmitting = false;
  // int _dropdownKey = 0; // Removed as we can control state better

  final List<String> _incomeCategories = ['Bán hàng', 'Dịch vụ', 'Khác'];
  final List<String> _expenseCategories = [
    'Nhập hàng',
    'Điện nước',
    'Lương nhân viên',
    'Mặt bằng',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _transactionRepo.getSummary(
        startDate: _startDate,
        endDate: _endDate,
      );
      final transactions = await _transactionRepo.getAll(
        startDate: _startDate,
        endDate: _endDate,
      );

      setState(() {
        _summary = summary;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        showAppAlertDialog(
          context,
          title: 'Lỗi',
          content: 'Lỗi tải dữ liệu: $e',
        );
      }
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      showAppAlertDialog(
        context,
        title: 'Thiếu thông tin',
        content: 'Vui lòng chọn danh mục',
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final amount =
          double.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;

      final transaction = Transaction(
        type: _selectedType,
        category: _selectedCategory!,
        amount: amount,
        description: _descController.text,
        userId: 1, // Hardcoded for now
        transactionDate: _selectedDate,
      );

      await _transactionRepo.create(transaction);

      // Reset form
      _amountController.clear();
      _descController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedCategory = null;
        // _dropdownKey++;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Đã lưu giao dịch ${_selectedType == 'income' ? 'Thu' : 'Chi'}',
            ),
            backgroundColor: AppTheme.successColor,
          ),
        );
      }

      await _loadData();
    } catch (e) {
      if (mounted) {
        showAppAlertDialog(context, title: 'Lỗi', content: 'Lỗi lưu: $e');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteTransaction(Transaction t) async {
    final confirm = await showAppConfirmDialog(
      context,
      title: 'Xóa giao dịch',
      content:
          'Bạn có chắc chắn muốn xóa giao dịch này? Hành động này không thể hoàn tác.',
      confirmText: 'Xóa',
      confirmColor: AppTheme.errorColor,
    );
    if (confirm == true) {
      await _transactionRepo.delete(t.id!);
      _loadData();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DesktopLayout(
      title: 'Quản lý Thu Chi',
      actions: [
        SecondaryButton(
          onPressed: () async {
            final picked = await showDateRangePicker(
              context: context,
              firstDate: DateTime(2020),
              lastDate: DateTime.now(),
              initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
            );
            if (picked != null) {
              setState(() {
                _startDate = picked.start;
                _endDate = picked.end;
              });
              _loadData();
            }
          },
          icon: Icons.calendar_today,
          label:
              '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
        ),
      ],
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatsRow(),
                  const SizedBox(height: 24),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 1000) {
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 2, child: _buildChartSection()),
                            const SizedBox(width: 24),
                            Expanded(flex: 1, child: _buildQuickAddForm()),
                          ],
                        );
                      } else {
                        return Column(
                          children: [
                            _buildChartSection(),
                            const SizedBox(height: 24),
                            _buildQuickAddForm(),
                          ],
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 24),
                  _buildTransactionList(),
                ],
              ),
            ),
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            'Tổng Thu',
            _summary['income']!,
            Icons.arrow_upward,
            Colors.green,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Tổng Chi',
            _summary['expense']!,
            Icons.arrow_downward,
            Colors.red,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            'Lợi Nhuận Ròng',
            _summary['balance']!,
            Icons.account_balance_wallet,
            Colors.blue,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    double value,
    IconData icon,
    Color color,
  ) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat.currency(
              locale: 'vi',
              symbol: 'đ',
              decimalDigits: 0,
            ).format(value),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getChartData() {
    if (_transactions.isEmpty) return [];

    // Group by month (last 6 months)
    final now = DateTime.now();
    final months = List.generate(
      6,
      (i) => DateTime(now.year, now.month - 5 + i, 1),
    );

    return months.asMap().entries.map((entry) {
      final monthStart = entry.value;
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);

      double income = 0;
      double expense = 0;

      for (var t in _transactions) {
        if (t.transactionDate.isAfter(
              monthStart.subtract(const Duration(days: 1)),
            ) &&
            t.transactionDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
          if (t.type == 'income') {
            income += t.amount;
          } else {
            expense += t.amount;
          }
        }
      }

      return BarChartGroupData(
        x: entry.key,
        barRods: [
          BarChartRodData(
            toY: income,
            color: Colors.green,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
          BarChartRodData(
            toY: expense,
            color: Colors.red,
            width: 12,
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      );
    }).toList();
  }

  Widget _buildChartSection() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.analytics_outlined,
                      color: Colors.blue,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Báo cáo Tài Chính',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Phân tích hiệu quả kinh doanh',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Simplified header actions
            ],
          ),
          const SizedBox(height: 24),

          // Filters (Simplified for now - kept visual placeholders or removed if unused logic)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 10),
                  const SizedBox(width: 4),
                  const Text(
                    'Thu nhập',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 16),
                  Icon(Icons.circle, color: Colors.red, size: 10),
                  const SizedBox(width: 4),
                  const Text(
                    'Chi phí',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Chart
          SizedBox(
            height: 350,
            child: BarChart(
              BarChartData(
                gridData: const FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final now = DateTime.now();
                        final monthIndex = now.month - 5 + value.toInt();
                        int displayMonth = monthIndex;
                        if (displayMonth <= 0) displayMonth += 12;
                        if (displayMonth > 12) displayMonth -= 12;

                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'T$displayMonth',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _getChartData(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.currency(
                          locale: 'vi',
                          symbol: 'đ',
                          decimalDigits: 0,
                        ).format(rod.toY),
                        const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickAddForm() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Ghi nhận Giao dịch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: () {
                    _amountController.clear();
                    _descController.clear();
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'income'
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedType == 'income'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.add_circle,
                              color: Colors.green,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Thu nhập',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'expense'
                              ? Colors.white
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedType == 'expense'
                              ? [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 4,
                                  ),
                                ]
                              : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(
                              Icons.remove_circle,
                              color: Colors.red,
                              size: 16,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Chi phí',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            AppNumberField(
              controller: _amountController,
              label: 'Số tiền',
              suffixText: 'đ',
              validator: (v) => v!.isEmpty ? 'Nhập số tiền' : null,
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                  initialDate: _selectedDate,
                );
                if (picked != null) setState(() => _selectedDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Ngày giao dịch',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.calendar_today),
                ),
                child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
              ),
            ),
            const SizedBox(height: 16),
            AppDropdown<String>(
              label: 'Danh mục',
              value: _selectedCategory,
              items:
                  (_selectedType == 'income'
                          ? _incomeCategories
                          : _expenseCategories)
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) => setState(() => _selectedCategory = v),
              hintText: 'Chọn danh mục',
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _descController,
              label: 'Mô tả chi tiết',
              hintText: 'Ví dụ: Thu tiền giặt 5kg quần áo...',
              maxLines: 2,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: PrimaryButton(
                onPressed: _isSubmitting ? null : _submitTransaction,
                icon: Icons.save,
                label: 'Lưu Giao Dịch',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return AppCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Lịch sử giao dịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text('Chưa có giao dịch nào'),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _transactions.length,
              separatorBuilder: (_, __) => const Divider(),
              itemBuilder: (context, index) {
                final t = _transactions[index];
                final isIncome = t.type == 'income';
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: (isIncome ? Colors.green : Colors.red).withValues(
                        alpha: 0.1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                      color: isIncome ? Colors.green : Colors.red,
                    ),
                  ),
                  title: Text(
                    t.category,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${DateFormat('dd/MM/yyyy').format(t.transactionDate)} • ${t.description ?? ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(t.amount)}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isIncome ? Colors.green : Colors.red,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          size: 20,
                          color: Colors.grey,
                        ),
                        onPressed: () => _deleteTransaction(t),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
