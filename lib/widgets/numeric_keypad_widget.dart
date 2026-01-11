import 'package:flutter/material.dart';

/// Bàn phím số trên màn hình cho POS touchscreen - tối ưu hiệu năng
class NumericKeypadWidget extends StatefulWidget {
  final String value;
  final ValueChanged<String> onValueChanged;
  final VoidCallback? onEnter;
  final String hintText;
  final int maxLength;

  const NumericKeypadWidget({
    super.key,
    required this.value,
    required this.onValueChanged,
    this.onEnter,
    this.hintText = 'Nhập mã số...',
    this.maxLength = 10,
  });

  @override
  State<NumericKeypadWidget> createState() => _NumericKeypadWidgetState();
}

class _NumericKeypadWidgetState extends State<NumericKeypadWidget> {
  late String _internalValue;

  @override
  void initState() {
    super.initState();
    _internalValue = widget.value;
  }

  @override
  void didUpdateWidget(NumericKeypadWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _internalValue = widget.value;
    }
  }

  void _onKeyPressed(String key) {
    if (_internalValue.length < widget.maxLength) {
      setState(() {
        _internalValue = _internalValue + key;
      });
      widget.onValueChanged(_internalValue);
    }
  }

  void _onDelete() {
    if (_internalValue.isNotEmpty) {
      setState(() {
        _internalValue = _internalValue.substring(0, _internalValue.length - 1);
      });
      widget.onValueChanged(_internalValue);
    }
  }

  void _onClear() {
    setState(() {
      _internalValue = '';
    });
    widget.onValueChanged(_internalValue);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Display
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!, width: 2),
          ),
          child: Text(
            _internalValue.isEmpty ? widget.hintText : _internalValue,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: 6,
              color: _internalValue.isEmpty
                  ? Colors.grey[400]
                  : Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
        ),

        // Keypad - compact
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(20),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1-3: Numbers
              for (int row = 0; row < 3; row++) ...[
                Row(
                  children: [
                    for (int col = 1; col <= 3; col++) ...[
                      if (col > 1) const SizedBox(width: 6),
                      _NumKey(
                        label: '${row * 3 + col}',
                        onTap: () => _onKeyPressed('${row * 3 + col}'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
              ],
              // Row 4: C, 0, ⌫
              Row(
                children: [
                  _ActionKey(
                    label: 'C',
                    color: Colors.orange[600]!,
                    onTap: _onClear,
                  ),
                  const SizedBox(width: 6),
                  _NumKey(label: '0', onTap: () => _onKeyPressed('0')),
                  const SizedBox(width: 6),
                  _ActionKey(
                    label: '⌫',
                    color: Colors.red[400]!,
                    onTap: _onDelete,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Enter button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _internalValue.isNotEmpty ? widget.onEnter : null,
                  icon: const Icon(Icons.search, size: 24),
                  label: const Text(
                    'TÌM KIẾM',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1565C0),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Nút số - tối ưu không rebuild
class _NumKey extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _NumKey({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 56,
        child: Material(
          color: Colors.grey[50],
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1565C0),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Nút hành động (C, ⌫)
class _ActionKey extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionKey({
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: SizedBox(
        height: 56,
        child: Material(
          color: color.withAlpha(30),
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: onTap,
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
