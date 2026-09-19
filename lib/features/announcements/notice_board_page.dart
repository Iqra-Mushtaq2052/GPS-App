import 'package:flutter/material.dart';

import '../../app_scope.dart';
import '../../core/supabase/supabase_service.dart';
import '../../data/db/app_database.dart';

class NoticeBoardPage extends StatefulWidget {
  const NoticeBoardPage({super.key});

  @override
  State<NoticeBoardPage> createState() => _NoticeBoardPageState();
}

class _NoticeBoardPageState extends State<NoticeBoardPage> {
  bool _isLoading = true;
  List<CloudAnnouncement> _announcements = [];
  List<Mosque> _savedMosques = [];
  bool _isImam = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Use addPostFrameCallback to avoid calling AppScope.of in initState
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    final scope = AppScope.of(context);
    try {
      final isImam = await scope.roleService.isImam();
      final mosques = await scope.mosqueRepository.getAll();

      final cloudIds = mosques
          .map((m) => m.supabaseId)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      List<CloudAnnouncement> announcements = [];
      if (cloudIds.isNotEmpty) {
        try {
          announcements = await scope.supabaseService
              .fetchAnnouncements(cloudIds)
              .timeout(const Duration(seconds: 5), onTimeout: () => []);
        } catch (_) {
          // Network error — show empty list, not loading forever
        }
      }

      if (mounted) {
        setState(() {
          _isImam = isImam;
          _savedMosques = mosques;
          _announcements = announcements;
          _isLoading = false;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Could not load data: $e';
        });
      }
    }
  }

  Future<void> _createAnnouncement() async {
    final scope = AppScope.of(context);
    final imamMosques =
        _savedMosques.where((m) => m.supabaseId != null).toList();

    if (imamMosques.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Please create a mosque first (with Supabase sync) before posting announcements.')),
      );
      return;
    }

    final titleController = TextEditingController();
    final contentController = TextEditingController();
    Mosque selectedMosque = imamMosques.first;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.campaign, color: Color(0xFF10B981)),
                  SizedBox(width: 8),
                  Text('New Announcement'),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (imamMosques.length > 1) ...[
                      DropdownButton<Mosque>(
                        value: selectedMosque,
                        isExpanded: true,
                        items: imamMosques.map((m) {
                          return DropdownMenuItem(
                              value: m, child: Text(m.name));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => selectedMosque = val);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title (e.g. Jummah Khutbah Time)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: contentController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Details / Notice Message',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Post Announcement'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirm == true) {
      final title = titleController.text.trim();
      final content = contentController.text.trim();

      if (title.isEmpty || content.isEmpty) return;

      setState(() => _isLoading = true);
      try {
        await scope.supabaseService.createAnnouncement(
          cloudMosqueId: selectedMosque.supabaseId!,
          title: title,
          content: content,
        );
        await _loadData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Announcement posted successfully!')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to post announcement: $e')),
          );
          setState(() => _isLoading = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF059669), Colors.transparent]
                  : [
                      const Color(0xFF059669).withValues(alpha: 0.2),
                      Colors.transparent
                    ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
        title: const Text('Mosque Notice Board'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _isLoading = true);
              _loadData();
            },
          ),
        ],
      ),
      floatingActionButton: _isImam
          ? FloatingActionButton.extended(
              backgroundColor: theme.colorScheme.primary,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_comment),
              label: const Text('Post Announcement'),
              onPressed: _createAnnouncement,
            )
          : null,
      body: Container(
        decoration: isDark
            ? const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.5,
                  colors: [Color(0xFF161B22), Color(0xFF0D1117)],
                ),
              )
            : null,
        child: _isLoading
            ? Center(
                child: CircularProgressIndicator(
                    color: theme.colorScheme.primary))
            : _errorMessage != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline,
                              size: 64, color: Colors.redAccent),
                          const SizedBox(height: 16),
                          Text(
                            _errorMessage!,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.6),
                            ),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: () {
                              setState(() {
                                _isLoading = true;
                                _errorMessage = null;
                              });
                              _loadData();
                            },
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : _announcements.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.campaign_outlined,
                                  size: 64,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _isImam
                                    ? 'No announcements posted yet.\nTap + to post your first announcement.'
                                    : 'No announcements from your mosques yet.\nImam will post notices here.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadData,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _announcements.length,
                          itemBuilder: (context, index) {
                            final item = _announcements[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Row(
                                            children: [
                                              Icon(Icons.campaign,
                                                  color: theme
                                                      .colorScheme.secondary),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  item.title,
                                                  style: const TextStyle(
                                                    fontSize: 18,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (_isImam)
                                          IconButton(
                                            icon: const Icon(
                                                Icons.delete_outline,
                                                color: Colors.redAccent,
                                                size: 20),
                                            onPressed: () async {
                                              await scope.supabaseService
                                                  .deleteAnnouncement(item.id);
                                              _loadData();
                                            },
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      item.content,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: theme.colorScheme.onSurface
                                            .withValues(alpha: 0.8),
                                        height: 1.4,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Divider(color: theme.dividerColor),
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Posted on ${item.createdAt.toString().substring(0, 16)}',
                                          style: const TextStyle(
                                              fontSize: 11, color: Colors.grey),
                                        ),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                              horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: theme.colorScheme.primary
                                                .withValues(alpha: 0.15),
                                            borderRadius:
                                                BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            'Official Notice',
                                            style: TextStyle(
                                              color:
                                                  theme.colorScheme.primary,
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
      ),
    );
  }
}
