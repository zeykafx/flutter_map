import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/map/map.dart';

class OverlayWidgetLayerOptions extends LayerOptions {
  final List<OverlayWidget> overlayWidget;

  OverlayWidgetLayerOptions({
    Key? key,
    this.overlayWidget = const [],
    Stream<void>? rebuild,
  }) : super(key: key, rebuild: rebuild);
}

class OverlayWidget {
  final LatLngBounds bounds;
  final Widget child;
  final double opacity;

  OverlayWidget({
    required this.bounds,
    required this.child,
    this.opacity = 1.0,
  });
}

class OverlayWidgetLayerWidget extends StatelessWidget {
  final OverlayWidgetLayerOptions options;

  OverlayWidgetLayerWidget({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mapState = MapState.maybeOf(context)!;
    return OverlayWidgetLayer(options, mapState, mapState.onMoved);
  }
}

class OverlayWidgetLayer extends StatelessWidget {
  final OverlayWidgetLayerOptions overlayWidgetOpts;
  final MapState map;
  final Stream<void>? stream;

  OverlayWidgetLayer(this.overlayWidgetOpts, this.map, this.stream)
      : super(key: overlayWidgetOpts.key);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<void>(
      stream: stream,
      builder: (BuildContext context, _) {
        return ClipRect(
          child: Stack(
            children: <Widget>[
              for (var overlayWidget in overlayWidgetOpts.overlayWidget)
                _positionedForOverlay(overlayWidget),
            ],
          ),
        );
      },
    );
  }

  Positioned _positionedForOverlay(OverlayWidget overlayWidget) {
    final zoomScale =
        map.getZoomScale(map.zoom, map.zoom); // TODO replace with 1?
    final pixelOrigin = map.getPixelOrigin();
    final upperLeftPixel =
        map.project(overlayWidget.bounds.northWest).multiplyBy(zoomScale) -
            pixelOrigin;
    final bottomRightPixel =
        map.project(overlayWidget.bounds.southEast).multiplyBy(zoomScale) -
            pixelOrigin;
    return Positioned(
      left: upperLeftPixel.x.toDouble(),
      top: upperLeftPixel.y.toDouble(),
      width: (bottomRightPixel.x - upperLeftPixel.x).toDouble(),
      height: (bottomRightPixel.y - upperLeftPixel.y).toDouble(),
      child: overlayWidget.child
    );
  }
}
