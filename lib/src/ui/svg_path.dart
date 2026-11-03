import 'dart:ui';

/// Turns SVG path data (the `d` attribute) into a [Path]. Flutter has no SVG support of its own, and Mossgrove takes
/// no third-party packages, so the art in `art/` is drawn with this. It reads every path command: M L H V C S Q T A Z,
/// absolute and relative.
Path parseSvgPath(String data) {
  final reader = _PathReader(data);
  final path = Path();
  var current = Offset.zero;
  var start = Offset.zero;
  // the last control point, for S and T, and the command that set it
  Offset? lastCubic;
  Offset? lastQuad;
  String? command;

  while (true) {
    reader.skipSeparators();
    if (reader.atEnd) break;
    if (reader.atCommand) {
      command = reader.readCommand();
    } else if (command == null) {
      throw FormatException('Path data must start with a command', data);
    }
    final relative = command.toLowerCase() == command;
    final base = relative ? current : Offset.zero;
    Offset point() => base + Offset(reader.readNumber(), reader.readNumber());

    switch (command.toUpperCase()) {
      case 'M':
        current = point();
        start = current;
        path.moveTo(current.dx, current.dy);
        // further pairs after a move are lines
        command = relative ? 'l' : 'L';
        lastCubic = lastQuad = null;
      case 'L':
        current = point();
        path.lineTo(current.dx, current.dy);
        lastCubic = lastQuad = null;
      case 'H':
        current = Offset(reader.readNumber() + (relative ? current.dx : 0), current.dy);
        path.lineTo(current.dx, current.dy);
        lastCubic = lastQuad = null;
      case 'V':
        current = Offset(current.dx, reader.readNumber() + (relative ? current.dy : 0));
        path.lineTo(current.dx, current.dy);
        lastCubic = lastQuad = null;
      case 'C':
        final c1 = point();
        final c2 = point();
        final end = point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCubic = c2;
        lastQuad = null;
        current = end;
      case 'S':
        final c1 = lastCubic == null ? current : current * 2 - lastCubic;
        final c2 = point();
        final end = point();
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
        lastCubic = c2;
        lastQuad = null;
        current = end;
      case 'Q':
        final c = point();
        final end = point();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastQuad = c;
        lastCubic = null;
        current = end;
      case 'T':
        final c = lastQuad == null ? current : current * 2 - lastQuad;
        final end = point();
        path.quadraticBezierTo(c.dx, c.dy, end.dx, end.dy);
        lastQuad = c;
        lastCubic = null;
        current = end;
      case 'A':
        final rx = reader.readNumber();
        final ry = reader.readNumber();
        final rotation = reader.readNumber();
        final largeArc = reader.readFlag();
        final sweep = reader.readFlag();
        final end = point();
        path.arcToPoint(
          end,
          radius: Radius.elliptical(rx, ry),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        lastCubic = lastQuad = null;
        current = end;
      case 'Z':
        path.close();
        current = start;
        lastCubic = lastQuad = null;
      default:
        throw FormatException('Unknown path command "$command"', data);
    }
  }
  return path;
}

class _PathReader {
  _PathReader(this.data);

  final String data;
  int index = 0;

  bool get atEnd => index >= data.length;

  bool get atCommand => !atEnd && 'MmLlHhVvCcSsQqTtAaZz'.contains(data[index]);

  String readCommand() => data[index++];

  void skipSeparators() {
    while (!atEnd && (data[index] == ' ' || data[index] == ',' || data[index] == '\n' || data[index] == '\t')) {
      index++;
    }
  }

  /// An arc's flags are single digits, and may be written with nothing between them ("a5 5 0 01 10 10").
  bool readFlag() {
    skipSeparators();
    final flag = data[index++];
    if (flag != '0' && flag != '1') throw FormatException('An arc flag is 0 or 1', data, index - 1);
    return flag == '1';
  }

  double readNumber() {
    skipSeparators();
    final begin = index;
    if (!atEnd && (data[index] == '-' || data[index] == '+')) index++;
    var dot = false;
    var exponent = false;
    while (!atEnd) {
      final c = data[index];
      if (c.codeUnitAt(0) >= 48 && c.codeUnitAt(0) <= 57) {
        index++;
      } else if (c == '.' && !dot && !exponent) {
        dot = true;
        index++;
      } else if ((c == 'e' || c == 'E') && !exponent) {
        exponent = true;
        index++;
        if (!atEnd && (data[index] == '-' || data[index] == '+')) index++;
      } else {
        break;
      }
    }
    if (begin == index) throw FormatException('Expected a number', data, index);
    return double.parse(data.substring(begin, index));
  }
}
