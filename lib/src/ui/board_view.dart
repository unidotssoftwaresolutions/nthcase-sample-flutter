import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A square board of equal cells that scrolls both ways: Flutter's own two-axis scroller, [TwoDimensionalScrollView],
/// with the smallest viewport that lays out a grid. The framework ships the scroll view and its viewport as abstract
/// classes and no grid of its own (`TableView` is in a separate package), so this file gives the one layout the Lobby
/// needs: [count] × [count] cells of [cell] logical pixels, built only when they come near the window.
///
/// A drag moves one axis at a time (`DiagonalDragBehavior.none`): a vertical `Scrollable` with a vertical drag
/// recognizer holds a horizontal one with a horizontal recognizer. The other behaviours (`free`, `weighted…`) replace
/// both with one pan recognizer, which needs twice the touch slop (36 logical pixels) before it accepts; inside the
/// Lobby's page, the page's own vertical drag accepts at 18, so every vertical or diagonal drag on the board would
/// scroll the page instead. The Lobby's tests show both.
///
/// In the semantics tree the scroll view is two scrollers, one inside the other, each with its own node and its own
/// scroll actions: the vertical one outside, the horizontal one inside. The README says so.
class BoardView extends TwoDimensionalScrollView {
  const BoardView({
    super.key,
    required this.count,
    required this.cell,
    required super.delegate,
    super.verticalDetails,
    super.horizontalDetails,
    super.diagonalDragBehavior,
  }) : super(dragStartBehavior: DragStartBehavior.start);

  final int count;
  final double cell;

  @override
  Widget buildViewport(BuildContext context, ViewportOffset verticalOffset, ViewportOffset horizontalOffset) =>
      _BoardViewport(
        verticalOffset: verticalOffset,
        verticalAxisDirection: verticalDetails.direction,
        horizontalOffset: horizontalOffset,
        horizontalAxisDirection: horizontalDetails.direction,
        delegate: delegate as TwoDimensionalChildBuilderDelegate,
        mainAxis: mainAxis,
        count: count,
        cell: cell,
        clipBehavior: clipBehavior,
      );
}

class _BoardViewport extends TwoDimensionalViewport {
  const _BoardViewport({
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required TwoDimensionalChildBuilderDelegate super.delegate,
    required super.mainAxis,
    required this.count,
    required this.cell,
    super.clipBehavior,
  });

  final int count;
  final double cell;

  @override
  RenderTwoDimensionalViewport createRenderObject(BuildContext context) => _RenderBoardViewport(
    horizontalOffset: horizontalOffset,
    horizontalAxisDirection: horizontalAxisDirection,
    verticalOffset: verticalOffset,
    verticalAxisDirection: verticalAxisDirection,
    mainAxis: mainAxis,
    delegate: delegate as TwoDimensionalChildBuilderDelegate,
    childManager: context as TwoDimensionalChildManager,
    clipBehavior: clipBehavior,
    count: count,
    cell: cell,
  );

  @override
  void updateRenderObject(BuildContext context, _RenderBoardViewport renderObject) {
    renderObject
      ..horizontalOffset = horizontalOffset
      ..horizontalAxisDirection = horizontalAxisDirection
      ..verticalOffset = verticalOffset
      ..verticalAxisDirection = verticalAxisDirection
      ..mainAxis = mainAxis
      ..delegate = delegate
      ..clipBehavior = clipBehavior;
  }
}

class _RenderBoardViewport extends RenderTwoDimensionalViewport {
  _RenderBoardViewport({
    required super.horizontalOffset,
    required super.horizontalAxisDirection,
    required super.verticalOffset,
    required super.verticalAxisDirection,
    required TwoDimensionalChildBuilderDelegate super.delegate,
    required super.mainAxis,
    required super.childManager,
    required this.count,
    required this.cell,
    super.clipBehavior,
  });

  /// Fixed for the board's life: the Lobby's board is always 26 × 26 cells of 56.
  final int count;
  final double cell;

  @override
  void layoutChildSequence() {
    final x = horizontalOffset.pixels;
    final y = verticalOffset.pixels;
    final width = viewportDimension.width;
    final height = viewportDimension.height;
    // one cell beyond each edge, so a cell is ready before it shows
    final firstCol = math.max((x / cell).floor() - 1, 0);
    final lastCol = math.min(((x + width) / cell).ceil(), count - 1);
    final firstRow = math.max((y / cell).floor() - 1, 0);
    final lastRow = math.min(((y + height) / cell).ceil(), count - 1);
    for (var col = firstCol; col <= lastCol; col++) {
      for (var row = firstRow; row <= lastRow; row++) {
        final child = buildOrObtainChildFor(ChildVicinity(xIndex: col, yIndex: row));
        if (child == null) continue;
        child.layout(BoxConstraints.tight(Size.square(cell)));
        parentDataOf(child).layoutOffset = Offset(col * cell - x, row * cell - y);
      }
    }
    final extent = cell * count;
    verticalOffset.applyContentDimensions(0, math.max(extent - height, 0));
    horizontalOffset.applyContentDimensions(0, math.max(extent - width, 0));
  }
}
