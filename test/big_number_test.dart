import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:number_flutter/logic/game_state.dart';
import 'package:number_flutter/logic/tutorial_step.dart';
import 'package:number_flutter/utils/big_number.dart';
import 'package:number_flutter/utils/number_formatter.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('wholeBigInt', () {
    test('is exact past the 64-bit int ceiling', () {
      // BigInt.from(x.floor()) capped every one of these at 9223372036854775807.
      expect(wholeBigInt(1e19), BigInt.parse('10000000000000000000'));
      expect(wholeBigInt(1e25), BigInt.from(1e25));
      expect(wholeBigInt(1e300).toString().length, 301);
    });

    test('drops the fraction and ignores sub-unit or invalid amounts', () {
      expect(wholeBigInt(12.9), BigInt.from(12));
      expect(wholeBigInt(0.99), BigInt.zero);
      expect(wholeBigInt(-5), BigInt.zero);
      expect(wholeBigInt(double.nan), BigInt.zero);
    });

    test('clamps Infinity instead of throwing', () {
      expect(wholeBigInt(double.infinity), BigInt.from(double.maxFinite));
    });
  });

  test('formatGain no longer tops out at ~9.22Qi', () {
    expect(NumberFormatter.formatGain(1e21), '1Sx');
  });

  group('late-game click', () {
    late GameState gs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      gs = GameState();
      await gs.ready;
      gs.debugSetTutorialStep(TutorialStep.done);
    });

    tearDown(() => gs.dispose());

    test('a tap worth more than 9.22e18 is credited in full', () {
      gs.clickPower = BigInt.parse('1${'0' * 25}');
      gs.number = BigInt.zero;
      final result = gs.click();
      expect(result.gain >= BigInt.parse('1${'0' * 25}'), isTrue,
          reason: 'gain was ${result.gain}');
      expect(gs.number, result.gain);
    });
  });
}
