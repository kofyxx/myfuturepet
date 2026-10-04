import 'package:flutter_test/flutter_test.dart';
import 'package:myfuturepet/pet_data.dart';

void main() {
  test('PetData notifier initializes and updates correctly', () {
    expect(PetData.pets, isEmpty);
    PetData.petsNotifier.value = [
      {
        'id': 'test-1',
        'name': 'Sky',
        'type': 'dog',
        'breed': 'Labrador mix',
        'status': 'available',
      }
    ];
    expect(PetData.pets.length, equals(1));
    expect(PetData.pets.first['name'], equals('Sky'));
  });
}
