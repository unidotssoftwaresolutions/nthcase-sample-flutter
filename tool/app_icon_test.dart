// Draws the iOS app icon from art/launcher.svg: the one picture tool/convert_art.dart cannot write as text.
//
//   flutter test tool/app_icon_test.dart
//
// It writes ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png (one 1024-pixel icon; Xcode makes the
// other sizes). It is a test only so that it runs inside Flutter's renderer; it is not part of `flutter test`.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:mossgrove/src/ui/svg_path.dart';

void main() {
  test('draw the iOS app icon', () async {
    final svg = File('art/launcher.svg').readAsStringSync();
    final viewBox = double.parse(RegExp(r'viewBox="0 0 (\d+) \d+"').firstMatch(svg)!.group(1)!);
    const size = 1024.0;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder)..scale(size / viewBox);

    ui.Color color(String hex) => ui.Color(int.parse('FF${hex.substring(1)}', radix: 16));
    Map<String, String> attributes(String text) => {
      for (final m in RegExp(r'([a-z-]+)="([^"]*)"').allMatches(text)) m.group(1)!: m.group(2)!,
    };

    // iOS draws the icon's rounded corners itself, so the background fills the whole square
    final background = RegExp(r'<rect[^>]*fill="(#[0-9A-Fa-f]{6})"').firstMatch(svg)!.group(1)!;
    canvas.drawRect(ui.Rect.fromLTWH(0, 0, viewBox, viewBox), ui.Paint()..color = color(background));
    for (final match in RegExp(r'<path ([^>]*)/>').allMatches(svg)) {
      final a = attributes(match.group(1)!);
      final path = parseSvgPath(a['d']!);
      final fill = a['fill'];
      if (fill != null && fill != 'none') canvas.drawPath(path, ui.Paint()..color = color(fill));
      if (a['stroke'] != null) {
        canvas.drawPath(
          path,
          ui.Paint()
            ..style = ui.PaintingStyle.stroke
            ..color = color(a['stroke']!)
            ..strokeWidth = double.parse(a['stroke-width'] ?? '1')
            ..strokeCap = a['stroke-linecap'] == 'round' ? ui.StrokeCap.round : ui.StrokeCap.butt,
        );
      }
    }

    final image = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('ios/Runner/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png');
    out.writeAsBytesSync(png!.buffer.asUint8List());
    File('ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json').writeAsStringSync('''
{
  "images" : [
    {
      "filename" : "AppIcon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
''');
    expect(out.lengthSync(), greaterThan(1000));
  });
}
