import 'package:flutter/material.dart';

import 'network_thumbnail_stub.dart'
    if (dart.library.html) 'network_thumbnail_web.dart' as impl;

class NetworkThumbnail extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget loadingWidget;
  final Widget errorWidget;
  final double? aspectRatio;
  final BorderRadius? borderRadius;
  final bool collapseOnError;

  const NetworkThumbnail({
    super.key,
    required this.imageUrl,
    required this.loadingWidget,
    required this.errorWidget,
    this.fit = BoxFit.cover,
    this.aspectRatio,
    this.borderRadius,
    this.collapseOnError = false,
  });

  @override
  State<NetworkThumbnail> createState() => _NetworkThumbnailState();
}

class _NetworkThumbnailState extends State<NetworkThumbnail> {
  bool _failed = false;

  @override
  Widget build(BuildContext context) {
    if (_failed && widget.collapseOnError) {
      return const SizedBox.shrink();
    }

    Widget child = impl.buildNetworkThumbnail(
      imageUrl: widget.imageUrl,
      fit: widget.fit,
      loadingWidget: widget.loadingWidget,
      errorWidget: widget.errorWidget,
      onError: () {
        if (!mounted || _failed) return;
        setState(() {
          _failed = true;
        });
      },
    );

    if (widget.aspectRatio != null) {
      child = AspectRatio(aspectRatio: widget.aspectRatio!, child: child);
    }

    if (widget.borderRadius != null) {
      child = ClipRRect(borderRadius: widget.borderRadius!, child: child);
    }

    return child;
  }
}
