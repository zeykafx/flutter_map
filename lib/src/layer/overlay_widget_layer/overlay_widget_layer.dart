import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

part 'overlay_widget.dart';

/// [OverlayWidgetLayer] is used to display one or multiple widgets on the map.
///
/// Note that the [OverlayWidgetLayer] needs to be placed after every non
/// translucent layer in the [FlutterMap.children] list to be actually visible!
@immutable
class OverlayWidgetLayer extends StatelessWidget {
  /// The widgets that the map should get overlayed with.
  final List<BaseOverlayWidget> overlayWidgets;

  /// Create a new [OverlayWidgetLayer].
  const OverlayWidgetLayer({super.key, required this.overlayWidgets});

  @override
  Widget build(BuildContext context) => MobileLayerTransformer(
        child: ClipRect(child: Stack(children: overlayWidgets)),
      );
}
