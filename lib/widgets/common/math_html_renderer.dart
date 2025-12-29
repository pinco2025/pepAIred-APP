import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html/flutter_widget_from_html.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class _MathFactory extends WidgetFactory {
  final TextStyle? textStyle;

  _MathFactory({this.textStyle});

  @override
  void parse(BuildMetadata meta) {
    if (meta.element.classes.contains('tex-inline')) {
      final content = meta.element.text;
      
      // Clear the element's children to prevent them from being parsed
      meta.element.nodes.clear();
      
      meta.register(BuildOp(
        onTree: (meta, tree) {
          tree.append(WidgetBit.inline(
            tree,
            Math.tex(
              content,
              textStyle: textStyle,
              mathStyle: MathStyle.text,
            ),
            alignment: PlaceholderAlignment.baseline,
          ));
        },
      ));
      
      return;
    }
    
    super.parse(meta);
  }
}

class MathHtmlRenderer extends StatelessWidget {
  final String content;
  final TextStyle? textStyle;

  const MathHtmlRenderer({
    super.key,
    required this.content,
    this.textStyle,
  });

  String _preprocessContent(String input) {
    // First, split the input by possible math delimiters to identify math blocks
    // Delimiters: $$...$$, \[...\], \(...\), $...$

    // We will build the result by iterating through segments.
    // However, splitting by regex and keeping delimiters is complex.
    // A simpler approach is to replace math blocks with placeholders,
    // then process newlines in the remaining text, then restore math blocks.

    final List<String> mathBlocks = [];
    String processed = input;

    // Function to replace match with placeholder
    String replaceWithPlaceholder(Match match) {
      mathBlocks.add(match.group(0)!);
      return 'MATH_BLOCK_${mathBlocks.length - 1}';
    }

    // 1. Display math: $$...$$
    processed = processed.replaceAllMapped(
      RegExp(r'\$\$(.*?)\$\$', dotAll: true),
      replaceWithPlaceholder,
    );

    // 2. Display math: \[...\]
    processed = processed.replaceAllMapped(
      RegExp(r'\\\[(.*?)\\\]', dotAll: true),
      replaceWithPlaceholder,
    );

    // 3. Inline math: \(...\)
    processed = processed.replaceAllMapped(
      RegExp(r'\\\((.*?)\\\)', dotAll: true),
      replaceWithPlaceholder,
    );

    // 4. Inline math: $...$
    processed = processed.replaceAllMapped(
      RegExp(r'(?<!\\)\$(.*?)(?<!\\)\$', dotAll: true),
      replaceWithPlaceholder,
    );

    // Now replace newlines in the non-math text
    processed = processed.replaceAll('\n', '<br>');

    // Now restore math blocks and simultaneously convert them to HTML tags
    // We loop through mathBlocks and replace the placeholders back

    for (int i = 0; i < mathBlocks.length; i++) {
      final block = mathBlocks[i];
      String replacement = block;

      // We need to apply the specific HTML formatting for each type of block
      // effectively repeating the logic that was there before but on the protected block

      if (block.startsWith(r'$$') && block.endsWith(r'$$')) {
        final content = block.substring(2, block.length - 2);
        replacement = '<tex-block>$content</tex-block>';
      } else if (block.startsWith(r'\[') && block.endsWith(r'\]')) {
        final content = block.substring(2, block.length - 2);
        replacement = '<tex-block>$content</tex-block>';
      } else if (block.startsWith(r'\(') && block.endsWith(r'\)')) {
         final content = block.substring(2, block.length - 2);
         replacement = '<span class="tex-inline">${htmlEscape.convert(content)}</span>';
      } else if (block.startsWith(r'$') && block.endsWith(r'$')) {
         // handle escaped dollar if any - though regex excluded them from being matched as delimiters
         final content = block.substring(1, block.length - 1);
         replacement = '<span class="tex-inline">${htmlEscape.convert(content)}</span>';
      }

      processed = processed.replaceFirst('MATH_BLOCK_$i', replacement);
    }

    return processed;
  }

  @override
  Widget build(BuildContext context) {
    return HtmlWidget(
      _preprocessContent(content),
      textStyle: textStyle,
      factoryBuilder: () => _MathFactory(textStyle: textStyle),
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
        // Inline math is handled by _MathFactory
        return null;
      },
    );
  }
}
