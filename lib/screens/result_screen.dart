import 'package:flutter/material.dart';
import '../models/result_models.dart';
import '../services/supabase_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';

class ResultScreen extends StatefulWidget {
  final String submissionId;

  const ResultScreen({super.key, required this.submissionId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  bool _isLoading = true;
  TestResultData? _resultData;
  DateTime? _submissionTime;
  DateTime? _startTime;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchResult();
  }

  Future<void> _fetchResult() async {
    try {
      final submissionData = await SupabaseService.fetchSubmissionData(widget.submissionId);

      if (submissionData == null) {
        throw Exception("Submission not found");
      }

      setState(() {
        _submissionTime = submissionData['submitted_at'] != null
            ? DateTime.parse(submissionData['submitted_at']).toLocal()
            : null;
        _startTime = submissionData['started_at'] != null
            ? DateTime.parse(submissionData['started_at']).toLocal()
            : null;
      });

      final resultUrl = submissionData['result_url'];

      if (resultUrl != null) {
        final response = await http.get(Uri.parse(resultUrl));
        if (response.statusCode == 200) {
           final Map<String, dynamic> jsonData = json.decode(response.body);
           setState(() {
             _resultData = TestResultData.fromJson(jsonData);
             _isLoading = false;
           });
        } else {
          throw Exception("Failed to fetch result JSON");
        }
      } else {
        // Result not ready yet
        setState(() {
          _isLoading = false;
          _errorMessage = "Results are being processed. Please check back later.";
        });
      }

    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
      });
    }
  }

  String _formatTimeTaken() {
    if (_startTime != null && _submissionTime != null) {
      final diff = _submissionTime!.difference(_startTime!);
      final hours = diff.inHours;
      final minutes = diff.inMinutes % 60;

      List<String> parts = [];
      if (hours > 0) parts.push("$hours H");
      if (minutes > 0 || hours == 0) parts.push("$minutes Min");
      return parts.join(' ');
    }
    return "??";
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Results')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 24),
                 ElevatedButton(
                  onPressed: _fetchResult,
                  child: const Text("Retry"),
                )
              ],
            ),
          ),
        ),
      );
    }

    if (_resultData == null) {
      return const Scaffold(
        body: Center(child: Text("No result data available")),
      );
    }

    final totalStats = _resultData!.totalStats;
    final accuracy = totalStats.totalAttempted > 0
        ? (totalStats.totalCorrect / totalStats.totalAttempted * 100)
        : 0.0;
    final scorePercentage = (totalStats.totalScore / _resultData!.totalMarks).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FE), // Light background similar to web
      appBar: AppBar(
        title: Text('Test Result: ${_resultData!.testId}'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Row(
              children: [
                Icon(Icons.event, size: 16, color: Colors.grey[600]),
                const SizedBox(width: 4),
                Text(
                  _submissionTime != null
                      ? "Completed on ${_submissionTime.toString().split('.')[0]}"
                      : "",
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Score Card
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
              ),
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularPercentIndicator(
                        radius: 80.0,
                        lineWidth: 12.0,
                        percent: scorePercentage,
                        center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${totalStats.totalScore}",
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                            Text(
                              "/ ${_resultData!.totalMarks}",
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                        progressColor: const Color(0xFF4C6FFF),
                        backgroundColor: Colors.grey[200]!,
                        circularStrokeCap: CircularStrokeCap.round,
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // Stats Grid
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 20) / 2;
                      return Wrap(
                        spacing: 20,
                        runSpacing: 20,
                        children: [
                          _buildStatItem("Accuracy", "${accuracy.toStringAsFixed(0)}%", accuracy / 100, const Color(0xFF4C6FFF), itemWidth),
                          _buildStatItem("Percentile", "??", 0, Colors.green, itemWidth), // Placeholder
                          _buildStatItem("Time Taken", _formatTimeTaken(), null, Colors.orange, itemWidth),
                          _buildStatItem("Rank", "??", null, Colors.purple, itemWidth), // Placeholder
                        ],
                      );
                    }
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Question Analysis & Subject Breakdown
            // On mobile, we stack them.
            _buildQuestionAnalysis(totalStats, _resultData!.totalQuestions),
            const SizedBox(height: 24),
            _buildSubjectBreakdown(_resultData!),

            const SizedBox(height: 40),

            // Start Review Button
             SizedBox(
               width: double.infinity,
               child: ElevatedButton.icon(
                 onPressed: () {
                   // Navigate to Review Screen (To be implemented)
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Review feature coming soon!")),
                   );
                 },
                 icon: const Icon(Icons.arrow_forward),
                 label: const Text("Start Review"),
                 style: ElevatedButton.styleFrom(
                   backgroundColor: const Color(0xFF4C6FFF),
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(
                     borderRadius: BorderRadius.circular(12),
                   ),
                   foregroundColor: Colors.white,
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, String value, double? progress, Color color, double width) {
    return SizedBox(
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 14)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[200],
              color: color,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildQuestionAnalysis(TotalStats stats, int totalQuestions) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.analytics_outlined, color: Color(0xFF4C6FFF)),
              SizedBox(width: 8),
              Text("Question Analysis", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          _buildAnalysisRow("Correct", stats.totalCorrect, Colors.green, Icons.check_circle),
          const SizedBox(height: 12),
          _buildAnalysisRow("Incorrect", stats.totalWrong, Colors.red, Icons.cancel),
          const SizedBox(height: 12),
          _buildAnalysisRow("Skipped", stats.totalUnattempted, Colors.grey, Icons.remove_circle),
          const SizedBox(height: 20),

          const Divider(),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Total Attempted", style: TextStyle(color: Colors.grey[600])),
              RichText(
                text: TextSpan(
                  text: "${stats.totalAttempted}",
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black, fontSize: 16),
                  children: [
                    TextSpan(text: "/$totalQuestions", style: TextStyle(color: Colors.grey[600], fontSize: 14, fontWeight: FontWeight.normal)),
                  ]
                ),
              )
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Row(
              children: [
                Expanded(flex: stats.totalCorrect, child: Container(height: 8, color: Colors.green)),
                Expanded(flex: stats.totalWrong, child: Container(height: 8, color: Colors.red)),
                Expanded(flex: totalQuestions - stats.totalAttempted, child: Container(height: 8, color: Colors.grey[200])),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalysisRow(String label, int count, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ],
          ),
          Text("$count", style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 18)),
        ],
      ),
    );
  }

  Widget _buildSubjectBreakdown(TestResultData result) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.subject, color: Color(0xFF4C6FFF)),
              SizedBox(width: 8),
              Text("Subject Breakdown", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 20),
          ...result.sectionScores.entries.map((entry) {
             final sectionName = entry.key;
             final scoreData = entry.value;
             // Calculate max score for section roughly
             // We need to look up section metadata for marks per question, but here we can try to find it in result.sections
             final sectionMeta = result.sections.firstWhere((s) => s.name == sectionName, orElse: () => ResultSection(name: sectionName, marksPerQuestion: 4));

             return _buildSubjectRow(sectionName, scoreData, sectionMeta.marksPerQuestion);
          }),
        ],
      ),
    );
  }

  Widget _buildSubjectRow(String name, SectionScore data, int marksPerQuestion) {
    // Subject icons/colors
    IconData icon = Icons.book;
    Color color = Colors.grey;
    if (name.contains("Physics")) { icon = Icons.science; color = Colors.blue; }
    else if (name.contains("Chemistry")) { icon = Icons.biotech; color = Colors.purple; }
    else if (name.contains("Math")) { icon = Icons.calculate; color = Colors.orange; }

    final maxScore = data.totalQuestions * marksPerQuestion;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        children: [
           Row(
             children: [
               Container(
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                 child: Icon(icon, color: color, size: 20),
               ),
               const SizedBox(width: 12),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Text(name, style: const TextStyle(fontWeight: FontWeight.w500)),
                     Text("Score: ${data.score}/$maxScore", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                   ],
                 ),
               ),
               _buildMiniStat(data.correct, Colors.green, Icons.check_circle),
               const SizedBox(width: 12),
               _buildMiniStat(data.incorrect, Colors.red, Icons.cancel),
               const SizedBox(width: 12),
               _buildMiniStat(data.unattempted, Colors.grey, Icons.remove_circle),
             ],
           ),
           const SizedBox(height: 8),
           // Progress bar
           LayoutBuilder(
             builder: (context, constraints) {
               double totalPossible = maxScore.toDouble();
               if (totalPossible == 0) totalPossible = 1;
               double progress = (data.score / totalPossible).clamp(0.0, 1.0);

               return Stack(
                 children: [
                   Container(
                     height: 6,
                     width: double.infinity,
                     decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(3)),
                   ),
                   Container(
                     height: 6,
                     width: constraints.maxWidth * progress,
                     decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
                   )
                 ],
               );
             }
           )
        ],
      ),
    );
  }

  Widget _buildMiniStat(int count, Color color, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 4),
        Text("$count", style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13)),
      ],
    );
  }
}
