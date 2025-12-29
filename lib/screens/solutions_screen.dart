import 'package:flutter/material.dart';
import 'package:prepaired/models/solution_models.dart';
import 'package:prepaired/services/supabase_service.dart';
import 'package:prepaired/widgets/common/math_html_renderer.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SolutionsScreen extends StatefulWidget {
  final String submissionId;

  const SolutionsScreen({super.key, required this.submissionId});

  @override
  State<SolutionsScreen> createState() => _SolutionsScreenState();
}

class _SolutionsScreenState extends State<SolutionsScreen> {
  bool _isLoading = true;
  String? _errorMessage;

  List<SolutionQuestion> _questions = [];
  Map<String, dynamic> _userAnswers = {};

  int _currentIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Filter state
  bool _showAll = true;
  bool _showIncorrectOnly = false;
  bool _showUnattemptedOnly = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      // 1. Fetch submission data (testId, answers)
      final submissionData = await SupabaseService.fetchSubmissionData(widget.submissionId);
      if (submissionData == null) throw Exception("Submission not found");

      final testId = submissionData['test_id'] as String;
      final answers = submissionData['answers'] as Map<String, dynamic>? ?? {};

      setState(() {
        _userAnswers = answers;
      });

      // 2. Fetch Test URLs
      final urls = await SupabaseService.fetchTestUrls(testId);
      final testUrl = urls['url'];
      final solutionsUrl = urls['solutions_url'];
      if (testUrl == null) throw Exception("Test data URL not found");

      // 3. Fetch Test JSON
      final testResponse = await http.get(Uri.parse(testUrl));
      if (testResponse.statusCode != 200) throw Exception("Failed to load test data");

      final testJsonMap = json.decode(testResponse.body);

      // 4. Fetch Solution JSON if available
      Map<String, dynamic> solutionsMap = {};
      if (solutionsUrl != null && solutionsUrl.isNotEmpty) {
        try {
          final solutionsResponse = await http.get(Uri.parse(solutionsUrl));
          if (solutionsResponse.statusCode == 200) {
            final solJson = json.decode(solutionsResponse.body);
            // Assuming structure { "questions": [ { "id": "q1", "solution_text": "..." } ] }
            List<dynamic> solQuestionsList = [];
            if (solJson is Map && solJson.containsKey('questions')) {
              solQuestionsList = solJson['questions'];
            } else if (solJson is List) {
              solQuestionsList = solJson;
            }

            for (var sol in solQuestionsList) {
              if (sol is Map && sol.containsKey('id')) {
                solutionsMap[sol['id'].toString()] = sol;
              }
            }
          }
        } catch (e) {
          print('Error fetching solutions: $e');
        }
      }

      // Parse questions
      // Assuming structure: { "questions": [...] } or list [...]
      List<dynamic> questionsList;
      if (testJsonMap is Map && testJsonMap.containsKey('questions')) {
        questionsList = testJsonMap['questions'];
      } else if (testJsonMap is List) {
        questionsList = testJsonMap;
      } else {
        // Fallback for some formats
        questionsList = [];
      }

      final questions = questionsList.map((q) {
        // Merge solution data if available
        final id = q['id'].toString();
        if (solutionsMap.containsKey(id)) {
          final solData = solutionsMap[id];
          if (solData['solution_text'] != null) {
            // Check if solution_image_url is present and not empty
            String? solutionText = solData['solution_text'].toString();

            // If there's an image, append it to the solution text or handle it
            // For now, let's append it as an image tag if MathHtmlRenderer supports it,
            // or we can modify SolutionQuestion to store it separately.
            // But wait, SolutionQuestion has 'solution' field.
            // The prompt says: "make sure to render the image field too inside the json which can have a non-null value so images for options should be rendered too."
            // AND "the solution to each question with a solution_url is in the tests table... check this raw url for format example"

            // The solution JSON has solution_image_url.
            // I should probably append this to the solution text or update SolutionQuestion model.
            // SolutionQuestion has `solution` (String?).

            if (solData['solution_image_url'] != null && solData['solution_image_url'].toString().isNotEmpty) {
              solutionText += '\n\n<img src="${solData['solution_image_url']}" />';
            }

            // We need to inject this into the question map before parsing
            // Or create SolutionQuestion manually.
            // It's easier to modify q map.
            // Note: q is usually an unmodifiable map if from json.decode directly sometimes? No, usually generic Map.
            // But q might be internal linked map.

            // Let's create a copy or just parse and then copyWith if we had copyWith.
            // We don't have copyWith.
            // So let's modify the map.
             Map<String, dynamic> qMap = Map<String, dynamic>.from(q);
             qMap['solution'] = solutionText;
             return SolutionQuestion.fromJson(qMap);
          }
        }
        return SolutionQuestion.fromJson(q);
      }).toList();

      if (!mounted) return;

      setState(() {
        _questions = questions;
        _isLoading = false;
      });

    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  void _nextQuestion() {
    if (_currentIndex < _questions.length - 1) {
      setState(() => _currentIndex++);
    }
  }

  void _prevQuestion() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
    }
  }

  void _jumpToQuestion(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Solutions")),
        body: Center(child: Text("Error: $_errorMessage")),
      );
    }

    if (_questions.isEmpty) {
      return const Scaffold(
        body: Center(child: Text("No questions found.")),
      );
    }

    final question = _questions[_currentIndex];
    final userAnswer = _userAnswers[question.uuid]?.toString();
    final correctAnswer = question.correctOption;

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text("Solutions Analysis"),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
          ),
        ],
      ),
      endDrawer: _buildDrawer(),
      body: Column(
        children: [
          // Header: Question Number
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: Colors.grey[100],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Question ${_currentIndex + 1} of ${_questions.length}",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                _buildStatusBadge(question, userAnswer, correctAnswer),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question Text
                  MathHtmlRenderer(
                    content: question.text,
                    textStyle: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  if (question.image != null) ...[
                    Image.network(question.image!),
                    const SizedBox(height: 16),
                  ],

                  // Options
                  ...question.options.map((option) => _buildOption(option, userAnswer, correctAnswer)),

                  const SizedBox(height: 24),

                  // Solution / Explanation
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0F7FF),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFB3D4FF)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: const [
                            Icon(Icons.lightbulb_outline, color: Color(0xFF0056D2)),
                            SizedBox(width: 8),
                            Text("Explanation", style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0056D2))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        MathHtmlRenderer(
                          content: question.solution ?? "No explanation provided.",
                          textStyle: const TextStyle(fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Footer Navigation
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: Colors.grey.shade300)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton.icon(
                  onPressed: _currentIndex > 0 ? _prevQuestion : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text("Prev"),
                ),
                ElevatedButton.icon(
                  onPressed: _currentIndex < _questions.length - 1 ? _nextQuestion : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text("Next"),
                  // Flip icon and label direction
                  style: ElevatedButton.styleFrom(
                    // To put icon on right, we use directionality or Row in child.
                    // But standard icon param puts it left. We'll leave it as is or use Directionality.
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(SolutionQuestion q, String? userAns, String? correctAns) {
    String text;
    Color color;

    if (userAns == null) {
      text = "Skipped";
      color = Colors.grey;
    } else if (userAns == correctAns) {
      text = "Correct";
      color = Colors.green;
    } else {
      text = "Incorrect";
      color = Colors.red;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  Widget _buildOption(SolutionOption option, String? userAns, String? correctAns) {
    bool isCorrect = option.id == correctAns;
    bool isSelected = option.id == userAns;

    Color borderColor = Colors.grey.shade300;
    Color bgColor = Colors.transparent;

    if (isCorrect) {
      borderColor = Colors.green;
      bgColor = Colors.green.withOpacity(0.1);
    } else if (isSelected) {
      // Selected but wrong
      borderColor = Colors.red;
      bgColor = Colors.red.withOpacity(0.1);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: (isCorrect || isSelected) ? 2 : 1),
        borderRadius: BorderRadius.circular(8),
        color: bgColor,
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.transparent),
              border: Border.all(color: isCorrect ? Colors.green : (isSelected ? Colors.red : Colors.grey)),
            ),
            child: Text(
              option.id.toUpperCase(),
              style: TextStyle(
                color: (isCorrect || isSelected) ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                MathHtmlRenderer(content: option.text),
                if (option.image != null) ...[
                  const SizedBox(height: 8),
                  Image.network(
                    option.image!,
                    errorBuilder: (context, error, stackTrace) =>
                        const Text('Failed to load image', style: TextStyle(color: Colors.red, fontSize: 10)),
                  ),
                ],
              ],
            ),
          ),
          if (isCorrect)
            const Icon(Icons.check_circle, color: Colors.green),
          if (isSelected && !isCorrect)
            const Icon(Icons.cancel, color: Colors.red),
        ],
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          const DrawerHeader(
            child: Center(
              child: Text("Question Palette", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                final q = _questions[index];
                final uAns = _userAnswers[q.uuid]?.toString();
                final cAns = q.correctOption;

                Color color;
                if (uAns == null) {
                  color = Colors.grey;
                } else if (uAns == cAns) {
                  color = Colors.green;
                } else {
                  color = Colors.red;
                }

                return InkWell(
                  onTap: () {
                    _jumpToQuestion(index);
                    Navigator.pop(context);
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.2),
                      border: Border.all(color: color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(color: color, fontWeight: FontWeight.bold),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _legendItem(Colors.green, "Correct"),
                _legendItem(Colors.red, "Wrong"),
                _legendItem(Colors.grey, "Skipped"),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
