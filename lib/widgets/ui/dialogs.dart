import 'package:flutter/material.dart';
import '../../config/theme.dart';
import 'buttons.dart';

Future<bool?> showAppConfirmDialog(
  BuildContext context, {
  required String title,
  required String content,
  String confirmText = 'Xác nhận',
  String cancelText = 'Hủy',
  Color? confirmColor,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTheme.heading3),
      content: Text(content, style: AppTheme.bodyMedium),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        SecondaryButton(
          onPressed: () => Navigator.of(context).pop(false),
          label: cancelText,
        ),
        const SizedBox(width: 12),
        if (confirmColor == AppTheme.errorColor)
          DangerButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: confirmText,
          )
        else
          PrimaryButton(
            onPressed: () => Navigator.of(context).pop(true),
            label: confirmText,
          ),
      ],
    ),
  );
}

Future<void> showAppAlertDialog(
  BuildContext context, {
  required String title,
  required String content,
  String buttonText = 'Đóng',
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: AppTheme.heading3),
      content: Text(content, style: AppTheme.bodyMedium),
      actionsPadding: const EdgeInsets.all(24),
      actions: [
        PrimaryButton(
          onPressed: () => Navigator.of(context).pop(),
          label: buttonText,
        ),
      ],
    ),
  );
}
