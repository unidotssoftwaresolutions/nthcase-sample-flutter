import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/catalog.dart';
import '../../data/form_rules.dart';
import '../../ids.dart';
import '../art.dart';
import '../components.dart';
import '../theme.dart';

const joinedMessage = 'Welcome to the club';

/// Join the club: every kind of form control, with its validation error as a line of its own under it.
class FormScreen extends StatefulWidget {
  const FormScreen({super.key});

  @override
  State<FormScreen> createState() => _FormScreenState();
}

class _FormScreenState extends State<FormScreen> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _age = TextEditingController();
  final _password = TextEditingController();
  final _categoryMenu = MenuController();
  bool _showPassword = false;
  Category? _category;
  DateTime? _date;
  bool _newsletter = false;
  double _budget = 50;
  bool _terms = false;
  bool _submitted = false;
  String? _joined;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _age, _password]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _email, _age, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  ClubForm get _form => ClubForm(
    name: _name.text,
    email: _email.text,
    age: _age.text,
    password: _password.text,
    category: _category,
    deliveryDate: _date,
    newsletter: _newsletter,
    budget: _budget.round(),
    acceptedTerms: _terms,
  );

  void _join() {
    final scope = AppScope.read(context);
    final form = _form;
    setState(() {
      _submitted = true;
      _joined = FormRules.errors(form).isEmpty
          ? "Welcome, ${form.name.trim()}. We'll write to ${form.email.trim()} about the ${form.category!.label} aisle "
                'and deliver on ${formatDeliveryDate(form.deliveryDate!)}.'
          : null;
    });
    if (_joined != null) scope.snack.show(joinedMessage);
  }

  Future<void> _pickDate() async {
    final today = AppScope.read(context).notifier!.clock();
    final picked = await showDialog<DateTime>(
      context: context,
      builder: (context) =>
          _DatePickerDialog(initialMonth: DateTime(today.year, today.month), today: today, selected: _date),
    );
    if (picked != null) setState(() => _date = picked);
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.read(context).notifier!;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Errors appear after the first Join, then follow every edit.
    final errors = _submitted ? FormRules.errors(_form) : const <String, String>{};

    Widget field(
      String label,
      TextEditingController controller,
      String id,
      String errorKey,
      String errorId, {
      TextInputType? keyboard,
      List<TextInputFormatter>? formatters,
      bool obscure = false,
      Widget? suffix,
    }) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Id(
            id,
            child: TextField(
              controller: controller,
              keyboardType: keyboard,
              inputFormatters: formatters,
              obscureText: obscure,
              enableSuggestions: !obscure,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: label,
                suffixIcon: suffix,
                error: errors[errorKey] == null ? null : const SizedBox.shrink(),
              ),
            ),
          ),
          _ErrorLine(errors[errorKey], errorId),
        ],
      );
    }

    return Id(
      TestIds.formScreen,
      region: true,
      child: Scaffold(
        appBar: TopBar('Join the club', onBack: state.back),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Members hear about new drawers first. Every field is required except the newsletter.',
                style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              field('Full name', _name, TestIds.formName, 'name', TestIds.formNameError),
              const SizedBox(height: 12),
              field(
                'Email',
                _email,
                TestIds.formEmail,
                'email',
                TestIds.formEmailError,
                keyboard: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              field(
                'Age',
                _age,
                TestIds.formAge,
                'age',
                TestIds.formAgeError,
                keyboard: TextInputType.number,
                formatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
              ),
              const SizedBox(height: 12),
              field(
                'Password',
                _password,
                TestIds.formPassword,
                'password',
                TestIds.formPasswordError,
                keyboard: TextInputType.visiblePassword,
                obscure: !_showPassword,
                suffix: IdControl(
                  TestIds.formPasswordToggle,
                  child: IconButton(
                    onPressed: () => setState(() => _showPassword = !_showPassword),
                    icon: ArtIcon(
                      _showPassword ? Art.eyeOff : Art.eye,
                      label: _showPassword ? 'Hide password' : 'Show password',
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              MenuAnchor(
                controller: _categoryMenu,
                alignmentOffset: const Offset(0, 4),
                menuChildren: [
                  for (final option in Category.values)
                    IdControl(
                      TestIds.formCategoryOption(option.key),
                      child: MenuItemButton(
                        onPressed: () => setState(() => _category = option),
                        child: SizedBox(width: 200, child: Text(option.label)),
                      ),
                    ),
                ],
                builder: (context, controller, _) => Id(
                  TestIds.formCategory,
                  child: Semantics(
                    button: true,
                    expanded: controller.isOpen,
                    child: InkWell(
                      borderRadius: radiusLabel,
                      onTap: () => controller.isOpen ? controller.close() : controller.open(),
                      child: InputDecorator(
                        isEmpty: _category == null,
                        isFocused: controller.isOpen,
                        decoration: InputDecoration(
                          labelText: 'Favourite aisle',
                          error: errors['category'] == null ? null : const SizedBox.shrink(),
                          suffixIcon: Transform.rotate(
                            angle: controller.isOpen ? -math.pi / 2 : math.pi / 2,
                            child: ArtIcon(Art.chevron, color: scheme.onSurfaceVariant),
                          ),
                        ),
                        child: Text(_category?.label ?? '', style: theme.textTheme.bodyLarge),
                      ),
                    ),
                  ),
                ),
              ),
              _ErrorLine(errors['category'], TestIds.formCategoryError),
              const SizedBox(height: 12),
              InputDecorator(
                isEmpty: _date == null,
                decoration: InputDecoration(
                  labelText: 'Delivery date',
                  error: errors['date'] == null ? null : const SizedBox.shrink(),
                  suffixIcon: IdControl(
                    TestIds.formDate,
                    child: IconButton(
                      onPressed: _pickDate,
                      icon: ArtIcon(Art.calendar, label: 'Choose a delivery date'),
                    ),
                  ),
                ),
                child: Text(_date == null ? '' : formatDeliveryDate(_date!), style: theme.textTheme.bodyLarge),
              ),
              _ErrorLine(errors['date'], TestIds.formDateError),
              const SizedBox(height: 4),
              ToggleRow(
                label: 'Email me about new drawers',
                value: _newsletter,
                onChanged: (value) => setState(() => _newsletter = value),
                kind: ToggleKind.switcher,
                id: TestIds.formNewsletter,
              ),
              Row(
                children: [
                  Expanded(child: Text('Monthly budget', style: theme.textTheme.bodyLarge)),
                  Id(TestIds.formBudgetValue, child: Text('\$${_budget.round()}', style: theme.textTheme.titleMedium)),
                ],
              ),
              IdControl(
                TestIds.formBudget,
                child: Semantics(
                  label: 'Monthly budget',
                  child: Slider(
                    value: _budget,
                    max: 200,
                    divisions: 20, // $10 steps
                    semanticFormatterCallback: (value) => '\$${value.round()}',
                    onChanged: (value) => setState(() => _budget = value),
                  ),
                ),
              ),
              ToggleRow(
                label: 'I accept the club terms',
                value: _terms,
                onChanged: (value) => setState(() => _terms = value),
                kind: ToggleKind.checkbox,
                id: TestIds.formTerms,
              ),
              _ErrorLine(errors['terms'], TestIds.formTermsError),
              const SizedBox(height: 16),
              SizedBox(
                height: 48,
                child: IdControl(
                  TestIds.formSubmit,
                  child: FilledButton(onPressed: _join, child: const Text('Join')),
                ),
              ),
              if (_joined != null) ...[
                const SizedBox(height: 16),
                Id(
                  TestIds.formResult,
                  // a plain box, not a Material Card: a Card makes a semantics level of its own, and the message must be
                  // the id's own label, so a check on form_result reads its text
                  child: DecoratedBox(
                    decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: radiusDrawer),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ArtIcon(Art.check, color: scheme.onPrimaryContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _joined!,
                              style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onPrimaryContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A field's error, as a line of its own under the field, with its own id. Flutter folds a field's error text into
/// the field's own node, which would leave the error without an id; this line keeps it.
class _ErrorLine extends StatelessWidget {
  const _ErrorLine(this.error, this.id);

  final String? error;
  final String id;

  @override
  Widget build(BuildContext context) {
    if (error == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final color = theme.colorScheme.error;
    return Padding(
      padding: const EdgeInsets.only(left: 4, top: 4),
      child: Row(
        children: [
          ArtIcon(Art.warning, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Id(
              id,
              child: Text(error!, style: theme.textTheme.bodySmall?.copyWith(color: color)),
            ),
          ),
        ],
      ),
    );
  }
}

/// The date picker: a month of days that opens on the current month, with Cancel and OK. Built here, not taken from
/// showDatePicker, so its buttons can carry the spec's ids and its arrows are Mossgrove's own drawings.
class _DatePickerDialog extends StatefulWidget {
  const _DatePickerDialog({required this.initialMonth, required this.today, this.selected});

  final DateTime initialMonth;
  final DateTime today;
  final DateTime? selected;

  @override
  State<_DatePickerDialog> createState() => _DatePickerDialogState();
}

class _DatePickerDialogState extends State<_DatePickerDialog> {
  late DateTime _month = widget.selected == null
      ? widget.initialMonth
      : DateTime(widget.selected!.year, widget.selected!.month);
  late DateTime? _selected = widget.selected;

  static const _weekdays = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

  bool _same(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final days = DateUtils.getDaysInMonth(_month.year, _month.month);
    // DateTime.weekday is 1 (Monday) to 7 (Sunday); the grid starts on Sunday
    final blanks = DateTime(_month.year, _month.month).weekday % 7;

    Widget day(int number) {
      final date = DateTime(_month.year, _month.month, number);
      final selected = _selected != null && _same(_selected!, date);
      final today = _same(widget.today, date);
      return Semantics(
        selected: selected,
        button: true,
        child: InkResponse(
          onTap: () => setState(() => _selected = date),
          radius: 20,
          child: Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? scheme.primary : null,
              border: today && !selected ? Border.all(color: scheme.primary) : null,
            ),
            child: Text(
              '$number',
              style: theme.textTheme.bodyLarge?.copyWith(color: selected ? scheme.onPrimary : scheme.onSurface),
            ),
          ),
        ),
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                  'Delivery date',
                  style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 12),
                child: Text(
                  _selected == null ? 'No date chosen' : formatDeliveryDate(_selected!),
                  style: theme.textTheme.headlineSmall,
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),
              Id(
                TestIds.formDatePicker,
                region: true,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 8),
                            child: Text(formatMonth(_month), style: theme.textTheme.titleSmall),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                          icon: Transform.rotate(
                            angle: math.pi,
                            child: ArtIcon(Art.chevron, label: 'Previous month'),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                          icon: ArtIcon(Art.chevron, label: 'Next month'),
                        ),
                      ],
                    ),
                    GridView.count(
                      crossAxisCount: 7,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final w in _weekdays)
                          ExcludeSemantics(
                            child: Center(
                              child: Text(
                                w,
                                style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                              ),
                            ),
                          ),
                        for (var i = 0; i < blanks; i++) const SizedBox.shrink(),
                        for (var d = 1; d <= days; d++) Center(child: day(d)),
                      ],
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IdControl(
                    TestIds.formDateCancel,
                    child: TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
                  ),
                  IdControl(
                    TestIds.formDateConfirm,
                    child: TextButton(
                      onPressed: _selected == null ? null : () => Navigator.of(context).pop(_selected),
                      child: const Text('OK'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
