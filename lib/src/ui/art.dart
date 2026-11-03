import 'package:flutter/material.dart';

import '../data/catalog.dart';
import 'art_data.g.dart';
import 'svg_path.dart';

/// One drawing from `art/`: a single stroked path in a square of [viewBox] units.
class ArtDrawing {
  const ArtDrawing(this.viewBox, this.stroke, this.data);

  final double viewBox;
  final double stroke;
  final String data;
}

/// The interface icons, by their file name in `art/icons`.
abstract final class Art {
  static ArtDrawing icon(String name) => iconDrawings[name] ?? (throw ArgumentError('No icon art/icons/$name.svg'));

  static ArtDrawing glyph(Glyph glyph) => glyphDrawings[glyph.name]!;

  static ArtDrawing get search => icon('search');
  static ArtDrawing get close => icon('close');
  static ArtDrawing get back => icon('back');
  static ArtDrawing get plus => icon('plus');
  static ArtDrawing get minus => icon('minus');
  static ArtDrawing get cart => icon('cart');
  static ArtDrawing get shop => icon('shop');
  static ArtDrawing get lab => icon('lab');
  static ArtDrawing get settings => icon('settings');
  static ArtDrawing get eye => icon('eye');
  static ArtDrawing get eyeOff => icon('eye_off');
  static ArtDrawing get trash => icon('trash');
  static ArtDrawing get chevron => icon('chevron');
  static ArtDrawing get calendar => icon('calendar');
  static ArtDrawing get warning => icon('warning');
  static ArtDrawing get empty => icon('empty');
  static ArtDrawing get check => icon('check');
}

final Map<String, Path> _paths = {};

/// Draws a drawing from `art/` at [size], in [color] (the icon theme's colour when null). With a [label] it is an image
/// with that name for screen readers; without one it is decoration, and says nothing.
class ArtIcon extends StatelessWidget {
  const ArtIcon(this.drawing, {super.key, this.size = 24, this.color, this.label});

  final ArtDrawing drawing;
  final double size;
  final Color? color;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final ink = color ?? IconTheme.of(context).color ?? Theme.of(context).colorScheme.onSurface;
    // drawn at its own size even where the slot is bigger (a text field's 48 dp icon slots), centred in it
    final picture = Center(
      widthFactor: 1,
      heightFactor: 1,
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _ArtPainter(drawing, ink)),
      ),
    );
    if (label == null) return ExcludeSemantics(child: picture);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: picture),
    );
  }
}

class _ArtPainter extends CustomPainter {
  _ArtPainter(this.drawing, this.color);

  final ArtDrawing drawing;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = _paths.putIfAbsent(drawing.data, () => parseSvgPath(drawing.data));
    final scale = size.shortestSide / drawing.viewBox;
    canvas.save();
    canvas.translate((size.width - drawing.viewBox * scale) / 2, (size.height - drawing.viewBox * scale) / 2);
    canvas.scale(scale);
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = drawing.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..isAntiAlias = true,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_ArtPainter old) => old.drawing != drawing || old.color != color;
}
