import 'dart:math' as math;

class NumberFormatter {
  static const List<String> _namedSuffixes = [
    '',
    'K',
    'M',
    'B',
    'T',
    'Qa',
    'Qi',
    'Sx',
    'Sp',
    'Oc',
    'No',
    'Dc',
    'UDc',
    'DDc',
    'TDc',
    'QaDc',
    'QiDc',
    'SxDc',
    'SpDc',
    'OcDc',
    'NoDc',
    'Vg',
    'UVg',
    'DVg',
    'TVg',
    'QaVg',
    'QiVg',
    'SxVg',
    'SpVg',
    'OcVg',
    'NoVg',
    'Tg',
    'UTg',
    'DTg',
    'TTg',
    'QaTg',
    'QiTg',
    'SxTg',
    'SpTg',
    'OcTg',
    'NoTg',
  ];
  static final List<String> _suffixes = _buildSuffixes();

  static List<String> _buildSuffixes() {
    final suffixes = <String>[..._namedSuffixes];
    for (int first = 0; first < 26; first++) {
      for (int second = 0; second < 26; second++) {
        suffixes.add(
          '${String.fromCharCode(97 + first)}${String.fromCharCode(97 + second)}',
        );
      }
    }
    return suffixes;
  }

  static String format(BigInt value) {
    if (value < BigInt.from(1000)) {
      return value.toString();
    }

    String asString = value.toString();
    int digits = asString.length;
    int suffixIndex = (digits - 1) ~/ 3;

    if (suffixIndex > 0 && suffixIndex < _suffixes.length) {
      final scaleExponent = suffixIndex * 3;
      final intDigits = digits - scaleExponent;
      final lead = asString.substring(0, intDigits);
      final rest = asString.substring(intDigits);
      final decimals = rest.padRight(2, '0').substring(0, 2);
      String compact = '$lead.$decimals';
      while (compact.contains('.') &&
          (compact.endsWith('0') || compact.endsWith('.'))) {
        compact = compact.substring(0, compact.length - 1);
      }
      return '$compact${_suffixes[suffixIndex]}';
    }

    // After named + aa..zz denominations, use scientific notation.
    int exponent = digits - 1;
    final mantissaEnd = math.min(4, asString.length);
    String mantissa = '${asString[0]}.${asString.substring(1, mantissaEnd)}';
    return '${mantissa}e+$exponent';
  }

  /// Format a double value with K, M, B denominations and 3 decimal places
  static String formatDouble(double value) {
    if (value < 1000) {
      return value.toStringAsFixed(3);
    }

    final suffixIndex = (math.log(value) / math.log(10) ~/ 3).toInt();

    if (suffixIndex < _suffixes.length && suffixIndex > 0) {
      double shortValue =
          value / (BigInt.from(10).pow(suffixIndex * 3).toDouble());
      // Format with exactly 3 decimal places
      String formatted = shortValue.toStringAsFixed(3);
      return '$formatted${_suffixes[suffixIndex]}';
    }

    // Fallback to scientific notation for absurdly large numbers
    int exponent = (math.log(value) / math.log(10)).floor();
    String mantissa = '${value / (BigInt.from(10).pow(exponent).toDouble())}';
    return '${mantissa.substring(0, 5)}e+$exponent';
  }

  /// Compact display for prestige multiplier (e.g. 1.028, 2.415).
  static String formatPrestigeMultiplier(double value) {
    if (!value.isFinite || value <= 0) return '1';
    String s = value.toStringAsFixed(4);
    while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
}
