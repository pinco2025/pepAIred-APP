import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_tex/flutter_tex.dart';
import '../models/test_models.dart';
import '../services/test_data_service.dart';
import '../services/supabase_service.dart';

class TestInterfaceScreen extends StatefulWidget {
  final Test test;

  const TestInterfaceScreen({super.key, required this.test});

  @override
  _TestInterfaceScreenState createState() => _TestInterfaceScreenState();
}

class _TestInterfaceScreenState extends State<TestInterfaceScreen> {
  LocalTest? _testData;
  int _currentQuestionIndex = 0;
  Map<String, dynamic> _answers = {};
  String? _selectedOption;
  String _numericalAnswer = '';
  int? _timeLeft;
  List<QuestionStatus> _questionStatuses = [];
  int _currentSectionIndex = 0;
  String? _studentTestId;
  bool _isSubmitting = false;
  Timer? _timer;
  bool _isLoading = true;

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
      final data = await TestDataService.fetchTestData(widget.test.url);

      final adaptedTest = LocalTest(
        id: data.testId,
        testId: data.testId,
        title: data.title,
        description: "${(data.duration / 60).floor()} minutes | ${data.totalMarks ?? 0} Marks",
        duration: data.duration,
        totalMarks: data.totalMarks ?? 0,
        totalQuestions: data.questions.length,
        markingScheme: widget.test.markingScheme,
        instructions: [
          'The test contains multiple-choice questions with a single correct answer.',
          'Each correct answer will be awarded marks as per the question.',
          'There is no negative marking for incorrect answers.',
          'Unanswered questions will receive 0 marks.',
          'You can navigate between questions and sections at any time during the test.',
          'Ensure you have a stable internet connection throughout the duration of the test.',
          'Do not close the application, as it may result in loss of progress.',
          'The test will automatically submit once the timer runs out.',
        ],
        sections: data.sections,
        questions: data.questions,
        exam: widget.test.exam,
      );

      setState(() {
        _testData = adaptedTest;
        _questionStatuses = List.filled(adaptedTest.questions.length, QuestionStatus.notVisited);
      });

      await _initializeSession(adaptedTest);

    } catch (e) {
      print('Error initializing test: $e');
      // Handle error (show dialog, go back)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to load test: $e")));
        Navigator.pop(context);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _initializeSession(LocalTest testData) async {
    final user = await SupabaseService.getCurrentUser();
    if (user == null) {
      print('User not logged in');
      return;
    }

    String? testStartTimeISO;
    final existingTest = await SupabaseService.getExistingTestSession(user.id, testData.testId);

    if (existingTest != null) {
      print('Found existing unsubmitted student test entry');
      testStartTimeISO = existingTest['started_at'];
      _studentTestId = existingTest['id'];
      if (existingTest['answers'] != null) {
         setState(() {
           _answers = Map<String, dynamic>.from(existingTest['answers']);
         });
      }
    } else {
      print('Creating new student test entry');
      final newTest = await SupabaseService.createTestSession(user.id, testData.testId);
      if (newTest != null) {
        testStartTimeISO = newTest['started_at'];
        _studentTestId = newTest['id'];
      } else {
        testStartTimeISO = DateTime.now().toIso8601String();
      }
    }

    // Start Timer
    final testDuration = testData.duration;
    final startTime = DateTime.parse(testStartTimeISO!);
    final now = DateTime.now();
    final elapsedTime = now.difference(startTime).inSeconds;
    final remainingTime = testDuration - elapsedTime;

    if (remainingTime <= 0) {
      setState(() {
        _timeLeft = 0;
      });
      // Auto submit handled in timer tick or effect
      _handleSubmit();
      return;
    }

    setState(() {
      _timeLeft = remainingTime;
    });

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft != null && _timeLeft! > 0) {
          _timeLeft = _timeLeft! - 1;
        } else {
          _timer?.cancel();
          _handleSubmit();
        }
      });
    });

    // Load from local storage if not in DB
    if (_answers.isEmpty) {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('test-answers-${testData.testId}');
      if (saved != null) {
        setState(() {
          _answers = Map<String, dynamic>.from(json.decode(saved));
        });
      }
    }
  }

  void _handleNext() {
    if (_testData == null) return;
    if (_currentQuestionIndex < _testData!.questions.length - 1) {
       // Update status of current question
      _updateStatus(_currentQuestionIndex);
      setState(() {
        _currentQuestionIndex++;
      });
    }
  }

  void _handlePrevious() {
    if (_currentQuestionIndex > 0) {
      // Update status
       _updateStatus(_currentQuestionIndex);
      setState(() {
        _currentQuestionIndex--;
      });
    }
  }

  void _updateStatus(int index) {
      if (_questionStatuses[index] == QuestionStatus.notVisited) {
          setState(() {
              _questionStatuses[index] = QuestionStatus.notAnswered;
          });
      }
  }

  void _handleSelectOption(String optionId) {
    final currentQ = _testData!.questions[_currentQuestionIndex];

    setState(() {
      if (_answers[currentQ.uuid] == optionId) {
        _answers.remove(currentQ.uuid);
        _selectedOption = null;
        _questionStatuses[_currentQuestionIndex] = QuestionStatus.notAnswered;
      } else {
        _answers[currentQ.uuid] = optionId;
        _selectedOption = optionId;
        _questionStatuses[_currentQuestionIndex] = QuestionStatus.answered;
      }
    });
    _saveProgress();
  }

  void _handleNumericalChange(String value) {
    final currentQ = _testData!.questions[_currentQuestionIndex];
    // Simple validation
    if (double.tryParse(value) != null || value.isEmpty) {
         setState(() {
             _numericalAnswer = value;
             if (value.isNotEmpty) {
                 _answers[currentQ.uuid] = value;
                 _questionStatuses[_currentQuestionIndex] = QuestionStatus.answered;
             } else {
                 _answers.remove(currentQ.uuid);
                 _questionStatuses[_currentQuestionIndex] = QuestionStatus.notAnswered;
             }
         });
         _saveProgress();
    }
  }

  void _handleMarkForReview() {
    setState(() {
      if (_questionStatuses[_currentQuestionIndex] != QuestionStatus.markedForReview) {
        _questionStatuses[_currentQuestionIndex] = QuestionStatus.markedForReview;
      } else {
        final currentQ = _testData!.questions[_currentQuestionIndex];
        _questionStatuses[_currentQuestionIndex] = _answers.containsKey(currentQ.uuid) ? QuestionStatus.answered : QuestionStatus.notAnswered;
      }
    });
  }

  Future<void> _saveProgress() async {
    if (_testData == null) return;
    // Local Storage
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('test-answers-${_testData!.testId}', json.encode(_answers));

    // DB (Debounce could be implemented here or in service, for now calling directly but maybe infrequently)
    if (_studentTestId != null) {
        // In a real app, use a debouncer
        await SupabaseService.updateAnswers(_studentTestId!, _answers);
    }
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting || _testData == null) return;

    setState(() {
      _isSubmitting = true;
    });

    try {
        if (_studentTestId == null) {
            final user = await SupabaseService.getCurrentUser();
            if (user != null) {
                final newTest = await SupabaseService.createTestSession(user.id, _testData!.testId);
                if (newTest != null) {
                    _studentTestId = newTest['id'];
                }
            }
        }

        if (_studentTestId != null) {
            final success = await SupabaseService.submitTest(_studentTestId!, _answers);
            if (success) {
                await SupabaseService.triggerScoreCalculation(_studentTestId!);

                 final prefs = await SharedPreferences.getInstance();
                 await prefs.remove('test-answers-${_testData!.testId}');

                 // Navigate to success or result screen
                 if (mounted) {
                     Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => Scaffold(
                         appBar: AppBar(title: const Text("Test Submitted")),
                         body: const Center(child: Text("Your test has been submitted successfully!")),
                     )));
                 }
            } else {
                // Show error
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Submission failed. Please try again.")));
                 }
            }
        }
    } catch (e) {
        print("Submission Error: $e");
    } finally {
        if (mounted) {
            setState(() {
                _isSubmitting = false;
            });
        }
    }
  }

  bool _isNumericalQuestion() {
    if (_testData == null) return false;
    final currentQ = _testData!.questions[_currentQuestionIndex];
    return currentQ.options.isEmpty;
  }

  // Helper to map current question to palette/section
  Map<String, int> get _sectionIndices {
      if (_testData == null) return {};
      final indices = <String, int>{};
      int count = 0;
      for (var section in _testData!.sections) {
          indices[section.name] = count;
          count += _testData!.questions.where((q) => q.section == section.name).length;
      }
      return indices;
  }

  void _handleSectionSwitch(int index) {
      final sectionName = _testData?.sections[index].name;
      if (sectionName != null && _sectionIndices.containsKey(sectionName)) {
          setState(() {
              _currentSectionIndex = index;
              _currentQuestionIndex = _sectionIndices[sectionName]!;
              _updateStatus(_currentQuestionIndex);
          });
      }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_testData == null) {
         return const Scaffold(body: Center(child: Text("Error loading test data")));
    }

    final currentQ = _testData!.questions[_currentQuestionIndex];
    _selectedOption = _answers[currentQ.uuid];
    if (_isNumericalQuestion()) {
        _numericalAnswer = _answers[currentQ.uuid]?.toString() ?? '';
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_testData!.title),
        actions: [
            Center(
                child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Text(
                        _timeLeft != null
                        ? "${(_timeLeft! ~/ 3600).toString().padLeft(2, '0')}:${((_timeLeft! % 3600) ~/ 60).toString().padLeft(2, '0')}:${(_timeLeft! % 60).toString().padLeft(2, '0')}"
                        : "--:--:--",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                ),
            )
        ],
      ),
      drawer: Drawer(
          child: Column(
              children: [
                  const DrawerHeader(child: Center(child: Text("Question Palette", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)))),
                  Expanded(
                      child: ListView(
                          children: [
                              Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: 8,
                                  children: _testData!.sections.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final section = entry.value;
                                      return ChoiceChip(
                                          label: Text(section.name),
                                          selected: _currentSectionIndex == index,
                                          onSelected: (bool selected) {
                                              if (selected) {
                                                  _handleSectionSwitch(index);
                                                  Navigator.pop(context); // Close drawer
                                              }
                                          },
                                      );
                                  }).toList(),
                              ),
                              const Divider(),
                              Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    alignment: WrapAlignment.center,
                                    children: List.generate(_testData!.questions.length, (index) {
                                        // Check if question belongs to current section to highlight or filter?
                                        // The react app filters by section in palette.
                                        final q = _testData!.questions[index];
                                        final currentSectionName = _testData!.sections[_currentSectionIndex].name;
                                        if (q.section != currentSectionName) return const SizedBox.shrink();

                                        Color color = Colors.grey.shade300;
                                        if (_questionStatuses[index] == QuestionStatus.answered) {
                                          color = Colors.green.shade200;
                                        } else if (_questionStatuses[index] == QuestionStatus.notAnswered) color = Colors.red.shade200;
                                        else if (_questionStatuses[index] == QuestionStatus.markedForReview) color = Colors.purple.shade200;

                                        return InkWell(
                                            onTap: () {
                                                setState(() {
                                                    _currentQuestionIndex = index;
                                                    _updateStatus(index);
                                                });
                                                Navigator.pop(context);
                                            },
                                            child: Container(
                                                width: 40,
                                                height: 40,
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                    color: color,
                                                    border: _currentQuestionIndex == index ? Border.all(color: Colors.blue, width: 2) : null,
                                                    borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text("${index + 1}"),
                                            ),
                                        );
                                    }),
                                ),
                              )
                          ],
                      ),
                  ),
                  Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: ElevatedButton(
                          style: ElevatedButton.styleFrom(minimumSize: const Size.fromHeight(50), backgroundColor: Colors.blue),
                          onPressed: () {
                              // Show confirmation dialog
                              showDialog(context: context, builder: (ctx) => AlertDialog(
                                  title: const Text("Submit Test"),
                                  content: const Text("Are you sure you want to submit?"),
                                  actions: [
                                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                      TextButton(onPressed: () {
                                          Navigator.pop(ctx);
                                          _handleSubmit();
                                      }, child: const Text("Submit")),
                                  ],
                              ));
                          },
                          child: const Text("Submit Test", style: TextStyle(color: Colors.white)),
                      ),
                  )
              ],
          ),
      ),
      body: Column(
        children: [
            // Question Area
            Expanded(
                child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                    Text("Question ${_currentQuestionIndex + 1}", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                                    Chip(label: Text(currentQ.section ?? "General")),
                                ],
                            ),
                            const SizedBox(height: 16),
                            // Question Text (Latex)
                            TeXView(
                                child: TeXViewColumn(children: [
                                    TeXViewDocument(currentQ.text, style: const TeXViewStyle(contentColor: Colors.black, fontStyle: TeXViewFontStyle(fontSize: 18))),
                                ]),
                            ),
                            if (currentQ.image != null)
                                Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                                    child: Image.network(currentQ.image!),
                                ),
                            const SizedBox(height: 24),
                            // Options or Numerical Input
                            if (_isNumericalQuestion()) ...[
                                const Text("Enter Numerical Answer:", style: TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 8),
                                TextField(
                                    controller: TextEditingController(text: _numericalAnswer),
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                    onChanged: _handleNumericalChange,
                                    decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        hintText: "Enter answer",
                                    ),
                                )
                            ] else ...[
                                ...currentQ.options.map((option) {
                                    final isSelected = _selectedOption == option.id;
                                    return Card(
                                        color: isSelected ? Colors.blue.withOpacity(0.1) : null,
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(8),
                                            side: BorderSide(color: isSelected ? Colors.blue : Colors.grey.shade300),
                                        ),
                                        child: InkWell(
                                            onTap: () => _handleSelectOption(option.id),
                                            child: Padding(
                                                padding: const EdgeInsets.all(12.0),
                                                child: Row(
                                                    children: [
                                                        Container(
                                                            width: 30,
                                                            height: 30,
                                                            alignment: Alignment.center,
                                                            decoration: BoxDecoration(
                                                                color: isSelected ? Colors.blue : Colors.transparent,
                                                                border: Border.all(color: Colors.blue),
                                                                shape: BoxShape.circle,
                                                            ),
                                                            child: Text(option.id.toUpperCase(), style: TextStyle(color: isSelected ? Colors.white : Colors.blue, fontWeight: FontWeight.bold)),
                                                        ),
                                                        const SizedBox(width: 12),
                                                        Expanded(
                                                            child: Column(
                                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                                children: [
                                                                    TeXView(
                                                                        child: TeXViewDocument(option.text),
                                                                    ),
                                                                    if (option.image != null)
                                                                        Image.network(option.image!),
                                                                ],
                                                            ),
                                                        ),
                                                    ],
                                                ),
                                            ),
                                        ),
                                    );
                                }),
                            ]
                        ],
                    ),
                ),
            ),
            // Bottom Bar
            Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
                ),
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                        ElevatedButton.icon(
                            onPressed: _currentQuestionIndex > 0 ? _handlePrevious : null,
                            icon: const Icon(Icons.arrow_back),
                            label: const Text("Prev"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade200, foregroundColor: Colors.black),
                        ),
                        ElevatedButton.icon(
                            onPressed: _handleMarkForReview,
                            icon: Icon(_questionStatuses[_currentQuestionIndex] == QuestionStatus.markedForReview ? Icons.bookmark : Icons.bookmark_border),
                            label: const Text("Review"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.withOpacity(0.1), foregroundColor: Colors.orange),
                        ),
                        ElevatedButton.icon(
                            onPressed: _currentQuestionIndex < _testData!.questions.length - 1 ? _handleNext : null,
                            icon: const Icon(Icons.arrow_forward),
                            label: const Text("Next"),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
                        ),
                    ],
                ),
            ),
        ],
      ),
    );
  }
}
