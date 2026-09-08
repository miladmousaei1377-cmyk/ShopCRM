import 'dart:io';
import 'package:flutter/material.dart';
import '../../../services/product_image_service.dart';

class ManagedProductImage extends StatelessWidget {
  final String? relativePath;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const ManagedProductImage({
    super.key,
    required this.relativePath,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final image = FutureBuilder<File?>(
      future: ProductImageService.resolve(relativePath),
      builder: (context, snapshot) {
        final file = snapshot.data;
        if (file == null) return _placeholder(context);
        return Image.file(
          file,
          width: width,
          height: height,
          fit: fit,
          cacheWidth:
              width == null || width!.isInfinite ? null : (width! * 2).round(),
          errorBuilder: (_, __, ___) => _placeholder(context),
        );
      },
    );
    return ClipRRect(
      borderRadius: borderRadius ?? BorderRadius.zero,
      child: SizedBox(width: width, height: height, child: image),
    );
  }

  Widget _placeholder(BuildContext context) => ColoredBox(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
          child: Icon(
            Icons.image_not_supported_outlined,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
}
