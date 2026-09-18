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

  static final BigInt _thousand = BigInt.from(1000);

  static String format(BigInt value) {
    if (value < _thousand) {
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
    if (!value.isFinite) return value.toString();
    if (value < 1000) {
      return value.toStringAsFixed(3);
    }

    final suffixIndex = _decimalExponent(value) ~/ 3;

    if (suffixIndex < _suffixes.length && suffixIndex > 0) {
      double shortValue =
          value / (BigInt.from(10).pow(suffixIndex * 3).toDouble());
      // Format with exactly 3 decimal places
      String formatted = shortValue.toStringAsFixed(3);
      return '$formatted${_suffixes[suffixIndex]}';
    }

    // Fallback to scientific notation for absurdly large numbers
    int exponent = _decimalExponent(value);
    String mantissa = '${value / (BigInt.from(10).pow(exponent).toDouble())}';
    // A round mantissa prints short ("1.0"), which substring(0, 5) threw on.
    return '${mantissa.substring(0, math.min(5, mantissa.length))}e+$exponent';
  }

  /// floor(log10(value)) for value >= 1, exactly.
  ///
  /// The float log alone lands just under the integer at exact powers of
  /// ten (log(1000)/log(10) is 2.9999999999999996), which rendered 1e6 as
  /// "1000.000K" and made formatDouble(1000) throw.
  static int _decimalExponent(double value) {
    var exponent = (math.log(value) / math.ln10).floor();
    if (BigInt.from(10).pow(exponent + 1).toDouble() <= value) {
      exponent++;
    } else if (exponent > 0 &&
        BigInt.from(10).pow(exponent).toDouble() > value) {
      exponent--;
    }
    return exponent;
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
