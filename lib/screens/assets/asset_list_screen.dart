import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:data_table_2/data_table_2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/asset.dart';
import '../../repositories/asset_repository.dart';
import '../../models/maintenance_record.dart';
import '../../repositories/maintenance_repository.dart';
import '../../config/theme.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';
import '../../widgets/ui/buttons.dart';
import '../../widgets/ui/inputs.dart';

class AssetListScreen extends StatefulWidget {
  const AssetListScreen({super.key});

  @override
  State<AssetListScreen> createState() => _AssetListScreenState();
}

class _AssetListScreenState extends State<AssetListScreen>
    with SingleTickerProviderStateMixin {
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

  final List<String> _categories = [
    'Máy giặt',
    'Máy sấy',
    'Nội thất',
    'Thiết bị điện',
    'Khác',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadData();
    _loadPremisesInfo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          _activeCount = assets
              .where(
                (a) => a.condition == 'Tốt' || a.condition == 'Bình thường',
              )
              .length;
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
        final matchesSearch =
            _searchQuery.isEmpty ||
            asset.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            (asset.code?.toLowerCase().contains(_searchQuery.toLowerCase()) ??
                false);

        final matchesStatus =
            _statusFilter == null ||
            (_statusFilter == 'active'
                ? (asset.condition == 'Tốt' || asset.condition == 'Bình thường')
                : _statusFilter == 'issue'
                ? (asset.condition == 'Cần sửa chữa' ||
                      asset.condition == 'Hỏng')
                : true);

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
    return DesktopLayout(
      title: 'Quản lý Tài sản & Mặt bằng',
      actions: [
        PrimaryButton(
          onPressed: () => _showAddEditDialog(),
          icon: Icons.add,
          label: 'Thêm tài sản',
        ),
      ],
      child: Column(
        children: [
          // Summary Cards
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Tổng tài sản',
                  '${_assets.length}',
                  Icons.inventory,
                  Colors.blue,
                  '$_activeCount đang hoạt động',
                  true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Tổng giá trị',
                  NumberFormat.currency(
                    locale: 'vi',
                    symbol: 'đ',
                  ).format(_totalValue),
                  Icons.attach_money,
                  Colors.green,
                  '+12% so với tháng trước',
                  true,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Chi phí thuê',
                  NumberFormat.currency(
                    locale: 'vi',
                    symbol: 'đ',
                  ).format(_rentalCost),
                  Icons.store,
                  Colors.orange,
                  'Đến hạn trong 5 ngày',
                  false,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildStatCard(
                  'Bảo trì',
                  '${_allMaintenanceRecords.length}',
                  Icons.build,
                  Colors.red,
                  '${_assets.length - _activeCount} thiết bị cần sửa',
                  false,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey, width: 0.5),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppTheme.primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: AppTheme.primaryColor,
              tabs: const [
                Tab(text: 'Danh sách Tài sản'),
                Tab(text: 'Thông tin Mặt bằng'),
                Tab(text: 'Lịch sử Bảo trì'),
              ],
            ),
          ),

          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAssetListTab(),
                _buildPremisesTab(),
                _buildMaintenanceTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetListTab() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          // Inputs and Filters
          AppCard(
            child: Row(
              children: [
                Expanded(
                  child: AppTextField(
                    label: 'Tìm kiếm',
                    hintText: 'Tìm kiếm theo tên, mã tài sản...',
                    prefixIcon: Icons.search,
                    onChanged: (v) {
                      _searchQuery = v;
                      _applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 250,
                  child: AppDropdown<String?>(
                    label: 'Trạng thái',
                    value: _statusFilter,
                    hintText: 'Tất cả trạng thái',
                    items: const [
                      DropdownMenuItem(
                        value: null,
                        child: Text('Tất cả trạng thái'),
                      ),
                      DropdownMenuItem(
                        value: 'active',
                        child: Text('Đang hoạt động'),
                      ),
                      DropdownMenuItem(
                        value: 'issue',
                        child: Text('Cần bảo trì'),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() => _statusFilter = v);
                      _applyFilters();
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          Expanded(
            child: AppCard(
              padding: EdgeInsets.zero,
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : DataTable2(
                      headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
                      columnSpacing: 12,
                      horizontalMargin: 20,
                      minWidth: 1000,
                      columns: const [
                        DataColumn2(
                          label: Text(
                            'MÃ TS',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'TÊN TÀI SẢN',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.L,
                        ),
                        DataColumn2(
                          label: Text(
                            'LOẠI',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                        ),
                        DataColumn2(
                          label: Text(
                            'NGÀY MUA',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                        ),
                        DataColumn2(
                          label: Text(
                            'GIÁ GỐC',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.M,
                          numeric: true,
                        ),
                        DataColumn2(
                          label: Text(
                            'TRẠNG THÁI',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                        ),
                        DataColumn2(
                          label: Text(
                            'HÀNH ĐỘNG',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          size: ColumnSize.S,
                          numeric: true,
                        ),
                      ],
                      rows: _filteredAssets
                          .map(
                            (asset) => DataRow2(
                              cells: [
                                DataCell(
                                  Text(
                                    asset.code ??
                                        'MG-${asset.id.toString().padLeft(4, '0')}',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.grey[200],
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Icon(
                                          _getIconForCategory(asset.category),
                                          size: 16,
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            asset.name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            'S/N: ${asset.serialNumber ?? 'N/A'}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                DataCell(Text(asset.category ?? '-')),
                                DataCell(
                                  Text(
                                    asset.purchaseDate != null
                                        ? DateFormat(
                                            'dd/MM/yyyy',
                                          ).format(asset.purchaseDate!)
                                        : '-',
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    asset.purchasePrice != null
                                        ? NumberFormat.currency(
                                            locale: 'vi',
                                            symbol: 'đ',
                                          ).format(asset.purchasePrice)
                                        : '-',
                                  ),
                                ),
                                DataCell(_buildStatusBadge(asset.condition)),
                                DataCell(
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      IconButton(
                                        icon: const Icon(
                                          Icons.build,
                                          color: AppTheme.warningColor,
                                          size: 20,
                                        ),
                                        tooltip: 'Bảo trì',
                                        onPressed: () =>
                                            _showMaintenanceHistoryDialog(
                                              asset,
                                            ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton(
                                        icon: const Icon(
                                          Icons.edit,
                                          color: AppTheme.primaryColor,
                                          size: 20,
                                        ),
                                        tooltip: 'Sửa',
                                        onPressed: () =>
                                            _showAddEditDialog(asset),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremisesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Thông tin Hợp đồng', style: AppTheme.heading2),
                SecondaryButton(
                  onPressed: _showEditPremisesDialog,
                  icon: Icons.edit,
                  label: 'Chỉnh sửa',
                ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.description,
                    'Số hợp đồng',
                    _contractNumber,
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    Icons.person,
                    'Chủ nhà',
                    '$_ownerName\n$_ownerPhone',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: _buildInfoRow(
                    Icons.calendar_today,
                    'Thời hạn thuê',
                    '${DateFormat('dd/MM/yyyy').format(_startDate)} - ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  ),
                ),
                Expanded(
                  child: _buildInfoRow(
                    Icons.monetization_on,
                    'Giá thuê',
                    '${NumberFormat.currency(locale: 'vi', symbol: 'đ').format(_rentalCost)}/tháng',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              'Thời hạn còn lại',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: 0.7, // Demo value, ideally calculated
              backgroundColor: Colors.grey[200],
              valueColor: const AlwaysStoppedAnimation(Colors.green),
              minHeight: 10,
              borderRadius: BorderRadius.circular(5),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_calculateRemainingMonths()} tháng còn lại',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Kết thúc: ${DateFormat('dd/MM/yyyy').format(_endDate)}',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaintenanceTab() {
    if (_allMaintenanceRecords.isEmpty) {
      return const Center(
        child: Text(
          'Chưa có lịch sử bảo trì nào',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: DataTable2(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columnSpacing: 12,
          horizontalMargin: 20,
          minWidth: 800,
          columns: const [
            DataColumn2(
              label: Text(
                'Tài sản',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text(
                'Ngày',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.S,
            ),
            DataColumn2(
              label: Text(
                'Nội dung',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.L,
            ),
            DataColumn2(
              label: Text(
                'Chi phí',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
              numeric: true,
            ),
            DataColumn2(
              label: Text(
                'Kỹ thuật viên',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              size: ColumnSize.M,
            ),
          ],
          rows: _allMaintenanceRecords.map((record) {
            final assetName = _assets
                .firstWhere(
                  (a) => a.id == record.assetId,
                  orElse: () => Asset(name: 'Unknown', id: record.assetId),
                )
                .name;
            return DataRow2(
              cells: [
                DataCell(
                  Text(
                    assetName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(Text(DateFormat('dd/MM/yyyy').format(record.date))),
                DataCell(Text(record.description)),
                DataCell(
                  Text(
                    NumberFormat.currency(
                      locale: 'vi',
                      symbol: 'đ',
                    ).format(record.cost),
                    style: const TextStyle(color: AppTheme.errorColor),
                  ),
                ),
                DataCell(Text(record.technician ?? '-')),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String footer,
    bool? isPositive,
  ) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: AppTheme.bodySmall),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (isPositive != null) ...[
                Icon(
                  isPositive ? Icons.trending_up : Icons.trending_down,
                  size: 16,
                  color: isPositive ? Colors.green : Colors.red,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                footer,
                style: TextStyle(
                  color: isPositive == null
                      ? Colors.orange
                      : (isPositive
                            ? Colors.green
                            : (isPositive == false && title.contains('Phí')
                                  ? Colors.green
                                  : Colors.red)),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue[50],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Colors.blue),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
            ),
            Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusBadge(String? condition) {
    Color color;
    String text;
    if (condition == 'Tốt' || condition == 'Bình thường') {
      color = AppTheme.successColor;
      text = 'Hoạt động';
    } else if (condition == 'Cần sửa chữa' || condition == 'Bảo trì') {
      color = AppTheme.warningColor;
      text = 'Bảo trì';
    } else {
      color = AppTheme.errorColor;
      text = 'Hỏng';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  IconData _getIconForCategory(String? category) {
    switch (category) {
      case 'Máy giặt':
        return Icons.local_laundry_service;
      case 'Máy sấy':
        return Icons.air;
      case 'Nội thất':
        return Icons.chair;
      case 'Thiết bị điện':
        return Icons.electrical_services;
      default:
        return Icons.inventory_2;
    }
  }

  Future<void> _showMaintenanceHistoryDialog(Asset asset) async {
    List<MaintenanceRecord> records = await _maintenanceRepo.getByAssetId(
      asset.id!,
    );

    if (!mounted) return;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 700,
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
                        Text(
                          'Lịch sử Bảo trì: ${asset.name}',
                          style: AppTheme.heading2,
                        ),
                        Text(
                          'Mã: ${asset.code ?? 'N/A'}',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const Divider(height: 32),

                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Danh sách phiếu bảo trì',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    PrimaryButton(
                      onPressed: () async {
                        await _showAddMaintenanceRecordDialog(asset);
                        final updated = await _maintenanceRepo.getByAssetId(
                          asset.id!,
                        );
                        if (mounted) {
                          setDialogState(() => records = updated);
                          _loadData();
                        }
                      },
                      icon: Icons.add,
                      label: 'Thêm phiếu',
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: records.isEmpty
                      ? const Center(child: Text('Chưa có dữ liệu bảo trì'))
                      : ListView.separated(
                          itemCount: records.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (ctx, idx) {
                            final rec = records[idx];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: Border.all(color: AppTheme.borderColor),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                leading: const CircleAvatar(
                                  backgroundColor: AppTheme.primaryLight,
                                  child: Icon(
                                    Icons.build,
                                    color: AppTheme.primaryColor,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  rec.description,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                subtitle: Text(
                                  'Ngày: ${DateFormat('dd/MM/yyyy').format(rec.date)} • KT: ${rec.technician ?? '-'}',
                                ),
                                trailing: Text(
                                  NumberFormat.currency(
                                    locale: 'vi',
                                    symbol: 'đ',
                                  ).format(rec.cost),
                                  style: const TextStyle(
                                    color: AppTheme.errorColor,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
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
        builder: (context, setInnerState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Thêm phiếu bảo trì', style: AppTheme.heading2),
                const SizedBox(height: 24),

                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setInnerState(() => selectedDate = picked);
                    }
                  },
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Ngày bảo trì',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    child: Text(DateFormat('dd/MM/yyyy').format(selectedDate)),
                  ),
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: descController,
                  label: 'Nội dung thực hiện *',
                  maxLines: 2,
                ),
                const SizedBox(height: 16),
                AppNumberField(
                  controller: costController,
                  label: 'Chi phí',
                  suffixText: 'đ',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: techController,
                  label: 'Đơn vị / Kỹ thuật viên',
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      label: 'Hủy',
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      onPressed: () async {
                        if (descController.text.isEmpty) return;

                        final record = MaintenanceRecord(
                          assetId: asset.id!,
                          date: selectedDate,
                          description: descController.text,
                          cost:
                              double.tryParse(
                                costController.text.replaceAll(',', ''),
                              ) ??
                              0,
                          technician: techController.text,
                        );

                        await _maintenanceRepo.create(record);
                        if (context.mounted) Navigator.pop(context);
                      },
                      label: 'Lưu phiếu',
                      icon: Icons.save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showAddEditDialog([Asset? asset]) async {
    final isEdit = asset != null;
    final nameController = TextEditingController(text: asset?.name ?? '');
    final codeController = TextEditingController(text: asset?.code ?? '');
    final serialController = TextEditingController(
      text: asset?.serialNumber ?? '',
    );
    String category = asset?.category ?? _categories.first;
    final priceController = TextEditingController(
      text: asset?.purchasePrice?.toString() ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEdit ? 'Cập nhật tài sản' : 'Thêm tài sản mới',
                  style: AppTheme.heading2,
                ),
                const SizedBox(height: 24),

                AppTextField(
                  controller: codeController,
                  label: 'Mã tài sản (Optional)',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: nameController,
                  label: 'Tên tài sản *',
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: serialController,
                  label: 'Serial Number',
                ),
                const SizedBox(height: 16),
                AppDropdown<String>(
                  label: 'Loại',
                  value: category,
                  items: _categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => category = v!),
                ),
                const SizedBox(height: 16),
                AppNumberField(
                  controller: priceController,
                  label: 'Giá mua',
                  suffixText: 'đ',
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      label: 'Hủy',
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      onPressed: () async {
                        if (nameController.text.isEmpty) return;

                        final newAsset = Asset(
                          id: asset?.id,
                          code: codeController.text,
                          name: nameController.text,
                          serialNumber: serialController.text,
                          category: category,
                          purchasePrice: double.tryParse(
                            priceController.text.replaceAll(',', ''),
                          ),
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
                      label: 'Lưu',
                      icon: Icons.save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showEditPremisesDialog() async {
    final contractController = TextEditingController(text: _contractNumber);
    final ownerController = TextEditingController(text: _ownerName);
    final phoneController = TextEditingController(text: _ownerPhone);
    final costController = TextEditingController(
      text: _rentalCost.toStringAsFixed(0),
    );
    DateTime tempStart = _startDate;
    DateTime tempEnd = _endDate;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Cập nhật Thông tin Mặt bằng', style: AppTheme.heading2),
                const SizedBox(height: 24),

                AppTextField(
                  controller: contractController,
                  label: 'Số hợp đồng',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: AppTextField(
                        controller: ownerController,
                        label: 'Tên chủ nhà',
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: AppTextField(
                        controller: phoneController,
                        label: 'Số điện thoại',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppNumberField(
                  controller: costController,
                  label: 'Giá thuê (VNĐ/tháng)',
                  suffixText: 'đ',
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempStart,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => tempStart = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày bắt đầu',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          child: Text(
                            DateFormat('dd/MM/yyyy').format(tempStart),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: tempEnd,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() => tempEnd = picked);
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Ngày kết thúc',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.event),
                          ),
                          child: Text(DateFormat('dd/MM/yyyy').format(tempEnd)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SecondaryButton(
                      onPressed: () => Navigator.pop(context),
                      label: 'Hủy',
                    ),
                    const SizedBox(width: 12),
                    PrimaryButton(
                      onPressed: () {
                        setState(() {
                          _contractNumber = contractController.text;
                          _ownerName = ownerController.text;
                          _ownerPhone = phoneController.text;
                          _rentalCost =
                              double.tryParse(
                                costController.text.replaceAll(',', ''),
                              ) ??
                              0;
                          _startDate = tempStart;
                          _endDate = tempEnd;
                        });
                        _savePremisesInfo();
                        Navigator.pop(context);
                      },
                      label: 'Lưu thông tin',
                      icon: Icons.save,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
