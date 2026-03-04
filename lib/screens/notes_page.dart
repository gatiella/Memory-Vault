import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../app_theme.dart';
import '../customs/search_bar.dart';
import '../models/note.dart';
import '../screens/note_screen.dart';
import '../services/note_service.dart';

// ─── Helpers (shared with NoteScreen) ────────────────────────────────────────

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

// ─── Sort options ─────────────────────────────────────────────────────────────

enum _SortBy { updatedAt, createdAt, title }

// ─── NotesPage ────────────────────────────────────────────────────────────────

class NotesPage extends StatefulWidget {
  const NotesPage({super.key});

  @override
  State<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends State<NotesPage>
    with SingleTickerProviderStateMixin {
  final NoteService _noteService = NoteService();

  String _searchQuery = '';
  bool _isGrid = false;
  _SortBy _sortBy = _SortBy.updatedAt;

  // Pinned note IDs (in-memory; persist via shared_preferences if desired)
  final Set<String> _pinned = {};

  // Selection mode
  bool _selecting = false;
  final Set<String> _selected = {};

  late AnimationController _fabAnim;

  @override
  void initState() {
    super.initState();
    _fabAnim = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _fabAnim.forward();
  }

  @override
  void dispose() {
    _fabAnim.dispose();
    super.dispose();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  void _onSearchQueryChange(String q) =>
      setState(() => _searchQuery = q.toLowerCase());

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(date);
  }

  String _plainText(String content) {
    if (content.isEmpty) return '';
    try {
      final list = jsonDecode(content) as List<dynamic>;
      return list
          .map((op) {
            final insert = (op as Map<String, dynamic>)['insert'];
            return insert is String ? insert : '';
          })
          .join('')
          .trim();
    } catch (_) {
      return content.trim();
    }
  }

  Color _accentFor(Note note, int index) =>
      NoteColors.fromHex(note.color);

  List<Note> _sort(List<Note> notes) {
    final pinned = notes.where((n) => _pinned.contains(n.id)).toList();
    final rest = notes.where((n) => !_pinned.contains(n.id)).toList();
    int cmp(Note a, Note b) {
      switch (_sortBy) {
        case _SortBy.title:
          return a.title.toLowerCase().compareTo(b.title.toLowerCase());
        case _SortBy.createdAt:
          return b.createdAt.compareTo(a.createdAt);
        case _SortBy.updatedAt:
        return b.updatedAt.compareTo(a.updatedAt);
      }
    }

    pinned.sort(cmp);
    rest.sort(cmp);
    return [...pinned, ...rest];
  }

  // ── Selection helpers ─────────────────────────────────────────────────────

  void _enterSelect(String id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(id);
    });
  }

  void _toggleSelect(String id) {
    setState(() {
      if (_selected.contains(id)) {
        _selected.remove(id);
        if (_selected.isEmpty) _selecting = false;
      } else {
        _selected.add(id);
      }
    });
  }

  void _cancelSelect() => setState(() {
        _selecting = false;
        _selected.clear();
      });

  Future<void> _deleteSelected(List<Note> allNotes) async {
    final ids = List<String>.from(_selected);
    final count = ids.length;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => _ConfirmDialog(
        isDark: isDark,
        title: 'Delete $count note${count > 1 ? 's' : ''}?',
        body: 'This cannot be undone.',
      ),
    );
    if (confirm != true) return;

    for (final id in ids) {
      await _noteService.deleteNote(id);
    }
    _cancelSelect();
  }

  // ── Long-press context menu ───────────────────────────────────────────────

  void _showContextMenu(
      BuildContext context, Note note, Color accent, bool isDark) {
    HapticFeedback.mediumImpact();
    final isPinned = _pinned.contains(note.id);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ContextSheet(
        note: note,
        accent: accent,
        isDark: isDark,
        isPinned: isPinned,
        onOpen: () {
          Navigator.pop(context);
          Navigator.push(context,
              MaterialPageRoute(builder: (_) => NoteScreen(note: note)));
        },
        onPin: () {
          Navigator.pop(context);
          setState(() {
            if (isPinned) {
              _pinned.remove(note.id);
            } else {
              _pinned.add(note.id);
            }
          });
        },
        onCopy: () {
          Navigator.pop(context);
          Clipboard.setData(
              ClipboardData(text: _plainText(note.content)));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Copied to clipboard'),
              behavior: SnackBarBehavior.floating,
              backgroundColor: accent,
              duration: const Duration(seconds: 2),
            ),
          );
        },
        onSelect: () {
          Navigator.pop(context);
          _enterSelect(note.id);
        },
        onDelete: () async {
          Navigator.pop(context);
          final confirm = await showDialog<bool>(
            context: context,
            builder: (_) => _ConfirmDialog(
              isDark: isDark,
              title: 'Delete note?',
              body: 'This cannot be undone.',
            ),
          );
          if (confirm == true) {
            await _noteService.deleteNote(note.id);
          }
        },
      ),
    );
  }

  // ── Sort sheet ────────────────────────────────────────────────────────────

  void _showSortSheet(bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
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
                        color: isDark
                            ? AppTheme.darkBorder
                            : AppTheme.lightBorder,
                        borderRadius: BorderRadius.circular(2))),
              ),
              const SizedBox(height: 16),
              Text('Sort by',
                  style: TextStyle(
                      color:
                          isDark ? AppTheme.darkText : AppTheme.lightText,
                      fontSize: 17,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              ...[
                (_SortBy.updatedAt, 'Last modified', Icons.edit_rounded),
                (_SortBy.createdAt, 'Date created',
                    Icons.calendar_today_rounded),
                (_SortBy.title, 'Title A→Z', Icons.sort_by_alpha_rounded),
              ].map((e) {
                final (sort, label, icon) = e;
                final selected = _sortBy == sort;
                return ListTile(
                  leading: Icon(icon,
                      color: selected
                          ? AppTheme.indigo
                          : (isDark
                              ? AppTheme.darkSubtext
                              : const Color(0xFF9999AA))),
                  title: Text(label,
                      style: TextStyle(
                          color: selected
                              ? AppTheme.indigo
                              : (isDark
                                  ? AppTheme.darkText
                                  : AppTheme.lightText),
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400)),
                  trailing: selected
                      ? const Icon(Icons.check_rounded,
                          color: AppTheme.indigo)
                      : null,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    setState(() => _sortBy = sort);
                    setS(() {});
                    Future.delayed(
                        const Duration(milliseconds: 200),
                        () => Navigator.pop(ctx));
                  },
                );
              }),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? AppTheme.darkBg : AppTheme.lightBg;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);
    final borderColor =
        isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Scaffold(
      backgroundColor: bg,
      body: Column(
        children: [
          // ── Search + toolbar row ──────────────────────────────────────
          if (!_selecting)
            Column(
              children: [
                CustomSearchBar(onSearch: _onSearchQueryChange),
                Padding(
                  padding:
                      const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      // Sort button
                      _ToolbarChip(
                        icon: Icons.sort_rounded,
                        label: _sortBy == _SortBy.updatedAt
                            ? 'Modified'
                            : _sortBy == _SortBy.createdAt
                                ? 'Created'
                                : 'Title',
                        isDark: isDark,
                        onTap: () => _showSortSheet(isDark),
                      ),
                      const Spacer(),
                      // Grid/List toggle
                      _IconToggle(
                        icon: _isGrid
                            ? Icons.view_list_rounded
                            : Icons.grid_view_rounded,
                        isDark: isDark,
                        onTap: () => setState(() => _isGrid = !_isGrid),
                        tooltip:
                            _isGrid ? 'List view' : 'Grid view',
                      ),
                    ],
                  ),
                ),
              ],
            ),

          // ── Selection bar ─────────────────────────────────────────────
          if (_selecting)
            _SelectionBar(
              count: _selected.length,
              isDark: isDark,
              textColor: textColor,
              borderColor: borderColor,
              onCancel: _cancelSelect,
              onDelete: () async {
                final snapshot =
                    await _noteService.getAllNotes();
                await _deleteSelected(snapshot);
              },
            ),

          // ── Notes list/grid ───────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<Note>>(
              stream: _noteService.getNotes(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error: ${snapshot.error}',
                          style: TextStyle(color: sub)));
                }
                if (snapshot.connectionState ==
                        ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(
                      child: CircularProgressIndicator(
                          color: AppTheme.indigo));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _emptyState(isDark, sub);
                }

                final filtered = snapshot.data!.where((note) {
                  final plain = _plainText(note.content);
                  return note.title
                          .toLowerCase()
                          .contains(_searchQuery) ||
                      plain.toLowerCase().contains(_searchQuery);
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            color: sub, size: 48),
                        const SizedBox(height: 12),
                        Text('No matching notes',
                            style: TextStyle(
                                color: sub, fontSize: 16)),
                      ],
                    ),
                  );
                }

                final sorted = _sort(filtered);

                if (_isGrid) {
                  // Two-column masonry: cards shrink to their content height
                  final left = <Widget>[];
                  final right = <Widget>[];
                  for (var i = 0; i < sorted.length; i++) {
                    final card = Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildCard(
                        note: sorted[i],
                        index: i,
                        isDark: isDark,
                        textColor: textColor,
                        sub: sub,
                        isGrid: true,
                      ),
                    );
                    if (i.isEven) {
                      left.add(card);
                    } else {
                      right.add(card);
                    }
                  }
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Column(children: left)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(children: right)),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding:
                      const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  itemCount: sorted.length,
                  itemBuilder: (ctx, i) => _buildCard(
                    note: sorted[i],
                    index: i,
                    isDark: isDark,
                    textColor: textColor,
                    sub: sub,
                    isGrid: false,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _selecting
          ? null
          : ScaleTransition(
              scale: CurvedAnimation(
                  parent: _fabAnim, curve: Curves.elasticOut),
              child: FloatingActionButton(
                heroTag: 'notesFAB',
                onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const NoteScreen())),
                backgroundColor: AppTheme.indigo,
                child: const Icon(Icons.add_rounded,
                    color: Colors.white, size: 28),
              ),
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  // ─── Card builder ─────────────────────────────────────────────────────────

  Widget _buildCard({
    required Note note,
    required int index,
    required bool isDark,
    required Color textColor,
    required Color sub,
    required bool isGrid,
  }) {
    final accent = _accentFor(note, index);
    final card = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;
    final cardBg = Color.alphaBlend(
        accent.withOpacity(isDark ? 0.13 : 0.07), card);
    final borderColor =
        Color.alphaBlend(accent.withOpacity(0.35), border);
    final preview = _plainText(note.content);
    final isPinned = _pinned.contains(note.id);
    final isSelected = _selected.contains(note.id);

    return isGrid
        ? _GridCard(
            note: note,
            accent: accent,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            sub: sub,
            isDark: isDark,
            preview: preview,
            isPinned: isPinned,
            isSelected: isSelected,
            isSelecting: _selecting,
            formatDate: _formatDate,
            onTap: () {
              if (_selecting) {
                _toggleSelect(note.id);
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NoteScreen(note: note)));
              }
            },
            onLongPress: () => _selecting
                ? _toggleSelect(note.id)
                : _showContextMenu(context, note, accent, isDark),
          )
        : _ListCard(
            note: note,
            accent: accent,
            cardBg: cardBg,
            borderColor: borderColor,
            textColor: textColor,
            sub: sub,
            isDark: isDark,
            preview: preview,
            isPinned: isPinned,
            isSelected: isSelected,
            isSelecting: _selecting,
            formatDate: _formatDate,
            onTap: () {
              if (_selecting) {
                _toggleSelect(note.id);
              } else {
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => NoteScreen(note: note)));
              }
            },
            onLongPress: () => _selecting
                ? _toggleSelect(note.id)
                : _showContextMenu(context, note, accent, isDark),
          );
  }

  // ─── Empty state ──────────────────────────────────────────────────────────

  Widget _emptyState(bool isDark, Color sub) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.indigo.withOpacity(0.1),
            ),
            child: const Icon(Icons.sticky_note_2_outlined,
                color: AppTheme.indigo, size: 40),
          ),
          const SizedBox(height: 20),
          Text('No notes yet',
              style: TextStyle(
                  color: isDark ? AppTheme.darkText : AppTheme.lightText,
                  fontSize: 20,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Tap + to create your first note',
              style: TextStyle(color: sub, fontSize: 15)),
        ],
      ),
    );
  }
}

// ─── List Card ────────────────────────────────────────────────────────────────

class _ListCard extends StatelessWidget {
  final Note note;
  final Color accent, cardBg, borderColor, textColor, sub;
  final bool isDark, isPinned, isSelected, isSelecting;
  final String preview;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap, onLongPress;

  const _ListCard({
    required this.note,
    required this.accent,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.sub,
    required this.isDark,
    required this.preview,
    required this.isPinned,
    required this.isSelected,
    required this.isSelecting,
    required this.formatDate,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected
              ? Color.alphaBlend(accent.withOpacity(0.25), cardBg)
              : cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? accent : borderColor,
            width: isSelected ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: accent.withOpacity(isDark ? 0.08 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            borderRadius: BorderRadius.circular(16),
            splashColor: accent.withOpacity(0.15),
            highlightColor: accent.withOpacity(0.08),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Accent bar
                  Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                      ),
                    ),
                  ),
                  // Content
                  Expanded(
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(14, 13, 14, 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (isPinned)
                                Padding(
                                  padding:
                                      const EdgeInsets.only(right: 6),
                                  child: Icon(Icons.push_pin_rounded,
                                      size: 13, color: accent),
                                ),
                              Expanded(
                                child: Text(
                                  note.title.isNotEmpty
                                      ? note.title
                                      : 'Untitled',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -0.3,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatDate(note.updatedAt),
                                style:
                                    TextStyle(color: sub, fontSize: 11),
                              ),
                            ],
                          ),
                          if (preview.isNotEmpty) ...[
                            const SizedBox(height: 5),
                            Text(
                              preview,
                              style: TextStyle(
                                  color: sub,
                                  fontSize: 13,
                                  height: 1.45),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Color dot tag
                          Container(
                            width: 24,
                            height: 4,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // Trailing
                  Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: isSelecting
                        ? AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: isSelected
                                  ? accent
                                  : Colors.transparent,
                              border: Border.all(
                                  color: isSelected ? accent : sub,
                                  width: 2),
                            ),
                            child: isSelected
                                ? const Icon(Icons.check_rounded,
                                    color: Colors.white, size: 14)
                                : null,
                          )
                        : Icon(Icons.chevron_right_rounded,
                            color: sub, size: 18),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Grid Card ────────────────────────────────────────────────────────────────

class _GridCard extends StatelessWidget {
  final Note note;
  final Color accent, cardBg, borderColor, textColor, sub;
  final bool isDark, isPinned, isSelected, isSelecting;
  final String preview;
  final String Function(DateTime) formatDate;
  final VoidCallback onTap, onLongPress;

  const _GridCard({
    required this.note,
    required this.accent,
    required this.cardBg,
    required this.borderColor,
    required this.textColor,
    required this.sub,
    required this.isDark,
    required this.preview,
    required this.isPinned,
    required this.isSelected,
    required this.isSelecting,
    required this.formatDate,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: isSelected
            ? Color.alphaBlend(accent.withOpacity(0.25), cardBg)
            : cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? accent : borderColor,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withOpacity(isDark ? 0.1 : 0.08),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          splashColor: accent.withOpacity(0.15),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row: pin + select
                Row(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.sticky_note_2_rounded,
                          color: accent, size: 15),
                    ),
                    const Spacer(),
                    if (isPinned)
                      Icon(Icons.push_pin_rounded,
                          size: 13, color: accent),
                    if (isSelecting)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? accent
                              : Colors.transparent,
                          border: Border.all(
                              color: isSelected ? accent : sub,
                              width: 2),
                        ),
                        child: isSelected
                            ? const Icon(Icons.check_rounded,
                                color: Colors.white, size: 12)
                            : null,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                // Title
                Text(
                  note.title.isNotEmpty ? note.title : 'Untitled',
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (preview.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    preview,
                    style: TextStyle(
                        color: sub, fontSize: 12, height: 1.45),
                    maxLines: 6,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // Bottom: color bar + date
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 20,
                      height: 3,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      formatDate(note.updatedAt),
                      style: TextStyle(color: sub, fontSize: 10),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Selection bar ────────────────────────────────────────────────────────────

class _SelectionBar extends StatelessWidget {
  final int count;
  final bool isDark;
  final Color textColor, borderColor;
  final VoidCallback onCancel, onDelete;

  const _SelectionBar({
    required this.count,
    required this.isDark,
    required this.textColor,
    required this.borderColor,
    required this.onCancel,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
        border: Border(bottom: BorderSide(color: borderColor)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.close_rounded, color: textColor),
            onPressed: onCancel,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 12),
          Text(
            '$count selected',
            style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w600,
                fontSize: 16),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                color: Colors.redAccent),
            onPressed: count > 0 ? onDelete : null,
            tooltip: 'Delete selected',
          ),
        ],
      ),
    );
  }
}

// ─── Context sheet ────────────────────────────────────────────────────────────

class _ContextSheet extends StatelessWidget {
  final Note note;
  final Color accent;
  final bool isDark, isPinned;
  final VoidCallback onOpen, onPin, onCopy, onSelect, onDelete;

  const _ContextSheet({
    required this.note,
    required this.accent,
    required this.isDark,
    required this.isPinned,
    required this.onOpen,
    required this.onPin,
    required this.onCopy,
    required this.onSelect,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isDark ? AppTheme.darkCard : AppTheme.lightSurface;
    final textColor = isDark ? AppTheme.darkText : AppTheme.lightText;
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Note title header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 4),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.sticky_note_2_rounded,
                      color: accent, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isNotEmpty ? note.title : 'Untitled',
                        style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        DateFormat('MMM d, yyyy · h:mm a')
                            .format(note.updatedAt.toLocal()),
                        style: TextStyle(color: sub, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Divider(
              color: isDark ? AppTheme.darkBorder : AppTheme.lightBorder,
              height: 16),
          // Actions
          _SheetAction(
            icon: Icons.open_in_new_rounded,
            label: 'Open',
            color: textColor,
            onTap: onOpen,
          ),
          _SheetAction(
            icon: isPinned
                ? Icons.push_pin_outlined
                : Icons.push_pin_rounded,
            label: isPinned ? 'Unpin' : 'Pin to top',
            color: accent,
            onTap: onPin,
          ),
          _SheetAction(
            icon: Icons.copy_rounded,
            label: 'Copy text',
            color: textColor,
            onTap: onCopy,
          ),
          _SheetAction(
            icon: Icons.check_circle_outline_rounded,
            label: 'Select',
            color: textColor,
            onTap: onSelect,
          ),
          _SheetAction(
            icon: Icons.delete_outline_rounded,
            label: 'Delete',
            color: Colors.redAccent,
            onTap: onDelete,
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color, size: 22),
      title: Text(label,
          style: TextStyle(
              color: color,
              fontSize: 15,
              fontWeight: FontWeight.w500)),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );
  }
}

// ─── Toolbar widgets ──────────────────────────────────────────────────────────

class _ToolbarChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isDark;
  final VoidCallback onTap;

  const _ToolbarChip({
    required this.icon,
    required this.label,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);
    final bg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: sub),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(color: sub, fontSize: 12)),
            const SizedBox(width: 2),
            Icon(Icons.expand_more_rounded, size: 14, color: sub),
          ],
        ),
      ),
    );
  }
}

class _IconToggle extends StatelessWidget {
  final IconData icon;
  final bool isDark;
  final VoidCallback onTap;
  final String tooltip;

  const _IconToggle({
    required this.icon,
    required this.isDark,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA);
    final bg = isDark ? AppTheme.darkCard : AppTheme.lightCard;
    final border = isDark ? AppTheme.darkBorder : AppTheme.lightBorder;

    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: border),
          ),
          child: Icon(icon, size: 18, color: sub),
        ),
      ),
    );
  }
}

// ─── Confirm dialog ───────────────────────────────────────────────────────────

class _ConfirmDialog extends StatelessWidget {
  final bool isDark;
  final String title, body;

  const _ConfirmDialog(
      {required this.isDark, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    final sub = isDark ? AppTheme.darkSubtext : const Color(0xFF666688);

    return AlertDialog(
      backgroundColor: isDark ? AppTheme.darkCard : AppTheme.lightSurface,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(title,
          style: TextStyle(
              color: isDark ? AppTheme.darkText : AppTheme.lightText,
              fontWeight: FontWeight.w700)),
      content: Text(body, style: TextStyle(color: sub)),
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
    );
  }
}