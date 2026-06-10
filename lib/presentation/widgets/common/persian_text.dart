import 'package:flutter/material.dart';

/// ویجت متن فارسی با RTL اجباری و فونت Vazirmatn
class PersianText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  const PersianText(
    this.text, {
    super.key,
    this.style,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Text(
        text,
        style: (style ?? const TextStyle()).copyWith(
          fontFamily: style?.fontFamily ?? 'Vazirmatn',
        ),
        textAlign: textAlign ?? TextAlign.right,
        maxLines: maxLines,
        overflow: overflow,
        textDirection: TextDirection.rtl,
      ),
    );
  }
}
