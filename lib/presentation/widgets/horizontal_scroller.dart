import 'package:flutter/gestures.dart';
import 'package:material_ui/material_ui.dart';

/// A horizontal list that also works with a desktop mouse: it can be dragged,
/// the vertical wheel scrolls it sideways, and a scrollbar shows there is
/// more. (Flutter only drags lists by touch, and wheels scroll vertically.)
class HorizontalScroller extends StatefulWidget {
  const HorizontalScroller({
    super.key,
    required this.height,
    required this.itemCount,
    required this.itemBuilder,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
    this.spacing = 8,
    this.showScrollbar = true,
    this.wheelScrollsSideways = false,
    this.scrollbarAlwaysVisible = false,
  });

  final double height;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsets padding;
  final double spacing;
  final bool showScrollbar;

  /// Whether the vertical mouse wheel scrolls this row. Leave it off for rows
  /// inside a vertical page, or the wheel would get stuck on every row;
  /// horizontal trackpad swipes always work.
  final bool wheelScrollsSideways;

  /// Keep the scrollbar on screen (desktop hides it until hovered), so a
  /// cut-off row clearly has more to show.
  final bool scrollbarAlwaysVisible;

  @override
  State<HorizontalScroller> createState() => _HorizontalScrollerState();
}

class _HorizontalScrollerState extends State<HorizontalScroller> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final position = _scroll.position;
    // Leave the wheel to the page when this row has nothing to scroll.
    if (position.maxScrollExtent <= 0) return;
    final delta = event.scrollDelta.dx != 0
        ? event.scrollDelta.dx
        : widget.wheelScrollsSideways
            ? event.scrollDelta.dy
            : 0.0;
    if (delta == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      _scroll.jumpTo((position.pixels + delta)
          .clamp(position.minScrollExtent, position.maxScrollExtent));
    });
  }

  @override
  Widget build(BuildContext context) {
    final list = ListView.separated(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      padding: widget.padding,
      itemCount: widget.itemCount,
      separatorBuilder: (_, _) => SizedBox(width: widget.spacing),
      itemBuilder: widget.itemBuilder,
    );
    return Listener(
      onPointerSignal: _onPointerSignal,
      child: ScrollConfiguration(
        behavior: ScrollConfiguration.of(context).copyWith(
          dragDevices: PointerDeviceKind.values.toSet(),
        ),
        child: SizedBox(
          height: widget.height,
          child: widget.showScrollbar
              ? Scrollbar(
                  controller: _scroll,
                  thumbVisibility: widget.scrollbarAlwaysVisible,
                  child: list,
                )
              : list,
        ),
      ),
    );
  }
}
