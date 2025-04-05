// utils/text_formatter.dart - Fixed implementation
import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'dart:convert';

/// Utility class for text formatting
class TextFormatter {
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

      // List to hold all spans (text and LaTeX)
      List<InlineSpan> spans = [];

      // Split by dollar sign but keep the delimiters
      List<String> parts = [];
      String currentPart = '';
      bool inMath = false;

      for (int i = 0; i < text.length; i++) {
        if (text[i] == '\$') {
          if (currentPart.isNotEmpty) {
            parts.add(currentPart);
            currentPart = '';
          }
          inMath = !inMath;
          parts.add('\$');
        } else {
          currentPart += text[i];
        }
      }

      if (currentPart.isNotEmpty) {
        parts.add(currentPart);
      }

      // Process the parts into spans
      inMath = false;
      String mathContent = '';
      String textContent = '';

      for (int i = 0; i < parts.length; i++) {
        if (parts[i] == '\$') {
          if (inMath) {
            // End of math, add the math span
            spans.add(
              WidgetSpan(
                alignment: PlaceholderAlignment.middle,
                child: Math.tex(
                  mathContent,
                  textStyle: defaultStyle,
                  onErrorFallback:
                      (err) => Text(
                        '\$$mathContent\$',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: defaultStyle.fontSize,
                        ),
                      ),
                ),
              ),
            );
            mathContent = '';
          } else {
            // Start of math, add any pending text span
            if (textContent.isNotEmpty) {
              spans.add(TextSpan(text: textContent, style: defaultStyle));
              textContent = '';
            }
          }
          inMath = !inMath;
        } else if (inMath) {
          mathContent += parts[i];
        } else {
          textContent += parts[i];
        }
      }

      // Add any remaining text
      if (textContent.isNotEmpty) {
        spans.add(TextSpan(text: textContent, style: defaultStyle));
      }

      return RichText(
        text: TextSpan(children: spans),
        overflow: TextOverflow.visible,
      );
    } catch (e) {
      // If any error occurs, return the original text
      print('Error in buildFormattedText: $e');
      return Text(text, style: defaultStyle);
    }
  }

  /// Sanitize JSON string to fix common issues that cause parsing errors
  static String sanitizeJsonString(String input) {
    try {
      // Step 1: Extract and protect LaTeX expressions
      final Map<String, String> latexExpressions = {};
      String placeholder = '##LATEX_EXPR_';
      int placeholderIndex = 0;

      // Find and extract all LaTeX expressions to protect them from JSON processing
      String processed = input;
      final RegExp latexPattern = RegExp(r'\$(.*?)\$', dotAll: true);
      final matches = latexPattern.allMatches(input);

      for (final match in matches) {
        final originalText = match.group(0) ?? '';
        final placeholderKey = '$placeholder${placeholderIndex++}##';

        // Replace LaTeX with placeholder in processed string
        processed = processed.replaceFirst(originalText, placeholderKey);

        // Store original expression with properly escaped backslashes for JSON
        latexExpressions[placeholderKey] = originalText.replaceAll(r'\', r'\\');
      }

      // Step 2: Fix common JSON syntax issues
      // Fix newlines and other escape sequences
      processed = processed.replaceAll(r'\n', '\\n');
      processed = processed.replaceAll(RegExp(r'(?<!\\)\n'), ' ');
      processed = processed.replaceAll(r'\r', '\\r');
      processed = processed.replaceAll(RegExp(r'(?<!\\)\r'), ' ');
      processed = processed.replaceAll(r'\t', '\\t');
      processed = processed.replaceAll(RegExp(r'(?<!\\)\t'), ' ');

      // Fix trailing commas in objects and arrays
      processed = processed.replaceAll(RegExp(r',\s*}'), '}');
      processed = processed.replaceAll(RegExp(r',\s*]'), ']');

      // Fix missing quotes around property names
      processed = processed.replaceAll(
        RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
        r'$1"$2"$3',
      );

      // Fix unquoted string values (but avoid messing with placeholders)
      processed = processed.replaceAll(
        RegExp(r':\s*([^"#{[\s][^,}\]]*?)([,}\]])'),
        r': "$1"$2',
      );

      // Step 3: Restore LaTeX expressions
      latexExpressions.forEach((placeholder, latex) {
        processed = processed.replaceAll(placeholder, latex);
      });

      // Verify JSON is valid (will throw if still invalid)
      jsonDecode(processed);

      return processed;
    } catch (e) {
      // If regular sanitization fails, try more aggressive approach
      print('Regular JSON sanitization failed: $e');
      try {
        // More aggressive fixes
        String aggressive = input;

        // Replace all LaTeX expressions with simple placeholders
        aggressive = aggressive.replaceAll(
          RegExp(r'\$(.*?)\$', dotAll: true),
          '"[MATH_FORMULA]"',
        );

        // Fix structure more aggressively
        aggressive = aggressive.replaceAll(
          RegExp(r'([{,]\s*)([a-zA-Z0-9_]+)(\s*:)'),
          r'$1"$2"$3',
        );
        aggressive = aggressive.replaceAll(
          RegExp(r':\s*([^"{\[\s][^,}\]]*?)([,}\]])'),
          r': "$1"$2',
        );

        // Updated trailing comma fix in aggressive cleaning
        aggressive = aggressive.replaceAllMapped(
          RegExp(r',\s*([}\]])'),
          (match) => match.group(1)!,
        );

        // Check if we've created valid JSON
        jsonDecode(aggressive);
        return aggressive;
      } catch (e) {
        print('Aggressive JSON sanitization failed: $e');
        // If all strategies fail, return the original
        return input;
      }
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
