import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/group_model.dart';
import '../channels/discussion_channel.dart';
import '../channels/assessment_channel.dart';
import '../channels/resource_channel.dart';
import '../channels/channel_creation.dart';

class GroupChannelsPage extends StatefulWidget {
  final String groupId;
  final UserRole userRole;

  const GroupChannelsPage({
    Key? key,
    required this.groupId,
    required this.userRole,
  }) : super(key: key);

  @override
  _GroupChannelsPageState createState() => _GroupChannelsPageState();
}

class _GroupChannelsPageState extends State<GroupChannelsPage>
    with SingleTickerProviderStateMixin {
  String _selectedChannelType = 'all';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;

  // Animation controller for channel selection
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize animation controller
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );

    _filterAnimationController.forward();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _filterAnimationController.dispose();
    super.dispose();
  }

  void _updateChannelType(String type) {
    if (_selectedChannelType != type) {
      _filterAnimationController.reset();
      setState(() {
        _selectedChannelType = type;
      });
      _filterAnimationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36393f), // Discord dark theme
      body: Column(
        children: [
          _buildSearchAndFilterBar(),
          Expanded(
            child: FadeTransition(
              opacity: _filterAnimation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.05),
                  end: Offset.zero,
                ).animate(_filterAnimation),
                child: _buildChannelsList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2f3136),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Search channels...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              prefixIcon: const Icon(Icons.search, color: Colors.grey),
              suffixIcon:
                  _isSearching
                      ? IconButton(
                        icon: const Icon(Icons.clear, color: Colors.grey),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _isSearching = false;
                          });
                          FocusScope.of(context).unfocus();
                        },
                      )
                      : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: const Color(0xFF202225),
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (value) {
              setState(() {
                _isSearching = value.isNotEmpty;
              });
            },
          ),
          const SizedBox(height: 12),

          // Channel type filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', Icons.all_inclusive),
                const SizedBox(width: 10),
                _buildFilterChip('Discussion', 'discussion', Icons.forum),
                const SizedBox(width: 10),
                _buildFilterChip('Assessment', 'assessment', Icons.assignment),
                const SizedBox(width: 10),
                _buildFilterChip('Resource', 'resource', Icons.folder),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedChannelType == value;
    final color = _getColorForChannelType(value);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected ? color.withOpacity(0.2) : const Color(0xFF202225),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? color : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: InkWell(
        onTap: () => _updateChannelType(value),
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: isSelected ? color : Colors.grey),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? color : Colors.grey,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChannelsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _getChannelsStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7289da)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _getIconForChannelType(_selectedChannelType),
                  size: 64,
                  color: Colors.grey.shade700,
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedChannelType == 'all'
                      ? 'No channels in this group yet'
                      : 'No ${_selectedChannelType} channels yet',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (widget.userRole == UserRole.mentor)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton.icon(
                      onPressed: () => _createChannel(),
                      icon: const Icon(Icons.add),
                      label: Text(
                        'Create ${_selectedChannelType == 'all' ? 'Channel' : _selectedChannelType.capitalize() + ' Channel'}',
                      ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF7289da),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          );
        }

        // Filter by search query if needed
        final query = _searchController.text.toLowerCase();
        final filteredDocs =
            _isSearching
                ? snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final name = (data['name'] as String? ?? '').toLowerCase();
                  final description =
                      (data['description'] as String? ?? '').toLowerCase();
                  return name.contains(query) || description.contains(query);
                }).toList()
                : snapshot.data!.docs;

        if (filteredDocs.isEmpty) {
          return Center(
            child: Text(
              'No matching channels found',
              style: TextStyle(fontSize: 16, color: Colors.grey.shade400),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final doc = filteredDocs[index];
            final channel = GroupChannel.fromFirestore(doc);

            // Use a staggered animation effect
            return AnimatedOpacity(
              duration: Duration(milliseconds: 300 + (index * 50)),
              opacity: 1.0,
              curve: Curves.easeInOut,
              child: AnimatedPadding(
                duration: Duration(milliseconds: 300 + (index * 50)),
                padding: const EdgeInsets.only(top: 0),
                curve: Curves.easeInOut,
                child: _buildChannelCard(channel, index),
              ),
            );
          },
        );
      },
    );
  }

  Stream<QuerySnapshot> _getChannelsStream() {
    Query query = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('channels')
        .orderBy('createdAt', descending: true);

    if (_selectedChannelType != 'all') {
      query = query.where('type', isEqualTo: _selectedChannelType);
    }

    return query.snapshots();
  }

  Widget _buildChannelCard(GroupChannel channel, int index) {
    final channelColor = _getColorForChannelType(channel.type);
    final channelIcon = _getIconForChannelType(channel.type);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF2f3136),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => _openChannel(channel),
            splashColor: channelColor.withOpacity(0.1),
            highlightColor: channelColor.withOpacity(0.05),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Channel header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: channelColor.withOpacity(0.1),
                    border: Border(
                      left: BorderSide(color: channelColor, width: 4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(channelIcon, color: channelColor),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          channel.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: channelColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          channel.type.capitalize(),
                          style: TextStyle(
                            color: channelColor,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Channel description and details
                if (channel.description.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      channel.description,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                // Channel metadata
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      FutureBuilder<DocumentSnapshot>(
                        future:
                            FirebaseFirestore.instance
                                .collection('users')
                                .doc(channel.createdBy)
                                .get(),
                        builder: (context, snapshot) {
                          String creatorName = 'Unknown';

                          if (snapshot.hasData && snapshot.data!.exists) {
                            final userData =
                                snapshot.data!.data() as Map<String, dynamic>;
                            creatorName =
                                userData['displayName'] as String? ?? 'Unknown';
                          }

                          return Row(
                            children: [
                              const Icon(
                                Icons.person_outline,
                                size: 14,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                creatorName,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 14,
                            color: Colors.grey,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatTimestamp(channel.createdAt),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade400,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Channel specific indicators
                if (channel.type == 'assessment')
                  _buildAssessmentChannelIndicator(channel),
                if (channel.type == 'resource')
                  _buildResourceChannelIndicator(channel),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentChannelIndicator(GroupChannel channel) {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(channel.id)
              .collection('assessments')
              .snapshots(),
      builder: (context, snapshot) {
        int assessmentCount = 0;

        if (snapshot.hasData) {
          assessmentCount = snapshot.data!.docs.length;
        }

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.1),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.assessment, color: Colors.orange.shade300, size: 16),
              const SizedBox(width: 8),
              Text(
                '$assessmentCount assessment${assessmentCount == 1 ? '' : 's'}',
                style: TextStyle(
                  color: Colors.orange.shade300,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.orange.shade300,
                size: 14,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildResourceChannelIndicator(GroupChannel channel) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.description, color: Colors.green.shade300, size: 16),
          const SizedBox(width: 8),
          Text(
            'Resources available',
            style: TextStyle(
              color: Colors.green.shade300,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Icon(Icons.arrow_forward_ios, color: Colors.green.shade300, size: 14),
        ],
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
      case 'all':
        return const Color(0xFF7289da); // Discord blurple
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
      case 'all':
        return Icons.all_inclusive;
      default:
        return Icons.circle;
    }
  }

  String _formatTimestamp(Timestamp timestamp) {
    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'just now';
    }
  }

  void _openChannel(GroupChannel channel) {
    Widget channelPage;

    switch (channel.type) {
      case 'discussion':
        channelPage = DiscussionChannelPage(
          groupId: widget.groupId,
          channel: channel,
          userRole: widget.userRole,
        );
        break;
      case 'assessment':
        channelPage = AssessmentChannelPage(
          groupId: widget.groupId,
          channel: channel,
          userRole: widget.userRole,
        );
        break;
      case 'resource':
        channelPage = ResourceChannelPage(
          groupId: widget.groupId,
          channel: channel,
          userRole: widget.userRole,
        );
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unknown channel type: ${channel.type}')),
        );
        return;
    }

    // Navigate with a nice transition
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => channelPage,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          var begin = const Offset(1.0, 0.0);
          var end = Offset.zero;
          var curve = Curves.easeInOut;
          var tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
      ),
    );
  }

  void _createChannel() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChannelCreationScreen(
              groupId: widget.groupId,
              initialType:
                  _selectedChannelType == 'all'
                      ? 'discussion'
                      : _selectedChannelType,
            ),
      ),
    );
  }
}

// Extension to capitalize first letter
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}
