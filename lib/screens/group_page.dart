import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'group_members.dart';
import 'group_channels.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';
import '../channels/channel_creation.dart';

class GroupPage extends StatefulWidget {
  final String groupId;

  const GroupPage({Key? key, required this.groupId}) : super(key: key);

  @override
  _GroupPageState createState() => _GroupPageState();
}

class _GroupPageState extends State<GroupPage>
    with SingleTickerProviderStateMixin {
  GroupModel? _group;
  UserRole? _userRole;
  bool _isLoading = true;
  bool _showMembers = false; // Default to showing channels
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Animation controller for switching sections
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _loadGroupData();

    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get current user ID
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;

      // Load group data
      final groupDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .get();

      if (!groupDoc.exists) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Group not found')));
        Navigator.pop(context);
        return;
      }

      // Create group model
      _group = GroupModel.fromFirestore(groupDoc);

      // Get user's role in the group
      final memberDoc =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('members')
              .doc(currentUserId)
              .get();

      if (memberDoc.exists) {
        final role = memberDoc.data()?['role'] as String?;
        _userRole = role == 'mentor' ? UserRole.mentor : UserRole.member;
      } else {
        // User is not a member of this group
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You are not a member of this group')),
        );
        Navigator.pop(context);
        return;
      }
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading group: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Toggle between members and channels with animation
  void _toggleSection() {
    setState(() {
      _showMembers = !_showMembers;
      if (_showMembers) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Loading group...',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      );
    }

    if (_group == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: const Center(
          child: Text(
            'Could not load group data',
            style: TextStyle(fontSize: 16),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFF282c34), // Dark background color
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF1e2124), // Discord-like dark header
        title: Row(
          children: [
            // Group avatar
            CircleAvatar(
              backgroundColor: Colors.grey.shade800,
              backgroundImage:
                  _group!.photoURL != null
                      ? NetworkImage(_group!.photoURL!)
                      : null,
              radius: 16,
              child:
                  _group!.photoURL == null
                      ? Text(
                        _group!.name[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                      : null,
            ),
            const SizedBox(width: 10),
            // Group name
            Text(
              _group!.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        actions: [
          // Group info button
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white70),
            tooltip: 'Group Information',
            onPressed: () => _showGroupInfo(),
          ),
          // Edit group button (only for mentors)
          if (_userRole == UserRole.mentor)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white70),
              tooltip: 'Edit Group',
              onPressed: () => _editGroup(),
            ),
        ],
      ),
      // Add a floating action button for mentors
      floatingActionButton:
          _userRole == UserRole.mentor
              ? FloatingActionButton(
                backgroundColor: const Color(0xFF7289da), // Discord blurple
                foregroundColor: Colors.white,
                elevation: 4,
                onPressed: () => _showActionMenu(),
                child: const Icon(Icons.add),
              )
              : null,
      // Main body with Discord-like sidebar and content layout
      body: Row(
        children: [
          // Left sidebar for navigation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            width: 70,
            color: const Color(0xFF1e2124), // Discord dark sidebar
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Channels button
                _buildSidebarButton(
                  icon: Icons.forum,
                  label: 'Channels',
                  isSelected: !_showMembers,
                  onTap: () {
                    if (_showMembers) _toggleSection();
                  },
                ),
                const SizedBox(height: 8),
                // Members button
                _buildSidebarButton(
                  icon: Icons.people,
                  label: 'Members',
                  isSelected: _showMembers,
                  onTap: () {
                    if (!_showMembers) _toggleSection();
                  },
                ),
                const Divider(
                  color: Color(0xFF424549),
                  height: 24,
                  thickness: 1,
                ),
                // Settings button
                _buildSidebarButton(
                  icon: Icons.settings,
                  label: 'Settings',
                  isSelected: false,
                  onTap: () => _showGroupInfo(),
                ),
              ],
            ),
          ),
          // Main content area
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 400),
              transitionBuilder: (Widget child, Animation<double> animation) {
                return FadeTransition(
                  opacity: animation,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: Offset(_showMembers ? -0.2 : 0.2, 0),
                      end: Offset.zero,
                    ).animate(animation),
                    child: child,
                  ),
                );
              },
              child:
                  _showMembers
                      ? GroupMembersPage(
                        key: const ValueKey('members'),
                        groupId: widget.groupId,
                        userRole: _userRole!,
                      )
                      : GroupChannelsPage(
                        key: const ValueKey('channels'),
                        groupId: widget.groupId,
                        userRole: _userRole!,
                      ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to build sidebar buttons
  Widget _buildSidebarButton({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: label,
      preferBelow: false,
      verticalOffset: 20,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF7289da) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Center(
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  void _showGroupInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            backgroundColor: const Color(0xFF36393f),
            title: Text(
              _group!.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_group!.photoURL != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: NetworkImage(_group!.photoURL!),
                      ),
                    ),
                  ),
                const Text(
                  'Description',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7289da),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _group!.description,
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Created',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7289da),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTimestamp(_group!.createdAt),
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Visibility',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7289da),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color:
                        _group!.settings.visibility == 'public'
                            ? Colors.green.withOpacity(0.2)
                            : Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _group!.settings.visibility.toUpperCase(),
                    style: TextStyle(
                      color:
                          _group!.settings.visibility == 'public'
                              ? Colors.green
                              : Colors.orange,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Tags',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF7289da),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      _group!.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              backgroundColor: const Color(
                                0xFF7289da,
                              ).withOpacity(0.2),
                              labelStyle: const TextStyle(
                                color: Color(0xFF7289da),
                                fontSize: 12,
                              ),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                            ),
                          )
                          .toList(),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Color(0xFF7289da)),
                ),
              ),
            ],
          ),
    );
  }

  void _editGroup() {
    // Navigate to edit group page
    // This is a placeholder for your implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit group functionality would go here')),
    );
  }

  String _formatTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  void _showActionMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => Container(
            decoration: const BoxDecoration(
              color: Color(0xFF36393f),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sheet handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade500,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Menu options
                _buildActionMenuItem(
                  icon: Icons.forum,
                  iconColor: Colors.blue,
                  title: 'Create Discussion Channel',
                  subtitle: 'For conversations and general chat',
                  onTap: () {
                    Navigator.pop(context);
                    _createChannel('discussion');
                  },
                ),
                const Divider(color: Color(0xFF2f3136), height: 1),
                _buildActionMenuItem(
                  icon: Icons.assignment,
                  iconColor: Colors.orange,
                  title: 'Create Assessment Channel',
                  subtitle: 'For quizzes and assessments',
                  onTap: () {
                    Navigator.pop(context);
                    _createChannel('assessment');
                  },
                ),
                const Divider(color: Color(0xFF2f3136), height: 1),
                _buildActionMenuItem(
                  icon: Icons.folder,
                  iconColor: Colors.green,
                  title: 'Create Resource Channel',
                  subtitle: 'For sharing files and resources',
                  onTap: () {
                    Navigator.pop(context);
                    _createChannel('resource');
                  },
                ),
                const Divider(color: Color(0xFF2f3136), height: 1),
                _buildActionMenuItem(
                  icon: Icons.person_add,
                  iconColor: Colors.purple,
                  title: 'Invite Members',
                  subtitle: 'Add new people to this group',
                  onTap: () {
                    Navigator.pop(context);
                    _inviteMembers();
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildActionMenuItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: iconColor),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  void _createChannel(String type) {
    // Navigate to channel creation page
    Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => ChannelCreationScreen(
              groupId: widget.groupId,
              initialType: type,
            ),
      ),
    ).then((_) => setState(() {})); // Refresh the UI when returning
  }

  void _inviteMembers() {
    // Navigate to member invitation page
    // This is a placeholder for your implementation
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Invite members functionality would go here'),
      ),
    );
  }
}
