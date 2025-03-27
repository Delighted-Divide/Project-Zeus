import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CreateGroupPage extends StatefulWidget {
  const CreateGroupPage({super.key});

  @override
  State<CreateGroupPage> createState() => _CreateGroupPageState();
}

class _CreateGroupPageState extends State<CreateGroupPage> {
  // Controllers for form fields
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();

  // Firebase instances
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Form state
  bool _isPublic = true;
  bool _requiresApproval = true;
  bool _isCreating = false;
  final List<String> _selectedTags = [];

  // Available tags
  List<Map<String, dynamic>> _availableTags = [];
  bool _isLoadingTags = true;

  @override
  void initState() {
    super.initState();
    _loadTags();
  }

  @override
  void dispose() {
    _nameController.dispose();
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

  // Toggle tag selection
  void _toggleTag(String tagId) {
    setState(() {
      if (_selectedTags.contains(tagId)) {
        _selectedTags.remove(tagId);
      } else {
        _selectedTags.add(tagId);
      }
    });
  }

  // Create the group in Firestore
  Future<void> _createGroup() async {
    if (_nameController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a group name')),
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

      // Get current user's display name
      final userDoc = await _firestore.collection('users').doc(userId).get();
      final userData = userDoc.data();
      final String displayName = userData?['displayName'] ?? 'Unknown User';
      final String photoURL = userData?['photoURL'] ?? '';

      // Create the group document
      final groupRef = _firestore.collection('groups').doc();
      final String groupId = groupRef.id;

      await groupRef.set({
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
        'creatorId': userId,
        'photoURL': '', // No photo initially
        'tags': _selectedTags,
        'settings': {
          'visibility': _isPublic ? 'public' : 'private',
          'joinApproval': _requiresApproval,
        },
      });

      // Add the creator as an admin member
      await groupRef.collection('members').doc(userId).set({
        'displayName': displayName,
        'photoURL': photoURL,
        'role': 'admin',
        'joinedAt': FieldValue.serverTimestamp(),
      });

      // Add the group to the user's groups collection
      await _firestore
          .collection('users')
          .doc(userId)
          .collection('groups')
          .doc(groupId)
          .set({
            'name': _nameController.text.trim(),
            'photoURL': '',
            'role': 'admin',
            'joinedAt': FieldValue.serverTimestamp(),
          });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Group created successfully!'),
          backgroundColor: Color(0xFF80AB82), // Green
        ),
      );

      // Return to the previous screen
      Navigator.of(context).pop();
    } catch (e) {
      print('Error creating group: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error creating group: $e'),
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
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Salmon colored top section
          Container(
            color: const Color(0xFFFFA07A), // Salmon background
            child: SafeArea(
              bottom: false, // Don't add bottom padding
              child: Column(
                children: [
                  _buildHeader(),
                  // Curved bottom edge
                  Container(
                    height: 30,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(30),
                        topRight: Radius.circular(30),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Main content area (white background)
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Form fields
                  _buildFormSection(),

                  const SizedBox(height: 20),

                  // Privacy settings
                  _buildPrivacySection(),

                  const SizedBox(height: 20),

                  // Tags selection
                  _buildTagsSection(),

                  const SizedBox(height: 30),

                  // Create button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isCreating ? null : _createGroup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF80AB82), // Green
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                        elevation: 2,
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
                                'CREATE GROUP',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                    ),
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Header with title and back button
  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.arrow_back, color: Colors.black),
            ),
          ),

          const Spacer(),

          // Page title
          const Text(
            'CREATE GROUP',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),

          const Spacer(),

          // Empty container for symmetry
          const SizedBox(width: 40),
        ],
      ),
    );
  }

  // Form fields section
  Widget _buildFormSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group Details',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),

        // Group name field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0E6FA), // Light purple
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              hintText: 'Group Name',
              prefixIcon: Icon(Icons.group, color: Color(0xFF6A3DE8)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(vertical: 15),
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Group description field
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF0E6FA), // Light purple
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Group Description',
              prefixIcon: Icon(Icons.description, color: Color(0xFF6A3DE8)),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                vertical: 15,
                horizontal: 15,
              ),
            ),
          ),
        ),
      ],
    );
  }

  // Privacy settings section
  Widget _buildPrivacySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Privacy Settings',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),

        // Public/Private toggle
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    _isPublic ? Icons.public : Icons.lock,
                    color:
                        _isPublic
                            ? const Color(0xFF80AB82)
                            : const Color(0xFFF4A9A8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _isPublic ? 'Public Group' : 'Private Group',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _isPublic,
                    onChanged: (value) {
                      setState(() {
                        _isPublic = value;
                      });
                    },
                    activeColor: const Color(0xFF80AB82),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _isPublic
                    ? 'Anyone can find and view this group'
                    : 'Only members can view this group',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const Divider(height: 24),

              // Approval toggle
              Row(
                children: [
                  Icon(
                    _requiresApproval ? Icons.check_circle : Icons.person_add,
                    color:
                        _requiresApproval
                            ? const Color(0xFF80AB82)
                            : const Color(0xFFF4A9A8),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _requiresApproval
                          ? 'Admin Approval Required'
                          : 'Anyone Can Join',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  Switch(
                    value: _requiresApproval,
                    onChanged: (value) {
                      setState(() {
                        _requiresApproval = value;
                      });
                    },
                    activeColor: const Color(0xFF80AB82),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _requiresApproval
                    ? 'Admin must approve new member requests'
                    : 'New members can join without approval',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Tags selection section
  Widget _buildTagsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Group Tags',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Select tags that describe your group',
          style: TextStyle(fontSize: 14, color: Colors.grey[600]),
        ),
        const SizedBox(height: 16),

        // Tags grid
        _isLoadingTags
            ? const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: CircularProgressIndicator(),
              ),
            )
            : _availableTags.isEmpty
            ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'No tags available',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
              ),
            )
            : Wrap(
              spacing: 10,
              runSpacing: 10,
              children:
                  _availableTags.map((tag) {
                    final bool isSelected = _selectedTags.contains(tag['id']);
                    return GestureDetector(
                      onTap: () => _toggleTag(tag['id']),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isSelected
                                  ? const Color(0xFF6A3DE8)
                                  : const Color(0xFFF0E6FA),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color:
                                isSelected
                                    ? const Color(0xFF6A3DE8)
                                    : Colors.grey.shade300,
                          ),
                        ),
                        child: Text(
                          tag['name'],
                          style: TextStyle(
                            color:
                                isSelected
                                    ? Colors.white
                                    : const Color(0xFF6A5CB5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
            ),
      ],
    );
  }
}
