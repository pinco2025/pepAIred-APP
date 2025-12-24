import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:prepaired/models/test_models.dart';
import 'package:prepaired/services/supabase_service.dart';
import 'package:prepaired/services/test_data_service.dart';
import 'package:flutter_tex/flutter_tex.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TestScreen extends StatefulWidget {
  final Test test;

  const TestScreen({super.key, required this.test});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  bool _isLoading = true;
  LocalTest? _testData;
  String? _studentTestId;

  // State variables for the test
  int _currentQuestionIndex = 0;
  Map<String, String> _answers = {}; // question uuid -> answer
  Map<int, QuestionStatus> _questionStatuses = {};
  int _timeLeft = 0;
  Timer? _timer;
  bool _isSubmitting = false;

  // Question Palette
  bool _showPalette = false;

  @override
  void initState() {
    super.initState();
    _initializeTest();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    try {
      // 1. Fetch Test Data JSON
      final localTest = await TestDataService.fetchTestData(widget.test.url);

      // 2. Initialize Session (Create or Resume)
      final user = await SupabaseService.getCurrentUser();
      if (user == null) {
        // Handle unauthenticated state
        return;
      }

      final existingSession = await SupabaseService.getExistingTestSession(user.id, widget.test.id);

      String sessionId;
      DateTime startTime;
      Map<String, dynamic> savedAnswers = {};

      if (existingSession != null) {
        sessionId = existingSession['id'];
        startTime = DateTime.parse(existingSession['started_at']);
        if (existingSession['answers'] != null) {
          savedAnswers = Map<String, dynamic>.from(existingSession['answers']);
        }
      } else {
        final newSession = await SupabaseService.createTestSession(user.id, widget.test.id);
        if (newSession != null) {
          sessionId = newSession['id'];
          startTime = DateTime.parse(newSession['started_at']);
        } else {
          // Fallback if DB fails?
          sessionId = 'temp';
          startTime = DateTime.now();
        }
      }

      // 3. Initialize Timer
      final durationSeconds = localTest.duration; // It's in seconds based on web code (duration from JSON seems to be seconds if > 60 usually, web code divides by 60 for minutes display)
      // Web code: `description: ${Math.floor((data.duration ?? 0) / 60)} minutes`
      // Web code timer: `let remainingTime = testDuration - elapsedTime;`
      // `LocalTest.duration` in flutter model parses to int.

      final elapsedTime = DateTime.now().difference(startTime).inSeconds;
      final remainingTime = durationSeconds - elapsedTime;

      if (remainingTime <= 0) {
        // Time expired
        _timeLeft = 0;
        // Should submit immediately
      } else {
        _timeLeft = remainingTime;
        _startTimer();
      }

      // 4. Load Answers
      // Prioritize DB answers, then LocalStorage (if we want to implement that fallback)
      final loadedAnswers = <String, String>{};
      savedAnswers.forEach((key, value) {
        loadedAnswers[key] = value.toString();
      });

      // Initialize question statuses
      final statuses = <int, QuestionStatus>{};
      for (int i = 0; i < (localTest.questions.length); i++) {
        final qUuid = localTest.questions[i].uuid;
        if (loadedAnswers.containsKey(qUuid)) {
          statuses[i] = QuestionStatus.answered;
        } else {
          statuses[i] = QuestionStatus.notVisited; // or notAnswered if we visited
        }
      }
      statuses[0] = QuestionStatus.notAnswered; // Current is visited

      if (mounted) {
        setState(() {
          _testData = localTest;
          _studentTestId = sessionId;
          _answers = loadedAnswers;
          _questionStatuses = statuses;
          _isLoading = false;
        });
      }

    } catch (e) {
      print('Error initializing test: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading test: $e')),
        );
      }
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 0) {
        timer.cancel();
        _submitTest();
      } else {
        setState(() {
          _timeLeft--;
        });
      }
    });
  }

  Future<void> _submitTest() async {
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
      if (_studentTestId != null) {
        final success = await SupabaseService.submitTest(_studentTestId!, _answers);
        if (success) {
            await SupabaseService.triggerScoreCalculation(_studentTestId!);
            if (mounted) {
                // Navigate to result or success page
                Navigator.of(context).pop(); // Go back for now, or replace with ResultScreen
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Test Submitted Successfully!')),
                );
            }
        } else {
            throw Exception('Submission failed');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error submitting test: $e')),
        );
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _saveAnswer(String questionUuid, String answer) {
    setState(() {
      _answers[questionUuid] = answer;
      _questionStatuses[_currentQuestionIndex] = QuestionStatus.answered;
    });

    // Debounced save to DB (simplified here: just call it, maybe optimize later)
    if (_studentTestId != null) {
      SupabaseService.updateAnswers(_studentTestId!, _answers);
    }
  }

  void _clearAnswer(String questionUuid) {
    setState(() {
      _answers.remove(questionUuid);
      _questionStatuses[_currentQuestionIndex] = QuestionStatus.notAnswered;
    });
     if (_studentTestId != null) {
      SupabaseService.updateAnswers(_studentTestId!, _answers);
    }
  }

  void _markForReview() {
    setState(() {
        _questionStatuses[_currentQuestionIndex] = QuestionStatus.markedForReview;
    });
  }

  void _nextQuestion() {
    if (_testData != null && _currentQuestionIndex < _testData!.questions.length - 1) {
      setState(() {
        if (_questionStatuses[_currentQuestionIndex + 1] == QuestionStatus.notVisited) {
            _questionStatuses[_currentQuestionIndex + 1] = QuestionStatus.notAnswered;
        }
        _currentQuestionIndex++;
      });
    }
  }

  void _prevQuestion() {
    if (_currentQuestionIndex > 0) {
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_testData == null) {
      return const Scaffold(
        body: Center(child: Text('Failed to load test data')),
      );
    }

    final question = _testData!.questions[_currentQuestionIndex];
    final selectedAnswer = _answers[question.uuid];

    return Scaffold(
      appBar: AppBar(
        title: Text(_formatTime(_timeLeft)),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () {
              setState(() {
                _showPalette = !_showPalette;
              });
            },
          ),
          TextButton(
            onPressed: () {
                 showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Submit Test"),
                      content: const Text("Are you sure you want to submit the test?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            _submitTest();
                          },
                          child: const Text("Submit"),
                        ),
                      ],
                    ),
                  );
            },
            child: const Text('Submit', style: TextStyle(color: Colors.red)),
          )
        ],
      ),
      drawer: _showPalette ? _buildQuestionPalette() : null,
      body: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                // Question Header
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Question ${_currentQuestionIndex + 1} of ${_testData!.questions.length}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      if (question.section != null)
                        Chip(label: Text(question.section!)),
                    ],
                  ),
                ),

                // Question Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         TeXView(
                          renderingEngine: const TeXViewRenderingEngine.katex(),
                          child: TeXViewColumn(children: [
                            TeXViewDocument(question.text,
                                style: const TeXViewStyle(
                                    contentColor: Colors.black,
                                    fontStyle: TeXViewFontStyle(fontSize: 18))),
                          ]),
                        ),
                        const SizedBox(height: 16),
                        if (question.image != null)
                           Image.network(question.image!),
                        const SizedBox(height: 24),

                        // Options or Input
                        if (question.options.isNotEmpty)
                          ...question.options.map((option) => _buildOption(option, selectedAnswer)).toList()
                        else
                          NumericalInputWidget(
                            key: ValueKey(question.uuid),
                            initialValue: selectedAnswer,
                            onChanged: (val) {
                                if (val.isEmpty) {
                                    _clearAnswer(question.uuid);
                                } else {
                                    _saveAnswer(question.uuid, val);
                                }
                            },
                          ),
                      ],
                    ),
                  ),
                ),

                // Footer Controls
                Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.grey.shade300)),
                    ),
                    child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                            ElevatedButton.icon(
                                onPressed: _currentQuestionIndex > 0 ? _prevQuestion : null,
                                icon: const Icon(Icons.arrow_back),
                                label: const Text("Prev"),
                            ),
                            ElevatedButton.icon(
                                onPressed: _markForReview,
                                icon: const Icon(Icons.bookmark_border),
                                label: const Text("Review"),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                            ),
                             ElevatedButton.icon(
                                onPressed: _currentQuestionIndex < _testData!.questions.length - 1 ? _nextQuestion : null,
                                icon: const Icon(Icons.arrow_forward),
                                label: const Text("Next"),
                            ),
                        ],
                    ),
                ),
              ],
            ),
          ),
          if (_showPalette && MediaQuery.of(context).size.width > 600) // Permanent sidebar on large screens
            SizedBox(width: 300, child: _buildQuestionPalette()),
        ],
      ),
    );
  }

  Widget _buildOption(LocalOption option, String? selectedId) {
    final isSelected = selectedId == option.id;
    return GestureDetector(
        onTap: () {
            if (isSelected) {
                _clearAnswer(_testData!.questions[_currentQuestionIndex].uuid);
            } else {
                _saveAnswer(_testData!.questions[_currentQuestionIndex].uuid, option.id);
            }
        },
        child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                border: Border.all(
                    color: isSelected ? const Color(0xFF4C6FFF) : Colors.grey.shade300,
                    width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? const Color(0xFF4C6FFF).withOpacity(0.1) : null,
            ),
            child: Row(
                children: [
                    Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected ? const Color(0xFF4C6FFF) : Colors.transparent,
                            border: Border.all(color: isSelected ? const Color(0xFF4C6FFF) : Colors.grey),
                        ),
                        child: Text(
                            option.id.toUpperCase(),
                            style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black,
                                fontWeight: FontWeight.bold,
                            ),
                        ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                         child: TeXView(
                          renderingEngine: const TeXViewRenderingEngine.katex(),
                          child: TeXViewDocument(option.text),
                        ),
                    ),
                ],
            ),
        ),
    );
  }

  Widget _buildQuestionPalette() {
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(child: Center(child: Text("Question Palette"))),
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: _testData!.questions.length,
              itemBuilder: (context, index) {
                final status = _questionStatuses[index] ?? QuestionStatus.notVisited;
                Color color;
                switch (status) {
                  case QuestionStatus.answered:
                    color: Colors.green;
                    break;
                  case QuestionStatus.notAnswered:
                    color: Colors.red;
                    break;
                  case QuestionStatus.markedForReview:
                    color: Colors.purple;
                    break;
                  default:
                    color: Colors.grey.shade300;
                }

                return InkWell(
                  onTap: () {
                    setState(() {
                      _currentQuestionIndex = index;
                      _showPalette = false; // Close drawer on mobile
                    });
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color == Colors.grey.shade300 ? Colors.transparent : color.withOpacity(0.2),
                      border: Border.all(color: color == Colors.grey.shade300 ? Colors.grey : color),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: color == Colors.grey.shade300 ? Colors.black : color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.center,
              children: [
                  _legendItem(Colors.green, "Answered"),
                  _legendItem(Colors.red, "Not Answered"),
                  _legendItem(Colors.purple, "Review"),
                  _legendItem(Colors.grey, "Not Visited"),
              ],
            ),
            const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
      return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
              Container(width: 12, height: 12, color: color),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10)),
          ],
      );
  }
}

class NumericalInputWidget extends StatefulWidget {
  final String? initialValue;
  final ValueChanged<String> onChanged;

  const NumericalInputWidget({super.key, this.initialValue, required this.onChanged});

  @override
  State<NumericalInputWidget> createState() => _NumericalInputWidgetState();
}

class _NumericalInputWidgetState extends State<NumericalInputWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant NumericalInputWidget oldWidget) {
      super.didUpdateWidget(oldWidget);
      if (widget.initialValue != _controller.text) {
           // Only update if the value is different to avoid cursor jumping if we were to push back updates
           // But here initialValue comes from parent state, which is updated by onChanged.
           // If we type "1", onChanged fires, parent updates state to "1", passes "1" back.
           // _controller.text is already "1". So no change.
           // If we navigate away and back, Key changes, so new State, new InitState.

           // However, if we receive an update from somewhere else (unlikely here), we might need this.
           // For now, let's just respect initialValue if it differs significantly, but be careful with cursor.
           if (widget.initialValue != null && widget.initialValue != _controller.text) {
               _controller.text = widget.initialValue!;
           }
      }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("Enter Numerical Answer:", style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Type your answer here...",
          ),
          onChanged: widget.onChanged,
          onSubmitted: widget.onChanged,
        ),
      ],
    );
  }
}
