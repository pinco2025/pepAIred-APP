import 'package:prepaired/models/test_models.dart';

class SolutionOption {
  final String id;
  final String text;
  final String? image;

  SolutionOption({
    required this.id,
    required this.text,
    this.image,
  });

  factory SolutionOption.fromJson(Map<String, dynamic> json) {
    return SolutionOption(
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

class SolutionQuestion {
  final String id;
  final String uuid;
  final String text;
  final String? image;
  final List<SolutionOption> options;
  final String? section;
  final String? correctOption; // ID of the correct option
  final String? solution; // Explanation text (HTML/LaTeX)

  SolutionQuestion({
    required this.id,
    required this.uuid,
    required this.text,
    this.image,
    required this.options,
    this.section,
    this.correctOption,
    this.solution,
  });

  factory SolutionQuestion.fromJson(Map<String, dynamic> json) {
    return SolutionQuestion(
      id: json['id'] as String,
      uuid: json['uuid'] as String,
      text: json['text'] as String,
      image: (json['image'] != null &&
              json['image'] != 0 &&
              json['image'] != "0")
          ? json['image'].toString()
          : null,
      options: (json['options'] as List?)
              ?.map((e) => SolutionOption.fromJson(e))
              .toList() ??
          [],
      section: json['section'] as String?,
      // Try to find the correct answer field. Common names: correctOption, answer, correctAnswer
      correctOption: (json['correctOption'] ?? json['answer'] ?? json['correctAnswer'])?.toString(),
      // Try to find explanation. Common names: solution, explanation
      solution: (json['solution'] ?? json['explanation'])?.toString(),
    );
  }
}
