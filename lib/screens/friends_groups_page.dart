import 'package:flutter/material.dart';
import 'journal_page.dart';
import 'dashboard.dart';

class FriendsGroupsPage extends StatefulWidget {
  const FriendsGroupsPage({super.key});

  @override
  State<FriendsGroupsPage> createState() => _FriendsGroupsPageState();
}

class _FriendsGroupsPageState extends State<FriendsGroupsPage> {
  int _selectedTabIndex = 0; // 0: Friends, 1: Groups, 2: Requests
  bool _showSentRequests = false; // Toggle between received and sent requests

  // Sample data for demonstration
  final List<Map<String, dynamic>> _friends = [
    {
      'name': 'Sarah Johnson',
      'avatar': 'assets/images/avatar1.jpg',
      'lastActive': '15m ago',
    },
    {
      'name': 'Mike Peterson',
      'avatar': 'assets/images/avatar2.jpg',
      'lastActive': '1h ago',
    },
    {
      'name': 'Emma Williams',
      'avatar': 'assets/images/avatar3.jpg',
      'lastActive': '2h ago',
    },
    {
      'name': 'David Lee',
      'avatar': 'assets/images/avatar4.jpg',
      'lastActive': 'Just now',
    },
  ];

  final List<Map<String, dynamic>> _groups = [
    {
      'name': 'Study Group',
      'avatar': 'assets/images/group1.jpg',
      'members': 28,
      'lastActive': 'Active now',
    },
    {
      'name': 'Math Club',
      'avatar': 'assets/images/group2.jpg',
      'members': 43,
      'lastActive': '30m ago',
    },
    {
      'name': 'Class of 2023',
      'avatar': 'assets/images/group3.jpg',
      'members': 112,
      'lastActive': '2h ago',
    },
  ];

  final List<Map<String, dynamic>> _receivedRequests = [
    {
      'name': 'James Taylor',
      'avatar': 'assets/images/avatar5.jpg',
      'sentAt': '2d ago',
    },
    {
      'name': 'Olivia Martin',
      'avatar': 'assets/images/avatar6.jpg',
      'sentAt': '5d ago',
    },
  ];

  final List<Map<String, dynamic>> _sentRequests = [
    {
      'name': 'Daniel Wilson',
      'avatar': 'assets/images/avatar7.jpg',
      'sentAt': '1d ago',
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Salmon colored top section
          Container(
            color: const Color(
              0xFFFFA07A,
            ), // Salmon background to match journal page
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildHeader(),
                  _buildTabSelector(),
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
            child: Container(
              color: Colors.white,
              child: _buildSelectedTabContent(),
            ),
          ),
        ],
      ),
      // Bottom navigation bar
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // Header with page title
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0),
      alignment: Alignment.center,
      child: const Text(
        'FRIENDS & GROUPS',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
    );
  }

  // Tab selector for Friends, Groups, and Requests
  Widget _buildTabSelector() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Row(
          children: [
            _buildTabButton(0, 'Friends'),
            _buildTabButton(1, 'Groups'),
            _buildTabButton(2, 'Requests'),
          ],
        ),
      ),
    );
  }

  // Individual tab button
  Widget _buildTabButton(int index, String label) {
    final isSelected = _selectedTabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedTabIndex = index;
          });
        },
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(25),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color:
                    isSelected ? Colors.black : Colors.black.withOpacity(0.7),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Content for the selected tab
  Widget _buildSelectedTabContent() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildFriendsTab();
      case 1:
        return _buildGroupsTab();
      case 2:
        return _buildRequestsTab();
      default:
        return const SizedBox.shrink();
    }
  }

  // Friends tab content
  Widget _buildFriendsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your Friends',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._friends.map((friend) => _buildFriendCard(friend)),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFA07A),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
              ),
              child: const Text(
                'Find More Friends',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Groups tab content
  Widget _buildGroupsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Your Groups',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ..._groups.map((group) => _buildGroupCard(group)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF80AB82,
                    ), // Green from dashboard
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Join a Group',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFFD8BFD8,
                    ), // Light purple from dashboard
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  child: const Text(
                    'Create Group',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Requests tab content
  Widget _buildRequestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Request type toggle button
          Container(
            margin: const EdgeInsets.symmetric(vertical: 16),
            width: double.infinity,
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.black, width: 2),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSentRequests = false;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            !_showSentRequests
                                ? const Color(0xFFFFA07A)
                                : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(23),
                          bottomLeft: Radius.circular(23),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Received (${_receivedRequests.length})',
                          style: TextStyle(
                            fontWeight:
                                !_showSentRequests
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 2,
                  height: double.infinity,
                  color: Colors.black,
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _showSentRequests = true;
                      });
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color:
                            _showSentRequests
                                ? const Color(0xFFFFA07A)
                                : Colors.transparent,
                        borderRadius: const BorderRadius.only(
                          topRight: Radius.circular(23),
                          bottomRight: Radius.circular(23),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'Sent (${_sentRequests.length})',
                          style: TextStyle(
                            fontWeight:
                                _showSentRequests
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Display appropriate requests
          if (_showSentRequests) ...[
            if (_sentRequests.isEmpty)
              _buildEmptyState('No pending friend requests'),
            ..._sentRequests.map((request) => _buildSentRequestCard(request)),
          ] else ...[
            if (_receivedRequests.isEmpty)
              _buildEmptyState('No friend requests received'),
            ..._receivedRequests.map(
              (request) => _buildReceivedRequestCard(request),
            ),
          ],
        ],
      ),
    );
  }

  // Friend card UI
  Widget _buildFriendCard(Map<String, dynamic> friend) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1),
              image: DecorationImage(
                image: AssetImage(friend['avatar']),
                fit: BoxFit.cover,
                onError:
                    (exception, stackTrace) =>
                        Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.person, size: 30),
                            )
                            as ImageProvider,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  friend['lastActive'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Message button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF4A9A8), // Light coral from dashboard
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(Icons.message, color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }

  // Group card UI
  Widget _buildGroupCard(Map<String, dynamic> group) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          // Group avatar
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.black, width: 1),
              image: DecorationImage(
                image: AssetImage(group['avatar']),
                fit: BoxFit.cover,
                onError:
                    (exception, stackTrace) =>
                        Container(
                              color: Colors.grey[300],
                              child: const Icon(Icons.group, size: 30),
                            )
                            as ImageProvider,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Group details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group['name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${group['members']} members · ${group['lastActive']}',
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          // Enter group button
          Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF98D8C8), // Light teal from dashboard
            ),
            padding: const EdgeInsets.all(8),
            child: const Icon(
              Icons.arrow_forward,
              color: Colors.white,
              size: 20,
            ),
          ),
        ],
      ),
    );
  }

  // Received friend request card
  Widget _buildReceivedRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                  image: DecorationImage(
                    image: AssetImage(request['avatar']),
                    fit: BoxFit.cover,
                    onError:
                        (exception, stackTrace) =>
                            Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 30),
                                )
                                as ImageProvider,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sent ${request['sentAt']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Action buttons
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(
                      0xFF80AB82,
                    ), // Green from dashboard
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Accept',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[300],
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: const Text(
                    'Decline',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Sent friend request card
  Widget _buildSentRequestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black, width: 1),
                  image: DecorationImage(
                    image: AssetImage(request['avatar']),
                    fit: BoxFit.cover,
                    onError:
                        (exception, stackTrace) =>
                            Container(
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.person, size: 30),
                                )
                                as ImageProvider,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Name and status
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request['name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Sent ${request['sentAt']}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Cancel button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[300],
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: const Text(
                'Cancel Request',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Empty state widget
  Widget _buildEmptyState(String message) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 30),
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_off, size: 50, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  // Bottom navigation bar - same style as journal_page.dart
  Widget _buildBottomNavBar() {
    return Container(
      height: 55,
      margin: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 25.0),
      decoration: BoxDecoration(
        color: const Color(
          0xFFFFA07A,
        ), // Salmon background color matching journal page
        border: Border.all(color: Colors.black, width: 1.5), // Black border
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildNavItem(Icons.bar_chart, false),
          _buildNavItem(Icons.access_time, false),
          // Home icon with navigation back to Dashboard
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const Dashboard()),
              );
            },
            child: _buildNavItem(Icons.home, false),
          ),
          // Journal icon with navigation to Journal page
          GestureDetector(
            onTap: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => const JournalPage()),
              );
            },
            child: _buildNavItem(Icons.assessment, false),
          ),
          _buildNavItem(Icons.person_outline, true), // Person icon is selected
        ],
      ),
    );
  }

  // Individual navigation item - matching journal_page.dart
  Widget _buildNavItem(IconData icon, bool isSelected) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isSelected ? Colors.white : Colors.transparent,
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: isSelected ? Colors.black : Colors.black.withOpacity(0.7),
        size: 24,
      ),
    );
  }
}
