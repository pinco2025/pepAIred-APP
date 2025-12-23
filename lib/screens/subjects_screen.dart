import 'package:flutter/material.dart';
import 'package:prepaired/theme/app_theme.dart';
import 'package:percent_indicator/percent_indicator.dart';

class SubjectsScreen extends StatelessWidget {
  const SubjectsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
        title: const Text(
          'Subject Mastery',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppTheme.backgroundColor,
        elevation: 0,
        actions: const [
           Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 18,
              backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
            ),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              'Deep dive into your subject performance and topic-wise breakdown.',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            _buildSubjectCard(
              context,
              'Physics',
              '12 Chapters • 840 Questions',
              'Strong',
              0.78,
              Colors.blue,
              Icons.science,
              [
                _TopicProgress('Mechanics', 0.85),
                _TopicProgress('Electrostatics', 0.60),
                _TopicProgress('Optics', 0.92),
              ],
            ),
            _buildSubjectCard(
              context,
              'Chemistry',
              '10 Chapters • 650 Questions',
              'Average',
              0.64,
              Colors.green,
              Icons.biotech,
              [
                _TopicProgress('Organic', 0.70),
                _TopicProgress('Inorganic', 0.55),
                _TopicProgress('Physical', 0.65),
              ],
            ),
            _buildSubjectCard(
              context,
              'Mathematics',
              '14 Chapters • 920 Questions',
              'Needs Focus',
              0.42,
              Colors.orange,
              Icons.calculate,
              [
                _TopicProgress('Calculus', 0.30),
                _TopicProgress('Algebra', 0.50),
                _TopicProgress('Vectors', 0.45),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubjectCard(
    BuildContext context,
    String title,
    String subtitle,
    String badgeText,
    double mastery,
    Color color,
    IconData icon,
    List<_TopicProgress> topics,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Content
          Row(
            children: [
              // Circular Indicator
              Expanded(
                flex: 4,
                child: CircularPercentIndicator(
                  radius: 60.0,
                  lineWidth: 10.0,
                  percent: mastery,
                  center: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "${(mastery * 100).toInt()}%",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const Text(
                        "MASTERY",
                        style: TextStyle(
                          fontSize: 10,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  progressColor: color,
                  backgroundColor: color.withOpacity(0.1),
                  circularStrokeCap: CircularStrokeCap.round,
                ),
              ),
              const SizedBox(width: 24),
              // Linear Progress Bars
              Expanded(
                flex: 6,
                child: Column(
                  children: topics.map((topic) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                topic.name,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              Text(
                                "${(topic.progress * 100).toInt()}%",
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          LinearPercentIndicator(
                            lineHeight: 6.0,
                            percent: topic.progress,
                            progressColor: color,
                            backgroundColor: color.withOpacity(0.1),
                            barRadius: const Radius.circular(3),
                            padding: EdgeInsets.zero,
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: Colors.grey.shade200),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 14, color: color),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopicProgress {
  final String name;
  final double progress;

  _TopicProgress(this.name, this.progress);
}
