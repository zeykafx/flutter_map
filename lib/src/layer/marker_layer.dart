import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map/src/core/bounds.dart';
import 'package:flutter_map/src/map/map.dart';
import 'package:latlong2/latlong.dart';

/// Configuration for marker layer
class MarkerLayerOptions extends LayerOptions {
  final List<Marker> markers;

  /// Toggle marker position caching. Enabling will improve performance, but may introducen
  /// errors when adding/removing markers. Default is enabled (`true`).
  final bool usePxCache;

  /// If true markers will be counter rotated to the map rotation
  final bool? rotate;

  /// The origin of the coordinate system (relative to the upper left corner of
  /// this render object) in which to apply the matrix.
  ///
  /// Setting an origin is equivalent to conjugating the transform matrix by a
  /// translation. This property is provided just for convenience.
  final Offset? rotateOrigin;

  /// The alignment of the origin, relative to the size of the box.
  ///
  /// This is equivalent to setting an origin based on the size of the box.
  /// If it is specified at the same time as the [rotateOrigin], both are applied.
  ///
  /// An [AlignmentDirectional.centerStart] value is the same as an [Alignment]
  /// whose [Alignment.x] value is `-1.0` if [Directionality.of] returns
  /// [TextDirection.ltr], and `1.0` if [Directionality.of] returns
  /// [TextDirection.rtl].	 Similarly [AlignmentDirectional.centerEnd] is the
  /// same as an [Alignment] whose [Alignment.x] value is `1.0` if
  /// [Directionality.of] returns	 [TextDirection.ltr], and `-1.0` if
  /// [Directionality.of] returns [TextDirection.rtl].
  final AlignmentGeometry? rotateAlignment;

  MarkerLayerOptions({
    Key? key,
    this.markers = const [],
    this.rotate = false,
    this.rotateOrigin,
    this.rotateAlignment = Alignment.center,
    this.usePxCache = true,
    Stream<Null>? rebuild,
  }) : super(key: key, rebuild: rebuild);
}

class Anchor {
  final double left;
  final double top;

  Anchor(this.left, this.top);

  Anchor._(double width, double height, AnchorAlign alignOpt)
      : left = _leftOffset(width, alignOpt),
        top = _topOffset(height, alignOpt);

  static double _leftOffset(double width, AnchorAlign alignOpt) {
    switch (alignOpt) {
      case AnchorAlign.left:
        return 0.0;
      case AnchorAlign.right:
        return width;
      case AnchorAlign.top:
      case AnchorAlign.bottom:
      case AnchorAlign.center:
      default:
        return width / 2;
    }
  }

  static double _topOffset(double height, AnchorAlign alignOpt) {
    switch (alignOpt) {
      case AnchorAlign.top:
        return 0.0;
      case AnchorAlign.bottom:
        return height;
      case AnchorAlign.left:
      case AnchorAlign.right:
      case AnchorAlign.center:
      default:
        return height / 2;
    }
  }

  factory Anchor.forPos(AnchorPos? pos, double width, double height) {
    if (pos == null) return Anchor._(width, height, AnchorAlign.none);
    if (pos.value is AnchorAlign) return Anchor._(width, height, pos.value);
    if (pos.value is Anchor) return pos.value;
    throw Exception('Unsupported AnchorPos value type: ${pos.runtimeType}.');
  }
}

class AnchorPos<T> {
  AnchorPos._(this.value);
  T value;
  static AnchorPos exactly(Anchor anchor) => AnchorPos._(anchor);
  static AnchorPos align(AnchorAlign alignOpt) => AnchorPos._(alignOpt);
}

enum AnchorAlign {
  none,
  left,
  right,
  top,
  bottom,
  center,
}

/// Marker object that is rendered by [MarkerLayerWidget]
class Marker {
  /// Coordinates of the marker
  final LatLng point;

  /// Function that builds UI of the marker
  final WidgetBuilder builder;
  final Key? key;

  /// Bounding box width of the marker
  final double width;

  /// Bounding box height of the marker
  final double height;
  final Anchor anchor;

  /// If true marker will be counter rotated to the map rotation
  final bool? rotate;

  /// The origin of the coordinate system (relative to the upper left corner of
  /// this render object) in which to apply the matrix.
  ///
  /// Setting an origin is equivalent to conjugating the transform matrix by a
  /// translation. This property is provided just for convenience.
  final Offset? rotateOrigin;

  /// The alignment of the origin, relative to the size of the box.
  ///
  /// This is equivalent to setting an origin based on the size of the box.
  /// If it is specified at the same time as the [rotateOrigin], both are applied.
  ///
  /// An [AlignmentDirectional.centerStart] value is the same as an [Alignment]
  /// whose [Alignment.x] value is `-1.0` if [Directionality.of] returns
  /// [TextDirection.ltr], and `1.0` if [Directionality.of] returns
  /// [TextDirection.rtl].	 Similarly [AlignmentDirectional.centerEnd] is the
  /// same as an [Alignment] whose [Alignment.x] value is `1.0` if
  /// [Directionality.of] returns	 [TextDirection.ltr], and `-1.0` if
  /// [Directionality.of] returns [TextDirection.rtl].
  final AlignmentGeometry? rotateAlignment;

  Marker({
    required this.point,
    required this.builder,
    this.key,
    this.width = 30.0,
    this.height = 30.0,
    this.rotate,
    this.rotateOrigin,
    this.rotateAlignment,
    AnchorPos? anchorPos,
  }) : anchor = Anchor.forPos(anchorPos, width, height);
}

class MarkerLayerWidget extends StatelessWidget {
  final MarkerLayerOptions options;

  MarkerLayerWidget({Key? key, required this.options}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final mapState = MapState.maybeOf(context)!;
    return MarkerLayer(options, mapState, mapState.onMoved);
  }
}

class MarkerLayer extends StatefulWidget {
  final MarkerLayerOptions markerLayerOptions;
  final MapState map;
  final Stream<Null>? stream;

  MarkerLayer(this.markerLayerOptions, this.map, this.stream)
      : super(key: markerLayerOptions.key);

  @override
  _MarkerLayerState createState() => _MarkerLayerState();
}

class _MarkerLayerState extends State<MarkerLayer> {
  var lastZoom = -1.0;

  /// List containing cached pixel positions of markers
  /// Should be discarded when zoom changes
  // Has a fixed length of markerOpts.markers.length - better performance:
  // https://stackoverflow.com/questions/15943890/is-there-a-performance-benefit-in-using-fixed-length-lists-in-dart
  var _pxCache = <CustomPoint>[];

  /// Calling this every time markerOpts change should guarantee proper length
  List<CustomPoint> generatePxCache() {
    if (widget.markerLayerOptions.usePxCache) {
      return List.generate(
        widget.markerLayerOptions.markers.length,
        (i) => widget.map.project(widget.markerLayerOptions.markers[i].point),
      );
    }
    return [];
  }

  bool updatePxCacheIfNeeded() {
    var didUpdate = false;

    /// markers may be modified, so update cache. Note, someone may
    /// have not added to a cache, but modified, so this won't catch
    /// this case. Parent widget setState should be called to call
    /// didUpdateWidget to force a cache reload

    if (widget.markerLayerOptions.markers.length != _pxCache.length) {
      _pxCache = generatePxCache();
      didUpdate = true;
    }
    return didUpdate;
  }

  @override
  void initState() {
    super.initState();
    _pxCache = generatePxCache();
  }

  @override
  void didUpdateWidget(covariant MarkerLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    lastZoom = -1.0;
    _pxCache = generatePxCache();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int?>(
      stream: widget.stream, // a Stream<int> or null
      builder: (BuildContext context, AsyncSnapshot<int?> snapshot) {
        var layerOptions = widget.markerLayerOptions;
        var map = widget.map;
        var usePxCache = layerOptions.usePxCache;
        var markers = <Widget>[];
        final sameZoom = map.zoom == lastZoom;

        var cacheUpdated = updatePxCacheIfNeeded();

        for (var i = 0; i < layerOptions.markers.length; i++) {
          var marker = layerOptions.markers[i];

          // Decide whether to use cached point or calculate it
          var pxPoint = usePxCache && (sameZoom || cacheUpdated)
              ? _pxCache[i]
              : map.project(marker.point);
          if (!sameZoom && usePxCache) {
            _pxCache[i] = pxPoint;
          }

          final width = marker.width - marker.anchor.left;
          final height = marker.height - marker.anchor.top;
          var sw = CustomPoint(pxPoint.x + width, pxPoint.y - height);
          var ne = CustomPoint(pxPoint.x - width, pxPoint.y + height);

          if (!map.pixelBounds.containsPartialBounds(Bounds(sw, ne))) {
            continue;
          }

          final pos = pxPoint - map.getPixelOrigin();
          final markerWidget = (marker.rotate ?? layerOptions.rotate ?? false)
              // Counter rotated marker to the map rotation
              ? Transform.rotate(
                  angle: -map.rotationRad,
                  origin: marker.rotateOrigin ?? layerOptions.rotateOrigin,
                  alignment:
                      marker.rotateAlignment ?? layerOptions.rotateAlignment,
                  child: marker.builder(context),
                )
              : marker.builder(context);

          markers.add(
            Positioned(
              key: marker.key,
              width: marker.width,
              height: marker.height,
              left: pos.x - width,
              top: pos.y - height,
              child: markerWidget,
            ),
          );
        }
        lastZoom = map.zoom;
        return Container(
          child: Stack(
            children: markers,
          ),
        );
      },
    );
  }
}
