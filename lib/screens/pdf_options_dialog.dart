import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/constants.dart';
import '../utils/text_formatter.dart';

/// Dialog to configure PDF options and question generation settings
class PdfOptionsDialog extends StatefulWidget {
  /// Name of the PDF document
  final String pdfName;

  /// Total number of pages in the PDF
  final int pdfPageCount;

  /// Current page range selection
  final RangeValues pageRange;

  /// Current difficulty level
  final String difficulty;

  /// Selected question types
  final List<String> selectedQuestionTypes;

  /// Question type counts
  final Map<String, TextEditingController> questionTypeCounts;

  /// Callback for when page range changes
  final Function(RangeValues) onPageRangeChanged;

  /// Callback for when difficulty changes
  final Function(String) onDifficultyChanged;

  /// Callback for when selected question types change
  final Function(List<String>) onSelectedQuestionTypesChanged;

  /// Callback for when question is generated
  final VoidCallback onGenerateQuestions;

  /// Constructor
  const PdfOptionsDialog({
    Key? key,
    required this.pdfName,
    required this.pdfPageCount,
    required this.pageRange,
    required this.difficulty,
    required this.selectedQuestionTypes,
    required this.questionTypeCounts,
    required this.onPageRangeChanged,
    required this.onDifficultyChanged,
    required this.onSelectedQuestionTypesChanged,
    required this.onGenerateQuestions,
  }) : super(key: key);

  @override
  State<PdfOptionsDialog> createState() => _PdfOptionsDialogState();
}

class _PdfOptionsDialogState extends State<PdfOptionsDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Local state to ensure immediate UI updates
  late RangeValues _localPageRange;
  late String _localDifficulty;
  late List<String> _localSelectedTypes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);

    // Initialize local state
    _localPageRange = widget.pageRange;
    _localDifficulty = widget.difficulty;
    _localSelectedTypes = List.from(widget.selectedQuestionTypes);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  /// Calculate total points based on selected question types and counts
  int _calculateTotalPoints() {
    int total = 0;
    for (final type in _localSelectedTypes) {
      final countText = widget.questionTypeCounts[type]?.text ?? '0';
      final count = int.tryParse(countText) ?? 0;
      final pointsPerQuestion = AppConstants.questionTypePoints[type] ?? 1;
      total += count * pointsPerQuestion;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with document info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.description, color: AppConstants.primaryColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.pdfName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.primaryColor,
                      fontFamily: 'Inter',
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // Main content - tabbed interface
          Expanded(
            child: Column(
              children: [
                // Tab bar
                Container(
                  color: Colors.white,
                  child: TabBar(
                    controller: _tabController,
                    labelColor: AppConstants.primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: AppConstants.primaryColor,
                    tabs: const [
                      Tab(icon: Icon(Icons.book), text: "Content Selection"),
                      Tab(
                        icon: Icon(Icons.question_answer),
                        text: "Question Types",
                      ),
                    ],
                  ),
                ),

                // Tab content
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      // Content Selection Tab
                      _buildContentSelectionTab(),

                      // Question Types Tab
                      _buildQuestionTypesTab(),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Action buttons - Generate or Cancel
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -4),
                  blurRadius: 8,
                ),
              ],
            ),
            child: Row(
              children: [
                // Cancel button
                Expanded(
                  flex: 1,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: Colors.grey[300]!),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.grey, fontFamily: 'Inter'),
                    ),
                  ),
                ),

                const SizedBox(width: 16),

                // Generate button
                Expanded(
                  flex: 2,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Ensure we pass the updated values back to parent
                      widget.onPageRangeChanged(_localPageRange);
                      widget.onDifficultyChanged(_localDifficulty);
                      widget.onSelectedQuestionTypesChanged(
                        _localSelectedTypes,
                      );

                      // Close dialog and generate questions
                      Navigator.pop(context);
                      widget.onGenerateQuestions();
                    },
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text(
                      'Generate Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build the content selection tab
  Widget _buildContentSelectionTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Page Range',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),

          // Page range display
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${_localPageRange.start.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),

              const Text(
                'to',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontFamily: 'Inter',
                ),
              ),

              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Page ${_localPageRange.end.toInt()}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w500,
                    fontFamily: 'Inter',
                    color: AppConstants.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Slider - Updated to use local state and propagate changes immediately
          RangeSlider(
            values: _localPageRange,
            min: 1,
            max: widget.pdfPageCount.toDouble(),
            divisions: widget.pdfPageCount > 1 ? widget.pdfPageCount - 1 : 1,
            activeColor: AppConstants.primaryColor,
            inactiveColor: AppConstants.primaryColor.withOpacity(0.2),
            labels: RangeLabels(
              _localPageRange.start.toInt().toString(),
              _localPageRange.end.toInt().toString(),
            ),
            onChanged: (values) {
              setState(() {
                _localPageRange = values;
              });
            },
          ),

          const SizedBox(height: 24),

          // Difficulty Selection
          const Text(
            'Difficulty Level',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              fontFamily: 'Inter',
            ),
          ),
          const SizedBox(height: 16),

          // Difficulty buttons - completely revised implementation
          SizedBox(
            height: 48,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: AppConstants.difficultyLevels.length,
              itemBuilder: (context, index) {
                final level = AppConstants.difficultyLevels[index];
                final isSelected = _localDifficulty == level;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _localDifficulty = level;
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          isSelected ? AppConstants.primaryColor : Colors.white,
                      foregroundColor:
                          isSelected ? Colors.white : Colors.grey[700],
                      elevation: isSelected ? 2 : 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(
                          color:
                              isSelected
                                  ? AppConstants.primaryColor
                                  : Colors.grey[300]!,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(
                      level.substring(0, 1).toUpperCase() + level.substring(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build the question types tab
  Widget _buildQuestionTypesTab() {
    return Column(
      children: [
        // Points Summary Card
        Container(
          width: double.infinity,
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              const Text(
                'Total Assessment Points',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${_calculateTotalPoints()}',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontFamily: 'Inter',
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Adjust question counts below',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                  fontFamily: 'Inter',
                ),
              ),
            ],
          ),
        ),

        // Question Types List - Uses local state for immediate updates
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: AppConstants.questionTypes.length,
            itemBuilder: (context, index) {
              final type = AppConstants.questionTypes[index];
              final isSelected = _localSelectedTypes.contains(type);
              final pointsPerQuestion =
                  AppConstants.questionTypePoints[type] ?? 1;

              return Card(
                margin: const EdgeInsets.only(bottom: 16),
                elevation: isSelected ? 2 : 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color:
                        isSelected
                            ? AppConstants.primaryColor
                            : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Row
                    InkWell(
                      onTap: () {
                        // Toggle selection when tapping the header
                        setState(() {
                          if (isSelected) {
                            if (_localSelectedTypes.length > 1) {
                              _localSelectedTypes.remove(type);
                            }
                          } else {
                            _localSelectedTypes.add(type);
                          }
                        });
                      },
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Checkbox
                            Checkbox(
                              value: isSelected,
                              activeColor: AppConstants.primaryColor,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  if (value == true) {
                                    if (!_localSelectedTypes.contains(type)) {
                                      _localSelectedTypes.add(type);
                                    }
                                  } else {
                                    if (_localSelectedTypes.length > 1) {
                                      _localSelectedTypes.remove(type);
                                    }
                                  }
                                });
                              },
                            ),

                            // Type Name
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    TextFormatter.formatQuestionType(type),
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                  Text(
                                    '$pointsPerQuestion points per question',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600],
                                      fontFamily: 'Inter',
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Example Icon
                            if (isSelected)
                              IconButton(
                                icon: const Icon(
                                  Icons.help_outline,
                                  color: Colors.grey,
                                ),
                                onPressed: () {
                                  // Show example of question type
                                  showDialog(
                                    context: context,
                                    builder:
                                        (context) => AlertDialog(
                                          title: Text(
                                            'Example: ${TextFormatter.formatQuestionType(type)}',
                                          ),
                                          content: _buildQuestionTypeExample(
                                            type,
                                          ),
                                          actions: [
                                            TextButton(
                                              onPressed:
                                                  () => Navigator.pop(context),
                                              child: const Text('Close'),
                                            ),
                                          ],
                                        ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),

                    // Counter section (if selected)
                    if (isSelected)
                      Container(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        child: Row(
                          children: [
                            // Counter with + and - buttons
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey[300]!),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  // Minus button - Using Material button for better touch response
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        final currentValue =
                                            int.tryParse(
                                              widget
                                                      .questionTypeCounts[type]
                                                      ?.text ??
                                                  '0',
                                            ) ??
                                            0;
                                        if (currentValue > 0) {
                                          setState(() {
                                            widget
                                                    .questionTypeCounts[type]
                                                    ?.text =
                                                (currentValue - 1).toString();
                                          });
                                        }
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.remove, size: 16),
                                      ),
                                    ),
                                  ),

                                  // Count input
                                  SizedBox(
                                    width: 40,
                                    child: TextField(
                                      controller:
                                          widget.questionTypeCounts[type],
                                      textAlign: TextAlign.center,
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        contentPadding: EdgeInsets.zero,
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                      ],
                                      onChanged: (_) {
                                        setState(() {});
                                      },
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),

                                  // Plus button - Using Material button for better touch response
                                  Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () {
                                        final currentValue =
                                            int.tryParse(
                                              widget
                                                      .questionTypeCounts[type]
                                                      ?.text ??
                                                  '0',
                                            ) ??
                                            0;
                                        setState(() {
                                          widget
                                                  .questionTypeCounts[type]
                                                  ?.text =
                                              (currentValue + 1).toString();
                                        });
                                      },
                                      customBorder: const CircleBorder(),
                                      child: const Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: Icon(Icons.add, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(width: 16),

                            // Subtotal
                            Expanded(
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey[100],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Subtotal:',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[700],
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                    Text(
                                      '${(int.tryParse(widget.questionTypeCounts[type]?.text ?? '0') ?? 0) * pointsPerQuestion} points',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: AppConstants.primaryColor,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Build an example of a specific question type
  Widget _buildQuestionTypeExample(String type) {
    switch (type) {
      case 'multiple-choice':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What is the capital of France?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('Paris', true),
            _buildExampleOption('London', false),
            _buildExampleOption('Berlin', false),
            _buildExampleOption('Madrid', false),
          ],
        );
      case 'multiple-answer':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Which of the following are primary colors?',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('Red', true),
            _buildExampleOption('Green', false),
            _buildExampleOption('Blue', true),
            _buildExampleOption('Yellow', true),
          ],
        );
      case 'true-false':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The Earth is flat.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            _buildExampleOption('True', false),
            _buildExampleOption('False', true),
          ],
        );
      case 'fill-in-the-blank':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The process of plants making food using sunlight is called ____________.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'Answer: photosynthesis',
                style: TextStyle(color: Color(0xFF1976D2), fontFamily: 'Inter'),
              ),
            ),
          ],
        );
      case 'short-answer':
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Explain Newton\'s Third Law of Motion in your own words.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontFamily: 'Inter',
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: const Text(
                'Sample answer: Newton\'s Third Law states that for every action, there is an equal and opposite reaction. When one object exerts a force on a second object, the second object exerts an equal force in the opposite direction on the first object.',
                style: TextStyle(color: Color(0xFF1976D2), fontFamily: 'Inter'),
              ),
            ),
          ],
        );
      default:
        return const Text(
          'Example not available for this question type.',
          style: TextStyle(fontFamily: 'Inter'),
        );
    }
  }

  /// Helper for building example options
  Widget _buildExampleOption(String text, bool isCorrect) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color:
                  isCorrect
                      ? AppConstants.primaryColor.withOpacity(0.1)
                      : Colors.transparent,
              border: Border.all(
                color: isCorrect ? AppConstants.primaryColor : Colors.grey,
                width: 1.5,
              ),
            ),
            child:
                isCorrect
                    ? const Center(
                      child: Icon(
                        Icons.check,
                        size: 12,
                        color: AppConstants.primaryColor,
                      ),
                    )
                    : null,
          ),
          Text(
            text,
            style: TextStyle(
              color: isCorrect ? AppConstants.primaryColor : Colors.black87,
              fontFamily: 'Inter',
            ),
          ),
        ],
      ),
    );
  }
}
