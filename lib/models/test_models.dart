enum QuestionStatus {
  answered,
  notAnswered,
  markedForReview,
  notVisited,
}

class LocalOption {
  final String id;
  final String text;
  final String? image;

  LocalOption({
    required this.id,
    required this.text,
    this.image,
  });

  factory LocalOption.fromJson(Map<String, dynamic> json) {
    return LocalOption(
      id: json['id'] as String,
      text: json['text'] as String,
      image: (json['image'] != null &&
              json['image'] != 0 &&
              json['image'] != "0")
          ? json['image'].toString()
          : null,
    );
  }
}

class LocalQuestion {
  final String id;
  final String uuid;
  final String text;
  final String? image;
  final List<LocalOption> options;
  final String? section;

  LocalQuestion({
    required this.id,
    required this.uuid,
    required this.text,
    this.image,
    required this.options,
    this.section,
  });

  factory LocalQuestion.fromJson(Map<String, dynamic> json) {
    return LocalQuestion(
      id: json['id'] as String,
      uuid: json['uuid'] as String,
      text: json['text'] as String,
      image: (json['image'] != null &&
              json['image'] != 0 &&
              json['image'] != "0")
          ? json['image'].toString()
          : null,
      options: (json['options'] as List?)
              ?.map((e) => LocalOption.fromJson(e))
              .toList() ??
          [],
      section: json['section'] as String?,
    );
  }
}

class LocalSection {
  final String name;

  LocalSection({required this.name});

  factory LocalSection.fromJson(Map<String, dynamic> json) {
    return LocalSection(
      name: json['name'] as String,
    );
  }
}

class LocalTest {
  final String id;
  final String testId;
  final String title;
  final String? description;
  final int duration;
  final int? totalMarks;
  final int? totalQuestions;
  final String? markingScheme;
  final List<String>? instructions;
  final List<LocalSection> sections;
  final List<LocalQuestion> questions;
  final String? exam;

  LocalTest({
    required this.id,
    required this.testId,
    required this.title,
    this.description,
    required this.duration,
    this.totalMarks,
    this.totalQuestions,
    this.markingScheme,
    this.instructions,
    required this.sections,
    required this.questions,
    this.exam,
  });

  factory LocalTest.fromJson(Map<String, dynamic> json) {
    return LocalTest(
      id: json['id'] as String? ?? json['testId'] as String,
      testId: json['testId'] as String? ?? json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      duration: json['duration'] is String
          ? int.tryParse(json['duration']) ?? 0
          : json['duration'] as int? ?? 0,
      totalMarks: json['totalMarks'] as int?,
      totalQuestions: (json['questions'] as List?)?.length,
      markingScheme: json['markingScheme'] as String?,
      instructions: (json['instructions'] as List?)
          ?.map((e) => e.toString())
          .toList(),
      sections: (json['sections'] as List?)
              ?.map((e) => LocalSection.fromJson(e))
              .toList() ??
          [],
      questions: (json['questions'] as List?)
              ?.map((e) => LocalQuestion.fromJson(e))
              .toList() ??
          [],
      exam: json['exam'] as String?,
    );
  }
}

// Represents the metadata row from Supabase 'tests' table
class Test {
  final String id; // maps to testID
  final String title;
  final String description;
  final int duration;
  final int totalQuestions;
  final String markingScheme;
  final List<String> instructions;
  final String url;
  final String category;
  final String? exam;

  Test({
    required this.id,
    required this.title,
    required this.description,
    required this.duration,
    required this.totalQuestions,
    required this.markingScheme,
    required this.instructions,
    required this.url,
    required this.category,
    this.exam,
  });

  factory Test.fromJson(Map<String, dynamic> json) {
    return Test(
      id: json['testID'] as String,
      title: json['title'] as String,
      description: json['description'] as String? ?? '',
      duration: json['duration'] as int? ?? 0,
      totalQuestions: json['totalQuestions'] as int? ?? 0,
      markingScheme: json['markingScheme'] as String? ?? '',
      instructions: (json['instructions'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      url: json['url'] as String,
      category: json['category'] as String? ?? 'General',
      exam: json['exam'] as String?,
    );
  }
}

class TestCategory {
  final String title;
  final List<Test> tests;

  TestCategory({
    required this.title,
    required this.tests,
  });
}

// Deprecated: Kept for backward compatibility if needed, but LocalQuestion is preferred.
class Question {
  final String id;
  final String uuid;
  final String text;
  final String? image;
  final List<LocalOption> options;
  final String correctOption;
  final String section;

  Question({
    required this.id,
    required this.uuid,
    required this.text,
    this.image,
    required this.options,
    required this.correctOption,
    required this.section,
  });
}

class Section {
  final String name;
  Section({required this.name});
}
