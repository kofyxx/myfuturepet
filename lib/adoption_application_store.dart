import 'package:flutter/foundation.dart';
import 'services/adoption_service.dart';

class AdoptionApplicationStore {
  // ============================================================
  // ALL ADOPTION APPLICATIONS
  // ============================================================

  static final List<Map<String, dynamic>> applications = [];

  // ============================================================
  // SYNC WITH SUPABASE
  // ============================================================

  static Future<List<Map<String, dynamic>>> syncWithSupabase() async {
    try {
      final myApps = await AdoptionService().fetchMyApplications();
      if (myApps.isNotEmpty) {
        applications.clear();
        for (var raw in myApps) {
          final petRaw = raw['pets'] as Map<String, dynamic>?;
          applications.add({
            'id': raw['id']?.toString() ?? '',
            'pet': {
              'id': petRaw?['id']?.toString() ?? '',
              'name': petRaw?['name']?.toString() ?? 'Pet',
              'breed': petRaw?['breed']?.toString() ?? '',
              'age': 'Young',
              'gender': petRaw?['gender']?.toString() ?? '',
              'image': petRaw?['image_url']?.toString() ?? '',
              'status': petRaw?['status']?.toString() ?? 'Available',
            },
            'status': (raw['status'] ?? 'pending').toString().toLowerCase() == 'pending'
                ? 'Under Review'
                : (raw['status'] ?? 'Under Review'),
            'fullName': raw['full_name']?.toString() ?? '',
            'phone': raw['contact_number']?.toString() ?? '',
            'email': '',
            'householdType': raw['housing_type']?.toString() ?? '',
            'address': raw['address']?.toString() ?? '',
            'submittedAt': raw['created_at']?.toString() ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing adoption applications: $e');
    }
    return applications;
  }

  // ============================================================
  // CHECK IF USER HAS ANY APPLICATION
  // ============================================================

  static bool get hasApplication {
    return applications.isNotEmpty;
  }

  // ============================================================
  // LATEST APPLICATION
  // ============================================================

  static Map<String, dynamic>? get application {
    if (applications.isEmpty) {
      return null;
    }
    return applications.last;
  }

  // ============================================================
  // SAVE APPLICATION
  // ============================================================

  static Future<void> saveApplication({
    required Map<String, dynamic> pet,

    // PERSONAL INFORMATION
    required String fullName,
    required String phone,
    required String email,
    required String age,
    required String occupation,

    // HOUSEHOLD INFORMATION
    required String householdType,
    required String address,
    required String householdMembers,
    required String children,

    // PET EXPERIENCE
    required String experienceLevel,
    required String previousPets,
    required String currentPets,

    // LIFESTYLE
    required String homeEnvironment,
    required String activityLevel,
    required String timeAvailable,

    // ADOPTION
    required String adoptionReason,
  }) async {
    final Map<String, dynamic> newApplication = {
      'pet': Map<String, dynamic>.from(pet),
      'status': 'Under Review',
      'fullName': fullName,
      'phone': phone,
      'email': email,
      'age': age,
      'occupation': occupation,
      'householdType': householdType,
      'address': address,
      'householdMembers': householdMembers,
      'children': children,
      'experienceLevel': experienceLevel,
      'previousPets': previousPets,
      'currentPets': currentPets,
      'homeEnvironment': homeEnvironment,
      'activityLevel': activityLevel,
      'timeAvailable': timeAvailable,
      'adoptionReason': adoptionReason,
      'submittedAt': DateTime.now().toIso8601String(),
    };

    applications.add(newApplication);

    // Persist to Supabase Database
    try {
      final petId = pet['id']?.toString() ?? '';
      if (petId.isNotEmpty) {
        final res = await AdoptionService().submitApplication(
          petId: petId,
          fullName: fullName,
          contactNumber: phone,
          address: address,
          occupation: occupation,
          housingType: householdType,
          reasonForAdoption: adoptionReason,
        );
        if (res['id'] != null) {
          newApplication['id'] = res['id'].toString();
        }
      }
    } catch (e) {
      debugPrint('Adoption submission to Supabase error: $e');
    }
  }

  // ============================================================
  // GET ALL APPLICATIONS
  // ============================================================

  static List<Map<String, dynamic>> getAllApplications() {
    return List<Map<String, dynamic>>.from(applications);
  }

  // ============================================================
  // GET APPLICATION COUNT
  // ============================================================

  static int get applicationCount {
    return applications.length;
  }

  // ============================================================
  // REMOVE ONE APPLICATION
  // ============================================================

  static void removeApplication(int index) {
    if (index >= 0 && index < applications.length) {
      final app = applications[index];
      final appId = app['id']?.toString();
      if (appId != null && appId.isNotEmpty) {
        AdoptionService().withdrawApplication(appId).catchError((_) => false);
      }
      applications.removeAt(index);
    }
  }

  // ============================================================
  // CLEAR ALL APPLICATIONS
  // ============================================================

  static void clearApplications() {
    applications.clear();
  }
}