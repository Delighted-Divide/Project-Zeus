import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';

class GroupMembersPage extends StatefulWidget {
  final String groupId;
  final UserRole userRole;

  const GroupMembersPage({
    Key? key,
    required this.groupId,
    required this.userRole,
  }) : super(key: key);

  @override
  _GroupMembersPageState createState() => _GroupMembersPageState();
}

class _GroupMembersPageState extends State<GroupMembersPage>
    with SingleTickerProviderStateMixin {
  final TextEditingController _searchController = TextEditingController();
  List<GroupMember> _filteredMembers = [];
  List<GroupMember> _allMembers = [];
  bool _isLoading = true;
  bool _isSearching = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _loadMembers();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadMembers() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final querySnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('members')
              .get();

      _allMembers =
          querySnapshot.docs
              .map((doc) => GroupMember.fromFirestore(doc))
              .toList();

      _allMembers.sort((a, b) {
        if (a.ismentor && !b.ismentor) return -1;
        if (!a.ismentor && b.ismentor) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      _filteredMembers = List.from(_allMembers);

      _animationController.forward();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading members: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterMembers(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredMembers = List.from(_allMembers);
      } else {
        _filteredMembers =
            _allMembers
                .where(
                  (member) => member.displayName.toLowerCase().contains(
                    query.toLowerCase(),
                  ),
                )
                .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36393f),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child:
                _isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF7289da),
                        ),
                      ),
                    )
                    : _filteredMembers.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.person_off,
                            size: 64,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _isSearching
                                ? 'No matching members found'
                                : 'No members in this group yet',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade400,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : FadeTransition(
                      opacity: _fadeAnimation,
                      child: _buildMembersList(),
                    ),
          ),
          if (widget.userRole == UserRole.mentor && !_isSearching)
            _buildPendingRequestsButton(),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2f3136),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: TextField(
        controller: _searchController,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search members...',
          hintStyle: TextStyle(color: Colors.grey.shade400),
          prefixIcon: const Icon(Icons.search, color: Colors.grey),
          suffixIcon:
              _isSearching
                  ? IconButton(
                    icon: const Icon(Icons.clear, color: Colors.grey),
                    onPressed: () {
                      _searchController.clear();
                      _filterMembers('');
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
          _filterMembers(value);
          setState(() {
            _isSearching = value.isNotEmpty;
          });
        },
      ),
    );
  }

  Widget _buildMembersList() {
    final mentors =
        _filteredMembers.where((member) => member.ismentor).toList();
    final regularMembers =
        _filteredMembers.where((member) => !member.ismentor).toList();

    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      children: [
        if (mentors.isNotEmpty) ...[
          _buildRoleHeader('Mentors', Icons.star, Colors.purple),
          ...mentors.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            return _buildMemberTile(member, index, true);
          }),
          const SizedBox(height: 16),
        ],

        if (regularMembers.isNotEmpty) ...[
          _buildRoleHeader('Members', Icons.people, Colors.blue),
          ...regularMembers.asMap().entries.map((entry) {
            final index = entry.key;
            final member = entry.value;
            return _buildMemberTile(member, index, false);
          }),
        ],
      ],
    );
  }

  Widget _buildRoleHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: color.withOpacity(0.3))),
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMember member, int index, bool ismentor) {
    final currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final isCurrentUser = member.userId == currentUserId;

    final delay = Duration(milliseconds: 50 * index);

    return FutureBuilder(
      future: Future.delayed(delay),
      builder: (context, snapshot) {
        return AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          child: AnimatedPadding(
            padding: const EdgeInsets.only(top: 0),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              color: const Color(0xFF2f3136),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(
                  color:
                      ismentor
                          ? Colors.purple.withOpacity(0.3)
                          : Colors.transparent,
                  width: 1,
                ),
              ),
              child: InkWell(
                onTap: () => _showMemberDetails(member),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Stack(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor:
                                ismentor
                                    ? Colors.purple.withOpacity(0.2)
                                    : Colors.blue.withOpacity(0.2),
                            backgroundImage:
                                member.photoURL != null
                                    ? NetworkImage(member.photoURL!)
                                    : null,
                            child:
                                member.photoURL == null
                                    ? Text(
                                      member.displayName[0].toUpperCase(),
                                      style: TextStyle(
                                        color:
                                            ismentor
                                                ? Colors.purple
                                                : Colors.blue,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    )
                                    : null,
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: const Color(0xFF2f3136),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  member.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    fontSize: 15,
                                  ),
                                ),
                                if (isCurrentUser)
                                  Container(
                                    margin: const EdgeInsets.only(left: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'YOU',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.grey,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              ismentor ? 'Mentor' : 'Member',
                              style: TextStyle(
                                color:
                                    ismentor
                                        ? Colors.purple.shade300
                                        : Colors.grey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.userRole == UserRole.mentor && !isCurrentUser)
                        PopupMenuButton(
                          icon: const Icon(
                            Icons.more_vert,
                            color: Colors.grey,
                            size: 20,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: const Color(0xFF202225),
                          onSelected:
                              (value) => _handleMemberAction(value, member),
                          itemBuilder:
                              (context) => [
                                if (!ismentor)
                                  PopupMenuItem(
                                    value: 'make_mentor',
                                    child: _buildPopupMenuItem(
                                      'Make Mentor',
                                      Icons.star,
                                      Colors.purple,
                                    ),
                                  ),
                                if (ismentor)
                                  PopupMenuItem(
                                    value: 'remove_mentor',
                                    child: _buildPopupMenuItem(
                                      'Remove Mentor Status',
                                      Icons.star_border,
                                      Colors.orange,
                                    ),
                                  ),
                                PopupMenuItem(
                                  value: 'remove',
                                  child: _buildPopupMenuItem(
                                    'Remove from Group',
                                    Icons.person_remove,
                                    Colors.red,
                                  ),
                                ),
                              ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopupMenuItem(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Text(text, style: const TextStyle(color: Colors.white)),
      ],
    );
  }

  Widget _buildPendingRequestsButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF2f3136),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('groups')
                .doc(widget.groupId)
                .collection('joinRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
        builder: (context, snapshot) {
          final int requestCount =
              snapshot.hasData ? snapshot.data!.docs.length : 0;

          return ElevatedButton.icon(
            onPressed: () => _viewPendingRequests(),
            icon: Stack(
              children: [
                const Icon(Icons.person_add),
                if (requestCount > 0)
                  Positioned(
                    right: -2,
                    top: -2,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 14,
                        minHeight: 14,
                      ),
                      child: Text(
                        requestCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
            label: Text(
              requestCount > 0
                  ? 'Pending Requests ($requestCount)'
                  : 'Pending Requests',
            ),
            style: ElevatedButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor:
                  requestCount > 0 ? Colors.purple : const Color(0xFF7289da),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showMemberDetails(GroupMember member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => FutureBuilder<DocumentSnapshot>(
            future:
                FirebaseFirestore.instance
                    .collection('users')
                    .doc(member.userId)
                    .get(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.6,
                  decoration: const BoxDecoration(
                    color: Color(0xFF36393f),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF7289da),
                      ),
                    ),
                  ),
                );
              }

              if (!snapshot.hasData || !snapshot.data!.exists) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.3,
                  decoration: const BoxDecoration(
                    color: Color(0xFF36393f),
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      'User details not available',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                );
              }

              final userData = snapshot.data!.data() as Map<String, dynamic>;
              final user = UserModel(
                id: member.userId,
                displayName: userData['displayName'] as String? ?? 'Unknown',
                email: userData['email'] as String? ?? '',
                photoURL: userData['photoURL'] as String?,
                createdAt:
                    userData['createdAt'] as Timestamp? ?? Timestamp.now(),
                bio: userData['bio'] as String? ?? '',
                status: userData['status'] as String? ?? '',
                isActive: userData['isActive'] as bool? ?? false,
                privacyLevel: userData['privacyLevel'] as String? ?? 'private',
                favTags: List<String>.from(userData['favTags'] ?? []),
              );

              return Container(
                height: MediaQuery.of(context).size.height * 0.6,
                decoration: const BoxDecoration(
                  color: Color(0xFF36393f),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(top: 12, bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade600,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Hero(
                                tag: 'member-avatar-${member.userId}',
                                child: CircleAvatar(
                                  radius: 40,
                                  backgroundColor:
                                      member.ismentor
                                          ? Colors.purple.withOpacity(0.2)
                                          : Colors.blue.withOpacity(0.2),
                                  backgroundImage:
                                      user.photoURL != null
                                          ? NetworkImage(user.photoURL!)
                                          : null,
                                  child:
                                      user.photoURL == null
                                          ? Text(
                                            user.displayName[0].toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 32,
                                              color:
                                                  member.ismentor
                                                      ? Colors.purple
                                                      : Colors.blue,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                          : null,
                                ),
                              ),
                              const SizedBox(width: 20),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user.displayName,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            member.ismentor
                                                ? Colors.purple.withOpacity(0.2)
                                                : Colors.blue.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        member.ismentor ? 'Mentor' : 'Member',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color:
                                              member.ismentor
                                                  ? Colors.purple.shade300
                                                  : Colors.blue.shade300,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Joined ${_formatDate(member.joinedAt.toDate())}',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          if (user.status.isNotEmpty) ...[
                            _buildSectionHeader('Status', Icons.mood),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f3136),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color:
                                          user.isActive
                                              ? Colors.green
                                              : Colors.grey,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      user.status,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          if (user.bio.isNotEmpty) ...[
                            _buildSectionHeader('About', Icons.info_outline),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f3136),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                user.bio,
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],

                          if (user.favTags.isNotEmpty) ...[
                            _buildSectionHeader('Interests', Icons.local_offer),
                            Container(
                              margin: const EdgeInsets.only(bottom: 24),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2f3136),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children:
                                    user.favTags
                                        .map(
                                          (tag) => Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF7289da,
                                              ).withOpacity(0.2),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              tag,
                                              style: TextStyle(
                                                color: const Color(
                                                  0xFF7289da,
                                                ).withOpacity(0.8),
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                        .toList(),
                              ),
                            ),
                          ],

                          if (widget.userRole == UserRole.mentor &&
                              member.userId !=
                                  FirebaseAuth.instance.currentUser!.uid) ...[
                            _buildSectionHeader(
                              'Actions',
                              Icons.admin_panel_settings,
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildActionButton(
                                    icon:
                                        member.ismentor
                                            ? Icons.star_border
                                            : Icons.star,
                                    label:
                                        member.ismentor
                                            ? 'Remove Mentor'
                                            : 'Make Mentor',
                                    color:
                                        member.ismentor
                                            ? Colors.orange
                                            : Colors.purple,
                                    onPressed:
                                        () => _handleMemberAction(
                                          member.ismentor
                                              ? 'remove_mentor'
                                              : 'make_mentor',
                                          member,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildActionButton(
                                    icon: Icons.person_remove,
                                    label: 'Remove from Group',
                                    color: Colors.red,
                                    onPressed:
                                        () => _handleMemberAction(
                                          'remove',
                                          member,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF7289da)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF7289da),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        foregroundColor: color,
        backgroundColor: color.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(vertical: 12),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide(color: color.withOpacity(0.3)),
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];

    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  void _handleMemberAction(dynamic action, GroupMember member) async {
    final memberRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(widget.groupId)
        .collection('members')
        .doc(member.userId);

    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }

    switch (action) {
      case 'make_mentor':
        try {
          await memberRef.update({'role': 'mentor'});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.displayName} is now a mentor'),
              backgroundColor: Colors.green,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error making mentor: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case 'remove_mentor':
        try {
          await memberRef.update({'role': 'member'});
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${member.displayName} is no longer a mentor'),
              backgroundColor: Colors.orange,
            ),
          );
        } catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error removing mentor status: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
        break;

      case 'remove':
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: const Color(0xFF36393f),
                title: const Text(
                  'Remove Member',
                  style: TextStyle(color: Colors.white),
                ),
                content: Text(
                  'Are you sure you want to remove ${member.displayName} from the group?',
                  style: const TextStyle(color: Colors.white70),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Color(0xFF7289da)),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    child: const Text(
                      'Remove',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
        );

        if (confirm == true) {
          try {
            await memberRef.delete();

            await FirebaseFirestore.instance
                .collection('users')
                .doc(member.userId)
                .collection('groups')
                .doc(widget.groupId)
                .delete();

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${member.displayName} removed from group'),
                backgroundColor: Colors.orange,
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error removing member: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
        break;
    }

    _loadMembers();
  }

  void _viewPendingRequests() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PendingRequestsPage(groupId: widget.groupId),
      ),
    ).then((_) => _loadMembers());
  }
}

class PendingRequestsPage extends StatelessWidget {
  final String groupId;

  const PendingRequestsPage({Key? key, required this.groupId})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF36393f),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2f3136),
        title: const Text('Pending Requests'),
        elevation: 0,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream:
            FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .collection('joinRequests')
                .where('status', isEqualTo: 'pending')
                .snapshots(),
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
                    Icons.person_search,
                    size: 64,
                    color: Colors.grey.shade600,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No pending requests',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey.shade400,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final doc = snapshot.data!.docs[index];
              final data = doc.data() as Map<String, dynamic>;

              return _buildRequestCard(context, doc.id, data, index);
            },
          );
        },
      ),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    String userId,
    Map<String, dynamic> data,
    int index,
  ) {
    return AnimatedOpacity(
      duration: Duration(milliseconds: 300 + (index * 50)),
      opacity: 1.0,
      child: Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: const Color(0xFF2f3136),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: Colors.purple.withOpacity(0.2),
                    backgroundImage:
                        data['photoURL'] != null
                            ? NetworkImage(data['photoURL'] as String)
                            : null,
                    child:
                        data['photoURL'] == null
                            ? Text(
                              (data['displayName'] as String? ?? 'U')[0]
                                  .toUpperCase(),
                              style: const TextStyle(
                                color: Colors.purple,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            )
                            : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['displayName'] as String? ?? 'Unknown User',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey.shade400,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatTimestamp(
                                data['requestedAt'] as Timestamp?,
                              ),
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
                ],
              ),
              if (data['message'] != null &&
                  (data['message'] as String).isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF42464D),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Message:',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        data['message'] as String,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          () => _handleRequestAction(
                            context,
                            'reject',
                            userId,
                            data['displayName'] as String? ?? 'Unknown User',
                          ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey,
                        side: const BorderSide(color: Colors.grey),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Decline'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          () => _handleRequestAction(
                            context,
                            'approve',
                            userId,
                            data['displayName'] as String? ?? 'Unknown User',
                          ),
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: const Color(0xFF7289da),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'unknown time';

    final now = DateTime.now();
    final date = timestamp.toDate();
    final difference = now.difference(date);

    if (difference.inDays > 0) {
      return '${difference.inDays} days ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hours ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minutes ago';
    } else {
      return 'just now';
    }
  }

  Future<void> _handleRequestAction(
    BuildContext context,
    String action,
    String userId,
    String userName,
  ) async {
    final requestRef = FirebaseFirestore.instance
        .collection('groups')
        .doc(groupId)
        .collection('joinRequests')
        .doc(userId);

    try {
      if (action == 'approve') {
        final groupDoc =
            await FirebaseFirestore.instance
                .collection('groups')
                .doc(groupId)
                .get();
        final groupData = groupDoc.data();
        final groupName = groupData?['name'] as String? ?? 'Group';
        final groupPhotoURL = groupData?['photoURL'] as String?;

        await FirebaseFirestore.instance
            .collection('groups')
            .doc(groupId)
            .collection('members')
            .doc(userId)
            .set({
              'displayName': userName,
              'photoURL': null,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('groups')
            .doc(groupId)
            .set({
              'name': groupName,
              'photoURL': groupPhotoURL,
              'role': 'member',
              'joinedAt': FieldValue.serverTimestamp(),
            });

        await requestRef.update({'status': 'approved'});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName approved to join the group'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        await requestRef.update({'status': 'rejected'});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$userName\'s request declined'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error processing request: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
