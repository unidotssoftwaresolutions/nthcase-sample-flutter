import 'catalog.dart';

/// The club form's fields, as typed.
class ClubForm {
  const ClubForm({
    this.name = '',
    this.email = '',
    this.age = '',
    this.password = '',
    this.category,
    this.deliveryDate,
    this.newsletter = false,
    this.budget = 50,
    this.acceptedTerms = false,
  });

  final String name;
  final String email;
  final String age;
  final String password;
  final Category? category;
  final DateTime? deliveryDate;
  final bool newsletter;
  final int budget;
  final bool acceptedTerms;
}

/// One message per invalid field. The texts are part of the spec: every framework shows the same words.
abstract final class FormRules {
  static const name = 'Enter your name';
  static const email = 'Enter a valid email address';
  static const age = 'Enter an age from 18 to 120';
  static const password = 'Use at least 8 characters, including a number';
  static const category = 'Choose a favourite aisle';
  static const date = 'Choose a delivery date';
  static const terms = 'Accept the terms to continue';

  static final RegExp _emailShape = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// The errors by field key: name, email, age, password, category, date, terms.
  static Map<String, String> errors(ClubForm form) {
    final age = int.tryParse(form.age.trim());
    return {
      if (form.name.trim().isEmpty) 'name': name,
      if (!_emailShape.hasMatch(form.email.trim())) 'email': email,
      if (age == null || age < 18 || age > 120) 'age': FormRules.age,
      if (form.password.length < 8 || !form.password.contains(RegExp('[0-9]'))) 'password': password,
      if (form.category == null) 'category': category,
      if (form.deliveryDate == null) 'date': date,
      if (!form.acceptedTerms) 'terms': terms,
    };
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "15 Nov 2026": the delivery date as every framework writes it.
String formatDeliveryDate(DateTime date) => '${date.day} ${_months[date.month - 1]} ${date.year}';

const _longMonths = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// "November 2026": the date picker's heading.
String formatMonth(DateTime month) => '${_longMonths[month.month - 1]} ${month.year}';
