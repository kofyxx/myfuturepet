import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppointmentService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Book a shelter visit or meet-and-greet appointment
  Future<Map<String, dynamic>> bookAppointment({
    required String shelterId,
    String? petId,
    required DateTime scheduledAt,
    String appointmentType = 'shelter_visit',
    String? notes,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('You must be logged in to book an appointment.');
    }

    // appointment_type enum: 'shelter_visit', 'meet_and_greet'
    final validTypes = ['shelter_visit', 'meet_and_greet'];
    final normalizedType = validTypes.contains(appointmentType) ? appointmentType : 'shelter_visit';

    try {
      final insertData = {
        'user_id': user.id,
        'shelter_id': shelterId,
        'pet_id': petId != null && petId.isNotEmpty ? petId : null,
        'appointment_type': normalizedType,
        'scheduled_at': scheduledAt.toUtc().toIso8601String(),
        'status': 'pending',
        'notes': notes?.trim().isEmpty == true ? null : notes?.trim(),
      };

      final response = await _client
          .from('appointments')
          .insert(insertData)
          .select()
          .single();

      return response;
    } catch (e) {
      debugPrint('Error booking appointment: $e');
      rethrow;
    }
  }

  /// Fetch all appointments for the current user
  Future<List<Map<String, dynamic>>> fetchMyAppointments() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];

    try {
      final response = await _client
          .from('appointments')
          .select('*, shelters(id, name, address, contact_number), pets(id, name, type, breed, image_url)')
          .eq('user_id', user.id)
          .order('scheduled_at', ascending: true);

      final List<dynamic> data = response as List<dynamic>;
      return data.map((item) => item as Map<String, dynamic>).toList();
    } catch (e) {
      debugPrint('Error fetching user appointments: $e');
      return [];
    }
  }

  /// Cancel an upcoming appointment
  Future<bool> cancelAppointment(String appointmentId) async {
    final user = _client.auth.currentUser;
    if (user == null) return false;

    try {
      await _client
          .from('appointments')
          .update({'status': 'cancelled'})
          .eq('id', appointmentId)
          .eq('user_id', user.id);
      return true;
    } catch (e) {
      debugPrint('Error cancelling appointment: $e');
      return false;
    }
  }
}
