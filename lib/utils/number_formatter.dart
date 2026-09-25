import 'dart:math' as math;

import 'big_number.dart';

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

  /// Compact display: 1234 -> "1.23K", 1200 -> "1.2K", 1000 -> "1K".
  ///
  /// [fixedDecimals] keeps both decimals ("1.20K", "1.00K") so the string
  /// length only changes when the magnitude does. Use it for any number that
  /// ticks live: trimming zeros made a centered counter change width several
  /// times a second and visibly jump sideways.
  static String format(BigInt value, {bool fixedDecimals = false}) {
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
      final String compact;
      if (fixedDecimals) {
        compact = '$lead.$decimals';
      } else if (decimals == '00') {
        compact = lead;
      } else if (decimals[1] == '0') {
        compact = '$lead.${decimals[0]}';
      } else {
        compact = '$lead.$decimals';
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

  /// Compact display for a production amount that may be fractional
  /// (e.g. 0.4, 12, 1.25K). Used for per-tap and per-second gains.
  static String formatGain(double value) {
    if (!value.isFinite || value <= 0) return '0';
    if (value < 10 && value != value.roundToDouble()) {
      String s = value.toStringAsFixed(value < 1 ? 2 : 1);
      while (s.endsWith('0')) {
        s = s.substring(0, s.length - 1);
      }
      if (s.endsWith('.')) s = s.substring(0, s.length - 1);
      return s;
    }
    return format(wholeBigInt(value.roundToDouble()));
  }

  /// Short human duration: "now", "42s", "3m 05s", "2h 14m", "3d 4h".
  static String formatDuration(double seconds) {
    if (!seconds.isFinite) return '∞';
    if (seconds < 1) return 'now';
    final s = seconds.round();
    if (s < 60) return '${s}s';
    if (s < 3600) {
      return '${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
    }
    if (s < 86400) return '${s ~/ 3600}h ${((s % 3600) ~/ 60)}m';
    if (s < 86400 * 365) return '${s ~/ 86400}d ${((s % 86400) ~/ 3600)}h';
    return '>1y';
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
