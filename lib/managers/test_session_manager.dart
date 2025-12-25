import 'dart:async';
import 'package:flutter/material.dart';
import 'package:prepaired/models/test_models.dart';
import 'package:prepaired/services/supabase_service.dart';
import 'package:prepaired/services/test_data_service.dart';

class TestSessionManager extends ChangeNotifier {
  final Test test;

  LocalTest? _testData;
  String? _studentTestId;

  // State variables
  bool _isLoading = true;
  String? _errorMessage;
  int _currentQuestionIndex = 0;
  Map<String, String> _answers = {}; // question uuid -> answer
  Map<int, QuestionStatus> _questionStatuses = {};
  int _timeLeft = 0;
  Timer? _timer;
  Timer? _debounceTimer;
  bool _isSubmitting = false;
  bool _isTestEnded = false;

  // Getters
  LocalTest? get testData => _testData;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get timeLeft => _timeLeft;
  bool get isSubmitting => _isSubmitting;
  bool get isTestEnded => _isTestEnded;
  Map<String, String> get answers => _answers;
  Map<int, QuestionStatus> get questionStatuses => _questionStatuses;

  LocalQuestion? get currentQuestion =>
      _testData != null ? _testData!.questions[_currentQuestionIndex] : null;

  TestSessionManager(this.test);

  @override
  void dispose() {
    _timer?.cancel();
    _debounceTimer?.cancel();
    super.dispose();
  }

  Future<void> initialize() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Fetch Test Data JSON
      final localTest = await TestDataService.fetchTestData(test.url)
          .timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Failed to fetch test data: Timeout');
      });

      // 2. Initialize Session (Create or Resume)
      final user = await SupabaseService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }

      final existingSession = await SupabaseService.getExistingTestSession(
              user.id, test.id)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('Failed to fetch session: Timeout');
      });

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
        final newSession = await SupabaseService.createTestSession(
                user.id, test.id)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          throw TimeoutException('Failed to create session: Timeout');
        });

        if (newSession != null) {
          sessionId = newSession['id'];
          startTime = DateTime.parse(newSession['started_at']);
        } else {
          throw Exception('Failed to create test session');
        }
      }

      // 3. Initialize Timer
      final durationSeconds = localTest.duration;
      final nowUtc = DateTime.now().toUtc();
      final elapsedTime = nowUtc.difference(startTime.toUtc()).inSeconds;
      final remainingTime = durationSeconds - elapsedTime;

      _timeLeft = remainingTime > 0 ? remainingTime : 0;

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

      // Mark first question as not answered if not already answered
      if (statuses[0] != QuestionStatus.answered) {
        statuses[0] = QuestionStatus.notAnswered;
      }

      _testData = localTest;
      _studentTestId = sessionId;
      _answers = loadedAnswers;
      _questionStatuses = statuses;
      _isLoading = false;

      if (_timeLeft > 0) {
        _startTimer();
      } else {
        _isTestEnded = true;
        // If loaded with 0 time, we can attempt to submit to finalize.
        // We use scheduleMicrotask or just call it, but safely.
        // We set isTestEnded = true so UI blocks interaction.
      }

      notifyListeners();

      if (_timeLeft <= 0) {
         submitTest();
      }

    } catch (e) {
      print('Error initializing test: $e');
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeLeft <= 0) {
        timer.cancel();
        _isTestEnded = true;
        notifyListeners();
        submitTest();
      } else {
        _timeLeft--;
        notifyListeners();
      }
    });
  }

  Future<bool> submitTest() async {
    if (_isSubmitting) return false;

    _isSubmitting = true;
    notifyListeners();

    try {
      if (_studentTestId != null) {
        final success = await SupabaseService.submitTest(_studentTestId!, _answers);
        if (success) {
          await SupabaseService.triggerScoreCalculation(_studentTestId!);
          return true;
        } else {
          throw Exception('Submission failed');
        }
      }
      return false;
    } catch (e) {
      print('Error submitting test: $e');
      _isSubmitting = false;
      notifyListeners();
      return false;
    }
  }

  void saveAnswer(String questionUuid, String answer) {
    if (_isTestEnded || _isSubmitting) return;

    _answers[questionUuid] = answer;
    _questionStatuses[_currentQuestionIndex] = QuestionStatus.answered;
    notifyListeners();

    // Debounced save to DB
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_studentTestId != null) {
        SupabaseService.updateAnswers(_studentTestId!, _answers);
      }
    });
  }

  void clearAnswer(String questionUuid) {
    if (_isTestEnded || _isSubmitting) return;

    _answers.remove(questionUuid);
    final currentStatus = _questionStatuses[_currentQuestionIndex];
    if (currentStatus != QuestionStatus.markedForReview) {
      _questionStatuses[_currentQuestionIndex] = QuestionStatus.notAnswered;
    }
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      if (_studentTestId != null) {
        SupabaseService.updateAnswers(_studentTestId!, _answers);
      }
    });
  }

  void markForReview() {
    _questionStatuses[_currentQuestionIndex] = QuestionStatus.markedForReview;
    notifyListeners();
  }

  void nextQuestion() {
    if (_testData != null && _currentQuestionIndex < _testData!.questions.length - 1) {
      final nextIndex = _currentQuestionIndex + 1;
      if (_questionStatuses[nextIndex] == QuestionStatus.notVisited) {
        _questionStatuses[nextIndex] = QuestionStatus.notAnswered;
      }
      _currentQuestionIndex = nextIndex;
      notifyListeners();
    }
  }

  void prevQuestion() {
    if (_currentQuestionIndex > 0) {
      _currentQuestionIndex--;
      notifyListeners();
    }
  }

  void jumpToQuestion(int index) {
    if (_testData != null && index >= 0 && index < _testData!.questions.length) {
       if (_questionStatuses[index] == QuestionStatus.notVisited) {
        final qUuid = _testData!.questions[index].uuid;
        if (_answers.containsKey(qUuid)) {
          _questionStatuses[index] = QuestionStatus.answered;
        } else {
          _questionStatuses[index] = QuestionStatus.notAnswered;
        }
      }
      _currentQuestionIndex = index;
      notifyListeners();
    }
  }
}
