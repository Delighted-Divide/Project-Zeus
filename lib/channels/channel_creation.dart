import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ChannelCreationScreen extends StatefulWidget {
  final String groupId;
  final String initialType;

  const ChannelCreationScreen({
    Key? key,
    required this.groupId,
    this.initialType = 'discussion',
  }) : super(key: key);

  @override
  _ChannelCreationScreenState createState() => _ChannelCreationScreenState();
}

class _ChannelCreationScreenState extends State<ChannelCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  String _selectedType = '';
  bool _isCreating = false;
  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Channel')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildChannelTypeSelector(),
              const SizedBox(height: 24),
              _buildChannelForm(),
              const SizedBox(height: 24),
              _buildCreateButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelTypeSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Channel Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _buildTypeCard(
                'discussion',
                'Discussion',
                Icons.forum,
                Colors.blue,
                'A channel for general discussions and conversations.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeCard(
                'assessment',
                'Assessment',
                Icons.assignment,
                Colors.orange,
                'A channel for quizzes, tests, and other assessments.',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildTypeCard(
                'resource',
                'Resource',
                Icons.folder,
                Colors.green,
                'A channel for sharing documents, files, and other resources.',
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTypeCard(
    String type,
    String title,
    IconData icon,
    Color color,
    String description,
  ) {
    final isSelected = _selectedType == type;

    return Card(
      elevation: isSelected ? 4 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? color : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 32),
              const SizedBox(height: 8),
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.bold, color: color),
              ),
              const SizedBox(height: 4),
              Text(
                description,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Channel Details',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Channel Name',
            hintText: 'Enter channel name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade100,
            prefixIcon: Icon(
              _getIconForChannelType(_selectedType),
              color: _getColorForChannelType(_selectedType),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a channel name';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: 'Description',
            hintText: 'Enter channel description',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _instructionsController,
          decoration: InputDecoration(
            labelText: 'Instructions (optional)',
            hintText: 'Enter instructions for channel members',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            filled: true,
            fillColor: Colors.grey.shade100,
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        _buildChannelTypeSpecificFields(),
      ],
    );
  }

  Widget _buildChannelTypeSpecificFields() {
    switch (_selectedType) {
      case 'discussion':
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Discussion channels are perfect for:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• General conversations'),
            Text('• Q&A sessions'),
            Text('• Collaborative discussions'),
            Text('• Sharing ideas and feedback'),
          ],
        );

      case 'assessment':
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Assessment channels allow you to:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Create quizzes and tests'),
            Text('• Assign deadlines and time limits'),
            Text('• Track student performance'),
            Text('• Provide feedback on submissions'),
          ],
        );

      case 'resource':
        return const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Resource channels are great for:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('• Sharing documents and files'),
            Text('• Organizing learning materials'),
            Text('• Providing reference content'),
            Text('• Uploading various file types'),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _isCreating ? null : _createChannel,
        style: ElevatedButton.styleFrom(
          backgroundColor: _getColorForChannelType(_selectedType),
        ),
        child:
            _isCreating
                ? CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                )
                : const Text(
                  'Create Channel',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
      ),
    );
  }

  Color _getColorForChannelType(String type) {
    switch (type) {
      case 'discussion':
        return Colors.blue;
      case 'assessment':
        return Colors.orange;
      case 'resource':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForChannelType(String type) {
    switch (type) {
      case 'discussion':
        return Icons.forum;
      case 'assessment':
        return Icons.assignment;
      case 'resource':
        return Icons.folder;
      default:
        return Icons.circle;
    }
  }

  void _createChannel() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isCreating = true;
    });

    try {
      final name = _nameController.text.trim();
      final description = _descriptionController.text.trim();
      final instructions = _instructionsController.text.trim();
      final userId = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('channels')
          .add({
            'name': name,
            'description': description,
            'type': _selectedType,
            'createdAt': FieldValue.serverTimestamp(),
            'createdBy': userId,
            'instructions': instructions,
          });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name channel created successfully')),
      );

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error creating channel: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
}
