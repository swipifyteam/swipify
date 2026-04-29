// ============================================================
// test/core/constants_test.dart
// Unit tests for AppConstants data integrity.
// ============================================================
import 'package:flutter_test/flutter_test.dart';
import 'package:swipify/core/constants.dart';

void main() {
  group('AppConstants', () {
    group('bannerImages', () {
      test('should have at least one banner image URL', () {
        expect(AppConstants.bannerImages, isNotEmpty);
      });

      test('every banner URL should start with http', () {
        for (final url in AppConstants.bannerImages) {
          expect(url, startsWith('http'),
              reason: 'Banner URL "$url" must be a valid http/https URL');
        }
      });
    });

    group('brands', () {
      test('should have at least one brand', () {
        expect(AppConstants.brands, isNotEmpty);
      });

      test('every brand must have name and icon keys', () {
        for (final brand in AppConstants.brands) {
          expect(brand.containsKey('name'), isTrue,
              reason: 'Brand is missing "name" key: $brand');
          expect(brand.containsKey('icon'), isTrue,
              reason: 'Brand is missing "icon" key: $brand');
        }
      });

      test('brand names should be non-empty strings', () {
        for (final brand in AppConstants.brands) {
          final name = brand['name'];
          expect(name, isA<String>());
          expect((name as String).isNotEmpty, isTrue);
        }
      });

      test('should have well-known brand names', () {
        final names = AppConstants.brands.map((b) => b['name']).toList();
        expect(names, containsAll(['Nike', 'Samsung', 'Apple']));
      });
    });

    group('paddingMedium', () {
      test('should be a positive number', () {
        expect(AppConstants.paddingMedium, greaterThan(0));
      });
    });
  });
}
