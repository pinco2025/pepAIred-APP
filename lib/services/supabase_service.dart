import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;

class SupabaseService {
  static final SupabaseClient supabase = Supabase.instance.client;

  static Future<User?> getCurrentUser() async {
    final session = supabase.auth.currentSession;
    return session?.user;
  }

  static Future<Map<String, dynamic>?> getExistingTestSession(
      String userId, String testId) async {
    try {
      final response = await supabase
          .from('student_tests')
          .select('id, started_at, answers, submitted_at')
          .eq('user_id', userId)
          .eq('test_id', testId)
          .filter('submitted_at', 'is', null)
          .order('started_at', ascending: false)
          .limit(1);

      if (response != null && (response as List).isNotEmpty) {
        return response[0];
      }
      return null;
    } catch (e) {
      print('Error fetching student test: $e');
      return null;
    }
  }

  static Future<Map<String, dynamic>?> createTestSession(
      String userId, String testId) async {
    try {
      final response = await supabase
          .from('student_tests')
          .insert({
            'test_id': testId,
            'user_id': userId,
            'started_at': DateTime.now().toIso8601String(),
          })
          .select('id, started_at')
          .single();
      return response;
    } catch (e) {
      print('Failed to create a new student test entry: $e');
      return null;
    }
  }

  static Future<void> updateAnswers(
      String studentTestId, Map<String, dynamic> answers) async {
    try {
      await supabase
          .from('student_tests')
          .update({'answers': answers}).eq('id', studentTestId);
    } catch (e) {
      print('Error auto-saving answers to DB: $e');
    }
  }

  static Future<bool> submitTest(
      String studentTestId, Map<String, dynamic> answers) async {
    try {
      final submissionData = {
        'answers': answers,
        'submitted_at': DateTime.now().toIso8601String()
      };

      await supabase
          .from('student_tests')
          .update(submissionData)
          .eq('id', studentTestId);

      return true;
    } catch (e) {
      print('Error submitting test: $e');
      return false;
    }
  }

  static Future<void> triggerScoreCalculation(String submissionId) async {
    try {
      final session = supabase.auth.currentSession;
      final token = session?.accessToken;

      await http.post(
        Uri.parse('https://prepaired-backend.onrender.com/api/v1/scores/$submissionId/calculate'),
        headers: {
          'Content-Type': 'application/json',
          if (token != null) 'Authorization': 'Bearer $token',
        },
      );
    } catch (e) {
      print('Failed to trigger score calculation: $e');
    }
  }
}
