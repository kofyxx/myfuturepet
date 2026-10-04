import 'package:flutter/foundation.dart';
import 'pet_data.dart';
import 'services/favorites_service.dart';

class SavedPetStore {
  // ============================================================
  // SAVED PETS
  // ============================================================

  static final List<Map<String, dynamic>> savedPets = [];

  // ============================================================
  // CHANGE NOTIFIER
  // ============================================================

  static final ValueNotifier<int> changeNotifier = ValueNotifier<int>(0);

  static void _notify() {
    changeNotifier.value++;
  }

  // ============================================================
  // CHECK IF PET IS SAVED
  // ============================================================

  static bool isSaved(String petNameOrId) {
    if (petNameOrId.trim().isEmpty) return false;
    final lower = petNameOrId.trim().toLowerCase();

    // 1. Direct match in FavoritesService (by ID or name)
    if (FavoritesService().favoritesNotifier.value.contains(petNameOrId)) {
      return true;
    }

    // 2. Check in-memory savedPets list
    if (savedPets.any((pet) {
      final id = pet['id']?.toString() ?? '';
      final name = pet['name']?.toString().toLowerCase() ?? '';
      return id == petNameOrId || name == lower;
    })) {
      return true;
    }

    // 3. Check PetData.pets: if petNameOrId matches any pet whose ID or name is favored
    for (final pet in PetData.pets) {
      final id = pet['id']?.toString() ?? '';
      final name = pet['name']?.toString().toLowerCase() ?? '';
      if (id == petNameOrId || name == lower) {
        if (FavoritesService().favoritesNotifier.value.contains(id) ||
            FavoritesService().favoritesNotifier.value.contains(pet['name']?.toString())) {
          return true;
        }
      }
    }

    return false;
  }

  static bool isSavedById(String petId) {
    return isSaved(petId);
  }

  // ============================================================
  // ADD PET
  // ============================================================

  static void addPet(Map<String, dynamic> pet) {
    final String petName = pet['name']?.toString() ?? '';
    final String petId = pet['id']?.toString() ?? petName;

    final bool alreadyInStore = savedPets.any((p) {
      final pId = p['id']?.toString() ?? '';
      final pName = p['name']?.toString().toLowerCase() ?? '';
      return (pId.isNotEmpty && pId == petId) ||
          (pName.isNotEmpty && pName == petName.toLowerCase());
    });

    if (!alreadyInStore) {
      savedPets.add(Map<String, dynamic>.from(pet));
    }

    if (petId.isNotEmpty) {
      FavoritesService().addFavorite(petId);
    }
    if (petName.isNotEmpty && petName != petId) {
      FavoritesService().addFavorite(petName);
    }

    _notify();
  }

  // ============================================================
  // REMOVE PET
  // ============================================================

  static void removePet(String petNameOrId) {
    final lower = petNameOrId.trim().toLowerCase();

    final pet = savedPets.firstWhere(
      (p) {
        final pId = p['id']?.toString() ?? '';
        final pName = p['name']?.toString().toLowerCase() ?? '';
        return pId == petNameOrId || pName == lower;
      },
      orElse: () => <String, dynamic>{},
    );

    final String petId = pet['id']?.toString() ?? petNameOrId;
    final String petName = pet['name']?.toString() ?? petNameOrId;

    savedPets.removeWhere((p) {
      final pId = p['id']?.toString() ?? '';
      final pName = p['name']?.toString().toLowerCase() ?? '';
      return pId == petNameOrId ||
          pName == lower ||
          pId == petId ||
          pName == petName.toLowerCase();
    });

    if (petId.isNotEmpty) {
      FavoritesService().removeFavorite(petId);
    }
    if (petName.isNotEmpty && petName != petId) {
      FavoritesService().removeFavorite(petName);
    }
    if (petNameOrId != petId && petNameOrId != petName) {
      FavoritesService().removeFavorite(petNameOrId);
    }

    _notify();
  }

  // ============================================================
  // TOGGLE SAVE
  // ============================================================

  static void togglePet(Map<String, dynamic> pet) {
    final String petName = pet['name']?.toString() ?? '';
    final String petId = pet['id']?.toString() ?? petName;

    if (isSaved(petName) || isSaved(petId)) {
      removePet(petId.isNotEmpty ? petId : petName);
    } else {
      addPet(pet);
    }
  }

  // ============================================================
  // SYNC WITH FAVORITES
  // ============================================================

  static void syncWithFavorites(List<Map<String, dynamic>> allPets) {
    final favIds = FavoritesService().getFavoriteIds();
    for (final id in favIds) {
      final found = allPets.firstWhere(
        (p) =>
            p['id']?.toString() == id ||
            p['name'].toString().toLowerCase() == id.toLowerCase(),
        orElse: () => <String, dynamic>{},
      );
      if (found.isNotEmpty) {
        final alreadyInStore = savedPets.any((p) {
          final pId = p['id']?.toString() ?? '';
          final pName = p['name']?.toString().toLowerCase() ?? '';
          return (pId.isNotEmpty && pId == found['id']?.toString()) ||
              (pName.isNotEmpty &&
                  pName == found['name']?.toString().toLowerCase());
        });
        if (!alreadyInStore) {
          savedPets.add(Map<String, dynamic>.from(found));
        }
      }
    }
    _notify();
  }

  // ============================================================
  // GET ALL SAVED PETS
  // ============================================================

  static List<Map<String, dynamic>> getAllSavedPets() {
    return List<Map<String, dynamic>>.from(savedPets);
  }

  // ============================================================
  // SAVED PET COUNT
  // ============================================================

  static int get savedCount {
    return savedPets.length;
  }

  // ============================================================
  // CLEAR ALL SAVED PETS
  // ============================================================

  static void clearAll() {
    savedPets.clear();
    _notify();
  }
}