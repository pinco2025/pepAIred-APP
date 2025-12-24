import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/test_models.dart';

class TestDataService {
  /// Fetches test data from the provided URL.
  static Future<LocalTest> fetchTestData(String url) async {
    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        return LocalTest.fromJson(data);
      } else {
        throw Exception('Failed to load test data: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Failed to load test data: $e');
    }
  }
}
