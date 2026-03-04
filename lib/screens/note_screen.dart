import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../models/note.dart';
import '../services/note_service.dart';

// ─── Color palette ────────────────────────────────────────────────────────────

class NoteColors {
  static const List<Color> palette = [
    Color(0xFF6366F1),
    Color(0xFF8B5CF6),
    Color(0xFF06B6D4),
    Color(0xFF10B981),
    Color(0xFFF59E0B),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
    Color(0xFFF97316),
    Color(0xFF14B8A6),
    Color(0xFF84CC16),
    Color(0xFF6B7280),
    Color(0xFFD946EF),
  ];

  static Color fromHex(String? hex) {
    if (hex == null || hex.isEmpty) return palette[0];
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return palette[0];
    }
  }

  static String toHex(Color color) {
    final hex = color.value.toRadixString(16).padLeft(8, '0');
    return '#${hex.substring(2).toUpperCase()}';
  }
}

// ─── NoteScreen ───────────────────────────────────────────────────────────────

class NoteScreen extends StatefulWidget {
  final Note? note;
  const NoteScreen({Key? key, this.note}) : super(key: key);

  @override
  State<NoteScreen> createState() => _NoteScreenState();
}

class _NoteScreenState extends State<NoteScreen>
    with SingleTickerProviderStateMixin {
  final NoteService _noteService = NoteService();

  late QuillController _controller;
  late TextEditingController _titleController;
  late TabController _tabController;
  final FocusNode _editorFocusNode = FocusNode();
  final ScrollController _editorScrollController = ScrollController();

  late Color _selectedColor;

  Timer? _autoSaveTimer;
  bool _hasUnsavedChanges = false;
  DateTime? _lastSaved;

  late String _noteId;
  late DateTime _createdAt;

  @override
  void initState() {
    super.initState();

    // Pre-generate a local Firestore ID immediately (no network needed).
    // This ensures _noteId is set before the first save fires, so concurrent
    // auto-saves all call updateNote (upsert) instead of addNote → no duplicates.
    if (widget.note != null && widget.note!.id.isNotEmpty) {
      _noteId = widget.note!.id;
    } else {
      final user = FirebaseAuth.instance.currentUser;
      _noteId = user != null
          ? FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('notes')
              .doc()
              .id
          : '';
    }
    _createdAt = widget.note?.createdAt ?? DateTime.now();
    _titleController =
        TextEditingController(text: widget.note?.title ?? '');
    _selectedColor = NoteColors.fromHex(widget.note?.color);
    _controller = _buildController(widget.note?.content);
    _tabController = TabController(length: 2, vsync: this);

    _controller.addListener(_onContentChanged);
    _titleController.addListener(_onContentChanged);
    _tabController.addListener(() => setState(() {}));
  }

  QuillController _buildController(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return QuillController.basic();
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return QuillController(
        document: Document.fromJson(list),
        selection: const TextSelection.collapsed(offset: 0),
      );
    } catch (_) {
      final doc = Document();
      doc.insert(0, raw);
      return QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
    }
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_hasUnsavedChanges) {
      // Fire-and-forget — no await in dispose
      _saveToFirestore(
        title: _titleController.text.trim(),
        content: jsonEncode(_controller.document.toDelta().toJson()),
        colorHex: NoteColors.toHex(_selectedColor),
        now: DateTime.now(),
      );
    }
    _controller.removeListener(_onContentChanged);
    _titleController.removeListener(_onContentChanged);
    _controller.dispose();
    _titleController.dispose();
    _tabController.dispose();
    _editorFocusNode.dispose();
    _editorScrollController.dispose();
    super.dispose();
  }

  // ─── Auto-save ────────────────────────────────────────────────────────────

  void _onContentChanged() {
    if (!mounted) return;
    setState(() => _hasUnsavedChanges = true);
    _autoSaveTimer?.cancel();
    _autoSaveTimer =
        Timer(const Duration(milliseconds: 1500), _performSave);
  }

  /// Save color immediately without debounce
  void _saveColorNow(Color color) {
    _autoSaveTimer?.cancel();
    final title = _titleController.text.trim();
    final plain = _controller.document.toPlainText().trim();
    if (title.isEmpty && plain.isEmpty) return;

    final now = DateTime.now();

    // ✅ Update UI immediately — don't wait for server
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _lastSaved = now;
      });
    }

    // Fire-and-forget — Firestore cache handles it instantly offline
    _saveToFirestore(
      title: title,
      content: jsonEncode(_controller.document.toDelta().toJson()),
      colorHex: NoteColors.toHex(color),
      now: now,
    );
  }

  void _performSave() {
    final title = _titleController.text.trim();
    final plain = _controller.document.toPlainText().trim();
    if (title.isEmpty && plain.isEmpty) return;

    final now = DateTime.now();

    // ✅ Update UI immediately — don't wait for server response
    // Firestore offline persistence writes to cache instantly,
    // then syncs to server when back online automatically.
    if (mounted) {
      setState(() {
        _hasUnsavedChanges = false;
        _lastSaved = now;
      });
    }

    // Fire-and-forget — never blocks the UI
    _saveToFirestore(
      title: title,
      content: jsonEncode(_controller.document.toDelta().toJson()),
      colorHex: NoteColors.toHex(_selectedColor),
      now: now,
    );
  }

  /// Core Firestore write — always fire-and-forget, never awaited by UI
  Future<void> _saveToFirestore({
    required String title,
    required String content,
    required String colorHex,
    required DateTime now,
  }) async {
    if (_noteId.isEmpty) return; // no user signed in
    try {
      // Always use updateNote/set — _noteId is pre-generated in initState
      // so this is safe even on the very first save, online or offline.
      await _noteService.saveNote(Note(
        id: _noteId,
        title: title,
        content: content,
        createdAt: _createdAt,
        updatedAt: now,
        color: colorHex,
      ));
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  // ─── Delete ───────────────────────────────────────────────────────────────

  Future<void> _deleteNote() async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF666688);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor:
            isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: Text('Delete Note',
            style: TextStyle(
                color: isDark ? AppTheme.darkText : AppTheme.lightText,
                fontWeight: FontWeight.w700)),
        content: Text('This note will be permanently deleted.',
            style: TextStyle(color: sub)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: sub))),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w600))),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      _autoSaveTimer?.cancel();
      if (_noteId.isNotEmpty) {
        await _noteService.deleteNote(_noteId);
      }
      if (mounted) Navigator.pop(context);
    }
  }

  // ─── Color picker ─────────────────────────────────────────────────────────

  void _showColorPicker() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final surface = isDark ? AppTheme.darkCard : AppTheme.lightSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: surface,
      shape: const RoundedRectangleBorder(
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: borderColor,
                      borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text('Note Color',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: NoteColors.palette.map((color) {
                  final selected =
                      _selectedColor.value == color.value;
                  return GestureDetector(
                    onTap: () {
                      // ✅ Update UI immediately
                      setState(() => _selectedColor = color);
                      setModal(() {});
                      // Fire-and-forget save
                      _saveColorNow(color);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: selected
                            ? Border.all(
                                color: isDark
                                    ? Colors.white
                                    : Colors.black,
                                width: 3)
                            : null,
                        boxShadow: selected
                            ? [
                                BoxShadow(
                                    color: color.withOpacity(0.5),
                                    blurRadius: 8,
                                    spreadRadius: 2)
                              ]
                            : null,
                      ),
                      child: selected
                          ? const Icon(Icons.check_rounded,
                              color: Colors.white, size: 22)
                          : null,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────

  String get _plainText =>
      _controller.document.toPlainText().trim();

  int get _wordCount =>
      _plainText.isEmpty ? 0 : _plainText.split(RegExp(r'\s+')).length;

  String _formatSaveTime(DateTime dt) =>
      'Saved ${DateFormat('h:mm a').format(dt.toLocal())}';

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = _selectedColor;

    final baseBg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final baseSurface =
        isDark ? AppTheme.darkCard : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final sub =
        isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);
    final border =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    final bg = Color.alphaBlend(
        accent.withOpacity(isDark ? 0.10 : 0.05), baseBg);
    final surface = Color.alphaBlend(
        accent.withOpacity(isDark ? 0.12 : 0.07), baseSurface);

    return WillPopScope(
      onWillPop: () async {
        _autoSaveTimer?.cancel();
        if (_hasUnsavedChanges) _performSave();
        return true;
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded,
                color: textColor, size: 20),
            onPressed: () {
              _autoSaveTimer?.cancel();
              if (_hasUnsavedChanges) _performSave();
              if (mounted) Navigator.pop(context);
            },
          ),
          centerTitle: true,
          title: _lastSaved != null
              ? Text(_formatSaveTime(_lastSaved!),
                  style: TextStyle(color: sub, fontSize: 13))
              : Text(
                  _noteId.isNotEmpty ? 'Edit Note' : 'New Note',
                  style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
          actions: [
            if (_noteId.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    color: Colors.redAccent, size: 22),
                onPressed: _deleteNote,
              ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(children: [
              Divider(color: border, height: 1),
              TabBar(
                controller: _tabController,
                labelColor: accent,
                unselectedLabelColor: sub,
                indicatorColor: accent,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: 2.5,
                labelStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(text: 'Write'),
                  Tab(text: 'Preview'),
                ],
              ),
            ]),
          ),
        ),

        floatingActionButton: Padding(
          padding: EdgeInsets.only(
              bottom: _tabController.index == 0 ? 108 : 0),
          child: FloatingActionButton.small(
            onPressed: _showColorPicker,
            backgroundColor: accent,
            elevation: 4,
            child: const Icon(Icons.palette_rounded,
                color: Colors.white, size: 20),
          ),
        ),
        floatingActionButtonLocation:
            FloatingActionButtonLocation.endFloat,

        body: Column(
          children: [
            Container(height: 3, color: accent),

            // Title
            Container(
              color: bg,
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
              child: TextField(
                controller: _titleController,
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5),
                decoration: InputDecoration(
                  hintText: 'Title',
                  hintStyle: TextStyle(
                      color: sub,
                      fontSize: 22,
                      fontWeight: FontWeight.w700),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  filled: false,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
            Divider(color: border, height: 1),

            // Editor / Preview
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  // ── Write ──
                  Container(
                    color: bg,
                    child: QuillEditor(
                      controller: _controller,
                      focusNode: _editorFocusNode,
                      scrollController: _editorScrollController,
                      config: QuillEditorConfig(
                        placeholder: 'Start writing…',
                        padding: const EdgeInsets.fromLTRB(
                            20, 12, 20, 20),
                        scrollable: true,
                        autoFocus: false,
                        expands: false,
                      ),
                    ),
                  ),

                  // ── Preview ──
                  _plainText.isEmpty
                      ? Container(
                          color: bg,
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.article_outlined,
                                    color: sub, size: 48),
                                const SizedBox(height: 12),
                                Text('Nothing to preview yet',
                                    style: TextStyle(
                                        color: sub, fontSize: 15)),
                              ],
                            ),
                          ),
                        )
                      : Container(
                          color: bg,
                          child: QuillEditor(
                            controller: QuillController(
                              document: _controller.document,
                              selection:
                                  const TextSelection.collapsed(
                                      offset: 0),
                              readOnly: true,
                            ),
                            focusNode:
                                FocusNode(canRequestFocus: false),
                            scrollController: ScrollController(),
                            config: const QuillEditorConfig(
                              padding: EdgeInsets.all(20),
                              scrollable: true,
                              autoFocus: false,
                              expands: false,
                              showCursor: false,
                            ),
                          ),
                        ),
                ],
              ),
            ),

            // Toolbar (Write tab only)
            if (_tabController.index == 0)
              _buildToolbar(surface, border, accent),

            // Status bar
            Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(
                color: surface,
                border: Border(top: BorderSide(color: border)),
              ),
              child: Row(
                children: [
                  Icon(Icons.text_fields_rounded,
                      size: 13, color: sub),
                  const SizedBox(width: 6),
                  Text(
                    '$_wordCount words · ${_plainText.length} chars',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                  const Spacer(),
                  if (_hasUnsavedChanges)
                    Container(
                      width: 7,
                      height: 7,
                      margin: const EdgeInsets.only(right: 6),
                      decoration: BoxDecoration(
                          color: accent, shape: BoxShape.circle),
                    ),
                  Text(
                    _lastSaved != null
                        ? _formatSaveTime(_lastSaved!)
                        : _hasUnsavedChanges
                            ? 'Unsaved'
                            : '',
                    style: TextStyle(color: sub, fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Toolbar ──────────────────────────────────────────────────────────────

  Widget _buildToolbar(Color surface, Color border, Color accent) {
    return Container(
      decoration: BoxDecoration(
        color: surface,
        border: Border(top: BorderSide(color: border)),
      ),
      child: QuillSimpleToolbar(
        controller: _controller,
        config: QuillSimpleToolbarConfig(
          multiRowsDisplay: false,
          showDividers: true,
          showFontFamily: false,
          showFontSize: false,
          showBoldButton: true,
          showItalicButton: true,
          showUnderLineButton: true,
          showStrikeThrough: true,
          showInlineCode: true,
          showColorButton: true,
          showBackgroundColorButton: false,
          showClearFormat: true,
          showAlignmentButtons: false,
          showLeftAlignment: false,
          showCenterAlignment: false,
          showRightAlignment: false,
          showJustifyAlignment: false,
          showHeaderStyle: true,
          showListNumbers: true,
          showListBullets: true,
          showListCheck: true,
          showCodeBlock: true,
          showQuote: true,
          showIndent: false,
          showLink: true,
          showUndo: true,
          showRedo: true,
          showDirection: false,
          showSearchButton: false,
          showSubscript: false,
          showSuperscript: false,
          buttonOptions: QuillSimpleToolbarButtonOptions(
            base: QuillToolbarBaseButtonOptions(
              afterButtonPressed: () =>
                  _editorFocusNode.requestFocus(),
            ),
          ),
        ),
      ),
    );
  }
}