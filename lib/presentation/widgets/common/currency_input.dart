import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/utils/currency_formatter.dart';

/// فیلد ورودی قیمت با فرمت خودکار (جداکننده هزار)
class CurrencyInput extends StatefulWidget {
  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final bool showToman;
  final ValueChanged<double>? onChanged;
  final String? Function(String?)? validator;
  final bool enabled;

  const CurrencyInput({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.showToman = true,
    this.onChanged,
    this.validator,
    this.enabled = true,
  });

  @override
  State<CurrencyInput> createState() => _CurrencyInputState();
}

class _CurrencyInputState extends State<CurrencyInput> {
  late TextEditingController _controller;
  bool _isFormatting = false;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? TextEditingController();
    _controller.addListener(_formatInput);
  }

  void _formatInput() {
    if (_isFormatting) return;
    final text = _controller.text;
    if (text.isEmpty) {
      widget.onChanged?.call(0);
      return;
    }
    final rawText = CurrencyFormatter.toEnglishNumber(text).replaceAll(',', '');
    final value = double.tryParse(rawText);
    if (value != null) {
      widget.onChanged?.call(value);
      _isFormatting = true;
      final formatted = CurrencyFormatter.formatNumber(value);
      _controller.value = TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
      _isFormatting = false;
    }
  }

  @override
  void dispose() {
    if (widget.controller == null) _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      enabled: widget.enabled,
      textAlign: TextAlign.right,
      keyboardType: const TextInputType.numberWithOptions(decimal: false),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'[0-9۰-۹,]')),
      ],
      decoration: InputDecoration(
        labelText: widget.label,
        hintText: widget.hint ?? '۰',
        suffixText: widget.showToman ? 'تومان' : null,
        suffixStyle: const TextStyle(
          fontFamily: 'Vazirmatn',
          fontSize: 13,
          color: Colors.grey,
        ),
      ),
      validator: widget.validator,
    );
  }
}
