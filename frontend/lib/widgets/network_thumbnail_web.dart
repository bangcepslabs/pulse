import 'dart:async';
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:web/web.dart' as web;

int _networkThumbnailCounter = 0;

Widget buildNetworkThumbnail({
  required String imageUrl,
  required BoxFit fit,
  required Widget loadingWidget,
  required Widget errorWidget,
  required VoidCallback onError,
}) {
  return _WebNetworkThumbnail(
    imageUrl: imageUrl,
    fit: fit,
    loadingWidget: loadingWidget,
    errorWidget: errorWidget,
    onError: onError,
  );
}

class _WebNetworkThumbnail extends StatefulWidget {
  final String imageUrl;
  final BoxFit fit;
  final Widget loadingWidget;
  final Widget errorWidget;
  final VoidCallback onError;

  const _WebNetworkThumbnail({
    required this.imageUrl,
    required this.fit,
    required this.loadingWidget,
    required this.errorWidget,
    required this.onError,
  });

  @override
  State<_WebNetworkThumbnail> createState() => _WebNetworkThumbnailState();
}

class _WebNetworkThumbnailState extends State<_WebNetworkThumbnail> {
  late final String _viewType;
  late final web.HTMLImageElement _imageElement;
  StreamSubscription? _loadSub;
  StreamSubscription? _errorSub;
  bool _loaded = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'network-thumbnail-${_networkThumbnailCounter++}';
    _imageElement = web.HTMLImageElement()
      ..src = widget.imageUrl
      ..alt = 'thumbnail'
      ..draggable = false
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.display = 'block'
      ..style.border = '0'
      ..style.objectFit = _objectFitValue(widget.fit);

    _loadSub = _imageElement.onLoad.listen((_) {
      if (mounted) {
        setState(() {
          _loaded = true;
          _failed = false;
        });
      }
    });

    _errorSub = _imageElement.onError.listen((_) {
      widget.onError();
      if (mounted) {
        setState(() {
          _failed = true;
        });
      }
    });

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int _) => _imageElement,
    );
  }

  @override
  void dispose() {
    _loadSub?.cancel();
    _errorSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.errorWidget;
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        HtmlElementView(viewType: _viewType),
        if (!_loaded) widget.loadingWidget,
      ],
    );
  }

  String _objectFitValue(BoxFit fit) {
    switch (fit) {
      case BoxFit.contain:
        return 'contain';
      case BoxFit.fill:
        return 'fill';
      case BoxFit.fitHeight:
        return 'scale-down';
      case BoxFit.fitWidth:
        return 'scale-down';
      case BoxFit.none:
        return 'none';
      case BoxFit.scaleDown:
        return 'scale-down';
      case BoxFit.cover:
      default:
        return 'cover';
    }
  }
}
