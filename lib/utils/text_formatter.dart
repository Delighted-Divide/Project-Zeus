// utils/text_formatter.dart
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Utility class for text formatting
class TextFormatter {
  /// Normalize LaTeX content to handle escaping issues
  static String normalizeLatexEscaping(String mathContent) {
    // Handle escaped backslashes that often cause issues
    String normalized = mathContent;

    // Handle multiple backslash sequences properly
    normalized = normalized.replaceAll(r'\\\\', r'\\');
    normalized = normalized.replaceAll(r'\\', r'\');

    return normalized;
  }

  /// Build formatted text with support for LaTeX math expressions
  static Widget buildFormattedText(String text, {TextStyle? textStyle}) {
    // Default text style if none provided
    final defaultStyle =
        textStyle ??
        const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          fontFamily: 'Inter',
        );

    // If text is empty or null, return empty container
    if (text.isEmpty) {
      return Text('', style: defaultStyle);
    }

    try {
      // If there are no LaTeX expressions, return simple text
      if (!text.contains('\$')) {
        return Text(text, style: defaultStyle);
      }

      // List to hold text segments and math expressions
      final List<Widget> segments = [];
      final parts = text.split('\$');

      for (int i = 0; i < parts.length; i++) {
        // Even indices are regular text, odd indices are LaTeX expressions
        if (i % 2 == 0) {
          if (parts[i].isNotEmpty) {
            segments.add(Text(parts[i], style: defaultStyle));
          }
        } else {
          // Handle LaTeX expression
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

      // Wrap all segments
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

  /// Render text with equations - uses the buildFormattedText method
  static Widget renderTextWithEquations(String text, {TextStyle? textStyle}) {
    return buildFormattedText(text, textStyle: textStyle);
  }

  /// Sanitize JSON string to fix common issues that cause parsing errors
  static String sanitizeJsonString(String input) {
    // Try to parse as-is first
    try {
      jsonDecode(input);
      return input;
    } catch (_) {
      // Continue with sanitization
    }

    try {
      // Log the original input for debugging
      _logToFile('json_sanitize_input.txt', input);

      // Replace LaTeX expressions with placeholders
      final Map<String, String> placeholders = {};
      int counter = 0;
      String processed = input;

      // Replace LaTeX expressions
      RegExp latexRegex = RegExp(r'\$([^\$]*)\$');
      processed = processed.replaceAllMapped(latexRegex, (match) {
        final placeholder = "##LATEX_${counter++}##";
        placeholders[placeholder] = match.group(0) ?? '';
        return placeholder;
      });

      // Fix common JSON issues
      processed = processed.replaceAll(
        RegExp(r',(\s*[\]}])'),
        r'$1',
      ); // Remove trailing commas
      processed = processed.replaceAll(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
        r'$1"$2"$3',
      ); // Quote property names

      // Restore LaTeX expressions
      placeholders.forEach((placeholder, latex) {
        processed = processed.replaceAll(placeholder, latex);
      });

      // Try parsing the processed JSON
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

  /// Aggressive sanitization for severely malformed JSON
  static String _aggressiveSanitizeJSON(String input) {
    try {
      // Extract JSON-like structure
      RegExp jsonObjectRegex = RegExp(r'(\{.*\})', dotAll: true);
      Match? match = jsonObjectRegex.firstMatch(input);

      if (match == null) {
        return '{"questions":[],"answers":[],"tags":[]}';
      }

      String extracted = match.group(1) ?? '';

      // Replace all LaTeX with placeholders
      extracted = extracted.replaceAll(
        RegExp(r'\$[^\$]*\$'),
        '"[MATH_EXPRESSION]"',
      );

      // Fix common issues
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

  /// Log content to a file for debugging
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

  /// Format question type for display
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
