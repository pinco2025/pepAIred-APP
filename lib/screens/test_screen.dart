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
  Timer? _debounceTimer;
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
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeTest() async {
    try {
      // 1. Fetch Test Data JSON
      final localTest = await TestDataService.fetchTestData(widget.test.url);

      // 2. Initialize Session (Create or Resume)
      final user = await SupabaseService.getCurrentUser();
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Please login to continue')),
          );
          Navigator.of(context).pop();
        }
        return;
      }

      final existingSession = await SupabaseService.getExistingTestSession(user.id, widget.test.id);

      String sessionId;
      DateTime startTime;
      Map<String, dynamic> savedAnswers = {};

      if (existingSession != null) {
        sessionId = existingSession['id'];
        startTime = DateTime.parse(existingSession['started_at']).toUtc();
        if (existingSession['answers'] != null) {
          savedAnswers = Map<String, dynamic>.from(existingSession['answers']);
        }
      } else {
        final newSession = await SupabaseService.createTestSession(user.id, widget.test.id);
        if (newSession != null) {
          sessionId = newSession['id'];
          startTime = DateTime.parse(newSession['started_at']).toUtc();
        } else {
          throw Exception('Failed to create test session');
        }
      }

      // 3. Initialize Timer (Use UTC)
      final durationSeconds = localTest.duration;
      final nowUtc = DateTime.now().toUtc();
      final elapsedTime = nowUtc.difference(startTime).inSeconds;
      final remainingTime = durationSeconds - elapsedTime;

      if (remainingTime <= 0) {
        // Time expired - submit immediately
        _timeLeft = 0;
        if (mounted) {
          await _submitTest();
        }
        return;
      } else {
        _timeLeft = remainingTime;
        _startTimer();
      }

      // 4. Load Answers
      final loadedAnswers = <String, String>{};
      savedAnswers.forEach((key, value) {
        loadedAnswers[key] = value.toString();
      });

      // 5. Initialize question statuses
      final statuses = <int, QuestionStatus>{};
      for (int i = 0; i < localTest.questions.length; i++) {
        final qUuid = localTest.questions[i].uuid;
        if (loadedAnswers.containsKey(qUuid)) {
          statuses[i] = QuestionStatus.answered;
        } else {
          statuses[i] = QuestionStatus.notVisited;
        }
      }
      
      // Mark first question as visited (but don't override if it's already answered)
      if (statuses[0] != QuestionStatus.answered) {
        statuses[0] = QuestionStatus.notAnswered;
      }

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
        if (mounted) {
          setState(() {
            _timeLeft--;
          });
        }
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
            Navigator.of(context).pop();
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

    // Debounced save to DB
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_studentTestId != null) {
        print("Saving answers for session $_studentTestId: $_answers");
        SupabaseService.updateAnswers(_studentTestId!, _answers);
      }
    });
  }

  void _clearAnswer(String questionUuid) {
    setState(() {
      _answers.remove(questionUuid);
      final currentStatus = _questionStatuses[_currentQuestionIndex];
      // Don't change status if it's marked for review
      if (currentStatus != QuestionStatus.markedForReview) {
        _questionStatuses[_currentQuestionIndex] = QuestionStatus.notAnswered;
      }
    });
    
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_studentTestId != null) {
        print("Saving answers (cleared) for session $_studentTestId: $_answers");
        SupabaseService.updateAnswers(_studentTestId!, _answers);
      }
    });
  }

  void _markForReview() {
    setState(() {
      _questionStatuses[_currentQuestionIndex] = QuestionStatus.markedForReview;
    });
  }

  void _nextQuestion() {
    if (_testData != null && _currentQuestionIndex < _testData!.questions.length - 1) {
      setState(() {
        final nextIndex = _currentQuestionIndex + 1;
        // Only mark as notAnswered if not visited and not already answered
        if (_questionStatuses[nextIndex] == QuestionStatus.notVisited) {
          _questionStatuses[nextIndex] = QuestionStatus.notAnswered;
        }
        _currentQuestionIndex = nextIndex;
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

  void _jumpToQuestion(int index) {
    setState(() {
      // Mark the question as visited if not visited before
      if (_questionStatuses[index] == QuestionStatus.notVisited) {
        final qUuid = _testData!.questions[index].uuid;
        if (_answers.containsKey(qUuid)) {
          _questionStatuses[index] = QuestionStatus.answered;
        } else {
          _questionStatuses[index] = QuestionStatus.notAnswered;
        }
      }
      _currentQuestionIndex = index;
      _showPalette = false; // Close drawer on navigation
    });
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
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Failed to load test data'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final question = _testData!.questions[_currentQuestionIndex];
    final selectedAnswer = _answers[question.uuid];

    return Scaffold(
      key: _scaffoldKey, // Used to open drawer
      appBar: AppBar(
        title: Text(_formatTime(_timeLeft)),
        leading: Builder(
          builder: (context) => IconButton(
             icon: const Icon(Icons.menu),
             onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.grid_view),
            onPressed: () {
               _scaffoldKey.currentState?.openDrawer();
            },
          ),
          TextButton(
            onPressed: _isSubmitting ? null : () {
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
      drawer: _buildQuestionPalette(),
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
                          key: ValueKey(question.uuid), // Force rebuild on question change
                          child: TeXViewColumn(children: [
                             TeXViewDocument(
                               question.text,
                               style: TeXViewStyle(
                                 contentColor: Colors.black,
                                 fontStyle: TeXViewFontStyle(fontSize: 18),
                               ),
                             ),
                             if (question.image != null)
                               TeXViewImage.network(question.image!),
                           ]),
                           loadingWidgetBuilder: (context) => const Center(child: CircularProgressIndicator()),
                        ),
                        const SizedBox(height: 24),

                        // Options or Input
                        if (question.options.isNotEmpty)
                          ...question.options.map((option) => _buildOption(option, selectedAnswer))
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
                        onPressed: _currentQuestionIndex < _testData!.questions.length - 1 
                            ? _nextQuestion 
                            : null,
                        icon: const Icon(Icons.arrow_forward),
                        label: const Text("Next"),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (MediaQuery.of(context).size.width > 800) // Show sidebar only on large screens
             SizedBox(width: 300, child: _buildQuestionPalette()),
        ],
      ),
    );
  }

  // Key for accessing scaffold to open drawer
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

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
                border: Border.all(
                  color: isSelected ? const Color(0xFF4C6FFF) : Colors.grey,
                ),
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
              // Using TeXWidget (which uses TeX2SVG) to avoid heavy WebViews for options
              child: TeX2SVG(
                 math: option.text,
                 style: TeXViewStyle(
                   contentColor: isSelected ? Colors.black : Colors.black,
                   // Note: TeX2SVG doesn't support full style like TeXView, but TeXViewStyle is accepted by some widgets.
                   // TeX2SVG accepts style for the container? No, it usually takes 'math' and 'style' params if it's a wrapper,
                   // but let's check standard flutter_tex usage.
                   // Actually TeX2SVG is a widget.
                 ),
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
          const DrawerHeader(
            child: Center(
              child: Text(
                "Question Palette",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
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
              itemCount: _testData!.questions.length,
              itemBuilder: (context, index) {
                final status = _questionStatuses[index] ?? QuestionStatus.notVisited;
                Color color;
                
                // Fixed switch statement with proper assignment
                switch (status) {
                  case QuestionStatus.answered:
                    color = Colors.green;
                    break;
                  case QuestionStatus.notAnswered:
                    color = Colors.red;
                    break;
                  case QuestionStatus.markedForReview:
                    color = Colors.purple;
                    break;
                  default:
                    color = Colors.grey.shade300;
                }

                return InkWell(
                  onTap: () {
                    _jumpToQuestion(index);
                    if (Navigator.canPop(context)) Navigator.pop(context); // Close drawer on mobile
                  },
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color == Colors.grey.shade300 
                          ? Colors.transparent 
                          : color.withOpacity(0.2),
                      border: Border.all(
                        color: color == Colors.grey.shade300 ? Colors.grey : color,
                      ),
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

  const NumericalInputWidget({
    super.key,
    this.initialValue,
    required this.onChanged,
  });

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
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          "Enter Numerical Answer:",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          keyboardType: const TextInputType.numberWithOptions(
            decimal: true,
            signed: true,
          ),
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Type your answer here...",
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}