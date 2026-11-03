import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/catalog.dart';
import '../art.dart';
import '../components.dart';
import '../theme.dart';

/// The one gift-card code that has a balance. Any other code is unknown.
const giftCardCode = 'MOSS-0025';
const giftCardBalance = r'Balance: $25.00';
const giftCardUnknown = "We don't recognise that code";

/// Upper-cases what is typed, keeping the cursor where it was.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

/// The screen with no test ids at all (SPEC.md §5). Nothing here carries a semantics identifier, its top bar included,
/// so NthCase must find each control by its visible text, its label and its position. Two buttons share the text
/// "Choose": only their position tells them apart.
class GiftCardsScreen extends StatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  final _code = TextEditingController();
  String? _result;
  int _amount = 25;
  String? _design;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: TopBar('Gift cards', onBack: state.back, tagged: false),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Check a balance', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            inputFormatters: [_UpperCase()],
            textCapitalization: TextCapitalization.characters,
            autocorrect: false,
            onChanged: (_) => setState(() => _result = null),
            decoration: const InputDecoration(labelText: 'Card code'),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              onPressed: () =>
                  setState(() => _result = _code.text.trim() == giftCardCode ? giftCardBalance : giftCardUnknown),
              child: const Text('Check balance'),
            ),
          ),
          if (_result != null) ...[const SizedBox(height: 16), Text(_result!, style: theme.textTheme.titleMedium)],
          const SizedBox(height: 24),
          Text('Buy a card', style: theme.textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final value in [10, 25, 50])
                // selected is a mark as well as a tint: the chip draws its check
                FilterChip(
                  label: Text('\$$value'),
                  selected: _amount == value,
                  onSelected: (_) => setState(() => _amount = value),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _DesignCard('Fern', 'Green leaves', _design == 'Fern', () => setState(() => _design = 'Fern')),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DesignCard(
                  'Stone',
                  'Grey pebbles',
                  _design == 'Stone',
                  () => setState(() => _design = 'Stone'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            _design == null ? 'Choose a design' : 'A \$$_amount card with the $_design design',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }
}

/// A gift-card design: a picture of it, its name, and Choose. The chosen one has a check and a primary border.
class _DesignCard extends StatelessWidget {
  const _DesignCard(this.title, this.body, this.chosen, this.onChoose);

  final String title;
  final String body;
  final bool chosen;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tints = Mossgrove.of(context);
    final tint = title == 'Fern' ? tints.garden : tints.home;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: radiusDrawer,
        side: chosen ? BorderSide(color: scheme.primary, width: 2) : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 72,
              decoration: BoxDecoration(color: tint.tile, borderRadius: radiusTile),
              alignment: Alignment.center,
              child: title == 'Fern'
                  ? ArtIcon(Art.glyph(Glyph.plant), size: 44, color: tint.ink)
                  // three pebbles, drawn for this card
                  : CustomPaint(size: const Size(64, 36), painter: _Pebbles(tint.ink)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
                if (chosen) ArtIcon(Art.check, size: 18, color: scheme.primary, label: 'Chosen'),
              ],
            ),
            const SizedBox(height: 4),
            Text(body, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            OutlinedButton(onPressed: onChoose, child: const Text('Choose')),
          ],
        ),
      ),
    );
  }
}

class _Pebbles extends CustomPainter {
  _Pebbles(this.ink);

  final Color ink;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawOval(Rect.fromLTWH(0, size.height * 0.35, size.width * 0.42, size.height * 0.6), stroke);
    canvas.drawOval(Rect.fromLTWH(size.width * 0.36, 0, size.width * 0.34, size.height * 0.5), stroke);
    canvas.drawOval(
      Rect.fromLTWH(size.width * 0.56, size.height * 0.45, size.width * 0.44, size.height * 0.52),
      stroke,
    );
  }

  @override
  bool shouldRepaint(_Pebbles old) => old.ink != ink;
}
