import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Import our custom files
import 'realtime_chat_service.dart';
import 'pdf_viewer_screen.dart';

class ChatPage extends StatefulWidget {
  final String friendName;
  final String friendAvatar;
  final String friendId; // Friend's ID for database

  const ChatPage({
    super.key,
    required this.friendName,
    required this.friendAvatar,
    required this.friendId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  // Controllers
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  // Services
  final RealtimeChatService _chatService = RealtimeChatService();
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Chat state
  String _chatId = '';
  bool _isLoading = true;
  Stream<List<Map<String, dynamic>>>? _messagesStream;

  // Media state
  File? _selectedImage;
  File? _selectedDocument;
  String? _documentName;

  // UI state
  bool _isOnline = true; // Friend online status (could be dynamic in future)
  bool _isScrolling = false;

  // Debug flags
  bool _databaseConnectionTested = false;

  @override
  void initState() {
    super.initState();

    // Verify authentication first
    if (_auth.currentUser == null) {
      // Show error and return to previous screen if not authenticated
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You must be logged in to use chat")),
        );
        Navigator.of(context).pop();
      });
      return;
    }

    // Test database, then initialize chat
    _testDatabaseAndInitialize();
  }

  @override
  void dispose() {
    // Clean up controllers to prevent memory leaks
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // Test database connection before initializing chat
  Future<void> _testDatabaseAndInitialize() async {
    setState(() => _isLoading = true);

    try {
      print("Testing database connection...");

      bool isConnected = await _chatService.testDatabaseConnection();
      _databaseConnectionTested = true;

      if (isConnected) {
        print("Database connection successful");
        _initializeChat();
      } else {
        _handleConnectionError(
          "Could not connect to database. Please check your internet connection.",
        );
      }
    } catch (e) {
      _handleConnectionError("Error connecting to database: $e");
    }
  }

  // Initialize chat after successful database connection
  Future<void> _initializeChat() async {
    try {
      print("Initializing chat with friend ID: ${widget.friendId}");

      // Get or create chat ID based on participants
      _chatId = await _chatService.getOrCreateChat(widget.friendId);
      print("Chat ID created/retrieved: $_chatId");

      // Set up messages stream
      setState(() {
        _messagesStream = _chatService.getMessages(_chatId);
        _isLoading = false;
      });

      // Scroll to bottom when messages load
      _scrollToBottomOnLoad();
    } catch (e) {
      print("Error initializing chat: $e");
      _handleConnectionError("Error loading chat: $e");
    }
  }

  // Handle connection or initialization errors
  void _handleConnectionError(String message) {
    setState(() => _isLoading = false);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Show attachment options menu (image or document)
  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25.0)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Wrap(
            children: [
              const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text(
                  "Share Attachment",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Divider(),
              // Image option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo, color: Color(0xFF6A3DE8)),
                ),
                title: const Text("Gallery"),
                onTap: () {
                  Navigator.pop(context);
                  _pickImage();
                },
              ),
              // Document option
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0E6FA),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.picture_as_pdf,
                    color: Color(0xFF6A3DE8),
                  ),
                ),
                title: const Text("Document"),
                onTap: () {
                  Navigator.pop(context);
                  _pickDocument();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Pick an image from gallery
  Future<void> _pickImage() async {
    try {
      final XFile? pickedImage = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // Reduce image size while keeping decent quality
      );

      if (pickedImage != null) {
        setState(() {
          _selectedImage = File(pickedImage.path);
        });

        // Send the image message right away
        await _sendImageMessage();
      }
    } catch (e) {
      _showErrorSnackBar("Error picking image: $e");
    }
  }

  // Pick a document file
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt', 'xls', 'xlsx'],
      );

      if (result != null && result.files.single.path != null) {
        setState(() {
          _selectedDocument = File(result.files.single.path!);
          _documentName = result.files.single.name;
        });

        // Send the document message right away
        await _sendDocumentMessage();
      }
    } catch (e) {
      _showErrorSnackBar("Error picking document: $e");
    }
  }

  // Send selected image as a message
  Future<void> _sendImageMessage() async {
    if (_selectedImage == null || _chatId.isEmpty) return;

    try {
      // Show loading indicator
      _showLoadingSnackBar("Uploading image...");

      // Send image with chat service
      await _chatService.sendImageMessage(_chatId, _selectedImage!);

      // Clear selected image after sending
      setState(() {
        _selectedImage = null;
      });

      // Dismiss loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Scroll to bottom after sending message
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar("Error sending image: $e");
    }
  }

  // Send selected document as a message
  Future<void> _sendDocumentMessage() async {
    if (_selectedDocument == null || _documentName == null || _chatId.isEmpty) {
      return;
    }

    try {
      // Show loading indicator
      _showLoadingSnackBar("Uploading document...");

      // Send document with chat service
      await _chatService.sendDocumentMessage(
        _chatId,
        _selectedDocument!,
        _documentName!,
      );

      // Clear selected document after sending
      setState(() {
        _selectedDocument = null;
        _documentName = null;
      });

      // Dismiss loading indicator
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
      }

      // Scroll to bottom after sending message
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar("Error sending document: $e");
    }
  }

  // Send text message
  Future<void> _sendMessage() async {
    // Don't send empty messages
    final text = _messageController.text.trim();
    if (text.isEmpty || _chatId.isEmpty) return;

    try {
      // Send the message
      await _chatService.sendMessage(_chatId, text);

      // Clear input field after sending
      _messageController.clear();

      // Scroll to bottom after sending message
      _scrollToBottom();
    } catch (e) {
      _showErrorSnackBar("Error sending message: $e");
    }
  }

  // Helper - Show loading snackbar
  void _showLoadingSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  // Helper - Show error snackbar
  void _showErrorSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  // Scroll to bottom when messages load initially
  void _scrollToBottomOnLoad() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  // Scroll to bottom of message list
  void _scrollToBottom() {
    // Prevent multiple scroll animations
    if (_isScrolling) return;

    _isScrolling = true;
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController
            .animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            )
            .then((_) {
              _isScrolling = false;
            });
      } else {
        _isScrolling = false;
      }
    });
  }

  // Open PDF viewer for document messages
  void _openPdfViewer(String url, String documentName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFViewerScreen(url: url, title: documentName),
      ),
    );
  }

  // Format timestamp for message display
  String _formatMessageTime(dynamic timestamp) {
    if (timestamp == null) return '';

    DateTime messageTime;
    if (timestamp is int) {
      messageTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
    } else {
      return '';
    }

    // Format time based on whether it's today, yesterday, or earlier
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(
      messageTime.year,
      messageTime.month,
      messageTime.day,
    );

    if (messageDate == today) {
      return DateFormat('HH:mm').format(messageTime);
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Yesterday ${DateFormat('HH:mm').format(messageTime)}';
    } else {
      return DateFormat('MMM dd, HH:mm').format(messageTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // Salmon colored top section with chat header
          Container(
            color: const Color(0xFFFFA07A),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  _buildChatHeader(),
                  // Curved bottom edge - smooth transition to chat area
                  Container(
                    height: 25,
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

          // Chat messages section (white background)
          Expanded(
            child:
                _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _buildMessagesList(),
          ),

          // Message input section at bottom
          _buildMessageInput(),
        ],
      ),
      // Debug button that tests database connection
    );
  }

  // Chat header with friend info
  Widget _buildChatHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
          const SizedBox(width: 12),

          // Friend profile picture
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black, width: 1.2),
              image: DecorationImage(
                image: AssetImage(widget.friendAvatar),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) => const Icon(Icons.person),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Friend name and status
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.friendName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isOnline ? "Online" : "Offline",
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Extra action buttons
          IconButton(
            icon: const Icon(
              Icons.auto_awesome,
              color: Color.fromARGB(255, 129, 129, 245),
              size: 28,
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("AI features coming soon!"),
                  backgroundColor: Colors.amber,
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {
              // Could show chat options menu
            },
          ),
        ],
      ),
    );
  }

  // Build the messages list with StreamBuilder
  Widget _buildMessagesList() {
    // Handle case where stream is not initialized
    if (_messagesStream == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 50, color: Colors.red),
            const SizedBox(height: 16),
            const Text("Chat stream not initialized"),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed:
                  _databaseConnectionTested
                      ? _initializeChat
                      : _testDatabaseAndInitialize,
              child: Text(
                _databaseConnectionTested ? "Retry" : "Test Connection",
              ),
            ),
          ],
        ),
      );
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _messagesStream,
      builder: (context, snapshot) {
        // Handle loading state
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        // Handle error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 50, color: Colors.red),
                const SizedBox(height: 16),
                Text('Error loading messages: ${snapshot.error}'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _initializeChat,
                  child: const Text("Retry"),
                ),
              ],
            ),
          );
        }

        // Get messages from snapshot
        final messages = snapshot.data ?? [];

        // Show empty state if no messages
        if (messages.isEmpty) {
          return const Center(
            child: Text(
              'No messages yet. Start the conversation!',
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
          );
        }

        // Build message list
        return ListView.builder(
          key: ValueKey<int>(
            messages.length,
          ), // Helps Flutter identify when list changes
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final message = messages[index];
            final bool isUser = _chatService.isCurrentUser(message['sender']);
            final String text = message['text'] ?? '';
            final dynamic timestamp = message['timestamp'];
            final bool isImage = message['isImage'] ?? false;
            final bool isDocument = message['isDocument'] ?? false;
            final String? mediaUrl = message['mediaUrl'];
            final String? documentName = message['documentName'];

            // Format time
            final String time = _formatMessageTime(timestamp);

            return _buildMessageBubble(
              message: text,
              time: time,
              isUser: isUser,
              isImage: isImage,
              isDocument: isDocument,
              mediaUrl: mediaUrl,
              documentName: documentName,
            );
          },
        );
      },
    );
  }

  // Single message bubble
  Widget _buildMessageBubble({
    required String message,
    required String time,
    required bool isUser,
    bool isImage = false,
    bool isDocument = false,
    String? mediaUrl,
    String? documentName,
  }) {
    // Message bubble colors - green for user, red for friend
    final Color userBubbleColor = const Color(0xFF4CAF50); // Green
    final Color friendBubbleColor = const Color(0xFFE57373); // Light red

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        // User messages on right, friend messages on left
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          // Friend message - left aligned with red bubble
          if (!isUser)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: friendBubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage && mediaUrl != null)
                      GestureDetector(
                        onTap: () {
                          // Show image in full screen if needed
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            mediaUrl,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 150,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              (loadingProgress
                                                      .expectedTotalBytes ??
                                                  1)
                                          : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 150,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      ),
                    if (isDocument && mediaUrl != null)
                      GestureDetector(
                        onTap: () {
                          _openPdfViewer(mediaUrl, documentName ?? 'Document');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!isImage && !isDocument)
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      time,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // User message - right aligned with green bubble
          if (isUser)
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: userBubbleColor,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.black, width: 1),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isImage && mediaUrl != null)
                      GestureDetector(
                        onTap: () {
                          // Show image in full screen if needed
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            mediaUrl,
                            width: 200,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                width: 200,
                                height: 150,
                                alignment: Alignment.center,
                                child: CircularProgressIndicator(
                                  value:
                                      loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress
                                                  .cumulativeBytesLoaded /
                                              (loadingProgress
                                                      .expectedTotalBytes ??
                                                  1)
                                          : null,
                                ),
                              );
                            },
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 200,
                                height: 150,
                                color: Colors.grey[300],
                                alignment: Alignment.center,
                                child: const Icon(Icons.error),
                              );
                            },
                          ),
                        ),
                      ),
                    if (isDocument && mediaUrl != null)
                      GestureDetector(
                        onTap: () {
                          _openPdfViewer(mediaUrl, documentName ?? 'Document');
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 10,
                            horizontal: 12,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.picture_as_pdf,
                                color: Colors.red,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  message,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (!isImage && !isDocument)
                      Text(
                        message,
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white,
                        ),
                      ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          time,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Read indicator
                        const Icon(
                          Icons.done_all,
                          size: 12,
                          color: Colors.white70,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Message input area
  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      margin: const EdgeInsets.only(bottom: 5), // Push up from bottom
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          // Attachment button (smaller)
          GestureDetector(
            onTap: _showAttachmentOptions,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFF0E6FA), // Light purple
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: const Icon(
                Icons.attach_file,
                color: Colors.black,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Text input field
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              height: 45,
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: TextField(
                controller: _messageController,
                decoration: const InputDecoration(
                  hintText: "Type a message...",
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                textCapitalization: TextCapitalization.sentences,
                // Send on Enter key
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Send button (smaller)
          GestureDetector(
            onTap: _sendMessage,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4CAF50), // Green to match user messages
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black, width: 1),
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
