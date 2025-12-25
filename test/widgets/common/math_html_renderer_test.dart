import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prepaired/widgets/common/math_html_renderer.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

void main() {
  testWidgets('MathHtmlRenderer renders HTML content', (WidgetTester tester) async {
    const htmlContent = '<p>Hello World</p>';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MathHtmlRenderer(content: htmlContent),
      ),
    ));
    await tester.pumpAndSettle();

    // HtmlWidget renders RichText, so find.text might not work directly if it's looking for Text widgets.
    // find.text finds Text widgets or RichText widgets with exact string match?
    // Actually find.text works on RichText if configured.
    // However, let's verify using find.byWidgetPredicate or simpler: find.byType(HtmlWidget)

    expect(find.byType(HtmlWidget), findsOneWidget);
    // Deep search for text content
    expect(find.text('Hello World', findRichText: true), findsOneWidget);
  });

  testWidgets('MathHtmlRenderer renders block math', (WidgetTester tester) async {
    const mathContent = r'$$ x^2 $$';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MathHtmlRenderer(content: mathContent),
      ),
    ));

    // Wait for async rendering if any
    await tester.pumpAndSettle();

    // Verify Math widget is present
    expect(find.byType(Math), findsOneWidget);
  });

  testWidgets('MathHtmlRenderer renders inline math', (WidgetTester tester) async {
    const mathContent = r'\( y = mx + c \)';
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: MathHtmlRenderer(content: mathContent),
      ),
    ));

    await tester.pumpAndSettle();

    expect(find.byType(Math), findsOneWidget);
  });
}
