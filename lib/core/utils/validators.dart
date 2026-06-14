class Validators {
  Validators._();

  static String? requiredText(String? value, {String label = 'Field'}) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  static String? nonNegativeInt(String? value, {String label = 'Value'}) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < 0) {
      return '$label must be >= 0';
    }
    return null;
  }

  static String? username(String? value) {
    if (value == null || value.trim().isEmpty) return 'Username is required';
    final trimmed = value.trim();
    if (trimmed.length < 3) return 'Username must be at least 3 characters';
    if (trimmed.length > 30) return 'Username must be at most 30 characters';
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(trimmed)) {
      return 'Only letters, numbers and underscores allowed';
    }
    return null;
  }

  static String? boundedInt(
    String? value, {
    required int min,
    required int max,
    String label = 'Value',
  }) {
    final parsed = int.tryParse(value ?? '');
    if (parsed == null || parsed < min || parsed > max) {
      return '$label must be between $min and $max';
    }
    return null;
  }
}
