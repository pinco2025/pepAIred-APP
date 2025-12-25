import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/test_models.dart';

class TestDataService {
  /// Fetches test data from the provided URL.
  static Future<LocalTest> fetchTestData(String url) async {
    try {
      print('Fetching test data from: $url');
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));

      print('Response status: ${response.statusCode}');
      if (response.statusCode == 200) {
        print('Response body length: ${response.body.length}');
        final Map<String, dynamic> data = json.decode(response.body);
        final test = LocalTest.fromJson(data);
        print('Parsed test: ${test.title} with ${test.questions.length} questions');
        return test;
      } else {
        print('Failed to load test data. Status code: ${response.statusCode}');
        print('Response body: ${response.body}');
        throw Exception('Failed to load test data: ${response.statusCode}');
      }
    } catch (e) {
      print('Exception fetching test data: $e');
      throw Exception('Failed to load test data: $e');
    }
  }
}
