import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';

class DiscussionChannelPage extends StatefulWidget {
  final String groupId;
  final GroupChannel channel;
  final UserRole userRole;

  const DiscussionChannelPage({
    Key? key,
    required this.groupId,
    required this.channel,
    required this.userRole,
  }) : super(key: key);

  @override
  _DiscussionChannelPageState createState() => _DiscussionChannelPageState();
}

class _DiscussionChannelPageState extends State<DiscussionChannelPage>
    with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isSending = false;
  String _replyingTo = '';
  String _replyingToName = '';
  bool _isEmojiPickerVisible = false;
  bool _isShowingInstructions = true;
  late AnimationController _instructionsAnimationController;
  late Animation<double> _instructionsAnimation;
  Map<String, bool> _expandedMessages = {};
  final _dateFormat = DateFormat('MMMM d, yyyy');
  final _timeFormat = DateFormat('h:mm a');
  String _currentDateGroup = '';
  @override
  void initState() {
    super.initState();
    _instructionsAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _instructionsAnimation = CurvedAnimation(
      parent: _instructionsAnimationController,
      curve: Curves.easeInOut,
    );
    _instructionsAnimationController.forward();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _instructionsAnimationController.dispose();
    super.dispose();
  }

  void _toggleInstructions() {
    setState(() {
      _isShowingInstructions = !_isShowingInstructions;
      if (_isShowingInstructions) {
        _instructionsAnimationController.forward();
      } else {
        _instructionsAnimationController.reverse();
      }
    });
  }

  void _setReplyingTo(String messageId, String userName) {
    setState(() {
      _replyingTo = messageId;
      _replyingToName = userName;
    });
  }

  void _cancelReply() {
    setState(() {
      _replyingTo = '';
      _replyingToName = '';
    });
  }

  void _toggleEmojiPicker() {
    setState(() {
      _isEmojiPickerVisible = !_isEmojiPickerVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
        if (_isEmojiPickerVisible) {
          setState(() {
            _isEmojiPickerVisible = false;
          });
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF2A2D32),
        appBar: _buildAppBar(),
        body: Column(
          children: [
            _buildChannelHeader(),
            Expanded(child: _buildMessagesList()),
            _buildReplyingToBar(),
            _buildMessageInput(),
            _buildEmojiPicker(),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E2124),
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.tag, size: 20, color: Color(0xFF7289DA)),
          const SizedBox(width: 8),
          Text(
            widget.channel.name,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 18,
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white70),
          tooltip: 'Search Messages',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Search feature coming soon!')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white70),
          tooltip: 'Notification Settings',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Notification settings coming soon!'),
              ),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          tooltip: 'Channel Info',
          onPressed: () => _showChannelInfo(),
        ),
      ],
    );
  }

  Widget _buildChannelHeader() {
    if (widget.channel.instructions.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizeTransition(
      sizeFactor: _instructionsAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: Color(0xFF292B2F),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 4,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF7289DA).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: Color(0xFF7289DA),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Channel Instructions',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7289DA),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    widget.channel.instructions,
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _isShowingInstructions
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: Colors.grey.shade400,
              ),
              onPressed: _toggleInstructions,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessagesList() {
    return StreamBuilder<QuerySnapshot>(
      stream:
          FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('messages')
              .orderBy('timestamp', descending: false)
              .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF7289DA)),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return _buildEmptyMessages();
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });

        _currentDateGroup = '';

        return ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          itemCount: snapshot.data!.docs.length,
          itemBuilder: (context, index) {
            final doc = snapshot.data!.docs[index];
            final data = doc.data() as Map<String, dynamic>;
            final messageId = doc.id;
            final timestamp = data['timestamp'] as Timestamp?;
            final messageDate = timestamp?.toDate() ?? DateTime.now();
            final messageDateStr = _dateFormat.format(messageDate);
            Widget? dateHeader;
            if (messageDateStr != _currentDateGroup) {
              _currentDateGroup = messageDateStr;
              dateHeader = _buildDateHeader(messageDateStr);
            }
            final isReply = data['replyTo'] != null;
            String? replyToId;
            if (isReply) {
              replyToId = data['replyTo'] as String?;
            }
            final userId = data['userId'] as String? ?? '';
            final isCurrentUser =
                userId == FirebaseAuth.instance.currentUser!.uid;

            return Column(
              children: [
                if (dateHeader != null) dateHeader,
                _buildMessageTile(
                  messageId: messageId,
                  data: data,
                  isCurrentUser: isCurrentUser,
                  replyToId: replyToId,
                  showAvatar: true,
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildEmptyMessages() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF7289DA).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 64,
              color: const Color(0xFF7289DA).withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No messages yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to start a conversation!',
            style: TextStyle(fontSize: 16, color: Colors.grey.shade500),
          ),
          const SizedBox(height: 32),
          OutlinedButton.icon(
            onPressed: () {
              FocusScope.of(context).requestFocus(FocusNode());
              Future.delayed(const Duration(milliseconds: 100), () {
                FocusScope.of(context).requestFocus(FocusNode());
                final RenderBox? renderBox =
                    context.findRenderObject() as RenderBox?;
                if (renderBox != null) {
                  Scrollable.ensureVisible(
                    context,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                }
              });
            },
            icon: const Icon(Icons.chat, color: Color(0xFF7289DA)),
            label: const Text(
              'Start Chatting',
              style: TextStyle(
                color: Color(0xFF7289DA),
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF7289DA)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader(String date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Expanded(child: Divider(color: Colors.grey.shade700, thickness: 1)),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF36393F),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              date,
              style: TextStyle(
                color: Colors.grey.shade400,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(child: Divider(color: Colors.grey.shade700, thickness: 1)),
        ],
      ),
    );
  }

  Widget _buildReplyPreview(String replyToId) {
    return FutureBuilder<DocumentSnapshot>(
      future:
          FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('messages')
              .doc(replyToId)
              .get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        if (!snapshot.data!.exists) {
          return Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade900.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Original message deleted',
              style: TextStyle(
                color: Colors.white70,
                fontStyle: FontStyle.italic,
                fontSize: 12,
              ),
            ),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final text = data['text'] as String? ?? 'No content';
        final userName = data['userName'] as String? ?? 'Unknown User';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF36393F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0xFF7289DA).withOpacity(0.5),
              width: 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.reply, size: 14, color: Color(0xFF7289DA)),
                  const SizedBox(width: 4),
                  Text(
                    'Reply to $userName',
                    style: const TextStyle(
                      color: Color(0xFF7289DA),
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                text.length > 100 ? '${text.substring(0, 100)}...' : text,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMessageTile({
    required String messageId,
    required Map<String, dynamic> data,
    required bool isCurrentUser,
    String? replyToId,
    required bool showAvatar,
  }) {
    final text = data['text'] as String? ?? '';
    final userName = data['userName'] as String? ?? 'Unknown User';
    final userPhotoURL = data['userPhotoURL'] as String?;
    final timestamp = data['timestamp'] as Timestamp?;
    final isExpanded = _expandedMessages[messageId] ?? false;
    final messageOptions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildMessageOption(
          icon: Icons.emoji_emotions_outlined,
          tooltip: 'React',
          onPressed: () {},
        ),
        _buildMessageOption(
          icon: Icons.reply,
          tooltip: 'Reply',
          onPressed: () {
            _setReplyingTo(messageId, userName);
          },
        ),
        if (isCurrentUser)
          _buildMessageOption(
            icon: Icons.edit,
            tooltip: 'Edit',
            onPressed: () {},
          ),
        if (isCurrentUser || widget.userRole == UserRole.mentor)
          _buildMessageOption(
            icon: Icons.delete_outline,
            tooltip: 'Delete',
            onPressed: () {
              _confirmDeleteMessage(messageId);
            },
          ),
      ],
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedMessages[messageId] = !isExpanded;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showAvatar) ...[
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage:
                      userPhotoURL != null ? NetworkImage(userPhotoURL) : null,
                  child:
                      userPhotoURL == null
                          ? Text(
                            userName[0].toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                          : null,
                ),
                const SizedBox(width: 12),
              ] else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (showAvatar) ...[
                        Row(
                          children: [
                            Text(
                              userName,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _getUserNameColor(userName),
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timestamp != null
                                  ? _timeFormat.format(timestamp.toDate())
                                  : '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade500,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                      ],
                      if (replyToId != null) _buildReplyPreview(replyToId),
                      Text(text, style: TextStyle(color: Colors.grey.shade200)),
                      if (data['reactions'] != null) ...[
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 4,
                          children: [
                            _buildReaction('👍', 2),
                            _buildReaction('❤️', 1),
                            _buildReaction('😂', 3),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              AnimatedCrossFade(
                firstChild: const SizedBox(width: 40, height: 24),
                secondChild: messageOptions,
                crossFadeState:
                    isExpanded
                        ? CrossFadeState.showSecond
                        : CrossFadeState.showFirst,
                duration: const Duration(milliseconds: 200),
                firstCurve: Curves.easeOut,
                secondCurve: Curves.easeIn,
                sizeCurve: Curves.easeInOut,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageOption({
    required IconData icon,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      margin: const EdgeInsets.only(left: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(4),
          child: Tooltip(
            message: tooltip,
            child: Padding(
              padding: const EdgeInsets.all(4.0),
              child: Icon(icon, size: 16, color: Colors.grey.shade400),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReaction(String emoji, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFF36393F),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade700, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            count.toString(),
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReplyingToBar() {
    if (_replyingTo.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF36393F),
        border: Border(top: BorderSide(color: Colors.grey.shade900, width: 1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 16, color: Color(0xFF7289DA)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Replying to $_replyingToName',
              style: const TextStyle(
                color: Color(0xFF7289DA),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18, color: Colors.grey),
            onPressed: _cancelReply,
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF36393F),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          IconButton(
            icon: Icon(
              _isEmojiPickerVisible
                  ? Icons.keyboard
                  : Icons.emoji_emotions_outlined,
              color:
                  _isEmojiPickerVisible
                      ? const Color(0xFF7289DA)
                      : Colors.grey.shade400,
            ),
            onPressed: _toggleEmojiPicker,
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: Colors.grey.shade400),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('File upload coming soon!')),
              );
            },
            splashRadius: 20,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF40444B),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _messageController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Message #${widget.channel.name}',
                  hintStyle: TextStyle(color: Colors.grey.shade500),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color:
                  _messageController.text.trim().isNotEmpty
                      ? const Color(0xFF7289DA)
                      : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: Icon(
                _isSending ? Icons.hourglass_top : Icons.send,
                color:
                    _messageController.text.trim().isNotEmpty
                        ? Colors.white
                        : Colors.grey.shade600,
                size: 20,
              ),
              onPressed:
                  _messageController.text.trim().isNotEmpty
                      ? _sendMessage
                      : null,
              splashRadius: 20,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmojiPicker() {
    if (!_isEmojiPickerVisible) {
      return const SizedBox.shrink();
    }

    return Container(
      height: 250,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F3136),
        border: Border(top: BorderSide(color: Colors.grey.shade900, width: 1)),
      ),
      child: GridView.builder(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          childAspectRatio: 1.0,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: 24,
        itemBuilder: (context, index) {
          const emojis = [
            '😀',
            '😂',
            '😍',
            '🥰',
            '😊',
            '🤔',
            '😎',
            '🙄',
            '😢',
            '😭',
            '😡',
            '🥳',
            '🤩',
            '😴',
            '🤯',
            '🥺',
            '👍',
            '👎',
            '❤️',
            '🔥',
            '🎉',
            '✨',
            '💯',
            '🤝',
          ];

          return InkWell(
            onTap: () {
              final text = _messageController.text;
              final selection = _messageController.selection;
              final newText = text.replaceRange(
                selection.start,
                selection.end,
                emojis[index],
              );
              _messageController.value = TextEditingValue(
                text: newText,
                selection: TextSelection.collapsed(
                  offset: selection.start + emojis[index].length,
                ),
              );
            },
            borderRadius: BorderRadius.circular(8),
            child: Center(
              child: Text(emojis[index], style: const TextStyle(fontSize: 24)),
            ),
          );
        },
      ),
    );
  }

  void _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _isSending = true;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;

      final messageData = {
        'text': text,
        'userId': user.uid,
        'userName': user.displayName ?? 'Unknown User',
        'userPhotoURL': user.photoURL,
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (_replyingTo.isNotEmpty) {
        messageData['replyTo'] = _replyingTo;
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('channels')
          .doc(widget.channel.id)
          .collection('messages')
          .add(messageData);

      _messageController.clear();
      _cancelReply();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error sending message: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  void _showChannelInfo() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF36393F),
            title: Row(
              children: [
                const Icon(Icons.tag, size: 20, color: Color(0xFF7289DA)),
                const SizedBox(width: 8),
                Text(
                  widget.channel.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection(
                    'Description',
                    Icons.description,
                    widget.channel.description.isNotEmpty
                        ? widget.channel.description
                        : 'No description provided',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoSection(
                    'Created',
                    Icons.event,
                    _formatFullTimestamp(widget.channel.createdAt),
                  ),
                  const SizedBox(height: 16),
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(widget.channel.createdBy)
                            .get(),
                    builder: (context, snapshot) {
                      String creatorName = 'Unknown';

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        creatorName =
                            userData['displayName'] as String? ?? 'Unknown';
                      }

                      return _buildInfoSection(
                        'Created By',
                        Icons.person,
                        creatorName,
                      );
                    },
                  ),
                  if (widget.channel.instructions.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _buildInfoSection(
                      'Instructions',
                      Icons.lightbulb_outline,
                      widget.channel.instructions,
                      highlight: true,
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              if (widget.userRole == UserRole.mentor) ...[
                TextButton.icon(
                  icon: const Icon(Icons.edit, size: 16),
                  label: const Text('Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey.shade400,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _editChannel();
                  },
                ),
                TextButton.icon(
                  icon: const Icon(Icons.delete, size: 16),
                  label: const Text('Delete'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red.shade400,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                    _confirmDeleteChannel();
                  },
                ),
              ],
              TextButton(
                child: const Text('Close'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF7289DA),
                ),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
    );
  }

  Widget _buildInfoSection(
    String title,
    IconData icon,
    String content, {
    bool highlight = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: const Color(0xFF7289DA)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF7289DA),
                fontSize: 14,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color:
                highlight
                    ? const Color(0xFF7289DA).withOpacity(0.1)
                    : const Color(0xFF2F3136),
            borderRadius: BorderRadius.circular(8),
            border:
                highlight
                    ? Border.all(
                      color: const Color(0xFF7289DA).withOpacity(0.3),
                      width: 1,
                    )
                    : null,
          ),
          child: Text(
            content,
            style: TextStyle(
              color: highlight ? const Color(0xFF7289DA) : Colors.grey.shade300,
            ),
          ),
        ),
      ],
    );
  }

  String _formatFullTimestamp(Timestamp timestamp) {
    final date = timestamp.toDate();
    final formatter = DateFormat('MMMM d, yyyy \'at\' h:mm a');
    return formatter.format(date);
  }

  void _editChannel() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Edit channel functionality would go here')),
    );
  }

  void _confirmDeleteChannel() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF36393F),
            title: const Text(
              'Delete Channel',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this channel? '
              'This action cannot be undone and all messages will be lost.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7289DA)),
                ),
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

  void _confirmDeleteMessage(String messageId) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF36393F),
            title: const Text(
              'Delete Message',
              style: TextStyle(color: Colors.white),
            ),
            content: const Text(
              'Are you sure you want to delete this message? '
              'This action cannot be undone.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF7289DA)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteMessage(messageId);
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
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AlertDialog(
              backgroundColor: const Color(0xFF36393F),
              content: Row(
                children: [
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Color(0xFF7289DA),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Deleting channel...',
                    style: TextStyle(color: Colors.grey.shade300),
                  ),
                ],
              ),
            ),
      );

      final messagesSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('messages')
              .get();

      final batch = FirebaseFirestore.instance.batch();

      for (final doc in messagesSnapshot.docs) {
        batch.delete(doc.reference);
      }

      batch.delete(
        FirebaseFirestore.instance
            .collection('groups')
            .doc(widget.groupId)
            .collection('channels')
            .doc(widget.channel.id),
      );

      await batch.commit();

      Navigator.pop(context);

      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Channel deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting channel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _deleteMessage(String messageId) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('channels')
          .doc(widget.channel.id)
          .collection('messages')
          .doc(messageId)
          .delete();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Message deleted'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting message: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Color _getUserNameColor(String userName) {
    const colors = [
      Color(0xFF7289DA),
      Color(0xFFE91E63),
      Color(0xFF4CAF50),
      Color(0xFFFF9800),
      Color(0xFF9C27B0),
      Color(0xFF2196F3),
      Color(0xFFFFEB3B),
      Color(0xFF795548),
      Color(0xFF009688),
      Color(0xFFE53935),
    ];

    int hash = 0;
    for (int i = 0; i < userName.length; i++) {
      hash = (hash + userName.codeUnitAt(i)) % colors.length;
    }

    return colors[hash];
  }
}
