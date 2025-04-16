import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';

class AssessmentChannelPage extends StatefulWidget {
  final String groupId;
  final GroupChannel channel;
  final UserRole userRole;

  const AssessmentChannelPage({
    Key? key,
    required this.groupId,
    required this.channel,
    required this.userRole,
  }) : super(key: key);

  @override
  _AssessmentChannelPageState createState() => _AssessmentChannelPageState();
}

class _AssessmentChannelPageState extends State<AssessmentChannelPage> {
  bool _isLoading = true;
  List<AssessmentInfo> _assessments = [];

  @override
  void initState() {
    super.initState();
    _loadAssessments();
  }

  Future<void> _loadAssessments() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('assessments')
              .orderBy('assignedAt', descending: true)
              .get();

      _assessments =
          snapshot.docs
              .map((doc) => AssessmentInfo.fromFirestore(doc))
              .toList();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading assessments: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const Icon(Icons.assignment, size: 20),
            const SizedBox(width: 8),
            Text(widget.channel.name),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showChannelInfo(),
          ),
          if (widget.userRole == UserRole.mentor)
            PopupMenuButton(
              icon: const Icon(Icons.more_vert),
              onSelected: (value) {
                if (value == 'edit') {
                  _editChannel();
                } else if (value == 'delete') {
                  _confirmDeleteChannel();
                }
              },
              itemBuilder:
                  (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Text('Edit Channel'),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text('Delete Channel'),
                    ),
                  ],
            ),
        ],
      ),
      body: Column(
        children: [
          if (widget.channel.instructions.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.orange.shade200, width: 1),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Colors.orange.shade700,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.channel.instructions,
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _assessments.isEmpty
                    ? _buildEmptyState()
                    : _buildAssessmentsList(),
          ),
        ],
      ),
      floatingActionButton:
          widget.userRole == UserRole.mentor
              ? FloatingActionButton(
                onPressed: () => _addAssessment(),
                child: const Icon(Icons.add),
                backgroundColor: Colors.orange,
              )
              : null,
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.assignment_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No assessments yet',
            style: TextStyle(fontSize: 18, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          if (widget.userRole == UserRole.mentor)
            ElevatedButton.icon(
              onPressed: () => _addAssessment(),
              icon: const Icon(Icons.add),
              label: const Text('Add Assessment'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            ),
        ],
      ),
    );
  }

  Widget _buildAssessmentsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _assessments.length,
      itemBuilder: (context, index) {
        final assessment = _assessments[index];
        return _buildAssessmentCard(assessment);
      },
    );
  }

  Widget _buildAssessmentCard(AssessmentInfo assessment) {
    final now = DateTime.now();
    final startDate = assessment.startTime.toDate();
    final endDate = assessment.endTime.toDate();
    final isActive = now.isAfter(startDate) && now.isBefore(endDate);
    final isUpcoming = now.isBefore(startDate);
    final isExpired = now.isAfter(endDate);

    // Get status text and color
    String statusText;
    Color statusColor;

    if (isUpcoming) {
      statusText = 'Upcoming';
      statusColor = Colors.blue;
    } else if (isActive) {
      statusText = 'Active';
      statusColor = Colors.green;
    } else {
      statusText = 'Expired';
      statusColor = Colors.red;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _viewAssessment(assessment),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  assessment.madeByAI
                      ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.purple,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI',
                              style: TextStyle(
                                color: Colors.purple.shade800,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      )
                      : const Icon(Icons.assignment, color: Colors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      assessment.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (assessment.description.isNotEmpty)
                    Text(
                      assessment.description,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Start Time',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDateTime(startDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'End Time',
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              _formatDateTime(endDate),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (assessment.hasTimer)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(
                        children: [
                          Icon(
                            Icons.timer,
                            size: 16,
                            color: Colors.orange.shade700,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Time Limit: ${assessment.timerDuration} minutes',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
              child: Row(
                children: [
                  // Get assigned by user name
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(assessment.assignedBy)
                            .get(),
                    builder: (context, snapshot) {
                      String assignerName = 'Unknown User';

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        assignerName =
                            userData['displayName'] as String? ??
                            'Unknown User';
                      }

                      return Expanded(
                        child: Text(
                          'Assigned by $assignerName',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      );
                    },
                  ),
                  // Show submission status for current user
                  FutureBuilder<QuerySnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('groups')
                            .doc(widget.groupId)
                            .collection('channels')
                            .doc(widget.channel.id)
                            .collection('assessments')
                            .doc(assessment.id)
                            .collection('submissions')
                            .where(
                              'userId',
                              isEqualTo: FirebaseAuth.instance.currentUser!.uid,
                            )
                            .limit(1)
                            .get(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return TextButton.icon(
                          onPressed:
                              isActive
                                  ? () => _takeAssessment(assessment)
                                  : null,
                          icon: const Icon(Icons.play_arrow),
                          label: Text(
                            isUpcoming
                                ? 'Not Available Yet'
                                : isExpired
                                ? 'Not Submitted'
                                : 'Start',
                          ),
                          style: TextButton.styleFrom(
                            foregroundColor:
                                isActive ? Colors.green : Colors.grey,
                          ),
                        );
                      }

                      final submission =
                          snapshot.data!.docs.first.data()
                              as Map<String, dynamic>;
                      final status =
                          submission['status'] as String? ?? 'in-progress';

                      IconData icon;
                      String label;
                      Color color;

                      switch (status) {
                        case 'in-progress':
                          icon = Icons.play_arrow;
                          label = 'Continue';
                          color = Colors.blue;
                          break;
                        case 'submitted':
                          icon = Icons.check_circle;
                          label = 'Submitted';
                          color = Colors.orange;
                          break;
                        case 'evaluated':
                          icon = Icons.assignment_turned_in;
                          label = 'View Results';
                          color = Colors.green;
                          break;
                        default:
                          icon = Icons.help;
                          label = 'Unknown';
                          color = Colors.grey;
                      }

                      return TextButton.icon(
                        onPressed: () => _viewSubmission(assessment, status),
                        icon: Icon(icon),
                        label: Text(label),
                        style: TextButton.styleFrom(foregroundColor: color),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
  }

  String _formatTimestamp(Timestamp timestamp) {
    return _formatDateTime(timestamp.toDate());
  }

  void _showChannelInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(widget.channel.name),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Description: ${widget.channel.description}'),
                const SizedBox(height: 8),
                Text('Created: ${_formatTimestamp(widget.channel.createdAt)}'),
                const SizedBox(height: 8),
                if (widget.channel.instructions.isNotEmpty) ...[
                  const Text(
                    'Instructions:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(widget.channel.instructions),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ],
          ),
    );
  }

  void _editChannel() {
    // Navigate to channel edit page
  }

  void _confirmDeleteChannel() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Delete Channel'),
            content: const Text(
              'Are you sure you want to delete this channel? '
              'This action cannot be undone and all assessments will be lost.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteChannel();
                },
                child: const Text(
                  'Delete',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _deleteChannel() async {
    try {
      // First, get all assessments
      final assessmentsSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('assessments')
              .get();

      final batch = FirebaseFirestore.instance.batch();

      // For each assessment, get and delete submissions
      for (final assessmentDoc in assessmentsSnapshot.docs) {
        final submissionsSnapshot =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('channels')
                .doc(widget.channel.id)
                .collection('assessments')
                .doc(assessmentDoc.id)
                .collection('submissions')
                .get();

        for (final submissionDoc in submissionsSnapshot.docs) {
          batch.delete(submissionDoc.reference);
        }

        batch.delete(assessmentDoc.reference);
      }

      // Delete the channel document
      batch.delete(
        FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('channels')
            .doc(widget.channel.id),
      );

      await batch.commit();

      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Channel deleted')));
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error deleting channel: $e')));
    }
  }

  void _addAssessment() {
    // Navigate to add assessment page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => AddAssessmentPage(
              groupId: widget.groupId,
              channelId: widget.channel.id,
            ),
      ),
    ).then((value) {
      if (value == true) {
        _loadAssessments();
      }
    });
  }

  void _viewAssessment(AssessmentInfo assessment) {
    // Navigate to view assessment page
  }

  void _takeAssessment(AssessmentInfo assessment) {
    // Navigate to take assessment page
  }

  void _viewSubmission(AssessmentInfo assessment, String status) {
    // Navigate to view submission page
  }
}

class AddAssessmentPage extends StatelessWidget {
  final String groupId;
  final String channelId;

  const AddAssessmentPage({
    Key? key,
    required this.groupId,
    required this.channelId,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Placeholder for assessment creation interface
    return Scaffold(
      appBar: AppBar(title: const Text('Add Assessment')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.assignment_add, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Assessment Creation Interface',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text(
                'Here you would build an interface to create or import assessments, '
                'including questions, answers, settings, etc.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Return to Channel'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
