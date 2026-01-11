import 'package:convex_flutter/convex_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/convex_service.dart';
import '../theme/app_theme.dart';

/// Bottom sheet displaying the trip checklist with sections and items
class ChecklistSheet extends StatefulWidget {
  final String tripId;
  final List<Map<String, dynamic>>? initialSections;

  const ChecklistSheet({super.key, required this.tripId, this.initialSections});

  static void show(
    BuildContext context, {
    required String tripId,
    List<Map<String, dynamic>>? initialSections,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          ChecklistSheet(tripId: tripId, initialSections: initialSections),
    );
  }

  @override
  State<ChecklistSheet> createState() => _ChecklistSheetState();
}

class _ChecklistSheetState extends State<ChecklistSheet> {
  late List<Map<String, dynamic>> _sections;
  SubscriptionHandle? _subscription;
  late bool _isLoading;
  Timer? _updateIgnoreTimer;

  @override
  void initState() {
    super.initState();
    if (widget.initialSections != null) {
      _sections = widget.initialSections!;
      _isLoading = false;
    } else {
      _sections = [];
      _isLoading = true;
    }
    _subscribeToChecklist();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _updateIgnoreTimer?.cancel();
    super.dispose();
  }

  Future<void> _subscribeToChecklist() async {
    try {
      final convexService = await ConvexService.getInstance();
      _subscription = await convexService.subscribeToChecklist(
        tripId: widget.tripId,
        onUpdate: (sections) {
          if (!mounted) return;
          if (_updateIgnoreTimer?.isActive ?? false) {
            debugPrint('Ignoring subscription update during reorder');
            return;
          }
          setState(() {
            _sections = sections;
            _isLoading = false;
          });
        },
        onError: (message, value) {
          debugPrint('Checklist subscription error: $message $value');
          if (mounted) setState(() => _isLoading = false);
        },
      );
    } catch (e) {
      debugPrint('Error subscribing to checklist: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _addSection() async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.createChecklistSection(
        tripId: widget.tripId,
        name: 'New Section',
      );
    } catch (e) {
      _showError('Error creating section: $e');
    }
  }

  Future<void> _renameSection(String sectionId, String newName) async {
    if (newName.trim().isEmpty) return;
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.updateChecklistSection(
        id: sectionId,
        name: newName.trim(),
      );
    } catch (e) {
      _showError('Error renaming section: $e');
    }
  }

  Future<void> _deleteSection(String sectionId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Section'),
        content: const Text(
          'Are you sure you want to delete this section and all its items?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteChecklistSection(sectionId);
    } catch (e) {
      _showError('Error deleting section: $e');
    }
  }

  Future<void> _addItem(String sectionId, String text) async {
    if (text.trim().isEmpty) return;
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.createChecklistItem(
        sectionId: sectionId,
        text: text.trim(),
      );
    } catch (e) {
      _showError('Error creating item: $e');
    }
  }

  Future<void> _toggleItem(String itemId, bool completed) async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.updateChecklistItem(
        id: itemId,
        completed: !completed,
      );
    } catch (e) {
      _showError('Error updating item: $e');
    }
  }

  Future<void> _updateItemText(String itemId, String newText) async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.updateChecklistItem(id: itemId, text: newText);
    } catch (e) {
      _showError('Error updating item: $e');
    }
  }

  Future<void> _deleteItem(String itemId) async {
    try {
      final convexService = await ConvexService.getInstance();
      await convexService.deleteChecklistItem(itemId);
    } catch (e) {
      _showError('Error deleting item: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final screenHeight = MediaQuery.of(context).size.height;
    final maxHeight = screenHeight * 0.85;
    final minHeight = screenHeight * 0.55;

    return AnimatedSize(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      child: Container(
        constraints: BoxConstraints(minHeight: minHeight, maxHeight: maxHeight),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHeader(colorScheme),
              Flexible(
                child: AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  child: _isLoading
                      ? const SizedBox(
                          height: 150,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      : _sections.isEmpty
                      ? _buildEmptyState()
                      : _buildChecklistContent(),
                ),
              ),
              _buildAddSectionButton(colorScheme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 16, 8),
      child: Column(
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Icon(Icons.checklist, color: AppColors.primary, size: 28),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Checklist',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Spacer(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.playlist_add_check_outlined,
            size: 64,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No checklist yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Text(
            'Add a section to get started',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistContent() {
    return ReorderableListView(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      proxyDecorator: (child, index, animation) {
        return Material(
          elevation: 3,
          borderRadius: BorderRadius.circular(12),
          child: Opacity(opacity: 0.7, child: child),
        );
      },
      onReorder: (oldIndex, newIndex) async {
        // Adjust newIndex if item is moved down
        if (newIndex > oldIndex) newIndex -= 1;

        if (oldIndex == newIndex) {
          return;
        }

        // Update local state
        setState(() {
          final item = _sections.removeAt(oldIndex);
          _sections.insert(newIndex, item);
        });

        // Update order in backend for all affected sections
        try {
          final convexService = await ConvexService.getInstance();

          // Update orders for all sections that moved
          final minIndex = oldIndex < newIndex ? oldIndex : newIndex;
          final maxIndex = oldIndex > newIndex ? oldIndex : newIndex;

          for (int i = minIndex; i <= maxIndex; i++) {
            final section = _sections[i];
            await convexService.updateChecklistSection(
              id: section['_id'] as String,
              order: i,
            );
          }

          // Ignore subscription updates for 1 second to avoid flashing stale data
          _updateIgnoreTimer?.cancel();
          _updateIgnoreTimer = Timer(const Duration(seconds: 1), () {});
        } catch (e) {
          debugPrint('Error reordering section: $e');
          // Revert on error
          setState(() {
            final item = _sections.removeAt(newIndex);
            _sections.insert(oldIndex, item);
          });
        }
      },
      children: List.generate(_sections.length, (index) {
        final section = _sections[index];
        return _ChecklistSectionWidget(
          key: ValueKey(section['_id']),
          section: section,
          index: index,
          onRename: (name) => _renameSection(section['_id'] as String, name),
          onDelete: () => _deleteSection(section['_id'] as String),
          onAddItem: (text) => _addItem(section['_id'] as String, text),
          onToggleItem: _toggleItem,
          onEditItem: (itemId, newText) => _updateItemText(itemId, newText),
          onDeleteItem: _deleteItem,
        );
      }),
    );
  }

  Widget _buildAddSectionButton(ColorScheme colorScheme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextButton.icon(
        onPressed: _addSection,
        icon: const Icon(Icons.add),
        label: const Text('Section'),
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _ChecklistSectionWidget extends StatefulWidget {
  final Map<String, dynamic> section;
  final int index;
  final void Function(String name) onRename;
  final VoidCallback onDelete;
  final void Function(String text) onAddItem;
  final Future<void> Function(String itemId, bool completed) onToggleItem;
  final Future<void> Function(String itemId, String currentText) onEditItem;
  final Future<void> Function(String itemId) onDeleteItem;

  const _ChecklistSectionWidget({
    super.key,
    required this.section,
    required this.index,
    required this.onRename,
    required this.onDelete,
    required this.onAddItem,
    required this.onToggleItem,
    required this.onEditItem,
    required this.onDeleteItem,
  });

  @override
  State<_ChecklistSectionWidget> createState() =>
      _ChecklistSectionWidgetState();
}

class _ChecklistSectionWidgetState extends State<_ChecklistSectionWidget> {
  final _addItemController = TextEditingController();
  final _addItemFocusNode = FocusNode();
  final _titleController = TextEditingController();
  final _titleFocusNode = FocusNode();
  final _titleFocusScope = FocusScopeNode();
  final _addItemFocusScope = FocusScopeNode();
  bool _isAddingItem = false;
  bool _isEditingTitle = false;
  late String _displayedTitle;

  @override
  void initState() {
    super.initState();
    _displayedTitle = widget.section['name'] as String;
    _titleFocusNode.addListener(_onTitleFocusChange);
  }

  @override
  void dispose() {
    _addItemController.dispose();
    _addItemFocusNode.dispose();
    _titleController.dispose();
    _titleFocusNode.removeListener(_onTitleFocusChange);
    _titleFocusNode.dispose();
    _titleFocusScope.dispose();
    _addItemFocusScope.dispose();
    super.dispose();
  }

  void _onTitleFocusChange() {
    if (!_titleFocusNode.hasFocus && _isEditingTitle) {
      _submitTitle();
    }
  }

  void _startEditingTitle() {
    setState(() {
      _isEditingTitle = true;
      _titleController.text = widget.section['name'] as String;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });
  }

  void _submitTitle() {
    final name = _titleController.text.trim();
    setState(() {
      _isEditingTitle = false;
      if (name.isNotEmpty && name != _displayedTitle) {
        _displayedTitle = name; // Update displayed title immediately
      }
    });
    if (name.isNotEmpty && name != widget.section['name']) {
      widget.onRename(name); // Send to backend
    }
  }

  void _submitItem() {
    final text = _addItemController.text.trim();
    if (text.isNotEmpty) {
      widget.onAddItem(text);
      _addItemController.clear();
      // Keep focus for rapid-fire adding
      _addItemFocusNode.requestFocus();
    }
  }

  void _startAddingItem() {
    setState(() => _isAddingItem = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _addItemFocusNode.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final items = (widget.section['items'] as List<dynamic>?) ?? [];
    final colorScheme = Theme.of(context).colorScheme;

    // Calculate progress
    final totalItems = items.length;
    final completedItems = items
        .where((i) => (i as Map)['completed'] == true)
        .length;

    return TapRegion(
      onTapOutside: (event) {
        // Unfocus both fields when tapping outside
        if (_titleFocusNode.hasFocus) {
          _titleFocusNode.unfocus();
        }
        if (_addItemFocusNode.hasFocus) {
          _addItemFocusNode.unfocus();
          setState(() {
            _isAddingItem = false;
            _addItemController.clear();
          });
        }
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section header
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ReorderableDragStartListener(
                  index: widget.index,
                  child: Padding(
                    padding: const EdgeInsets.all(0),
                    child: Icon(
                      Icons.drag_indicator,
                      size: 20,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: _isEditingTitle
                      ? Focus(
                          onKey: (node, event) {
                            if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
                              _submitTitle();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            onSubmitted: (_) => _submitTitle(),
                          ),
                        )
                      : GestureDetector(
                          onDoubleTap: _startEditingTitle,
                          child: Text(
                            _displayedTitle,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.0,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                ),
                // Progress indicator
                if (totalItems > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: completedItems == totalItems
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : colorScheme.outline.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$completedItems/$totalItems',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: completedItems == totalItems
                            ? AppColors.primary
                            : Colors.grey.shade600,
                      ),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert,
                    size: 22,
                    color: Colors.grey.shade600,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      widget.onDelete();
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Delete', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Items and add button
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Items
              ...items.map((item) {
                final itemData = item as Map<String, dynamic>;
                final itemId = itemData['_id'] as String;
                final text = itemData['text'] as String;
                final completed = itemData['completed'] as bool? ?? false;

                return _ChecklistItemWidget(
                  key: ValueKey(itemId),
                  itemId: itemId,
                  text: text,
                  completed: completed,
                  onToggle: () => widget.onToggleItem(itemId, completed),
                  onEditItem: (id, newText) => widget.onEditItem(id, newText),
                  onDelete: () => widget.onDeleteItem(itemId),
                );
              }),
              // Inline add item
              if (_isAddingItem)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.radio_button_unchecked,
                        size: 22,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Focus(
                          onKey: (node, event) {
                            if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
                              _addItemFocusNode.unfocus();
                              setState(() => _isAddingItem = false);
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _addItemController,
                            focusNode: _addItemFocusNode,
                            decoration: InputDecoration(
                              hintText: 'Add item...',
                              hintStyle: TextStyle(color: Colors.grey.shade500),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 0,
                              ),
                            ),
                            style: const TextStyle(fontSize: 15, height: 1.0),
                            maxLines: 1,
                            onSubmitted: (_) => _submitItem(),
                            onEditingComplete: _submitItem,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: _submitItem,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 8, right: 12),
                          child: Icon(
                            Icons.check,
                            size: 20,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 8,
                  ),
                  child: GestureDetector(
                    onTap: _startAddingItem,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Icon(Icons.add, size: 22, color: Colors.grey.shade500),
                        const SizedBox(width: 12),
                        Text(
                          'Add item...',
                          style: TextStyle(
                            fontSize: 15,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              // Divider between sections
              Divider(
                height: 1,
                color: colorScheme.outline.withValues(alpha: 0.15),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChecklistItemWidget extends StatefulWidget {
  final String itemId;
  final String text;
  final bool completed;
  final VoidCallback onToggle;
  final Function(String itemId, String newText) onEditItem;
  final VoidCallback onDelete;

  const _ChecklistItemWidget({
    super.key,
    required this.itemId,
    required this.text,
    required this.completed,
    required this.onToggle,
    required this.onEditItem,
    required this.onDelete,
  });

  @override
  State<_ChecklistItemWidget> createState() => _ChecklistItemWidgetState();
}

class _ChecklistItemWidgetState extends State<_ChecklistItemWidget> {
  late TextEditingController _editController;
  late FocusNode _editFocusNode;
  bool _isEditing = false;
  late String _displayedText;

  @override
  void initState() {
    super.initState();
    _displayedText = widget.text;
    _editController = TextEditingController(text: widget.text);
    _editFocusNode = FocusNode();
    _editFocusNode.addListener(_onEditFocusChange);
  }

  @override
  void dispose() {
    _editController.dispose();
    _editFocusNode.removeListener(_onEditFocusChange);
    _editFocusNode.dispose();
    super.dispose();
  }

  void _onEditFocusChange() {
    if (!_editFocusNode.hasFocus && _isEditing) {
      _submitEdit();
    }
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
      _editController.text = widget.text;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _editFocusNode.requestFocus();
      _editController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _editController.text.length,
      );
    });
  }

  void _submitEdit() {
    final newText = _editController.text.trim();
    setState(() {
      _isEditing = false;
      if (newText.isNotEmpty && newText != _displayedText) {
        _displayedText = newText; // Update displayed text immediately
      }
    });
    if (newText.isNotEmpty && newText != widget.text) {
      // Optimistic update - UI already updated via setState above
      widget.onEditItem(widget.itemId, newText); // Send to backend
    }
  }

  @override
  Widget build(BuildContext context) {
    return TapRegion(
      onTapOutside: (event) {
        // Unfocus edit field when tapping outside
        if (_editFocusNode.hasFocus) {
          _editFocusNode.unfocus();
        }
      },
      child: Dismissible(
        key: Key(widget.itemId),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          color: Colors.red.shade100,
          child: Icon(Icons.delete, color: Colors.red.shade700),
        ),
        onDismissed: (_) => widget.onDelete(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: _isEditing ? null : widget.onToggle,
                child: Icon(
                  widget.completed
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 22,
                  color: widget.completed
                      ? AppColors.primary
                      : Colors.grey.shade400,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  onDoubleTap: _startEditing,
                  child: _isEditing
                      ? Focus(
                          onKey: (node, event) {
                            if (event.isKeyPressed(LogicalKeyboardKey.escape)) {
                              _submitEdit();
                              return KeyEventResult.handled;
                            }
                            return KeyEventResult.ignored;
                          },
                          child: TextField(
                            controller: _editController,
                            focusNode: _editFocusNode,
                            decoration: const InputDecoration(
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.0,
                              decoration: widget.completed
                                  ? TextDecoration.lineThrough
                                  : null,
                              color: widget.completed
                                  ? Colors.grey.shade500
                                  : null,
                            ),
                            maxLines: 1,
                            onSubmitted: (_) => _submitEdit(),
                          ),
                        )
                      : Text(
                          _displayedText,
                          style: TextStyle(
                            fontSize: 15,
                            height: 1.0,
                            decoration: widget.completed
                                ? TextDecoration.lineThrough
                                : null,
                            color: widget.completed
                                ? Colors.grey.shade500
                                : null,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
