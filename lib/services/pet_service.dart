import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PetService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Fetch adoptable pets with optional filters (category, search, breed, gender)
  Future<List<Map<String, dynamic>>> fetchPets({
    String? category,
    String? searchQuery,
    String? breed,
    String? gender,
    String? status,
  }) async {
    try {
      var query = _client
          .from('pets')
          .select('*, shelters(id, name, address, contact_number)');

      // Category filter (Dogs / Cats)
      if (category != null && category != 'All') {
        if (category.toLowerCase() == 'dogs' || category.toLowerCase() == 'dog') {
          query = query.eq('type', 'dog');
        } else if (category.toLowerCase() == 'cats' || category.toLowerCase() == 'cat') {
          query = query.eq('type', 'cat');
        }
      }

      // Status filter (default to showing available first, or specific status)
      if (status != null && status != 'All') {
        query = query.eq('status', status.toLowerCase());
      }

      // Search query (pet name or breed)
      if (searchQuery != null && searchQuery.trim().isNotEmpty) {
        final term = searchQuery.trim();
        query = query.or('name.ilike.%$term%,breed.ilike.%$term%');
      }

      // Breed filter
      if (breed != null && breed != 'All Breeds' && breed.isNotEmpty) {
        query = query.eq('breed', breed);
      }

      // Gender filter
      if (gender != null && gender != 'Any Gender' && gender.isNotEmpty) {
        query = query.eq('gender', gender.toLowerCase());
      }

      final response = await query.order('created_at', ascending: false);
      final List<dynamic> data = response as List<dynamic>;

      return data.map((item) => _normalizePetData(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching pets: $e');
      return [];
    }
  }

  /// Fetch featured pets for the Home screen carousel
  Future<List<Map<String, dynamic>>> fetchFeaturedPets({int limit = 5}) async {
    try {
      final response = await _client
          .from('pets')
          .select('*, shelters(id, name, address, contact_number)')
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _normalizePetData(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching featured pets: $e');
      return [];
    }
  }

  /// Fetch recommended pets for the Home grid
  Future<List<Map<String, dynamic>>> fetchRecommendedPets({int limit = 6}) async {
    try {
      final response = await _client
          .from('pets')
          .select('*, shelters(id, name, address, contact_number)')
          .eq('status', 'available')
          .order('created_at', ascending: false)
          .limit(limit);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => _normalizePetData(item as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Error fetching recommended pets: $e');
      return [];
    }
  }

  /// Single pet details by ID
  Future<Map<String, dynamic>?> fetchPetById(String id) async {
    try {
      final response = await _client
          .from('pets')
          .select('*, shelters(id, name, address, contact_number)')
          .eq('id', id)
          .maybeSingle();

      if (response == null) return null;
      return _normalizePetData(response);
    } catch (e) {
      debugPrint('Error fetching pet by ID: $e');
      return null;
    }
  }

  /// Helper to normalize pet attributes for consistent UI consumption
  Map<String, dynamic> _normalizePetData(Map<String, dynamic> raw) {
    final shelter = raw['shelters'] as Map<String, dynamic>?;
    final type = (raw['type'] ?? 'dog').toString().toLowerCase();

    // Default fallback image depending on species
    final fallbackImage = type == 'dog'
        ? 'https://images.unsplash.com/photo-1552053831-71594a27632d?w=800'
        : 'https://images.unsplash.com/photo-1514888286974-6c03e2ca1dba?w=800';

    final imageUrl = (raw['image_url'] != null && raw['image_url'].toString().trim().isNotEmpty)
        ? raw['image_url'].toString()
        : fallbackImage;

    // Calculate age string from birthdate
    String ageStr = 'Young';
    if (raw['birthdate'] != null) {
      try {
        final bday = DateTime.parse(raw['birthdate'].toString());
        final now = DateTime.now();
        final diffDays = now.difference(bday).inDays;
        final years = (diffDays / 365.25).floor();
        final months = ((diffDays % 365.25) / 30.4).floor();

        if (years >= 1) {
          ageStr = '$years ${years == 1 ? 'yr' : 'yrs'}';
        } else if (months >= 1) {
          ageStr = '$months ${months == 1 ? 'mo' : 'mos'}';
        } else {
          ageStr = '$diffDays days';
        }
      } catch (_) {}
    }

    final temperamentStr = raw['temperament']?.toString() ?? 'Friendly, Gentle';
    final personalityList = temperamentStr
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    if (personalityList.isEmpty) {
      personalityList.addAll(['Friendly', 'Gentle']);
    }

    final vacStatus = raw['vaccination_status']?.toString() ?? 'Up to date';
    final isVaccinated = !vacStatus.toLowerCase().contains('unvac') &&
        !vacStatus.toLowerCase().contains('not') &&
        !vacStatus.toLowerCase().contains('no');

    return {
      'id': raw['id']?.toString() ?? '',
      'name': raw['name']?.toString() ?? 'Unnamed Pet',
      'type': type,
      'category': type == 'dog' ? 'Dogs' : 'Cats',
      'breed': raw['breed']?.toString() ?? (type == 'dog' ? 'Aspin' : 'Puspin'),
      'gender': (raw['gender'] != null)
          ? raw['gender'].toString().substring(0, 1).toUpperCase() +
              raw['gender'].toString().substring(1)
          : 'Unknown',
      'age': ageStr,
      'birthdate': raw['birthdate']?.toString(),
      'status': (raw['status'] != null)
          ? raw['status'].toString().substring(0, 1).toUpperCase() +
              raw['status'].toString().substring(1)
          : 'Available',
      'raw_status': raw['status']?.toString() ?? 'available',
      'size': raw['size']?.toString() ?? 'Medium',
      'weight': raw['weight_kg'] != null ? '${raw['weight_kg']} kg' : 'Normal',
      'color': raw['color']?.toString() ?? 'Mixed',
      'health_condition': raw['health_condition']?.toString() ?? 'Healthy',
      'vaccination_status': vacStatus,
      'vaccinationStatus': vacStatus,
      'temperament': temperamentStr,
      'personality': personalityList,
      'personalityShort': personalityList.join(', '),
      'behavior': personalityList.isNotEmpty ? personalityList.first : 'Active',
      'energy': personalityList.isNotEmpty ? personalityList.first : 'Active',
      'vaccinated': isVaccinated,
      'kidFriendly': temperamentStr.toLowerCase().contains('kid') ||
          temperamentStr.toLowerCase().contains('gentle') ||
          temperamentStr.toLowerCase().contains('friendly'),
      'description': raw['description']?.toString() ??
          'Rescued and cared for by Jagna Animal Lover and Rescue Group.',
      'about': raw['description']?.toString() ??
          'Rescued and cared for by Jagna Animal Lover and Rescue Group.',
      'adoption_requirements': raw['adoption_requirements']?.toString() ??
          'Valid ID, screening questionnaire, home inspection agreement.',
      'image': imageUrl,
      'image_url': imageUrl,
      'images': [imageUrl],
      'model_url': raw['model_url']?.toString(),
      'shelter_id': raw['shelter_id']?.toString(),
      'shelter': shelter?['name']?.toString() ?? 'JAGNA ANIMAL LOVER AND RESCUE GROUP',
      'shelterPhone': shelter?['contact_number']?.toString() ?? '+63 900 000 0000',
      'shelterAddress': shelter?['address']?.toString() ?? 'Jagna, Bohol, Philippines',
      'location': shelter?['address']?.toString() ?? 'Jagna, Bohol, Philippines',
      'deworming': raw['deworming']?.toString() ??
          ((raw['health_condition']?.toString().toLowerCase().contains('deworm') ?? false)
              ? 'Completed'
              : 'Up to date'),
      'rabies': raw['rabies']?.toString() ?? (isVaccinated ? 'Immunized' : 'Up to date'),
      'likes': raw['likes'] ?? 0,
    };
  }
}
