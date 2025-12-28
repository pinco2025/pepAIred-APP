import 'package:flutter/material.dart';
import 'package:prepaired/managers/test_session_manager.dart';
import 'package:prepaired/models/test_models.dart';
import 'package:prepaired/screens/test_submitted_screen.dart';
import 'package:prepaired/widgets/common/math_html_renderer.dart';
import 'package:provider/provider.dart';

class TestScreen extends StatefulWidget {
  final Test test;

  const TestScreen({super.key, required this.test});

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  late TestSessionManager _manager;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final bool _showPalette = true;
  bool _canPop = false;

  @override
  void initState() {
    super.initState();
    _manager = TestSessionManager(widget.test);
    _manager.initialize();
  }

  @override
  void dispose() {
    _manager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _manager,
      child: Consumer<TestSessionManager>(
        builder: (context, manager, child) {
          if (manager.isLoading) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (manager.errorMessage != null) {
            return Scaffold(
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Error: ${manager.errorMessage}'),
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

          if (manager.testData == null) {
             return const Scaffold(
               body: Center(child: Text("No test data available")),
             );
          }

          return PopScope(
            canPop: _canPop,
            onPopInvoked: (didPop) async {
              if (didPop) {
                return;
              }
              final shouldPop = await showDialog<bool>(
                context: context,
                builder: (context) {
                  return AlertDialog(
                    title: const Text('Exit Test?'),
                    content: const Text(
                      'Leaving the test may cause you to lose progress. Are you sure you want to exit?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, false);
                        },
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        child: const Text('Exit'),
                      ),
                    ],
                  );
                },
              );
              if (shouldPop == true && context.mounted) {
                setState(() {
                  _canPop = true;
                });
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (context.mounted) {
                    Navigator.pop(context);
                  }
                });
              }
            },
            child: Scaffold(
            key: _scaffoldKey,
            appBar: AppBar(
              title: const _TimerWidget(),
              actions: [
                IconButton(
                  icon: const Icon(Icons.grid_view),
                  onPressed: () {
                    _scaffoldKey.currentState?.openEndDrawer();
                  },
                ),
                _SubmitButton(),
              ],
            ),
            endDrawer: const QuestionPalette(),
            body: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      // Header
                      const _QuestionHeader(),

                      // Content
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Use Selector to rebuild only when question changes
                              Selector<TestSessionManager, LocalQuestion?>(
                                selector: (_, m) => m.currentQuestion,
                                builder: (context, question, child) {
                                  if (question == null) return const SizedBox();
                                  return Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      MathHtmlRenderer(
                                        content: question.text,
                                        textStyle: const TextStyle(fontSize: 18),
                                      ),
                                      const SizedBox(height: 16),
                                      if (question.image != null)
                                        Image.network(
                                          question.image!,
                                          errorBuilder: (context, error, stackTrace) {
                                            return const Text('Failed to load image');
                                          },
                                        ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),

                              // Options List
                              const _OptionsList(),
                            ],
                          ),
                        ),
                      ),

                      // Footer
                      const _FooterControls(),
                    ],
                  ),
                ),
                if (_showPalette && MediaQuery.of(context).size.width > 800)
                  const SizedBox(width: 300, child: QuestionPalette()),
              ],
            ),
            ),
          );
        },
      ),
    );
  }
}

class _TimerWidget extends StatelessWidget {
  const _TimerWidget();

  String _formatTime(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Selector<TestSessionManager, int>(
      selector: (_, m) => m.timeLeft,
      builder: (_, timeLeft, __) => Text(_formatTime(timeLeft)),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Selector<TestSessionManager, bool>(
      selector: (_, m) => m.isSubmitting || m.isTestEnded,
      builder: (context, disabled, child) {
        return TextButton(
          onPressed: disabled
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text("Submit Test"),
                      content: const Text(
                          "Are you sure you want to submit the test?"),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text("Cancel"),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final manager = context.read<TestSessionManager>();
                            final submissionId = await manager.submitTest();
                            if (submissionId != null && context.mounted) {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (_) => TestSubmittedScreen(submissionId: submissionId),
                                ),
                              );
                            }
                          },
                          child: const Text("Submit"),
                        ),
                      ],
                    ),
                  );
                },
          child: const Text('Submit', style: TextStyle(color: Colors.red)),
        );
      },
    );
  }
}

class _QuestionHeader extends StatelessWidget {
  const _QuestionHeader();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Selector<TestSessionManager, LocalQuestion?>(
        selector: (_, m) => m.currentQuestion,
        builder: (context, question, child) {
          if (question == null) return const SizedBox();
          final manager = context.read<TestSessionManager>();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Question ${manager.currentQuestionIndex + 1} of ${manager.testData!.questions.length}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              if (question.section != null)
                Chip(label: Text(question.section!)),
            ],
          );
        },
      ),
    );
  }
}

class _OptionsList extends StatelessWidget {
  const _OptionsList();

  @override
  Widget build(BuildContext context) {
    return Consumer<TestSessionManager>(
      builder: (context, manager, child) {
        final question = manager.currentQuestion;
        if (question == null) return const SizedBox();
        final selectedAnswer = manager.answers[question.uuid];

        // Disable interaction if test ended
        final isReadOnly = manager.isTestEnded || manager.isSubmitting;

        if (question.options.isNotEmpty) {
          return Column(
            children: question.options.map((option) =>
              _OptionWidget(
                option: option,
                selectedAnswer: selectedAnswer,
                isReadOnly: isReadOnly,
                onSelected: (id) {
                  if (isReadOnly) return;
                  if (selectedAnswer == id) {
                    manager.clearAnswer(question.uuid);
                  } else {
                    manager.saveAnswer(question.uuid, id);
                  }
                },
              )
            ).toList(),
          );
        } else {
          return NumericalInputWidget(
            key: ValueKey(question.uuid),
            initialValue: selectedAnswer,
            readOnly: isReadOnly,
            onChanged: (val) {
              if (isReadOnly) return;
              if (val.isEmpty) {
                manager.clearAnswer(question.uuid);
              } else {
                manager.saveAnswer(question.uuid, val);
              }
            },
          );
        }
      },
    );
  }
}

class _FooterControls extends StatelessWidget {
  const _FooterControls();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Consumer<TestSessionManager>(
        builder: (context, manager, child) {
          if (manager.testData == null) return const SizedBox();
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ElevatedButton.icon(
                onPressed: manager.currentQuestionIndex > 0
                    ? manager.prevQuestion
                    : null,
                icon: const Icon(Icons.arrow_back),
                label: const Text("Prev"),
              ),
              ElevatedButton.icon(
                onPressed: manager.markForReview,
                icon: const Icon(Icons.bookmark_border),
                label: const Text("Review"),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange),
              ),
              ElevatedButton.icon(
                onPressed: manager.currentQuestionIndex <
                        manager.testData!.questions.length - 1
                    ? manager.nextQuestion
                    : null,
                icon: const Icon(Icons.arrow_forward),
                label: const Text("Next"),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OptionWidget extends StatelessWidget {
  final LocalOption option;
  final String? selectedAnswer;
  final Function(String) onSelected;
  final bool isReadOnly;

  const _OptionWidget({
    required this.option,
    required this.selectedAnswer,
    required this.onSelected,
    this.isReadOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final isSelected = selectedAnswer == option.id;
    return GestureDetector(
      onTap: isReadOnly ? null : () => onSelected(option.id),
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
              child: MathHtmlRenderer(
                content: option.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuestionPalette extends StatelessWidget {
  const QuestionPalette({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Consumer<TestSessionManager>(
        builder: (context, manager, child) {
          if (manager.testData == null) return const SizedBox();

          return Column(
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
                  itemCount: manager.testData!.questions.length,
                  itemBuilder: (context, index) {
                    final status = manager.questionStatuses[index] ??
                        QuestionStatus.notVisited;
                    Color color;

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
                         manager.jumpToQuestion(index);
                         Navigator.of(context).pop();
                      },
                      child: Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color == Colors.grey.shade300
                              ? Colors.transparent
                              : color.withOpacity(0.2),
                          border: Border.all(
                            color: color == Colors.grey.shade300
                                ? Colors.grey
                                : color,
                          ),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '${index + 1}',
                          style: TextStyle(
                            color: color == Colors.grey.shade300
                                ? Colors.black
                                : color,
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
          );
        },
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
  final bool readOnly;

  const NumericalInputWidget({
    super.key,
    this.initialValue,
    required this.onChanged,
    this.readOnly = false,
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
  void didUpdateWidget(NumericalInputWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialValue != oldWidget.initialValue && widget.initialValue != _controller.text) {
       _controller.text = widget.initialValue ?? '';
    }
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
          enabled: !widget.readOnly,
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
