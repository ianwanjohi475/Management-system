/// Form validators. Each returns `null` when valid, else a short message.
abstract final class V {
  static final _email = RegExp(r"^[\w.+\-']+@[\w\-]+(\.[\w\-]+)*\.[a-zA-Z]{2,}$");
  static final _phone = RegExp(r'^\+?[0-9 ]{9,15}$');

  static String? required(String? v, [String field = 'This field']) => (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? email(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!_email.hasMatch(v.trim())) return "That email doesn't look right";
    return null;
  }

  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Use at least 6 characters';
    if (!RegExp(r'[0-9]').hasMatch(v) && !RegExp(r'[^A-Za-z]').hasMatch(v)) {
      return 'Add a number or symbol to make it stronger';
    }
    return null;
  }

  static String? phone(String? v, {bool optional = false}) {
    if (v == null || v.trim().isEmpty) return optional ? null : 'Phone number is required';
    if (!_phone.hasMatch(v.trim())) return 'Enter a valid phone number, e.g. 0712 345 678';
    return null;
  }

  static String? name(String? v, [String field = 'Name']) {
    if (v == null || v.trim().isEmpty) return '$field is required';
    if (v.trim().length < 2) return '$field is too short';
    if (v.trim().length > 60) return '$field is too long';
    return null;
  }

  static String? number(String? v, {String field = 'Value', bool optional = false, bool allowZero = false, bool integer = false, num? max}) {
    if (v == null || v.trim().isEmpty) return optional ? null : '$field is required';
    final n = num.tryParse(v.trim().replaceAll(',', ''));
    if (n == null) return 'Enter a valid number';
    if (integer && n % 1 != 0) return 'Use a whole number';
    if (n < 0) return "$field can't be negative";
    if (!allowZero && n == 0) return '$field must be more than 0';
    if (max != null && n > max) return '$field is too large (max ${max is int ? max : max.toStringAsFixed(0)})';
    return null;
  }

  static num? parse(String? v) => v == null ? null : num.tryParse(v.trim().replaceAll(',', ''));
}
