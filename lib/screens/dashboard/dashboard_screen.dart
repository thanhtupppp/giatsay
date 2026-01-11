import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../core/services/auth_service.dart';
import '../../models/order.dart';
import '../../repositories/order_repository.dart';
import '../../repositories/customer_repository.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../utils/test_data_seeder.dart';
import '../../widgets/layouts/desktop_layout.dart';
import '../../widgets/ui/cards.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final _orderRepo = OrderRepository();
  final _customerRepo = CustomerRepository();

  Map<String, int> _orderStatusCounts = {};
  double _todayRevenue = 0;
  double _monthRevenue = 0;
  int _totalCustomers = 0;
  bool _isLoading = true;

  // Chart Data
  List<double> _weeklyRevenue = [0, 0, 0, 0, 0, 0, 0];

  // Quick Stats & Recent Activity Data
  List<Order> _recentOrders = [];
  double _onTimePercentage = 0;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    await TestDataSeeder.seedTestData();
    await _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final statusCounts = await _orderRepo.getOrderStatusCounts();
      final today = DateTime.now();
      final startOfMonth = DateTime(today.year, today.month, 1);

      final todayRevenue = await _orderRepo.getTotalRevenue(
        startDate: today,
        endDate: today,
      );

      final monthRevenue = await _orderRepo.getTotalRevenue(
        startDate: startOfMonth,
        endDate: today,
      );

      final customerCount = await _customerRepo.getCount();

      // Fetch Recent Orders
      final recentOrders = await _orderRepo.getAll(limit: 5);

      // Calculate On Time Percentage (Mock logic for now as we lack delivery history)
      // Real logic: count(delivered_on_time) / count(delivered) * 100
      final completedOrders =
          statusCounts[AppConstants.orderStatusDelivered] ?? 0;
      double onTimeRate = 0;
      if (completedOrders > 0) {
        onTimeRate = 85.0;
      }

      final weeklyData = List.generate(7, (index) => (dayRevenueMock(index)));

      setState(() {
        _orderStatusCounts = statusCounts;
        _todayRevenue = todayRevenue;
        _monthRevenue = monthRevenue;
        _totalCustomers = customerCount;
        _weeklyRevenue = weeklyData;
        _recentOrders = recentOrders;
        _onTimePercentage = onTimeRate;
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi tải dữ liệu: $e'),
            backgroundColor: AppTheme.errorColor,
          ),
        );
      }
    }
  }

  // Mock function for chart
  double dayRevenueMock(int dayIndex) {
    return (100000.0 * (dayIndex + 1)) + (dayIndex % 2 == 0 ? 50000 : 0);
  }

  @override
  Widget build(BuildContext context) {
    // final user = AuthService.instance.currentUser; // Accessed in DesktopLayout Header

    return DesktopLayout(
      title: 'Dashboard',
      isLoading: _isLoading,
      child: RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildGreeting(),
              const SizedBox(height: 24),

              LayoutBuilder(
                builder: (context, constraints) {
                  // If width > 1300, use 2 columns (Main + Sidebar)
                  // But DesktopLayout max width is 1400.
                  // Let's stick to the responsive logic
                  if (constraints.maxWidth > 1000) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column (Main Stats + Charts)
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              _buildStatisticsCards(),
                              const SizedBox(height: 24),
                              _buildRevenueChart(),
                              const SizedBox(height: 24),
                              _buildOrderStatusChart(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right Column (Quick Stats + Recent)
                        Expanded(
                          flex: 1,
                          child: Column(
                            children: [
                              _buildQuickStats(),
                              const SizedBox(height: 24),
                              _buildRecentActivity(),
                            ],
                          ),
                        ),
                      ],
                    );
                  } else {
                    // Mobile/Tablet: Vertical Stacking
                    return Column(
                      children: [
                        _buildStatisticsCards(),
                        const SizedBox(height: 24),
                        _buildQuickStats(),
                        const SizedBox(height: 24),
                        _buildRevenueChart(),
                        const SizedBox(height: 24),
                        _buildOrderStatusChart(),
                        const SizedBox(height: 24),
                        _buildRecentActivity(),
                      ],
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildGreeting() {
    final user = AuthService.instance.currentUser;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Xin chào, ${user?.fullName ?? 'User'}!',
          style: AppTheme.heading1.copyWith(fontSize: 28),
        ),
        const SizedBox(height: 4),
        Text(
          'Hôm nay là ${DateFormat('EEEE, dd/MM/yyyy', 'vi').format(DateTime.now())}',
          style: AppTheme.bodyMedium.copyWith(color: AppTheme.textSecondary),
        ),
      ],
    );
  }

  Widget _buildStatisticsCards() {
    // Using GridView for better responsiveness
    return LayoutBuilder(
      builder: (context, constraints) {
        int crossAxisCount = constraints.maxWidth > 800 ? 4 : 2;
        return GridView.count(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          shrinkWrap: true,
          childAspectRatio: 1.2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            StatCard(
              title: 'Hôm nay',
              value: NumberFormat.compactCurrency(
                locale: 'vi',
                symbol: 'đ',
              ).format(_todayRevenue),
              icon: Icons.attach_money,
              color: const Color(0xFF43A047),
            ),
            StatCard(
              title: 'Tháng này',
              value: NumberFormat.compactCurrency(
                locale: 'vi',
                symbol: 'đ',
              ).format(_monthRevenue),
              icon: Icons.calendar_month,
              color: const Color(0xFF1976D2),
            ),
            StatCard(
              title: 'Khách hàng',
              value: _totalCustomers.toString(),
              icon: Icons.people,
              color: const Color(0xFFEF6C00),
            ),
            StatCard(
              title: 'Chờ xử lý',
              value: (_orderStatusCounts[AppConstants.orderStatusReceived] ?? 0)
                  .toString(),
              icon: Icons.pending_actions,
              color: const Color(0xFF7B1FA2),
            ),
          ],
        );
      },
    );
  }

  Widget _buildQuickStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Tổng quan'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 16,
          crossAxisSpacing: 16,
          childAspectRatio: 1.1,
          children: [
            _buildQuickStatItem(
              icon: Icons.local_laundry_service,
              count: _orderStatusCounts[AppConstants.orderStatusWashing] ?? 0,
              label: 'Đang giặt',
              color: Colors.orange,
              bgColor: Colors.orange.withValues(alpha: 0.1),
            ),
            _buildQuickStatItem(
              icon: Icons.shopping_bag,
              count: _orderStatusCounts[AppConstants.orderStatusWashed] ?? 0,
              label: 'Sẵn sàng',
              color: Colors.teal,
              bgColor: Colors.teal.withValues(alpha: 0.1),
            ),
            _buildQuickStatItem(
              icon: Icons.check_circle,
              count: _onTimePercentage.toInt(),
              label: 'Đúng hạn',
              color: Colors.green,
              bgColor: Colors.green.withValues(alpha: 0.1),
              isPercentage: true,
            ),
            _buildQuickStatItem(
              icon: Icons.local_shipping,
              count: _orderStatusCounts[AppConstants.orderStatusDelivered] ?? 0,
              label: 'Đã giao',
              color: Colors.blue,
              bgColor: Colors.blue.withValues(alpha: 0.1),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickStatItem({
    required IconData icon,
    required num count, // int or double
    required String label,
    required Color color,
    required Color bgColor,
    bool isPercentage = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 12),
          Text(
            isPercentage ? '$count%' : count.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: color.withValues(alpha: 0.8),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentActivity() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: 'Gần đây'),
        AppCard(
          padding: EdgeInsets.zero,
          child: _recentOrders.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Chưa có hoạt động nào')),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _recentOrders.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final order = _recentOrders[index];
                    bool isNew =
                        order.createdAt
                            .difference(order.updatedAt)
                            .abs()
                            .inMinutes <
                        1;

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: isNew
                              ? Colors.blue.withValues(alpha: 0.1)
                              : Colors.green.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isNew ? Icons.add_shopping_cart : Icons.update,
                          color: isNew ? Colors.blue : Colors.green,
                          size: 20,
                        ),
                      ),
                      title: Text.rich(
                        TextSpan(
                          text: isNew ? 'Tạo mới đơn ' : 'Cập nhật đơn ',
                          children: [
                            TextSpan(
                              text: '#${order.orderCode}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 14),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Row(
                          children: [
                            Text(
                              _getTimeAgo(order.updatedAt),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 4,
                              height: 4,
                              decoration: const BoxDecoration(
                                color: AppTheme.textSecondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              AppConstants.orderStatusLabels[order.status] ??
                                  order.status,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppTheme.getStatusColor(order.status),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final diff = DateTime.now().difference(dateTime);
    if (diff.inMinutes < 60) return '${diff.inMinutes} phút trước';
    if (diff.inHours < 24) return '${diff.inHours} giờ trước';
    return '${diff.inDays} ngày trước';
  }

  Widget _buildRevenueChart() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Doanh thu 7 ngày', icon: Icons.bar_chart),
          SizedBox(
            height: 300,
            child: BarChart(
              BarChartData(
                alignment: BarChartAlignment.spaceAround,
                maxY:
                    _weeklyRevenue.reduce(
                      (curr, next) => curr > next ? curr : next,
                    ) *
                    1.2,
                barTouchData: BarTouchData(
                  touchTooltipData: BarTouchTooltipData(
                    tooltipBgColor: AppTheme.primaryDark,
                    getTooltipItem: (group, groupIndex, rod, rodIndex) {
                      return BarTooltipItem(
                        NumberFormat.compact(locale: 'vi').format(rod.toY),
                        const TextStyle(color: Colors.white),
                      );
                    },
                  ),
                ),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, meta) {
                        const days = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];
                        if (value.toInt() < days.length) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              days[value.toInt()],
                              style: AppTheme.bodySmall,
                            ),
                          );
                        }
                        return const Text('');
                      },
                    ),
                  ),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 40,
                      getTitlesWidget: (value, meta) {
                        return Text(
                          NumberFormat.compact(locale: 'vi').format(value),
                          style: AppTheme.caption.copyWith(fontSize: 10),
                        );
                      },
                    ),
                  ),
                  topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                  rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false),
                  ),
                ),
                gridData: const FlGridData(show: false),
                borderData: FlBorderData(show: false),
                barGroups: _weeklyRevenue.asMap().entries.map((e) {
                  return BarChartGroupData(
                    x: e.key,
                    barRods: [
                      BarChartRodData(
                        toY: e.value,
                        color: AppTheme.primaryColor,
                        width: 20,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6),
                        ),
                        backDrawRodData: BackgroundBarChartRodData(
                          show: true,
                          toY:
                              _weeklyRevenue.reduce(
                                (curr, next) => curr > next ? curr : next,
                              ) *
                              1.2,
                          color: AppTheme.backgroundColor,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatusChart() {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(
            title: 'Trạng thái đơn hàng',
            icon: Icons.pie_chart,
          ),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: SizedBox(
                  height: 250,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 40,
                      sections: AppConstants.orderStatuses.map((status) {
                        final count = _orderStatusCounts[status] ?? 0;
                        final color = AppTheme.getStatusColor(status);
                        final total = _orderStatusCounts.values.fold(
                          0,
                          (sum, item) => sum + item,
                        );
                        final percentage = total == 0
                            ? 0.0
                            : (count / total * 100);

                        return PieChartSectionData(
                          color: color,
                          value: count.toDouble(),
                          title: '${percentage.toStringAsFixed(0)}%',
                          radius: 50,
                          titleStyle: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 2,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: AppConstants.orderStatuses.map((status) {
                    final color = AppTheme.getStatusColor(status);
                    final label =
                        AppConstants.orderStatusLabels[status] ?? status;
                    final count = _orderStatusCounts[status] ?? 0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(label, style: AppTheme.bodyMedium),
                          ),
                          Text(
                            count.toString(),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
