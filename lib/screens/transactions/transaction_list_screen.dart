import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../repositories/transaction_repository.dart';
import '../../models/transaction.dart';
import '../../config/theme.dart';
import '../../widgets/main_layout.dart';
import '../../widgets/common_dialogs.dart';

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
  int _dropdownKey = 0;

  final List<String> _incomeCategories = ['Bán hàng', 'Dịch vụ', 'Khác'];
  final List<String> _expenseCategories = ['Nhập hàng', 'Điện nước', 'Lương nhân viên', 'Mặt bằng', 'Khác'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final summary = await _transactionRepo.getSummary(startDate: _startDate, endDate: _endDate);
      final transactions = await _transactionRepo.getAll(startDate: _startDate, endDate: _endDate);
      
      setState(() {
        _summary = summary;
        _transactions = transactions;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải dữ liệu: $e')));
      }
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn danh mục')));
      return;
    }

    setState(() => _isSubmitting = true);
    
    try {
      final amount = double.parse(_amountController.text.replaceAll('.', '').replaceAll(',', ''));
      
      final transaction = Transaction(
        type: _selectedType,
        category: _selectedCategory!,
        amount: amount,
        description: _descController.text,
        userId: 1, // Hardcoded for now, should come from Auth
        transactionDate: _selectedDate,
      );
      
      await _transactionRepo.create(transaction);
      
      // Reset form
      _amountController.clear();
      _descController.clear();
      setState(() {
        _selectedDate = DateTime.now();
        _selectedCategory = null;
        _dropdownKey++;
      });
      
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Đã lưu giao dịch ${_selectedType == 'income' ? 'Thu' : 'Chi'}'), backgroundColor: AppTheme.successColor),
         );
      }
      
      await _loadData();
    } catch (e) {
       if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi lưu: $e'), backgroundColor: AppTheme.errorColor));
       }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _deleteTransaction(Transaction t) async {
     final confirm = await CommonDialogs.showDeleteConfirmation(context, title: 'Xóa giao dịch', content: 'Bạn có chắc chắn muốn xóa giao dịch này?');
     if (confirm) {
       await _transactionRepo.delete(t.id!);
       _loadData();
     }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Quản lý Thu Chi',
      child: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
                const SizedBox(height: 24),
                _buildStatsRow(),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    if (constraints.maxWidth > 900) {
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
  
  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theo dõi dòng tiền và hiệu quả kinh doanh', style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary)),
          ],
        ),
        OutlinedButton.icon(
          onPressed: () async {
             final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: _startDate, end: _endDate));
             if (picked != null) {
               setState(() { _startDate = picked.start; _endDate = picked.end; });
               _loadData();
             }
          },
          icon: const Icon(Icons.calendar_today, size: 16),
          label: Text('${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}'),
        )
      ],
    );
  }

  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(child: _buildStatCard('Tổng Thu', _summary['income']!, Icons.arrow_upward, Colors.green)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Tổng Chi', _summary['expense']!, Icons.arrow_downward, Colors.red)),
        const SizedBox(width: 16),
        Expanded(child: _buildStatCard('Lợi Nhuận Ròng', _summary['balance']!, Icons.account_balance_wallet, Colors.blue)),
      ],
    );
  }

  Widget _buildStatCard(String title, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Text(title, style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(value),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  List<BarChartGroupData> _getChartData() {
    if (_transactions.isEmpty) return [];
    
    // Group by month (last 6 months)
    final now = DateTime.now();
    final months = List.generate(6, (i) => DateTime(now.year, now.month - 5 + i, 1));
    
    return months.asMap().entries.map((entry) {
      final monthStart = entry.value;
      final monthEnd = DateTime(monthStart.year, monthStart.month + 1, 0);
      
      double income = 0;
      double expense = 0;
      
      for (var t in _transactions) {
        if (t.transactionDate.isAfter(monthStart.subtract(const Duration(days: 1))) && 
            t.transactionDate.isBefore(monthEnd.add(const Duration(days: 1)))) {
           if (t.type == 'income') {
             income += t.amount;
           } else {
             expense += t.amount;
           }
        }
      }
      
      return BarChartGroupData(x: entry.key, barRods: [
        BarChartRodData(toY: income, color: Colors.green, width: 12, borderRadius: BorderRadius.circular(4)),
        BarChartRodData(toY: expense, color: Colors.red, width: 12, borderRadius: BorderRadius.circular(4)),
      ]);
    }).toList();
  }

  Widget _buildChartSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
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
                    decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: const Icon(Icons.analytics_outlined, color: Colors.blue),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Báo cáo Tài Chính', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('Phân tích hiệu quả kinh doanh & Xuất dữ liệu', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                    ],
                  ),
                ],
              ),
              Row(
                children: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.picture_as_pdf, size: 16, color: Colors.red),
                    label: const Text('Xuất PDF', style: TextStyle(color: Colors.black87)),
                    style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300)),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.table_view, size: 16, color: Colors.green),
                    label: const Text('Xuất Excel', style: TextStyle(color: Colors.black87)),
                     style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.grey.shade300)),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 24),
          
          // Filters
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Khoảng thời gian', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: 'Theo Tháng',
                          isExpanded: true,
                          items: ['Theo Tháng', 'Theo Quý', 'Theo Năm'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Loại báo cáo', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: 'Báo cáo Lãi Lỗ',
                          isExpanded: true,
                          items: ['Báo cáo Lãi Lỗ', 'Báo cáo Thu Nhập', 'Báo cáo Chi phí'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                          onChanged: (_) {},
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
               Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Chọn khoảng', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () async {
                         final picked = await showDateRangePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDateRange: DateTimeRange(start: _startDate, end: _endDate));
                         if (picked != null) {
                           setState(() { _startDate = picked.start; _endDate = picked.end; });
                           _loadData();
                         }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(DateFormat('MM/yyyy').format(_startDate), style: const TextStyle(fontSize: 14)),
                            const Icon(Icons.calendar_today, size: 16, color: Colors.grey),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
               const SizedBox(width: 16),
               Padding(
                 padding: const EdgeInsets.only(top: 24),
                 child: ElevatedButton(
                   onPressed: _loadData,
                   style: ElevatedButton.styleFrom(
                     backgroundColor: const Color(0xFF1976D2),
                     foregroundColor: Colors.white,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                     padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20), // Match height of inputs
                   ),
                   child: const Text('Xem'),
                 ),
               ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Chart Title & Legend
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
               const Text('Biểu đồ Lãi Lỗ (6 tháng gần nhất)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
               Row(
                children: [
                  Icon(Icons.circle, color: Colors.green, size: 10), const SizedBox(width: 4), const Text('Thu nhập', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 16),
                  Icon(Icons.circle, color: Colors.red, size: 10), const SizedBox(width: 4), const Text('Chi phí', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              )
            ],
          ),
          const SizedBox(height: 24),
          
          // Chart
          SizedBox(
            height: 350,
            child: BarChart(
              BarChartData(
                gridData: FlGridData(show: false),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        final now = DateTime.now();
                        final monthIndex = now.month - 5 + value.toInt();
                        int displayMonth = monthIndex;
                        if (displayMonth <= 0) displayMonth += 12;
                        if (displayMonth > 12) displayMonth -= 12;
                        
                        return Padding(padding: const EdgeInsets.only(top: 8), child: Text('T$displayMonth', style: const TextStyle(fontSize: 12, color: Colors.grey)));
                      },
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                barGroups: _getChartData(),
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                     tooltipBgColor: Colors.black87,
                     getTooltipItem: (group, groupIndex, rod, rodIndex) {
                       return BarTooltipItem(
                         NumberFormat.currency(locale: 'vi', symbol: 'đ', decimalDigits: 0).format(rod.toY),
                         const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                       );
                     }
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
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Ghi nhận Giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.refresh, size: 20), onPressed: () {
                  _amountController.clear(); _descController.clear();
                }),
              ],
            ),
            const SizedBox(height: 24),
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'income'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'income' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedType == 'income' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.add_circle, color: Colors.green, size: 16), SizedBox(width: 8), Text('Thu nhập', style: TextStyle(fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedType = 'expense'),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: _selectedType == 'expense' ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: _selectedType == 'expense' ? [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4)] : [],
                        ),
                         child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [Icon(Icons.remove_circle, color: Colors.red, size: 16), SizedBox(width: 8), Text('Chi phí', style: TextStyle(fontWeight: FontWeight.bold))]),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              decoration: const InputDecoration(
                labelText: 'Số tiền (VNĐ)',
                prefixText: 'đ ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              validator: (v) => v!.isEmpty ? 'Nhập số tiền' : null,
            ),
             const SizedBox(height: 16),
             InkWell(
               onTap: () async {
                 final picked = await showDatePicker(context: context, firstDate: DateTime(2020), lastDate: DateTime.now(), initialDate: _selectedDate);
                 if (picked != null) setState(() => _selectedDate = picked);
               },
               child: InputDecorator(
                 decoration: const InputDecoration(labelText: 'Ngày giao dịch', border: OutlineInputBorder(), prefixIcon: Icon(Icons.calendar_today)),
                 child: Text(DateFormat('dd/MM/yyyy').format(_selectedDate)),
               ),
             ),
             const SizedBox(height: 16),
             DropdownButtonFormField<String>(
               key: ValueKey(_dropdownKey),
               initialValue: _selectedCategory,
               decoration: const InputDecoration(labelText: 'Danh mục', border: OutlineInputBorder(), prefixIcon: Icon(Icons.category)),
               items: (_selectedType == 'income' ? _incomeCategories : _expenseCategories).map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
               onChanged: (v) => setState(() => _selectedCategory = v),
             ),
             const SizedBox(height: 16),
             TextFormField(
              controller: _descController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Mô tả chi tiết',
                hintText: 'Ví dụ: Thu tiền giặt 5kg quần áo...',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isSubmitting ? null : _submitTransaction,
                icon: const Icon(Icons.save),
                label: const Text('Lưu Giao Dịch', style: TextStyle(fontSize: 16)),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF1976D2), foregroundColor: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Lịch sử giao dịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          if (_transactions.isEmpty)
            const Center(child: Padding(padding: EdgeInsets.all(32), child: Text('Chưa có giao dịch nào')))
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
                    decoration: BoxDecoration(color: (isIncome ? Colors.green : Colors.red).withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(isIncome ? Icons.arrow_upward : Icons.arrow_downward, color: isIncome ? Colors.green : Colors.red),
                  ),
                  title: Text(t.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${DateFormat('dd/MM/yyyy').format(t.transactionDate)} • ${t.description ?? ''}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${isIncome ? '+' : '-'}${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(t.amount)}',
                        style: TextStyle(fontWeight: FontWeight.bold, color: isIncome ? Colors.green : Colors.red, fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      IconButton(icon: const Icon(Icons.delete_outline, size: 20, color: Colors.grey), onPressed: () => _deleteTransaction(t)),
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
