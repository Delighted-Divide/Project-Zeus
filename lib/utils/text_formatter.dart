import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class TextFormatter {
  static String normalizeLatexEscaping(String mathContent) {
    String normalized = mathContent;
    normalized = normalized.replaceAll(r'\\\\', r'\\');
    normalized = normalized.replaceAll(r'\\', r'\');
    return normalized;
  }

  static Widget buildFormattedText(String text, {TextStyle? textStyle}) {
    final defaultStyle =
        textStyle ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        );

    if (text.isEmpty) {
      return Text('', style: defaultStyle);
    }

    try {
      if (!text.contains('\$')) {
        return Text(text, style: defaultStyle);
      }

      final List<Widget> segments = [];
      final parts = text.split('\$');

      for (int i = 0; i < parts.length; i++) {
        if (i % 2 == 0) {
          if (parts[i].isNotEmpty) {
            segments.add(Text(parts[i], style: defaultStyle));
          }
        } else {
          try {
            final normalized = normalizeLatexEscaping(parts[i]);
            segments.add(
              Math.tex(
                normalized,
                textStyle: defaultStyle,
                onErrorFallback: (e) {
                  print(
                    'LaTeX rendering error: $e for expression: ${parts[i]}',
                  );
                  return Text('\$${parts[i]}\$', style: defaultStyle);
                },
              ),
            );
          } catch (e) {
            print('Error rendering LaTeX: $e for ${parts[i]}');
            segments.add(Text('\$${parts[i]}\$', style: defaultStyle));
          }
        }
      }

      return Wrap(
        children: segments,
        spacing: 0,
        runSpacing: 4,
        alignment: WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
      );
    } catch (e) {
      print('Error in buildFormattedText: $e');
      return Text(text, style: defaultStyle);
    }
  }

  static Widget renderTextWithEquations(String text, {TextStyle? textStyle}) {
    return buildFormattedText(text, textStyle: textStyle);
  }

  static String sanitizeJsonString(String input) {
    try {
      jsonDecode(input);
      return input;
    } catch (_) {}

    try {
      _logToFile('json_sanitize_input.txt', input);

      final Map<String, String> placeholders = {};
      int counter = 0;
      String processed = input;

      RegExp latexRegex = RegExp(r'\$([^\$]*)\$');
      processed = processed.replaceAllMapped(latexRegex, (match) {
        final placeholder = "##LATEX_${counter++}##";
        placeholders[placeholder] = match.group(0) ?? '';
        return placeholder;
      });

      processed = processed.replaceAll(RegExp(r',(\s*[\]}])'), r'$1');
      processed = processed.replaceAll(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
        r'$1"$2"$3',
      );

      placeholders.forEach((placeholder, latex) {
        processed = processed.replaceAll(placeholder, latex);
      });

      try {
        jsonDecode(processed);
        _logToFile('json_sanitize_output.txt', processed);
        return processed;
      } catch (e) {
        print('First-pass sanitization failed: $e');
        return _aggressiveSanitizeJSON(input);
      }
    } catch (e) {
      print('Error in sanitizeJsonString: $e');
      return _aggressiveSanitizeJSON(input);
    }
  }

  static String _aggressiveSanitizeJSON(String input) {
    try {
      RegExp jsonObjectRegex = RegExp(r'(\{.*\})', dotAll: true);
      Match? match = jsonObjectRegex.firstMatch(input);

      if (match == null) {
        return '{"questions":[],"answers":[],"tags":[]}';
      }

      String extracted = match.group(1) ?? '';

      extracted = extracted.replaceAll(
        RegExp(r'\$[^\$]*\$'),
        '"[MATH_EXPRESSION]"',
      );

      extracted = extracted.replaceAll(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
        r'$1"$2"$3',
      );

      extracted = extracted.replaceAll(RegExp(r',(\s*[\]}])'), r'$1');

      try {
        jsonDecode(extracted);
        return extracted;
      } catch (e) {
        print('Aggressive sanitization failed: $e');
        return '{"questions":[],"answers":[],"tags":[]}';
      }
    } catch (e) {
      print('Error in aggressive sanitization: $e');
      return '{"questions":[],"answers":[],"tags":[]}';
    }
  }

  static Future<void> _logToFile(String filename, String content) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final path = '${directory.path}/logs';
      await Directory(path).create(recursive: true);
      final file = File('$path/$filename');
      await file.writeAsString(content, mode: FileMode.append);
    } catch (e) {
      print('Error logging to file: $e');
    }
  }

  static String formatQuestionType(String type) {
    switch (type) {
      case 'multiple-choice':
        return 'Multiple Choice';
      case 'multiple-answer':
        return 'Multiple Answer';
      case 'true-false':
        return 'True/False';
      case 'fill-in-the-blank':
        return 'Fill in Blank';
      case 'short-answer':
        return 'Short Answer';
      case 'code-snippet':
        return 'Code Snippet';
      case 'diagram-interpretation':
        return 'Diagram';
      case 'math-equation':
        return 'Math Equation';
      case 'chemical-formula':
        return 'Chemical Formula';
      case 'language-translation':
        return 'Translation';
      default:
        return type
            .split('-')
            .map(
              (word) =>
                  word.isEmpty ? '' : word[0].toUpperCase() + word.substring(1),
            )
            .join(' ');
    }
  }
}
