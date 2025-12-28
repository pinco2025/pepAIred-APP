class SectionScore {
  final int score;
  final int correct;
  final int incorrect;
  final int unattempted;
  final int totalQuestions;

  SectionScore({
    required this.score,
    required this.correct,
    required this.incorrect,
    required this.unattempted,
    required this.totalQuestions,
  });

  factory SectionScore.fromJson(Map<String, dynamic> json) {
    return SectionScore(
      score: json['score'] as int,
      correct: json['correct'] as int,
      incorrect: json['incorrect'] as int,
      unattempted: json['unattempted'] as int,
      totalQuestions: json['total_questions'] as int,
    );
  }
}

class TotalStats {
  final int totalScore;
  final int totalAttempted;
  final int totalCorrect;
  final int totalWrong;
  final int totalUnattempted;

  TotalStats({
    required this.totalScore,
    required this.totalAttempted,
    required this.totalCorrect,
    required this.totalWrong,
    required this.totalUnattempted,
  });

  factory TotalStats.fromJson(Map<String, dynamic> json) {
    return TotalStats(
      totalScore: json['total_score'] as int,
      totalAttempted: json['total_attempted'] as int,
      totalCorrect: json['total_correct'] as int,
      totalWrong: json['total_wrong'] as int,
      totalUnattempted: json['total_unattempted'] as int,
    );
  }
}

class ResultSection {
  final String name;
  final int marksPerQuestion;

  ResultSection({
    required this.name,
    required this.marksPerQuestion,
  });

  factory ResultSection.fromJson(Map<String, dynamic> json) {
    return ResultSection(
      name: json['name'] as String,
      marksPerQuestion: json['marksPerQuestion'] as int,
    );
  }
}

class TestResultData {
  final String testId;
  final int totalMarks;
  final int totalQuestions;
  final List<ResultSection> sections;
  final Map<String, SectionScore> sectionScores;
  final TotalStats totalStats;

  TestResultData({
    required this.testId,
    required this.totalMarks,
    required this.totalQuestions,
    required this.sections,
    required this.sectionScores,
    required this.totalStats,
  });

  factory TestResultData.fromJson(Map<String, dynamic> json) {
    final sectionsList = (json['sections'] as List)
        .map((e) => ResultSection.fromJson(e))
        .toList();

    final sectionScoresMap = (json['section_scores'] as Map<String, dynamic>).map(
      (key, value) => MapEntry(key, SectionScore.fromJson(value)),
    );

    return TestResultData(
      testId: json['testId'] as String,
      totalMarks: json['totalMarks'] as int,
      totalQuestions: json['totalQuestions'] as int,
      sections: sectionsList,
      sectionScores: sectionScoresMap,
      totalStats: TotalStats.fromJson(json['total_stats']),
    );
  }
}
