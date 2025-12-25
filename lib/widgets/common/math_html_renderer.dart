import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class MathHtmlRenderer extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const MathHtmlRenderer({
    super.key,
    required this.content,
    this.textStyle,
  });

  String _preprocessContent(String input) {
    // Replace display math \[ ... \] or $$ ... $$ with <tex-block>...</tex-block>
    String processed = input;

    // Display math: $$...$$
    processed = processed.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      (match) => '<tex-block>${match.group(1)}</tex-block>',
    );

    // Display math: \[...\]
    processed = processed.replaceAllMapped(
      RegExp(r'\\\[(.*?)\\\]', dotAll: true),
      (match) => '<tex-block>${match.group(1)}</tex-block>',
    );

    // Inline math: \(...\)
    processed = processed.replaceAllMapped(
      RegExp(r'\\\((.*?)\\\)', dotAll: true),
      (match) => '<tex-inline>${match.group(1)}</tex-inline>',
    );

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      _preprocessContent(content),
      textStyle: textStyle,
      customWidgetBuilder: (element) {
        if (element.localName == 'tex-block') {
          return Center(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Math.tex(
                element.text,
                textStyle: textStyle,
                mathStyle: MathStyle.display,
              ),
            ),
          );
        }
        if (element.localName == 'tex-inline') {
          return Math.tex(
            element.text,
            textStyle: textStyle,
            mathStyle: MathStyle.text,
          );
        }
        return null;
      },
    );
  }
}
