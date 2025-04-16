import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import '../models/group_model.dart';
import '../models/user_model.dart';

class ResourceChannelPage extends StatefulWidget {
  final String groupId;
  final GroupChannel channel;
  final UserRole userRole;

  const ResourceChannelPage({
    Key? key,
    required this.groupId,
    required this.channel,
    required this.userRole,
  }) : super(key: key);

  @override
  _ResourceChannelPageState createState() => _ResourceChannelPageState();
}

class ResourceItem {
  final String id;
  final String title;
  final String description;
  final String fileType;
  final String fileURL;
  final String uploadedBy;
  final Timestamp uploadedAt;
  final int? fileSize; // Added file size
  final int? downloadCount; // Added download count
  final List<String>? tags; // Added tags

  ResourceItem({
    required this.id,
    required this.title,
    required this.description,
    required this.fileType,
    required this.fileURL,
    required this.uploadedBy,
    required this.uploadedAt,
    this.fileSize,
    this.downloadCount,
    this.tags,
  });

  factory ResourceItem.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ResourceItem(
      id: doc.id,
      title: data['title'] as String? ?? 'Untitled Resource',
      description: data['description'] as String? ?? '',
      fileType: data['fileType'] as String? ?? 'unknown',
      fileURL: data['fileURL'] as String? ?? '',
      uploadedBy: data['uploadedBy'] as String? ?? '',
      uploadedAt: data['uploadedAt'] as Timestamp? ?? Timestamp.now(),
      fileSize: data['fileSize'] as int?,
      downloadCount: data['downloadCount'] as int?,
      tags: data['tags'] != null ? List<String>.from(data['tags']) : null,
    );
  }
}

class _ResourceChannelPageState extends State<ResourceChannelPage>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  List<ResourceItem> _resources = [];
  bool _isUploading = false;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  String _sortBy = 'newest'; // 'newest', 'oldest', 'alphabetical', 'popular'

  // For animations
  late AnimationController _filterAnimationController;
  late Animation<double> _filterAnimation;

  // For expanded resource view
  String? _expandedResourceId;

  // For expanded instructions
  bool _showInstructions = true;
  late AnimationController _instructionsController;
  late Animation<double> _instructionsAnimation;

  // For grouping by file type
  Map<String, List<ResourceItem>> _resourcesByType = {};

  // Resource type info
  final Map<String, Color> _typeColors = {
    'pdf': Colors.red,
    'document': Colors.blue,
    'presentation': Colors.orange,
    'spreadsheet': Colors.green,
    'image': Colors.purple,
    'video': Colors.pink,
    'audio': Colors.teal,
    'link': Colors.indigo,
    'code': Colors.amber,
    'archive': Colors.brown,
    'other': Colors.grey,
  };

  final Map<String, IconData> _typeIcons = {
    'pdf': Icons.picture_as_pdf,
    'document': Icons.description,
    'presentation': Icons.slideshow,
    'spreadsheet': Icons.table_chart,
    'image': Icons.image,
    'video': Icons.video_library,
    'audio': Icons.audiotrack,
    'link': Icons.link,
    'code': Icons.code,
    'archive': Icons.inventory_2,
    'other': Icons.insert_drive_file,
  };

  final Map<String, String> _typeLabels = {
    'pdf': 'PDF',
    'document': 'Document',
    'presentation': 'Presentation',
    'spreadsheet': 'Spreadsheet',
    'image': 'Image',
    'video': 'Video',
    'audio': 'Audio',
    'link': 'Link',
    'code': 'Code',
    'archive': 'Archive',
    'other': 'Other',
  };

  final DateFormat _dateFormat = DateFormat('MMM d, yyyy');

  @override
  void initState() {
    super.initState();

    // Set up animations
    _filterAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _filterAnimation = CurvedAnimation(
      parent: _filterAnimationController,
      curve: Curves.easeInOut,
    );

    // Set up instructions animation
    _instructionsController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _instructionsAnimation = CurvedAnimation(
      parent: _instructionsController,
      curve: Curves.easeInOut,
    );

    _instructionsController.forward();

    _loadResources();
  }

  @override
  void dispose() {
    _filterAnimationController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  Future<void> _loadResources() async {
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
              .collection('resources')
              .orderBy('uploadedAt', descending: true)
              .get();

      _resources =
          snapshot.docs.map((doc) => ResourceItem.fromFirestore(doc)).toList();

      // Group resources by type
      _groupResourcesByType();

      // Sort resources
      _sortResources();

      // Start animation
      _filterAnimationController.forward();
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading resources: $e')));
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _groupResourcesByType() {
    _resourcesByType = {};

    // Initialize with empty lists for all types
    _typeColors.keys.forEach((type) {
      _resourcesByType[type] = [];
    });

    // Group resources by type
    for (var resource in _resources) {
      if (_resourcesByType.containsKey(resource.fileType)) {
        _resourcesByType[resource.fileType]!.add(resource);
      } else {
        _resourcesByType['other']!.add(resource);
      }
    }
  }

  void _sortResources() {
    switch (_sortBy) {
      case 'newest':
        _resources.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        _resourcesByType.forEach((key, value) {
          value.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
        });
        break;
      case 'oldest':
        _resources.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
        _resourcesByType.forEach((key, value) {
          value.sort((a, b) => a.uploadedAt.compareTo(b.uploadedAt));
        });
        break;
      case 'alphabetical':
        _resources.sort(
          (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
        );
        _resourcesByType.forEach((key, value) {
          value.sort(
            (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
          );
        });
        break;
      case 'popular':
        // Sort by download count (fallback to upload date if download count is null)
        _resources.sort((a, b) {
          if (a.downloadCount != null && b.downloadCount != null) {
            return b.downloadCount!.compareTo(a.downloadCount!);
          } else if (a.downloadCount != null) {
            return -1;
          } else if (b.downloadCount != null) {
            return 1;
          } else {
            return b.uploadedAt.compareTo(a.uploadedAt);
          }
        });
        _resourcesByType.forEach((key, value) {
          value.sort((a, b) {
            if (a.downloadCount != null && b.downloadCount != null) {
              return b.downloadCount!.compareTo(a.downloadCount!);
            } else if (a.downloadCount != null) {
              return -1;
            } else if (b.downloadCount != null) {
              return 1;
            } else {
              return b.uploadedAt.compareTo(a.uploadedAt);
            }
          });
        });
        break;
    }
  }

  void _toggleInstructions() {
    setState(() {
      _showInstructions = !_showInstructions;
      if (_showInstructions) {
        _instructionsController.forward();
      } else {
        _instructionsController.reverse();
      }
    });
  }

  void _updateCategoryFilter(String category) {
    if (_selectedCategory != category) {
      _filterAnimationController.reset();
      setState(() {
        _selectedCategory = category;
      });
      _filterAnimationController.forward();
    }
  }

  void _updateSearchQuery(String query) {
    if (_searchQuery != query) {
      _filterAnimationController.reset();
      setState(() {
        _searchQuery = query;
      });
      _filterAnimationController.forward();
    }
  }

  void _updateSortOrder(String sortBy) {
    if (_sortBy != sortBy) {
      setState(() {
        _sortBy = sortBy;
        _sortResources();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF2A2D32),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildChannelHeader(),
          _buildSearchAndFilterBar(),
          Expanded(
            child:
                _isLoading
                    ? _buildLoadingIndicator()
                    : FadeTransition(
                      opacity: _filterAnimation,
                      child: _buildResourceContent(),
                    ),
          ),
        ],
      ),
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFF1E2124),
      elevation: 0,
      title: Row(
        children: [
          const Icon(Icons.folder, size: 20, color: Color(0xFF4CAF50)),
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
          icon: const Icon(Icons.cloud_download, color: Colors.white70),
          tooltip: 'Download All',
          onPressed: () {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bulk download coming soon!')),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.info_outline, color: Colors.white70),
          tooltip: 'Channel Info',
          onPressed: () => _showChannelInfo(),
        ),
        if (widget.userRole == UserRole.mentor)
          PopupMenuButton(
            icon: const Icon(Icons.more_vert, color: Colors.white70),
            tooltip: 'More Options',
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            color: const Color(0xFF36393F),
            itemBuilder:
                (context) => [
                  PopupMenuItem(
                    value: 'edit',
                    child: _buildPopupMenuItem(
                      'Edit Channel',
                      Icons.edit,
                      Colors.blue,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'delete',
                    child: _buildPopupMenuItem(
                      'Delete Channel',
                      Icons.delete,
                      Colors.red,
                    ),
                  ),
                  PopupMenuItem(
                    value: 'stats',
                    child: _buildPopupMenuItem(
                      'Channel Statistics',
                      Icons.bar_chart,
                      Colors.amber,
                    ),
                  ),
                ],
            onSelected: (value) {
              if (value == 'edit') {
                _editChannel();
              } else if (value == 'delete') {
                _confirmDeleteChannel();
              } else if (value == 'stats') {
                _showChannelStats();
              }
            },
          ),
      ],
    );
  }

  Widget _buildPopupMenuItem(String text, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 12),
        Text(text, style: const TextStyle(color: Colors.white)),
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
        padding: const EdgeInsets.all(16),
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
                color: const Color(0xFF4CAF50).withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.lightbulb_outline,
                color: Color(0xFF4CAF50),
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
                      color: Color(0xFF4CAF50),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.channel.instructions,
                    style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_special,
                        size: 14,
                        color: Colors.grey.shade500,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${_resources.length} resources available',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                _showInstructions
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

  Widget _buildSearchAndFilterBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: const BoxDecoration(
        color: Color(0xFF36393F),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Search bar and sort button
          Row(
            children: [
              // Search bar
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF202225),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Search resources...',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onChanged: _updateSearchQuery,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Sort button
              PopupMenuButton<String>(
                tooltip: 'Sort By',
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        _sortBy != 'newest'
                            ? const Color(0xFF4CAF50).withOpacity(0.2)
                            : Colors.transparent,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sort,
                    color:
                        _sortBy != 'newest'
                            ? const Color(0xFF4CAF50)
                            : Colors.grey.shade400,
                    size: 20,
                  ),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                color: const Color(0xFF202225),
                itemBuilder:
                    (context) => [
                      const PopupMenuItem(
                        value: 'newest',
                        child: Text(
                          'Newest First',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'oldest',
                        child: Text(
                          'Oldest First',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'alphabetical',
                        child: Text(
                          'Alphabetical',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'popular',
                        child: Text(
                          'Most Downloaded',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                onSelected: _updateSortOrder,
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Category filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('All', 'all', Icons.folder),
                const SizedBox(width: 8),
                _buildFilterChip('Documents', 'document', Icons.description),
                const SizedBox(width: 8),
                _buildFilterChip('PDFs', 'pdf', Icons.picture_as_pdf),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Presentations',
                  'presentation',
                  Icons.slideshow,
                ),
                const SizedBox(width: 8),
                _buildFilterChip(
                  'Spreadsheets',
                  'spreadsheet',
                  Icons.table_chart,
                ),
                const SizedBox(width: 8),
                _buildFilterChip('Images', 'image', Icons.image),
                const SizedBox(width: 8),
                _buildFilterChip('Videos', 'video', Icons.video_library),
                const SizedBox(width: 8),
                _buildFilterChip('Audio', 'audio', Icons.audiotrack),
                const SizedBox(width: 8),
                _buildFilterChip('Links', 'link', Icons.link),
                const SizedBox(width: 8),
                _buildFilterChip('Code', 'code', Icons.code),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, IconData icon) {
    final isSelected = _selectedCategory == value;
    final color =
        value == 'all'
            ? const Color(0xFF4CAF50)
            : _typeColors[value] ?? Colors.grey;

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
        onTap: () => _updateCategoryFilter(value),
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

  Widget _buildLoadingIndicator() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4CAF50)),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading resources...',
            style: TextStyle(color: Colors.grey.shade400),
          ),
        ],
      ),
    );
  }

  Widget _buildResourceContent() {
    // Apply search and category filters
    List<ResourceItem> filteredResources =
        _resources.where((resource) {
          // Apply category filter
          if (_selectedCategory != 'all' &&
              resource.fileType != _selectedCategory) {
            return false;
          }

          // Apply search filter
          if (_searchQuery.isNotEmpty) {
            final query = _searchQuery.toLowerCase();
            return resource.title.toLowerCase().contains(query) ||
                resource.description.toLowerCase().contains(query);
          }

          return true;
        }).toList();

    if (filteredResources.isEmpty) {
      return _buildEmptyState();
    }

    // If showing all resources and not searching, group by type
    if (_selectedCategory == 'all' && _searchQuery.isEmpty) {
      return _buildResourcesByType();
    }

    // Otherwise, show a regular list
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filteredResources.length,
      itemBuilder: (context, index) {
        // Staggered animation based on index
        return AnimatedOpacity(
          opacity: 1.0,
          duration: Duration(milliseconds: 300 + (index * 50)),
          curve: Curves.easeInOut,
          child: AnimatedPadding(
            padding: const EdgeInsets.only(top: 0),
            duration: Duration(milliseconds: 300 + (index * 50)),
            curve: Curves.easeInOut,
            child: _buildResourceCard(filteredResources[index]),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    String message;
    IconData icon;

    if (_searchQuery.isNotEmpty) {
      message = 'No resources match your search';
      icon = Icons.search_off;
    } else if (_selectedCategory != 'all') {
      message =
          'No ${_typeLabels[_selectedCategory]?.toLowerCase() ?? _selectedCategory} resources found';
      icon = _typeIcons[_selectedCategory] ?? Icons.folder_off;
    } else {
      message = 'No resources available yet';
      icon = Icons.folder_off;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 72, color: Colors.grey.shade700),
          const SizedBox(height: 24),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            widget.userRole == UserRole.mentor
                ? 'Upload resources to get started'
                : 'Check back later for new resources',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
            textAlign: TextAlign.center,
          ),
          if (widget.userRole == UserRole.mentor) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => _uploadResource(),
              icon: const Icon(Icons.upload_file),
              label: const Text('Upload Resource'),
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: const Color(0xFF4CAF50),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResourcesByType() {
    // Get all types that have resources
    final types =
        _resourcesByType.entries
            .where((entry) => entry.value.isNotEmpty)
            .map((entry) => entry.key)
            .toList();

    if (types.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: types.length,
      itemBuilder: (context, index) {
        final type = types[index];
        final resources = _resourcesByType[type]!;

        if (resources.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (index > 0) const SizedBox(height: 24),
            _buildSectionHeader(type),
            const SizedBox(height: 12),
            ...resources.asMap().entries.map((entry) {
              final resourceIndex = entry.key;
              final resource = entry.value;

              // Staggered animation based on index
              return AnimatedOpacity(
                opacity: 1.0,
                duration: Duration(milliseconds: 300 + (resourceIndex * 50)),
                curve: Curves.easeInOut,
                child: AnimatedPadding(
                  padding: const EdgeInsets.only(top: 0),
                  duration: Duration(milliseconds: 300 + (resourceIndex * 50)),
                  curve: Curves.easeInOut,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _buildResourceCard(resource),
                  ),
                ),
              );
            }).toList(),
          ],
        );
      },
    );
  }

  Widget _buildSectionHeader(String type) {
    final color = _typeColors[type] ?? Colors.grey;
    final icon = _typeIcons[type] ?? Icons.folder;
    final label = _typeLabels[type] ?? 'Other';

    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 8),
        Text(
          '$label Resources',
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 16,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: color.withOpacity(0.3))),
      ],
    );
  }

  Widget _buildResourceCard(ResourceItem resource) {
    final color = _typeColors[resource.fileType] ?? Colors.grey;
    final icon = _typeIcons[resource.fileType] ?? Icons.insert_drive_file;
    final isExpanded = _expandedResourceId == resource.id;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          setState(() {
            _expandedResourceId = isExpanded ? null : resource.id;
          });
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF2F3136),
                border: Border(left: BorderSide(color: color, width: 4)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, color: color, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          resource.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        if (resource.tags != null && resource.tags!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Wrap(
                              spacing: 4,
                              runSpacing: 4,
                              children:
                                  resource.tags!
                                      .map(
                                        (tag) => Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: color.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            tag,
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _typeLabels[resource.fileType] ?? 'File',
                      style: TextStyle(
                        color: color,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body - shown when expanded
            AnimatedCrossFade(
              firstChild: const SizedBox(height: 0),
              secondChild: _buildExpandedResourceDetails(resource),
              crossFadeState:
                  isExpanded
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 300),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF2F3136),
                border: Border(
                  top: BorderSide(color: Color(0xFF202225), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Uploader info
                  FutureBuilder<DocumentSnapshot>(
                    future:
                        FirebaseFirestore.instance
                            .collection('users')
                            .doc(resource.uploadedBy)
                            .get(),
                    builder: (context, snapshot) {
                      String uploaderName = 'Unknown';
                      String? photoURL;

                      if (snapshot.hasData && snapshot.data!.exists) {
                        final userData =
                            snapshot.data!.data() as Map<String, dynamic>;
                        uploaderName =
                            userData['displayName'] as String? ?? 'Unknown';
                        photoURL = userData['photoURL'] as String?;
                      }

                      return Expanded(
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: Colors.grey.shade800,
                              backgroundImage:
                                  photoURL != null
                                      ? NetworkImage(photoURL)
                                      : null,
                              child:
                                  photoURL == null
                                      ? Text(
                                        uploaderName[0].toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      )
                                      : null,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    uploaderName,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    _formatTimestamp(resource.uploadedAt),
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),

                  // Action buttons
                  Row(
                    children: [
                      if (widget.userRole == UserRole.mentor)
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _confirmDeleteResource(resource),
                          tooltip: 'Delete',
                          splashRadius: 20,
                        ),
                      IconButton(
                        icon: Icon(
                          resource.fileType == 'link'
                              ? Icons.open_in_new
                              : Icons.download,
                          color: color,
                          size: 20,
                        ),
                        onPressed: () => _openResource(resource),
                        tooltip:
                            resource.fileType == 'link'
                                ? 'Open Link'
                                : 'Download',
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedResourceDetails(ResourceItem resource) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      color: const Color(0xFF36393F),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Description
          if (resource.description.isNotEmpty) ...[
            Text(
              'Description',
              style: TextStyle(
                color: _typeColors[resource.fileType] ?? Colors.grey,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              resource.description,
              style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
            ),
            const SizedBox(height: 16),
          ],

          // Resource details in a grid
          Row(
            children: [
              // File details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      'Type',
                      _typeLabels[resource.fileType] ?? 'File',
                      _typeIcons[resource.fileType] ?? Icons.insert_drive_file,
                    ),
                    const SizedBox(height: 12),
                    if (resource.fileSize != null)
                      _buildDetailItem(
                        'Size',
                        _formatFileSize(resource.fileSize!),
                        Icons.data_usage,
                      ),
                  ],
                ),
              ),

              // Usage details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(
                      'Uploaded',
                      _dateFormat.format(resource.uploadedAt.toDate()),
                      Icons.date_range,
                    ),
                    const SizedBox(height: 12),
                    if (resource.downloadCount != null)
                      _buildDetailItem(
                        'Downloads',
                        resource.downloadCount.toString(),
                        Icons.file_download,
                      ),
                  ],
                ),
              ),
            ],
          ),

          // Preview (placeholder)
          if (_canShowPreview(resource.fileType)) ...[
            const SizedBox(height: 16),
            const Divider(color: Color(0xFF202225)),
            const SizedBox(height: 16),
            Center(child: _buildPreviewPlaceholder(resource)),
          ],
        ],
      ),
    );
  }

  bool _canShowPreview(String fileType) {
    // File types that could have previews
    return [
      'image',
      'pdf',
      'document',
      'presentation',
      'video',
    ].contains(fileType);
  }

  Widget _buildPreviewPlaceholder(ResourceItem resource) {
    switch (resource.fileType) {
      case 'image':
        return Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.image, size: 64, color: Colors.grey),
          ),
        );
      case 'pdf':
        return Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.picture_as_pdf, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => _openResource(resource),
                icon: const Icon(Icons.visibility),
                label: const Text('Preview PDF'),
                style: ElevatedButton.styleFrom(
                  foregroundColor: Colors.white,
                  backgroundColor: Colors.red,
                ),
              ),
            ],
          ),
        );
      case 'document':
        return Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.description, size: 64, color: Colors.blue),
              const SizedBox(height: 16),
              Text(
                'Document Preview',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preview not available in this build',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      case 'presentation':
        return Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.slideshow, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              Text(
                'Presentation Preview',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preview not available in this build',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      case 'video':
        return Container(
          width: 300,
          height: 200,
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.video_library, size: 64, color: Colors.pink),
                  Container(
                    width: 32,
                    height: 32,
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.play_arrow,
                        color: Colors.pink,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Video Preview',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Preview not available in this build',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDetailItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey.shade500),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.grey.shade300,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFloatingActionButton() {
    if (widget.userRole != UserRole.mentor) {
      return const SizedBox.shrink();
    }

    return FloatingActionButton(
      onPressed: _isUploading ? null : () => _uploadResource(),
      backgroundColor: const Color(0xFF4CAF50),
      foregroundColor: Colors.white,
      elevation: 6,
      child:
          _isUploading
              ? const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              )
              : const Icon(Icons.upload_file),
    );
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

  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
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
                const Icon(Icons.folder, size: 20, color: Color(0xFF4CAF50)),
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
                  // Channel description
                  _buildInfoSection(
                    'Description',
                    Icons.description,
                    widget.channel.description.isNotEmpty
                        ? widget.channel.description
                        : 'No description provided',
                  ),

                  const SizedBox(height: 16),

                  // Creation info
                  _buildInfoSection(
                    'Created',
                    Icons.event,
                    _formatFullTimestamp(widget.channel.createdAt),
                  ),

                  const SizedBox(height: 16),

                  // Creator info
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

                  // Channel instructions
                  if (widget.channel.instructions.isNotEmpty) ...[
                    const SizedBox(height: 16),

                    _buildInfoSection(
                      'Instructions',
                      Icons.lightbulb_outline,
                      widget.channel.instructions,
                      highlight: true,
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Resource statistics
                  _buildInfoSection(
                    'Statistics',
                    Icons.bar_chart,
                    'Total Resources: ${_resources.length}\n\n'
                        'Documents: ${_resourcesByType['document']?.length ?? 0}\n'
                        'PDFs: ${_resourcesByType['pdf']?.length ?? 0}\n'
                        'Presentations: ${_resourcesByType['presentation']?.length ?? 0}\n'
                        'Spreadsheets: ${_resourcesByType['spreadsheet']?.length ?? 0}\n'
                        'Images: ${_resourcesByType['image']?.length ?? 0}\n'
                        'Videos: ${_resourcesByType['video']?.length ?? 0}\n'
                        'Links: ${_resourcesByType['link']?.length ?? 0}\n',
                  ),
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
                  foregroundColor: const Color(0xFF4CAF50),
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
            Icon(icon, size: 16, color: const Color(0xFF4CAF50)),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFF4CAF50),
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
                    ? const Color(0xFF4CAF50).withOpacity(0.1)
                    : const Color(0xFF2F3136),
            borderRadius: BorderRadius.circular(8),
            border:
                highlight
                    ? Border.all(
                      color: const Color(0xFF4CAF50).withOpacity(0.3),
                      width: 1,
                    )
                    : null,
          ),
          child: Text(
            content,
            style: TextStyle(
              color: highlight ? const Color(0xFF4CAF50) : Colors.grey.shade300,
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

  void _showChannelStats() {
    // Calculate total download count
    int totalDownloads = 0;
    for (final resource in _resources) {
      if (resource.downloadCount != null) {
        totalDownloads += resource.downloadCount!;
      }
    }

    // Find most popular resource
    ResourceItem? mostPopular;
    int maxDownloads = 0;
    for (final resource in _resources) {
      if (resource.downloadCount != null &&
          resource.downloadCount! > maxDownloads) {
        maxDownloads = resource.downloadCount!;
        mostPopular = resource;
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF36393F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.bar_chart,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Channel Statistics',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: [
                        // Resources by type
                        _buildStatCard(
                          'Resources by Type',
                          Icons.folder,
                          const Color(0xFF4CAF50),
                          [
                            _buildStatItem(
                              'Total Resources',
                              _resources.length.toString(),
                              Icons.folder,
                              const Color(0xFF4CAF50),
                            ),
                            const SizedBox(height: 12),
                            _buildStatItem(
                              'Documents',
                              ((_resourcesByType['document']?.length ?? 0) +
                                      (_resourcesByType['pdf']?.length ?? 0))
                                  .toString(),
                              Icons.description,
                              Colors.blue,
                            ),
                            const SizedBox(height: 12),
                            _buildStatItem(
                              'Presentations',
                              (_resourcesByType['presentation']?.length ?? 0)
                                  .toString(),
                              Icons.slideshow,
                              Colors.orange,
                            ),
                            const SizedBox(height: 12),
                            _buildStatItem(
                              'Spreadsheets',
                              (_resourcesByType['spreadsheet']?.length ?? 0)
                                  .toString(),
                              Icons.table_chart,
                              Colors.green,
                            ),
                            const SizedBox(height: 12),
                            _buildStatItem(
                              'Media Files',
                              ((_resourcesByType['image']?.length ?? 0) +
                                      (_resourcesByType['video']?.length ?? 0) +
                                      (_resourcesByType['audio']?.length ?? 0))
                                  .toString(),
                              Icons.perm_media,
                              Colors.purple,
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Usage statistics
                        _buildStatCard(
                          'Usage Statistics',
                          Icons.analytics,
                          Colors.blue,
                          [
                            _buildStatItem(
                              'Total Downloads',
                              totalDownloads.toString(),
                              Icons.download,
                              Colors.blue,
                            ),
                            if (mostPopular != null) ...[
                              const SizedBox(height: 16),
                              const Text(
                                'Most Popular Resource:',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2F3136),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.blue.withOpacity(0.3),
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      _typeIcons[mostPopular.fileType] ??
                                          Icons.insert_drive_file,
                                      color:
                                          _typeColors[mostPopular.fileType] ??
                                          Colors.grey,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            mostPopular.title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            '${mostPopular.downloadCount} downloads',
                                            style: const TextStyle(
                                              color: Colors.blue,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(height: 24),

                        // User engagement
                        _buildStatCard(
                          'User Engagement',
                          Icons.people,
                          Colors.purple,
                          [
                            StreamBuilder<QuerySnapshot>(
                              stream:
                                  FirebaseFirestore.instance
                                      .collection('groups')
                                      .doc(widget.groupId)
                                      .collection('members')
                                      .snapshots(),
                              builder: (context, snapshot) {
                                final memberCount =
                                    snapshot.hasData
                                        ? snapshot.data!.docs.length
                                        : 0;
                                return _buildStatItem(
                                  'Total Members',
                                  memberCount.toString(),
                                  Icons.people,
                                  Colors.purple,
                                );
                              },
                            ),
                            const SizedBox(height: 12),
                            FutureBuilder<QuerySnapshot>(
                              future:
                                  FirebaseFirestore.instance
                                      .collection('groups')
                                      .doc(widget.groupId)
                                      .collection('channels')
                                      .doc(widget.channel.id)
                                      .collection('resources')
                                      .orderBy('uploadedAt')
                                      .get(),
                              builder: (context, snapshot) {
                                // Count unique uploaders
                                final uploaders = <String>{};
                                if (snapshot.hasData) {
                                  for (final doc in snapshot.data!.docs) {
                                    final data =
                                        doc.data() as Map<String, dynamic>;
                                    if (data['uploadedBy'] != null) {
                                      uploaders.add(
                                        data['uploadedBy'] as String,
                                      );
                                    }
                                  }
                                }
                                return _buildStatItem(
                                  'Unique Uploaders',
                                  uploaders.length.toString(),
                                  Icons.upload_file,
                                  Colors.orange,
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildStatCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2F3136),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF202225)),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 14),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF202225),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  void _editChannel() {
    // Navigate to channel edit page
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
              'This action cannot be undone and all resources will be lost.',
              style: TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF4CAF50)),
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

  void _deleteChannel() async {
    try {
      // Show loading indicator
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
                      Color(0xFF4CAF50),
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

      // First, get all resources
      final resourcesSnapshot =
          await FirebaseFirestore.instance
              .collection('groups')
              .doc(widget.groupId)
              .collection('channels')
              .doc(widget.channel.id)
              .collection('resources')
              .get();

      final batch = FirebaseFirestore.instance.batch();

      // Delete all resources
      for (final resourceDoc in resourcesSnapshot.docs) {
        batch.delete(resourceDoc.reference);

        // TODO: In a real app, you would also delete the file from storage here
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

      // Pop loading dialog
      Navigator.pop(context);

      // Pop back to group page
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Channel deleted successfully'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      // Pop loading dialog
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting channel: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _uploadResource() {
    setState(() {
      _isUploading = true;
    });

    // Show upload dialog with options
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder:
          (context) => Container(
            height: MediaQuery.of(context).size.height * 0.7,
            decoration: const BoxDecoration(
              color: Color(0xFF36393F),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              children: [
                // Handle bar
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade600,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Title
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.upload_file,
                        color: Color(0xFF4CAF50),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Upload Resource',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _isUploading = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                // Upload options
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Select resource type to upload',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Grid of upload options
                        GridView.count(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          children: [
                            _buildUploadOption(
                              'Document',
                              Icons.description,
                              Colors.blue,
                              () => _addMockResource('document'),
                            ),
                            _buildUploadOption(
                              'PDF',
                              Icons.picture_as_pdf,
                              Colors.red,
                              () => _addMockResource('pdf'),
                            ),
                            _buildUploadOption(
                              'Presentation',
                              Icons.slideshow,
                              Colors.orange,
                              () => _addMockResource('presentation'),
                            ),
                            _buildUploadOption(
                              'Spreadsheet',
                              Icons.table_chart,
                              Colors.green,
                              () => _addMockResource('spreadsheet'),
                            ),
                            _buildUploadOption(
                              'Image',
                              Icons.image,
                              Colors.purple,
                              () => _addMockResource('image'),
                            ),
                            _buildUploadOption(
                              'Video',
                              Icons.video_library,
                              Colors.pink,
                              () => _addMockResource('video'),
                            ),
                            _buildUploadOption(
                              'Audio',
                              Icons.audiotrack,
                              Colors.teal,
                              () => _addMockResource('audio'),
                            ),
                            _buildUploadOption(
                              'Link',
                              Icons.link,
                              Colors.indigo,
                              () => _addMockResource('link'),
                            ),
                            _buildUploadOption(
                              'Code',
                              Icons.code,
                              Colors.amber,
                              () => _addMockResource('code'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),
                        const Divider(color: Color(0xFF202225)),
                        const SizedBox(height: 16),

                        // Create folder option
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Create folder functionality coming soon!',
                                ),
                              ),
                            );
                            setState(() {
                              _isUploading = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF4CAF50,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.create_new_folder,
                                    color: Color(0xFF4CAF50),
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Create New Folder',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Organize your resources better',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Bulk upload option
                        InkWell(
                          onTap: () {
                            Navigator.pop(context);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Bulk upload functionality coming soon!',
                                ),
                              ),
                            );
                            setState(() {
                              _isUploading = false;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.drive_folder_upload,
                                    color: Colors.blue,
                                    size: 24,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                const Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bulk Upload',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Upload multiple files at once',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.grey,
                                  size: 16,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
    ).then((_) {
      if (mounted && _isUploading) {
        setState(() {
          _isUploading = false;
        });
      }
    });
  }

  Widget _buildUploadOption(
    String label,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF2F3136),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addMockResource(String fileType) async {
    try {
      // In a real app, you would upload the file to Firebase Storage
      // and then add the resource document with the file URL

      final userId = FirebaseAuth.instance.currentUser!.uid;

      // Generate a random file size between 100KB and 50MB
      final fileSize =
          fileType == 'link'
              ? null
              : (100 + (50000 * (DateTime.now().microsecond / 1000000)))
                      .round() *
                  1024;

      // Generate random download count
      final downloadCount =
          fileType == 'link' ? null : (DateTime.now().second % 20) + 1;

      // Generate random tags
      final tags = _generateRandomTags(fileType);

      // Create resource data
      final resourceData = {
        'title': 'Sample ${_typeLabels[fileType] ?? ''} resource',
        'description':
            'This is a mock ${_typeLabels[fileType]?.toLowerCase() ?? ''} resource for demonstration purposes.',
        'fileType': fileType,
        'fileURL': 'https://example.com/sample.$fileType',
        'uploadedBy': userId,
        'uploadedAt': FieldValue.serverTimestamp(),
      };

      // Add optional fields
      if (fileSize != null) {
        resourceData['fileSize'] = fileSize;
      }

      if (downloadCount != null) {
        resourceData['downloadCount'] = downloadCount;
      }

      if (tags.isNotEmpty) {
        resourceData['tags'] = tags;
      }

      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('channels')
          .doc(widget.channel.id)
          .collection('resources')
          .add(resourceData);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${_typeLabels[fileType] ?? "Resource"} added successfully',
          ),
          backgroundColor: Colors.green,
        ),
      );

      _loadResources();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error adding resource: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  List<String> _generateRandomTags(String fileType) {
    final tags = <String>[];

    // Add file type as a tag
    if (_typeLabels.containsKey(fileType)) {
      tags.add(_typeLabels[fileType]!);
    }

    // Add random subject tags
    final subjects = [
      'Mathematics',
      'Science',
      'History',
      'English',
      'Art',
      'Computer Science',
      'Physics',
      'Chemistry',
      'Biology',
    ];

    // Random level tags
    final levels = [
      'Beginner',
      'Intermediate',
      'Advanced',
      'Year 1',
      'Year 2',
      'Year 3',
    ];

    // Add 1-3 random tags
    final tagCount = (DateTime.now().millisecond % 3) + 1;
    final random = DateTime.now().microsecond;

    if (tagCount > 0) {
      tags.add(subjects[random % subjects.length]);
    }

    if (tagCount > 1) {
      tags.add(levels[random % levels.length]);
    }

    return tags;
  }

  void _confirmDeleteResource(ResourceItem resource) {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF36393F),
            title: const Text(
              'Delete Resource',
              style: TextStyle(color: Colors.white),
            ),
            content: Text(
              'Are you sure you want to delete "${resource.title}"? '
              'This action cannot be undone.',
              style: const TextStyle(color: Colors.white70),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Color(0xFF4CAF50)),
                ),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _deleteResource(resource);
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

  void _deleteResource(ResourceItem resource) async {
    try {
      await FirebaseFirestore.instance
          .collection('groups')
          .doc(widget.groupId)
          .collection('channels')
          .doc(widget.channel.id)
          .collection('resources')
          .doc(resource.id)
          .delete();

      // TODO: In a real app, you would also delete the file from storage here

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Resource deleted'),
          backgroundColor: Colors.green,
        ),
      );

      setState(() {
        // If the deleted resource was expanded, clear the expanded resource id
        if (_expandedResourceId == resource.id) {
          _expandedResourceId = null;
        }
      });

      _loadResources();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting resource: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _openResource(ResourceItem resource) async {
    try {
      if (resource.fileType == 'link') {
        final uri = Uri.parse(resource.fileURL);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        } else {
          throw 'Could not launch ${resource.fileURL}';
        }
      } else {
        // Show a preview dialog
        _showResourcePreview(resource);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error opening resource: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showResourcePreview(ResourceItem resource) {
    final color = _typeColors[resource.fileType] ?? Colors.grey;
    final icon = _typeIcons[resource.fileType] ?? Icons.insert_drive_file;

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor: const Color(0xFF36393F),
            contentPadding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icon, color: color),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          resource.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white70),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),

                // Preview content (placeholder)
                Container(
                  width: 400,
                  height: 300,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 64, color: color.withOpacity(0.5)),
                      const SizedBox(height: 24),
                      const Text(
                        'Preview not available in this demo',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'In a real application, you would see a preview of the ${_typeLabels[resource.fileType]?.toLowerCase() ?? "file"} here',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      if (resource.fileSize != null)
                        Text(
                          _formatFileSize(resource.fileSize!),
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),

                // Action buttons
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF2F3136),
                    borderRadius: BorderRadius.vertical(
                      bottom: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                        label: const Text('Close'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: BorderSide(color: Colors.grey.shade700),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Download started!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        icon: const Icon(Icons.download),
                        label: const Text('Download'),
                        style: ElevatedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
