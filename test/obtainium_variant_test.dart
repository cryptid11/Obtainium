import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/providers/settings_provider.dart';
import 'package:obtainium/utils/string_utils.dart';

void main() {
  test('isObtainiumVariant recognises the push build', () {
    expect(isObtainiumVariant(obtainiumId), isTrue);
    expect(isObtainiumVariant('$obtainiumId.push'), isTrue);
    expect(isObtainiumVariant('$obtainiumId.pusher'), isFalse);
  });
}
