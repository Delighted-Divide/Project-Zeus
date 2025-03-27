import 'dart:io';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart';

class RealtimeChatService {
  // Singleton pattern implementation
  static final RealtimeChatService _instance = RealtimeChatService._internal();

  factory RealtimeChatService() {
    return _instance;
  }

  // Private constructor
  RealtimeChatService._internal() {
    print("RealtimeChatService initialized");
  }

  // References to Firebase services
  final FirebaseDatabase _database = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL:
        'https://attempt1-314eb-default-rtdb.asia-southeast1.firebasedatabase.app',
  );
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Get the current user ID directly from Firebase Auth
  String? _getCurrentUserId() {
    return _auth.currentUser?.uid;
  }

  // Check if user is authenticated
  bool _isUserAuthenticated() {
    return _auth.currentUser != null;
  }

  // Get or create a chat between two users
  Future<String> getOrCreateChat(String otherUserId) async {
    print("=== START: getOrCreateChat ===");

    // Safety check
    final currentUserId = _getCurrentUserId();
    if (currentUserId == null) {
      print("ERROR: User not authenticated in getOrCreateChat");
      throw Exception("User not authenticated");
    }

    print("Current user: $currentUserId, Other user: $otherUserId");

    // Sort IDs to ensure consistent chat ID regardless of who initiates
    final List<String> userIds = [currentUserId, otherUserId]..sort();
    final String chatId = userIds.join('_');
    print("Generated chat ID: $chatId");

    try {
      // Check if chat exists with timeout
      final DatabaseReference chatRef = _database.ref().child('chats/$chatId');
      print("Checking for chat at path: chats/$chatId");

      // Try to read the chat data with a timeout to avoid hanging
      final DataSnapshot snapshot = await chatRef.get().timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print("Database operation timed out");
          throw TimeoutException('Database operation timed out');
        },
      );

      print("Database response received, exists: ${snapshot.exists}");

      if (!snapshot.exists) {
        print("Chat doesn't exist, creating new chat");
        // Create new chat
        final Map<String, dynamic> chatData = {
          'participants': userIds,
          'createdAt': ServerValue.timestamp,
          'lastMessage': null,
          'lastMessageTime': null,
        };

        await chatRef.set(chatData);
        print("Chat created successfully");
      } else {
        print("Chat already exists");
      }

      return chatId;
    } catch (e) {
      print("ERROR in getOrCreateChat: $e");
      // For debugging purposes, return the chat ID anyway so UI doesn't hang
      // In production, you'd likely want to rethrow the exception
      return chatId;
    } finally {
      print("=== END: getOrCreateChat ===");
    }
  }

  // Stream messages for a specific chat
  Stream<List<Map<String, dynamic>>> getMessages(String chatId) {
    print("Getting messages stream for chat: $chatId");

    try {
      final DatabaseReference messagesRef = _database.ref().child(
        'chats/$chatId/messages',
      );

      return messagesRef
          .orderByChild('timestamp')
          .onValue
          .map((event) {
            print("Message event received for chat: $chatId");
            final DataSnapshot snapshot = event.snapshot;
            final List<Map<String, dynamic>> messages = [];

            if (snapshot.value != null) {
              print("Processing message snapshot");
              try {
                // Convert the data to a map
                final messagesMap = Map<dynamic, dynamic>.from(
                  snapshot.value as Map<dynamic, dynamic>,
                );

                messagesMap.forEach((key, value) {
                  if (value is Map) {
                    final messageData = Map<String, dynamic>.from(value as Map);
                    messageData['id'] = key;
                    messages.add(messageData);
                  }
                });

                // Sort by timestamp to ensure order
                messages.sort((a, b) {
                  final aTime = a['timestamp'] ?? 0;
                  final bTime = b['timestamp'] ?? 0;
                  return aTime.compareTo(bTime);
                });

                print("Processed ${messages.length} messages");
              } catch (e) {
                print("Error processing messages: $e");
              }
            } else {
              print("No messages found for chat: $chatId");
            }

            return messages;
          })
          .handleError((error) {
            print("Error in messages stream: $error");
            return <Map<String, dynamic>>[];
          });
    } catch (e) {
      print("Error setting up messages stream: $e");
      // Return an empty stream in case of error
      return Stream.value(<Map<String, dynamic>>[]);
    }
  }

  // Send a text message
  Future<void> sendMessage(String chatId, String text) async {
    print("Sending text message to chat: $chatId");

    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("User not authenticated");
      }

      // Generate a unique key for this message
      final DatabaseReference messagesRef = _database.ref().child(
        'chats/$chatId/messages',
      );
      final newMessageRef = messagesRef.push();
      print("Created message reference: ${newMessageRef.path}");

      // Set message data
      await newMessageRef.set({
        'sender': currentUserId,
        'text': text,
        'timestamp': ServerValue.timestamp,
        'isImage': false,
        'isDocument': false,
        'mediaUrl': null,
        'documentName': null,
      });
      print("Message data saved successfully");

      // Update last message preview
      await _database.ref().child('chats/$chatId').update({
        'lastMessage': text,
        'lastMessageTime': ServerValue.timestamp,
      });
      print("Last message preview updated");
    } catch (e) {
      print("Error sending message: $e");
      rethrow;
    }
  }

  // Send an image message
  Future<void> sendImageMessage(String chatId, File imageFile) async {
    print("Sending image message to chat: $chatId");

    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("User not authenticated");
      }

      // Upload image to Firebase Storage
      final String fileName =
          'image_${DateTime.now().millisecondsSinceEpoch}${path.extension(imageFile.path)}';
      final Reference storageRef = _storage.ref().child(
        'chats/$chatId/media/$fileName',
      );
      print("Uploading image to: ${storageRef.fullPath}");

      // Upload file
      final uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot snapshot = await uploadTask;
      print("Image upload complete: ${snapshot.bytesTransferred} bytes");

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Image download URL: $downloadUrl");

      // Add message to Realtime Database
      final DatabaseReference messagesRef = _database.ref().child(
        'chats/$chatId/messages',
      );
      final newMessageRef = messagesRef.push();

      await newMessageRef.set({
        'sender': currentUserId,
        'text': '📷 Image',
        'timestamp': ServerValue.timestamp,
        'isImage': true,
        'isDocument': false,
        'mediaUrl': downloadUrl,
        'documentName': null,
      });
      print("Image message saved to database");

      // Update last message preview
      await _database.ref().child('chats/$chatId').update({
        'lastMessage': '📷 Image',
        'lastMessageTime': ServerValue.timestamp,
      });
      print("Last message preview updated");
    } catch (e) {
      print("Error sending image message: $e");
      rethrow;
    }
  }

  // Send a document message
  Future<void> sendDocumentMessage(
    String chatId,
    File documentFile,
    String documentName,
  ) async {
    print("Sending document message to chat: $chatId");

    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId == null) {
        throw Exception("User not authenticated");
      }

      // Upload document to Firebase Storage
      final String fileName =
          'doc_${DateTime.now().millisecondsSinceEpoch}${path.extension(documentFile.path)}';
      final Reference storageRef = _storage.ref().child(
        'chats/$chatId/documents/$fileName',
      );
      print("Uploading document to: ${storageRef.fullPath}");

      // Upload file
      final uploadTask = storageRef.putFile(documentFile);
      final TaskSnapshot snapshot = await uploadTask;
      print("Document upload complete: ${snapshot.bytesTransferred} bytes");

      // Get download URL
      final String downloadUrl = await snapshot.ref.getDownloadURL();
      print("Document download URL: $downloadUrl");

      // Add message to Realtime Database
      final DatabaseReference messagesRef = _database.ref().child(
        'chats/$chatId/messages',
      );
      final newMessageRef = messagesRef.push();

      await newMessageRef.set({
        'sender': currentUserId,
        'text': documentName,
        'timestamp': ServerValue.timestamp,
        'isImage': false,
        'isDocument': true,
        'mediaUrl': downloadUrl,
        'documentName': documentName,
      });
      print("Document message saved to database");

      // Update last message preview
      await _database.ref().child('chats/$chatId').update({
        'lastMessage': '📄 $documentName',
        'lastMessageTime': ServerValue.timestamp,
      });
      print("Last message preview updated");
    } catch (e) {
      print("Error sending document message: $e");
      rethrow;
    }
  }

  // Download a file from URL to a local path
  Future<File> downloadFile(String url, String filename) async {
    print("Downloading file: $filename from URL");

    try {
      // Get temp directory
      final Directory tempDir = await getTemporaryDirectory();
      final String filePath = '${tempDir.path}/$filename';
      print("File will be saved to: $filePath");

      // Check if file already exists
      final File file = File(filePath);
      if (await file.exists()) {
        print("File already exists locally, returning cached version");
        return file;
      }

      // Download the file
      print("File not found locally, downloading from URL...");
      final http.Response response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        throw Exception(
          "Failed to download file: Status ${response.statusCode}",
        );
      }

      await file.writeAsBytes(response.bodyBytes);
      print(
        "File downloaded successfully (${response.bodyBytes.length} bytes)",
      );

      return file;
    } catch (e) {
      print("Error downloading file: $e");
      rethrow;
    }
  }

  // Check if this is the current user
  bool isCurrentUser(String userId) {
    final currentUserId = _getCurrentUserId();
    return userId == currentUserId;
  }

  // Get current user ID - useful for UI that needs to know the current user
  String? getCurrentUserId() {
    return _getCurrentUserId();
  }

  // Simple test method to verify database connectivity
  Future<bool> testDatabaseConnection() async {
    try {
      print("Testing database connection...");
      final testRef = _database.ref("connection_test");
      await testRef.set({
        "timestamp": ServerValue.timestamp,
        "testValue": "Connection test at ${DateTime.now()}",
      });

      final snapshot = await testRef.get();
      print("Test completed successfully: ${snapshot.value}");
      return true;
    } catch (e) {
      print("Database connection test failed: $e");
      return false;
    }
  }
}
