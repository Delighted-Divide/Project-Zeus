import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class CreateAssessmentPage extends StatefulWidget {
  final String type; // 'manual', 'ai', or 'pdf'

  const CreateAssessmentPage({super.key, required this.type});

  @override
  State<CreateAssessmentPage> createState() => _CreateAssessmentPageState();
}

class _CreateAssessmentPageState extends State<CreateAssessmentPage> {
  // Controllers for form fields
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Form state
  String _selectedDifficulty = 'Medium';
  final List<String> _selectedTags = [];
  bool _isPublic = false;
  bool _isCreating = false;

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // List of available difficulties
  final List<String> _difficulties = ['Easy', 'Medium', 'Hard', 'Expert'];

  // Available tags (to be loaded from Firestore)
  List<Map<String, dynamic>> _availableTags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  // Load available tags from Firestore
  Future<void> _loadTags() async {
    setState(() {
      _isLoadingTags = true;
    });

    try {
      final tagsSnapshot = await _firestore.collection('tags').get();

      setState(() {
        _availableTags =
            tagsSnapshot.docs.map((doc) {
              return {
                'id': doc.id,
                'name': doc.data()['name'] ?? 'Unnamed Tag',
              };
            }).toList();
        _isLoadingTags = false;
      });
    } catch (e) {
      print('Error loading tags: $e');
      setState(() {
        _isLoadingTags = false;
      });
    }
  }

  // Create the assessment
  Future<void> _createAssessment() async {
    if (_titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a title for your assessment'),
        ),
      );
      return;
    }

    setState(() {
      _isCreating = true;
    });

    try {
      final String? userId = _auth.currentUser?.uid;
      if (userId == null) {
        throw Exception('User not signed in');
      }

      // Create the assessment document
      final assessmentRef = _firestore.collection('assessments').doc();
      final String assessmentId = assessmentRef.id;

      // Base assessment data
      final Map<String, dynamic> assessmentData = {
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': userId,
        'difficulty': _selectedDifficulty,
        'isPublic': _isPublic,
        'tags': _selectedTags,
        'totalPoints': 0, // Will be calculated based on questions
        'madeByAI': widget.type == 'ai',
      };

      // Add assessment to Firestore
      await assessmentRef.set(assessmentData);

      // Add to user's assessments subcollection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('assessments')
          .doc(assessmentId)
          .set({
            'title': _titleController.text.trim(),
            'createdAt': FieldValue.serverTimestamp(),
          });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assessment created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Navigate back
      Navigator.of(context).pop();
    } catch (e) {
      print('Error creating assessment: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating assessment: $e'),
          backgroundColor: Colors.red,
        ),
      );
      setState(() {
        _isCreating = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Create ${_getAssessmentTypeText()} Assessment'),
        backgroundColor: _getAssessmentTypeColor(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title and description
            const Text(
              'Basic Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),

            // Title field
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Assessment Title',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.title),
              ),
            ),
            const SizedBox(height: 16),

            // Description field
            TextField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
            ),
            const SizedBox(height: 24),

            // Difficulty selector
            const Text(
              'Difficulty',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              children:
                  _difficulties.map((difficulty) {
                    final isSelected = _selectedDifficulty == difficulty;
                    return ChoiceChip(
                      label: Text(difficulty),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedDifficulty = difficulty;
                          });
                        }
                      },
                      backgroundColor: Colors.grey[200],
                      selectedColor: _getDifficultyColor(difficulty),
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : Colors.black,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    );
                  }).toList(),
            ),
            const SizedBox(height: 24),

            // Tags selector
            const Text(
              'Tags',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            _isLoadingTags
                ? const Center(child: CircularProgressIndicator())
                : Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children:
                      _availableTags.map((tag) {
                        final isSelected = _selectedTags.contains(tag['id']);
                        return FilterChip(
                          label: Text(tag['name']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedTags.add(tag['id']);
                              } else {
                                _selectedTags.remove(tag['id']);
                              }
                            });
                          },
                          backgroundColor: Colors.grey[200],
                          selectedColor: const Color(
                            0xFF6A3DE8,
                          ).withOpacity(0.2),
                          checkmarkColor: const Color(0xFF6A3DE8),
                          labelStyle: TextStyle(
                            fontWeight:
                                isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        );
                      }).toList(),
                ),
            const SizedBox(height: 24),

            // Public/Private toggle
            SwitchListTile(
              title: const Text(
                'Make Public',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text(
                'Public assessments can be discovered and used by all users',
              ),
              value: _isPublic,
              onChanged: (value) {
                setState(() {
                  _isPublic = value;
                });
              },
              activeColor: const Color(0xFF6A3DE8),
            ),
            const SizedBox(height: 40),

            // Create button
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isCreating ? null : _createAssessment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _getAssessmentTypeColor(),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                ),
                child:
                    _isCreating
                        ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                        : const Text(
                          'CREATE ASSESSMENT',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // Helper to get text based on assessment type
  String _getAssessmentTypeText() {
    switch (widget.type) {
      case 'ai':
        return 'AI';
      case 'pdf':
        return 'PDF';
      case 'manual':
        return 'Manual';
      default:
        return '';
    }
  }

  // Helper to get color based on assessment type
  Color _getAssessmentTypeColor() {
    switch (widget.type) {
      case 'ai':
        return const Color(0xFF6A3DE8); // Purple
      case 'pdf':
        return const Color(0xFFF4A9A8); // Coral
      case 'manual':
        return const Color(0xFF80AB82); // Green
      default:
        return Colors.blue;
    }
  }

  // Helper to get color based on difficulty
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return const Color(0xFF80AB82); // Green
      case 'medium':
        return const Color(0xFFFFC857); // Gold
      case 'hard':
        return const Color(0xFFF4A9A8); // Coral
      case 'expert':
        return const Color(0xFFE57373); // Red
      default:
        return const Color(0xFF98D8C8); // Teal
    }
  }
}
