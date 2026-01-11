import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/asset.dart';
import '../../repositories/asset_repository.dart';
import '../../models/maintenance_record.dart';
import '../../repositories/maintenance_repository.dart';
import '../../widgets/main_layout.dart';

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key});

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen> with SingleTickerProviderStateMixin {
  final _assetRepo = AssetRepository();
  final _maintenanceRepo = MaintenanceRepository();
  late TabController _tabController;
  
  List<Asset> _assets = [];
  List<Asset> _filteredAssets = [];
  List<MaintenanceRecord> _allMaintenanceRecords = [];
  bool _isLoading = true;
  double _totalValue = 0;
  int _activeCount = 0;
  
  String _searchQuery = '';
  String? _statusFilter;
  
  // Premises Info State
  String _contractNumber = 'HD-2023-001';
  String _ownerName = 'Nguyễn Văn A';
  String _ownerPhone = '0909 123 456';
  double _rentalCost = 15000000;
  DateTime _startDate = DateTime(2023, 1, 1);
  DateTime _endDate = DateTime(2025, 1, 1);

  final List<String> _categories = ['Máy giặt', 'Máy sấy', 'Nội thất', 'Thiết bị điện', 'Khác'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadPremisesInfo();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final assets = await _assetRepo.getAll();
      final totalValue = await _assetRepo.getTotalValue();
      final maintenance = await _maintenanceRepo.getAll();
      
      if (mounted) {
        setState(() {
          _assets = assets;
          _totalValue = totalValue;
          _allMaintenanceRecords = maintenance;
          _activeCount = assets.where((a) => a.condition == 'Tốt' || a.condition == 'Bình thường').length;
          _isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPremisesInfo() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _contractNumber = prefs.getString('premises_contract') ?? 'HD-2023-001';
        _ownerName = prefs.getString('premises_owner') ?? 'Nguyễn Văn A';
        _ownerPhone = prefs.getString('premises_phone') ?? '0909 123 456';
        _rentalCost = prefs.getDouble('premises_cost') ?? 15000000;
        final start = prefs.getString('premises_start');
        final end = prefs.getString('premises_end');
        if (start != null) _startDate = DateTime.parse(start);
        if (end != null) _endDate = DateTime.parse(end);
      });
    }
  }

  Future<void> _savePremisesInfo() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('premises_contract', _contractNumber);
    await prefs.setString('premises_owner', _ownerName);
    await prefs.setString('premises_phone', _ownerPhone);
    await prefs.setDouble('premises_cost', _rentalCost);
    await prefs.setString('premises_start', _startDate.toIso8601String());
    await prefs.setString('premises_end', _endDate.toIso8601String());
  }
  
  void _applyFilters() {
    setState(() {
      _filteredAssets = _assets.where((asset) {
        final matchesSearch = _searchQuery.isEmpty || 
          asset.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          (asset.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ?? false);
        
        final matchesStatus = _statusFilter == null || 
          (_statusFilter == 'active' ? (asset.condition == 'Tốt' || asset.condition == 'Bình thường') : 
           _statusFilter == 'issue' ? (asset.condition == 'Cần sửa chữa' || asset.condition == 'Hỏng') : true);
           
        return matchesSearch && matchesStatus;
      }).toList();
    });
  }

  int _calculateRemainingMonths() {
    final now = DateTime.now();
    int months = (_endDate.year - now.year) * 12 + _endDate.month - now.month;
    if (now.day > _endDate.day) months--;
    return months > 0 ? months : 0;
  }

  @override
  Widget build(BuildContext context) {
    return MainLayout(
      title: 'Quản lý Tài sản',
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.inventory_2_outlined, size: 32, color: Color(0xFF1976D2)),
                    const SizedBox(width: 16),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quản lý Tài sản & Mặt bằng', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        Text('Theo dõi tài sản, khấu hao và thông tin thuê mặt bằng', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: () => _showAddEditDialog(),
                      icon: const Icon(Icons.add),
                      label: const Text('Thêm tài sản'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1976D2),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                // Summary Cards
                Row(
                  children: [
                    Expanded(child: _buildStatCard('Tổng tài sản', '${_assets.length}', Icons.inventory, Colors.blue, '$_activeCount đang hoạt động', true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Tổng giá trị', NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_totalValue), Icons.attach_money, Colors.green, '+12% so với tháng trước', true)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Chi phí thuê', NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_rentalCost), Icons.store, Colors.orange, 'Đến hạn trong 5 ngày', false)),
                    const SizedBox(width: 16),
                    Expanded(child: _buildStatCard('Bảo trì', '${_allMaintenanceRecords.length}', Icons.build, Colors.red, '${_assets.length - _activeCount} thiết bị cần sửa', false)),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Tabs
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(topLeft: Radius.circular(12), topRight: Radius.circular(12)),
              border: Border(bottom: BorderSide(color: Colors.grey, width: 0.5)),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1976D2),
              unselectedLabelColor: Colors.grey,
              indicatorColor: const Color(0xFF1976D2),
              tabs: const [
                Tab(text: 'Danh sách Tài sản'),
                Tab(text: 'Thông tin Mặt bằng'),
                Tab(text: 'Lịch sử Bảo trì'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12), bottomRight: Radius.circular(12)),
              ),
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildAssetListTab(),
                  _buildPremisesTab(),
                  _buildMaintenanceTab(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetListTab() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          // Filter Bar
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, mã tài sản...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 12),
                  ),
                  onChanged: (v) {
                    _searchQuery = v;
                    _applyFilters();
                  },
                ),
              ),
              const SizedBox(width: 16),
              const Text('Lọc theo:'),
              const SizedBox(width: 8),
              DropdownButtonHideUnderline(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(8)),
                  child: DropdownButton<String?>(
                    value: _statusFilter,
                    hint: const Text('Tất cả trạng thái'),
                    items: const [
                       DropdownMenuItem(value: null, child: Text('Tất cả trạng thái')),
                       DropdownMenuItem(value: 'active', child: Text('Đang hoạt động')),
                       DropdownMenuItem(value: 'issue', child: Text('Cần bảo trì')),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v);
                      _applyFilters();
                    },
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(onPressed: (){}, icon: const Icon(Icons.filter_list_alt)),
            ],
          ),
          const SizedBox(height: 16),
          
          // Data Table
          Expanded(
            child: _isLoading 
              ? const Center(child: CircularProgressIndicator())
              : DataTable2(
                  headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                  columnSpacing: 12,
                  horizontalMargin: 12,
                  minWidth: 1000,
                  columns: const [
                    DataColumn2(label: Text('MÃ TS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.S),
                    DataColumn2(label: Text('TÊN TÀI SẢN', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.L),
                    DataColumn2(label: Text('LOẠI', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.M),
                    DataColumn2(label: Text('NGÀY MUA', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.M),
                    DataColumn2(label: Text('GIÁ GỐC', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.M),
                    DataColumn2(label: Text('TRẠNG THÁI', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.S),
                    DataColumn2(label: Text('HÀNH ĐỘNG', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 11)), size: ColumnSize.S, numeric: true),
                  ],
                  rows: _filteredAssets.map((asset) => DataRow2(
                    cells: [
                      DataCell(Text(asset.code ?? 'MG-${asset.id.toString().padLeft(4, '0')}', style: const TextStyle(color: Colors.grey))),
                      DataCell(
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
                              child: Icon(_getIconForCategory(asset.category), size: 16, color: Colors.grey[700]),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(asset.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                Text('S/N: ${asset.serialNumber ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                      DataCell(Text(asset.category ?? '-')),
                      DataCell(Text(asset.purchaseDate != null ? DateFormat('dd/MM/yyyy').format(asset.purchaseDate!) : '-')),
                      DataCell(Text(asset.purchasePrice != null ? NumberFormat.currency(locale: 'vi', symbol: 'đ').format(asset.purchasePrice) : '-')),
                      DataCell(_buildStatusBadge(asset.condition)),
                      DataCell(
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.build, color: Colors.orange, size: 20),
                              tooltip: 'Bảo trì',
                              onPressed: () => _showMaintenanceHistoryDialog(asset),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                              tooltip: 'Sửa',
                              onPressed: () => _showAddEditDialog(asset),
                            ),
                          ],
                        )
                      ),
                    ],
                  )).toList(),
                ),
          ),
          
           if (_filteredAssets.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Text('Hiển thị ${_filteredAssets.length} trong số ${_assets.length} tài sản', style: const TextStyle(color: Colors.grey)),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                    child: Row(
                      children: [
                        IconButton(icon: const Icon(Icons.chevron_left), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: (){}),
                        Container(color: const Color(0xFF1976D2), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: const Text('1', style: TextStyle(color: Colors.white))),
                        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), child: const Text('2')),
                        IconButton(icon: const Icon(Icons.chevron_right), padding: EdgeInsets.zero, constraints: const BoxConstraints(), onPressed: (){}),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPremisesTab() {
     return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Container(
             padding: const EdgeInsets.all(24),
             decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)]),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     const Text('Thông tin Hợp đồng', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                     TextButton.icon(
                       onPressed: _showEditPremisesDialog,
                       icon: const Icon(Icons.edit),
                       label: const Text('Chỉnh sửa'),
                     ),
                   ],
                 ),
                 const Divider(height: 32),
                 Row(
                   children: [
                     Expanded(child: _buildInfoRow(Icons.description, 'Số hợp đồng', _contractNumber)),
                     Expanded(child: _buildInfoRow(Icons.person, 'Chủ nhà', '$_ownerName\n$_ownerPhone')),
                   ],
                 ),
                 const SizedBox(height: 24),
                 Row(
                   children: [
                     Expanded(child: _buildInfoRow(Icons.calendar_today, 'Thời hạn thuê', '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}')),
                     Expanded(child: _buildInfoRow(Icons.monetization_on, 'Giá thuê', '${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_rentalCost)}/tháng')),
                   ],
                 ),
                 const SizedBox(height: 32),
                 const Text('Thời hạn còn lại', style: TextStyle(fontWeight: FontWeight.bold)),
                 const SizedBox(height: 12),
                 LinearProgressIndicator(
                   value: 0.7, 
                   backgroundColor: Colors.grey[200], 
                   valueColor: const AlwaysStoppedAnimation(Colors.green),
                   minHeight: 10,
                   borderRadius: BorderRadius.circular(5),
                 ),
                 const SizedBox(height: 8),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('${_calculateRemainingMonths()} tháng còn lại', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                     Text('Kết thúc: ${DateFormat('dd/MM/yyyy').format(_endDate)}', style: const TextStyle(color: Colors.grey)),
                   ],
                 )
               ],
             ),
           ),
        ],
      ),
    );
  }

  Widget _buildMaintenanceTab() {
     if (_allMaintenanceRecords.isEmpty) {
       return const Center(child: Text('Chưa có lịch sử bảo trì nào', style: TextStyle(color: Colors.grey)));
     }
     
     return ListView.separated(
       padding: const EdgeInsets.all(24),
       itemCount: _allMaintenanceRecords.length,
       separatorBuilder: (_,__) => const SizedBox(height: 16),
       itemBuilder: (context, index) {
         final record = _allMaintenanceRecords[index];
         final assetName = _assets.firstWhere((a) => a.id == record.assetId, orElse: () => Asset(name: 'Unknown', id: record.assetId)).name;
         
         return _buildMaintenanceItem(
           Icons.build, 
           Colors.blue, 
           '$assetName: ${record.description}', 
           DateFormat('dd/MM/yyyy').format(record.date), 
           'Chi phí: ${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(record.cost)} - Technician: ${record.technician ?? 'N/A'}'
         );
       }
     );
  }
  
  Widget _buildStatCard(String title, String value, IconData icon, Color color, String footer, bool? isPositive) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, color: color, size: 16)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isPositive != null) ...[
                 Icon(isPositive ? Icons.trending_up : Icons.trending_down, size: 16, color: isPositive ? Colors.green : Colors.red),
                 const SizedBox(width: 4),
              ],
              Text(footer, style: TextStyle(color: isPositive == null ? Colors.orange : (isPositive ? Colors.green : (isPositive == false && title.contains('Phí') ? Colors.green : Colors.red)), fontSize: 12)),
            ], 
          )
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(8)), child: Icon(icon, color: Colors.blue)),
        const SizedBox(width: 16),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)), Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))]),
      ],
    );
  }
  
  Widget _buildMaintenanceItem(IconData icon, Color color, String title, String date, String desc) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade100)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle), child: Icon(icon, size: 16, color: color)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                   Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold))),
                   Text(date, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ]),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(String? condition) {
    Color color;
    String text;
    if (condition == 'Tốt' || condition == 'Bình thường') {
      color = Colors.green;
      text = 'Hoạt động';
    } else if (condition == 'Cần sửa chữa' || condition == 'Bảo trì') {
      color = Colors.orange;
      text = 'Bảo trì';
    } else {
      color = Colors.red;
      text = 'Hỏng';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'Máy giặt': return Icons.local_laundry_service;
      case 'Máy sấy': return Icons.air;
      case 'Nội thất': return Icons.chair;
      case 'Thiết bị điện': return Icons.electrical_services;
      default: return Icons.inventory_2;
    }
  }

  Future<void> _showMaintenanceHistoryDialog(Asset asset) async {
    List<MaintenanceRecord> records = await _maintenanceRepo.getByAssetId(asset.id!);
    
    if (!mounted) return;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 600,
            constraints: const BoxConstraints(maxHeight: 700),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Lịch sử Bảo trì: ${asset.name}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Text('Mã: ${asset.code ?? 'N/A'}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                    IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                  ],
                ),
                const Divider(height: 32),
                
                Row(
                   children: [
                     const Expanded(child: Text('Danh sách phiếu bảo trì', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold))),
                     ElevatedButton.icon(
                       onPressed: () async {
                          await _showAddMaintenanceRecordDialog(asset);
                          final updated = await _maintenanceRepo.getByAssetId(asset.id!);
                          if (mounted) {
                            setDialogState(() => records = updated);
                            _loadData();
                          }
                       },
                       icon: const Icon(Icons.add, size: 18),
                       label: const Text('Thêm phiếu'),
                       style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                     ),
                   ],
                ),
                
                const SizedBox(height: 16),
                
                Expanded(
                  child: records.isEmpty 
                  ? const Center(child: Text('Chưa có dữ liệu bảo trì'))
                  : ListView.separated(
                      itemCount: records.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (ctx, idx) {
                        final rec = records[idx];
                        return ListTile(
                          leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.build, color: Colors.white, size: 16)),
                          title: Text(rec.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text('Ngày: ${DateFormat('dd/MM/yyyy').format(rec.date)} • KT: ${rec.technician ?? '-'}'),
                          trailing: Text(NumberFormat.currency(locale: 'vi', symbol: 'đ').format(rec.cost), style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                        );
                      },
                    ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddMaintenanceRecordDialog(Asset asset) async {
    final descController = TextEditingController();
    final costController = TextEditingController();
    final techController = TextEditingController();
    DateTime selectedDate = DateTime.now();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setInnerState) => AlertDialog(
          title: const Text('Thêm phiếu bảo trì mới'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: selectedDate, firstDate: DateTime(2000), lastDate: DateTime.now());
                    if (picked != null) setInnerState(() => selectedDate = picked);
                  },
                  child: InputDecorator(decoration: const InputDecoration(labelText: 'Ngày bảo trì', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(selectedDate))),
                ),
                const SizedBox(height: 12),
                TextField(controller: descController, decoration: const InputDecoration(labelText: 'Nội dung thực hiện *', border: OutlineInputBorder()), maxLines: 2),
                const SizedBox(height: 12),
                TextField(controller: costController, decoration: const InputDecoration(labelText: 'Chi phí (VNĐ)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                TextField(controller: techController, decoration: const InputDecoration(labelText: 'Đơn vị / Kỹ thuật viên', border: OutlineInputBorder())),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () async {
                if (descController.text.isEmpty) return;
                
                final record = MaintenanceRecord(
                  assetId: asset.id!,
                  date: selectedDate,
                  description: descController.text,
                  cost: double.tryParse(costController.text) ?? 0,
                  technician: techController.text,
                );
                
                await _maintenanceRepo.create(record);
                if (context.mounted) Navigator.pop(context);
              },
              child: const Text('Lưu phiếu'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog([Asset? asset]) async {
    final isEdit = asset != null;
    final nameController = TextEditingController(text: asset?.name ?? '');
    final codeController = TextEditingController(text: asset?.code ?? '');
    final serialController = TextEditingController(text: asset?.serialNumber ?? '');
    final categoryController = TextEditingController(text: asset?.category ?? _categories.first);
    final priceController = TextEditingController(text: asset?.purchasePrice?.toString() ?? '');
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(isEdit ? 'Cập nhật tài sản' : 'Thêm tài sản mới'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: codeController, decoration: const InputDecoration(labelText: 'Mã tài sản (Optional)', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Tên tài sản *', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              TextField(controller: serialController, decoration: const InputDecoration(labelText: 'Serial Number', border: OutlineInputBorder())),
              const SizedBox(height: 12),
              DropdownMenu<String>(
                initialSelection: categoryController.text,
                dropdownMenuEntries: _categories.map((c) => DropdownMenuEntry(value: c, label: c)).toList(),
                onSelected: (v) => categoryController.text = v ?? '',
                label: const Text('Loại'),
                width: 250,
              ),
              const SizedBox(height: 12),
              TextField(controller: priceController, decoration: const InputDecoration(labelText: 'Giá mua', border: OutlineInputBorder())),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
          ElevatedButton(
            onPressed: () async {
              if (nameController.text.isEmpty) return;
              
              final newAsset = Asset(
                id: asset?.id,
                code: codeController.text,
                name: nameController.text,
                serialNumber: serialController.text,
                category: categoryController.text,
                purchasePrice: double.tryParse(priceController.text),
                condition: 'Tốt', 
                purchaseDate: DateTime.now(), 
              );
              
              if (isEdit) {
                 await _assetRepo.update(newAsset);
              } else {
                 await _assetRepo.create(newAsset);
              }
              if (context.mounted) {
                Navigator.pop(context);
                _loadData();
              }
            },
            child: const Text('Lưu'),
          ),
        ],
      )
    );
  }

  Future<void> _showEditPremisesDialog() async {
    final contractController = TextEditingController(text: _contractNumber);
    final ownerController = TextEditingController(text: _ownerName);
    final phoneController = TextEditingController(text: _ownerPhone);
    final costController = TextEditingController(text: _rentalCost.toStringAsFixed(0));
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Cập nhật Thông tin Mặt bằng'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: contractController, decoration: const InputDecoration(labelText: 'Số hợp đồng', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: TextField(controller: ownerController, decoration: const InputDecoration(labelText: 'Tên chủ nhà', border: OutlineInputBorder()))),
                    const SizedBox(width: 12),
                    Expanded(child: TextField(controller: phoneController, decoration: const InputDecoration(labelText: 'Số điện thoại', border: OutlineInputBorder()))),
                  ],
                ),
                const SizedBox(height: 12),
                TextField(controller: costController, decoration: const InputDecoration(labelText: 'Giá thuê (VNĐ/tháng)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                           final picked = await showDatePicker(context: context, initialDate: tempStart, firstDate: DateTime(2000), lastDate: DateTime(2100));
                           if (picked != null) setDialogState(() => tempStart = picked);
                        },
                        child: InputDecorator(decoration: const InputDecoration(labelText: 'Ngày bắt đầu', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(tempStart))),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: InkWell(
                         onTap: () async {
                           final picked = await showDatePicker(context: context, initialDate: tempEnd, firstDate: DateTime(2000), lastDate: DateTime(2100));
                           if (picked != null) setDialogState(() => tempEnd = picked);
                        },
                        child: InputDecorator(decoration: const InputDecoration(labelText: 'Ngày kết thúc', border: OutlineInputBorder()), child: Text(DateFormat('dd/MM/yyyy').format(tempEnd))),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Hủy')),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _contractNumber = contractController.text;
                  _ownerName = ownerController.text;
                  _ownerPhone = phoneController.text;
                  _rentalCost = double.tryParse(costController.text) ?? 0;
                  _startDate = tempStart;
                  _endDate = tempEnd;
                });
                _savePremisesInfo();
                Navigator.pop(context);
              },
              child: const Text('Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
