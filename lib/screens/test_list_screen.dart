import 'package:flutter/material.dart';
import 'package:prepaired/models/test_models.dart';
import 'package:prepaired/services/supabase_service.dart';
import 'package:prepaired/screens/test_instructions_screen.dart';

class TestListScreen extends StatefulWidget {
  const TestListScreen({super.key});

  @override
  State<TestListScreen> createState() => _TestListScreenState();
}

class _TestListScreenState extends State<TestListScreen> {
  List<TestCategory> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTests();
  }

  Future<void> _loadTests() async {
    final tests = await SupabaseService.fetchTests();
    final categoriesMap = <String, List<Test>>{};

    for (var test in tests) {
      if (!categoriesMap.containsKey(test.category)) {
        categoriesMap[test.category] = [];
      }
      categoriesMap[test.category]!.add(test);
    }

    final categories = categoriesMap.entries.map((entry) {
      return TestCategory(title: entry.key, tests: entry.value);
    }).toList();

    if (mounted) {
      setState(() {
        _categories = categories;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Your Test'),
        automaticallyImplyLeading: false, // Assuming it's a top level or after auth
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choose a category to begin your assessment.',
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  ..._categories.map((category) => _buildCategorySection(category)).toList(),
                ],
              ),
            ),
    );
  }

  Widget _buildCategorySection(TestCategory category) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.checklist, color: Color(0xFF4C6FFF)), // Using primary color from memory
            const SizedBox(width: 8),
            Text(
              category.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 1, // Start with 1 column for mobile, maybe 2 for tablet
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 2.5, // Adjust based on content
          ),
          itemCount: category.tests.length,
          itemBuilder: (context, index) {
            final test = category.tests[index];
            return _buildTestCard(test);
          },
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildTestCard(Test test) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => TestInstructionsScreen(test: test),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      test.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      test.description,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.grey,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}
