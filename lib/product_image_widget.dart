import 'dart:convert';
import 'package:flutter/material.dart';

class ProductImageWidget extends StatelessWidget {
  final String? imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final Widget? fallback;

  const ProductImageWidget({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallback,
  });

  @override
  Widget build(BuildContext context) {
    final url = (imageUrl ?? '').trim();

    Widget imageContent;

    if (url.startsWith('data:image')) {
      try {
        final commaIndex = url.indexOf(',');
        final base64Str = commaIndex != -1 ? url.substring(commaIndex + 1) : url;
        final bytes = base64Decode(base64Str);
        imageContent = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          errorBuilder: (ctx, err, stack) => fallback ?? _defaultFallback(),
        );
      } catch (_) {
        imageContent = fallback ?? _defaultFallback();
      }
    } else if (url.startsWith('http://') || url.startsWith('https://')) {
      imageContent = Image.network(
        url,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (ctx, err, stack) => fallback ?? _defaultFallback(),
      );
    } else {
      imageContent = fallback ?? _defaultFallback();
    }

    if (borderRadius != null) {
      return ClipRRect(
        borderRadius: borderRadius!,
        child: imageContent,
      );
    }

    return imageContent;
  }

  Widget _defaultFallback() {
    return Container(
      width: width,
      height: height,
      color: const Color(0xFFEFF6FF),
      alignment: Alignment.center,
      child: const Icon(Icons.format_paint_rounded, size: 20, color: Color(0xFF1E40AF)),
    );
  }
}
