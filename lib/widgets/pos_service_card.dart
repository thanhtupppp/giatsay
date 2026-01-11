import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/service.dart';
import '../config/theme.dart';

/// Card dịch vụ cho POS - thiết kế touch-friendly
class POSServiceCard extends StatelessWidget {
  final Service service;
  final int quantity;
  final VoidCallback onTap;
  final VoidCallback onIncrement;
  final VoidCallback onDecrement;

  const POSServiceCard({
    super.key,
    required this.service,
    required this.quantity,
    required this.onTap,
    required this.onIncrement,
    required this.onDecrement,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = quantity > 0;
    final currencyFormat = NumberFormat.currency(locale: 'vi', symbol: 'đ');

    // Icon theo loại dịch vụ
    IconData serviceIcon = Icons.local_laundry_service;
    if (service.name.toLowerCase().contains('ủi')) {
      serviceIcon = Icons.iron;
    } else if (service.name.toLowerCase().contains('khô')) {
      serviceIcon = Icons.dry_cleaning;
    } else if (service.name.toLowerCase().contains('chăn') ||
        service.name.toLowerCase().contains('màn')) {
      serviceIcon = Icons.bed;
    } else if (service.name.toLowerCase().contains('hấp')) {
      serviceIcon = Icons.dry;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.primaryColor,
                  AppTheme.primaryColor.withValues(alpha: 0.8),
                ],
              )
            : null,
        color: isSelected ? null : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.08),
            blurRadius: isSelected ? 16 : 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(
          color: isSelected ? Colors.transparent : Colors.grey[200]!,
          width: 2,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Icon
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.2)
                        : AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    serviceIcon,
                    size: 32,
                    color: isSelected ? Colors.white : AppTheme.primaryColor,
                  ),
                ),

                const SizedBox(height: 12),

                // Service name
                Text(
                  service.name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: isSelected ? Colors.white : AppTheme.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                const SizedBox(height: 6),

                // Price
                Text(
                  currencyFormat.format(service.price),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.9)
                        : AppTheme.primaryColor,
                  ),
                ),

                // Quantity controls
                if (isSelected) ...[
                  const SizedBox(height: 12),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Minus button
                        _QuantityButton(
                          icon: Icons.remove,
                          onTap: onDecrement,
                          color: AppTheme.errorColor,
                        ),
                        // Quantity
                        Container(
                          constraints: const BoxConstraints(minWidth: 48),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '$quantity',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: AppTheme.primaryColor,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                        // Plus button
                        _QuantityButton(
                          icon: Icons.add,
                          onTap: onIncrement,
                          color: AppTheme.successColor,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuantityButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  const _QuantityButton({
    required this.icon,
    required this.onTap,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(icon, color: color, size: 24),
        ),
      ),
    );
  }
}
