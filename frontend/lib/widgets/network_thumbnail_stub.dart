import 'package:flutter/material.dart';

Widget buildNetworkThumbnail({
  required String imageUrl,
  required BoxFit fit,
  required Widget loadingWidget,
  required Widget errorWidget,
  required VoidCallback onError,
}) {
  return Image.network(
    imageUrl,
    fit: fit,
    errorBuilder: (_, __, ___) {
      onError();
      return errorWidget;
    },
    loadingBuilder: (context, child, progress) {
      if (progress == null) return child;
      return loadingWidget;
    },
  );
}
