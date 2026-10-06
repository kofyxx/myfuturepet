import 'package:flutter/foundation.dart';
import 'services/appointment_service.dart';

class AppointmentStore {
  // ============================================================
  // ALL APPOINTMENTS
  // ============================================================

  static final List<Map<String, dynamic>> appointments = [];

  // ============================================================
  // SYNC WITH SUPABASE
  // ============================================================

  static Future<List<Map<String, dynamic>>> syncWithSupabase() async {
    try {
      final myAppts = await AppointmentService().fetchMyAppointments();
      if (myAppts.isNotEmpty) {
        appointments.clear();
        for (var raw in myAppts) {
          final petRaw = raw['pets'] as Map<String, dynamic>?;
          final shelterRaw = raw['shelters'] as Map<String, dynamic>?;

          DateTime? scheduled;
          if (raw['scheduled_at'] != null) {
            try {
              scheduled = DateTime.parse(raw['scheduled_at'].toString());
            } catch (_) {}
          }

          appointments.add({
            'id': raw['id']?.toString() ?? '',
            'pet': {
              'id': petRaw?['id']?.toString() ?? '',
              'name': petRaw?['name']?.toString() ?? 'Shelter Pet',
              'breed': petRaw?['breed']?.toString() ?? '',
              'image': petRaw?['image_url']?.toString() ?? '',
            },
            'appointmentType': (raw['appointment_type'] ?? 'shelter_visit') == 'meet_and_greet'
                ? 'Meet & Greet'
                : 'Shelter Visit',
            'date': scheduled != null ? scheduled.toIso8601String() : DateTime.now().toIso8601String(),
            'time': scheduled != null
                ? '${scheduled.hour.toString().padLeft(2, '0')}:${scheduled.minute.toString().padLeft(2, '0')}'
                : '10:00 AM',
            'shelter': shelterRaw?['name']?.toString() ?? 'JAGNA ANIMAL LOVER AND RESCUE GROUP',
            'status': () {
              final s = (raw['status'] ?? 'pending').toString().toLowerCase();
              if (s == 'confirmed' || s == 'approved') return 'Confirmed';
              if (s == 'cancelled' || s == 'rejected') return 'Cancelled';
              if (s == 'completed') return 'Completed';
              return 'Pending';
            }(),
            'createdAt': raw['created_at']?.toString() ?? '',
          });
        }
      }
    } catch (e) {
      debugPrint('Error syncing appointments with Supabase: $e');
    }
    return appointments;
  }

  // ============================================================
  // CHECK IF USER HAS ANY APPOINTMENT
  // ============================================================

  static bool get hasAppointment {
    return appointments.isNotEmpty;
  }

  // ============================================================
  // LATEST APPOINTMENT
  // ============================================================

  static Map<String, dynamic>? get appointment {
    if (appointments.isEmpty) {
      return null;
    }
    return appointments.last;
  }

  // ============================================================
  // SAVE APPOINTMENT
  // ============================================================

  static Future<void> saveAppointment({
    required Map<String, dynamic> pet,
    required String appointmentType,
    required DateTime date,
    required String time,
    required String shelter,
  }) async {
    final Map<String, dynamic> newAppointment = {
      'pet': Map<String, dynamic>.from(pet),
      'appointmentType': appointmentType,
      'date': date.toIso8601String(),
      'time': time,
      'shelter': shelter,
      'status': 'Confirmed',
      'createdAt': DateTime.now().toIso8601String(),
    };

    appointments.add(newAppointment);

    // Persist to Supabase Database
    try {
      final shelterId = pet['shelter_id']?.toString() ?? '327b47f9-e81c-4ff7-a133-8702563601e6';
      final petId = pet['id']?.toString();
      final normalizedType = appointmentType.toLowerCase().contains('meet')
          ? 'meet_and_greet'
          : 'shelter_visit';

      final res = await AppointmentService().bookAppointment(
        shelterId: shelterId,
        petId: petId,
        scheduledAt: date,
        appointmentType: normalizedType,
        notes: 'Booked via My Future Pet Mobile App',
      );

      if (res['id'] != null) {
        newAppointment['id'] = res['id'].toString();
      }
    } catch (e) {
      debugPrint('Appointment booking to Supabase error: $e');
    }
  }

  // ============================================================
  // GET ALL APPOINTMENTS
  // ============================================================

  static List<Map<String, dynamic>> getAllAppointments() {
    return List<Map<String, dynamic>>.from(appointments);
  }

  // ============================================================
  // COUNT
  // ============================================================

  static int get appointmentCount {
    return appointments.length;
  }

  // ============================================================
  // REMOVE APPOINTMENT
  // ============================================================

  static void removeAppointment(int index) {
    if (index >= 0 && index < appointments.length) {
      final appt = appointments[index];
      final apptId = appt['id']?.toString();
      if (apptId != null && apptId.isNotEmpty) {
        AppointmentService().cancelAppointment(apptId).catchError((_) => false);
      }
      appointments.removeAt(index);
    }
  }

  // ============================================================
  // CLEAR ALL
  // ============================================================

  static void clearAppointments() {
    appointments.clear();
  }
}