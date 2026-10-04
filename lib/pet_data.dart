import 'package:flutter/foundation.dart';
import 'services/pet_service.dart';

class PetData {
  static final ValueNotifier<List<Map<String, dynamic>>> petsNotifier =
      ValueNotifier<List<Map<String, dynamic>>>([]);

  /// Real pets fetched directly from the Jagna Shelter Supabase database
  static List<Map<String, dynamic>> get pets {
    return petsNotifier.value;
  }

  /// Sync pet list with Supabase database in real time (no fake or mock fallbacks)
  static Future<List<Map<String, dynamic>>> syncWithSupabase() async {
    try {
      final livePets = await PetService().fetchPets();
      petsNotifier.value = livePets;
      return livePets;
    } catch (e) {
      debugPrint('Error syncing pets with Supabase: $e');
    }
    return petsNotifier.value;
  }
}