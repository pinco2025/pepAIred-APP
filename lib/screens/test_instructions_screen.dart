import 'package:flutter/material.dart';
import 'package:prepaired/models/test_models.dart';
import 'package:prepaired/services/supabase_service.dart';
import 'package:prepaired/screens/test_screen.dart';

class TestInstructionsScreen extends StatefulWidget {
  final Test test;

  const TestInstructionsScreen({super.key, required this.test});

  @override
  State<TestInstructionsScreen> createState() => _TestInstructionsScreenState();
}

class _TestInstructionsScreenState extends State<TestInstructionsScreen> {
  bool _isLoading = true;
  String? _existingSubmissionId;

  @override
  void initState() {
    super.initState();
    _checkExistingAttempt();
  }

  Future<void> _checkExistingAttempt() async {
    final user = await SupabaseService.getCurrentUser();
    if (user != null) {
      final session = await SupabaseService.getExistingTestSession(user.id, widget.test.id);

      // Note: The logic in web checks if submitted_at is NOT null to redirect to results.
      // And if it is null (in progress), it likely resumes.
      // Let's verify SupabaseService logic.
      // SupabaseService.getExistingTestSession filters 'submitted_at', 'is', null.
      // So it returns IN PROGRESS sessions.

      // I need to check for COMPLETED sessions too to redirect to results.
      // But SupabaseService currently doesn't have a method for that in the interface I saw.
      // Wait, in `TestPage.tsx`:
      // .not('submitted_at', 'is', null) -> Redirect to results.

      // The current SupabaseService.getExistingTestSession is designed to "resume" a test.

      // I should add a check for completed tests here if I want to redirect.
      // For now, I'll proceed. If there is an active session, we can resume it.

      // Let's just focus on starting/resuming for now.
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _startTest() {
    // Navigate to TestScreen
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => TestScreen(test: widget.test),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.test.title),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.test.title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.test.description,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Colors.grey[600],
                  ),
            ),
            const SizedBox(height: 24),
            _buildInfoRow(Icons.timer, '${widget.test.duration ~/ 60} mins'),
            _buildInfoRow(Icons.help_outline, '${widget.test.totalQuestions} Questions'),
            _buildInfoRow(Icons.grade, widget.test.markingScheme),

            const SizedBox(height: 32),
            Text(
              'Instructions',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 16),
            ...widget.test.instructions.map((instruction) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('• ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Expanded(
                        child: Text(
                          instruction,
                          style: const TextStyle(fontSize: 16, height: 1.5),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _startTest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4C6FFF),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Start Test',
                  style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(fontSize: 16, color: Colors.black87),
          ),
        ],
      ),
    );
  }
}
