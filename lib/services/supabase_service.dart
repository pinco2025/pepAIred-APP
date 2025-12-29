import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/test_models.dart';

class SupabaseService {
  static final SupabaseClient supabase = Supabase.instance.client;

  /// Returns the current authenticated user.
  static Future<User?> getCurrentUser() async {
    final session = supabase.auth.currentSession;
    return session?.user;
  }

  static Future<List<Test>> fetchTests() async {
    try {
      final response = await supabase.from('tests').select('*');
      final List<dynamic> data = response as List<dynamic>;
      return data.map((json) => Test.fromJson(json)).toList();
    } catch (e) {
      print('Error fetching tests: $e');
      return [];
    }
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

      if ((response as List).isNotEmpty) {
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
            'started_at': DateTime.now().toUtc().toIso8601String(),
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
        'submitted_at': DateTime.now().toUtc().toIso8601String()
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

  static Future<Map<String, dynamic>?> fetchSubmissionData(
      String submissionId) async {
    try {
      final response = await supabase
          .from('student_tests')
          .select('started_at, submitted_at, result_url, test_id, answers')
          .eq('id', submissionId)
          .single();
      return response;
    } catch (e) {
      print('Error fetching submission data: $e');
      return null;
    }
  }

  static Future<String?> fetchTestUrl(String testId) async {
    try {
      final response = await supabase
          .from('tests')
          .select('url')
          .eq('testID', testId) // Assuming testID is the column name based on Test model
          .single();
      return response['url'] as String?;
    } catch (e) {
      print('Error fetching test URL: $e');
      return null;
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
