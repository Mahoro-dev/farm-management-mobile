import 'package:farm_desk/scan.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a stick line becomes a tag number', () {
    expect(RfidScanner.extractTag('982000123456789\r'), '982000123456789');
    expect(RfidScanner.extractTag('TAG: A840000123'), 'A840000123');
    expect(RfidScanner.extractTag('short'), isNull);
  });

  test('a photo can hold several ear tags', () {
    const photo = '''
4521
A-8891
HOLSTEIN
Ear tag 12045
982000123456789
''';
    expect(RfidScanner.extractEarTags(photo), ['4521', 'A8891', '12045', '982000123456789']);
  });
}
