import 'dart:async';
import 'package:flutter/material.dart';
import '../app_theme.dart';

class CustomSearchBar extends StatefulWidget {
  final Function(String) onSearch;
  const CustomSearchBar({super.key, required this.onSearch});

  @override
  _CustomSearchBarState createState() => _CustomSearchBarState();
}

class _CustomSearchBarState extends State<CustomSearchBar> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      widget.onSearch(_searchController.text.trim());
      setState(() {});
    });
  }

  void _clearSearch() {
    _searchController.clear();
    widget.onSearch('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        focusNode: _focusNode,
        style: TextStyle(
            color: isDark ? AppTheme.darkText : AppTheme.lightText,
            fontSize: 15),
        decoration: InputDecoration(
          hintText: 'Search notes...',
          prefixIcon: Icon(Icons.search_rounded,
              color: isDark ? AppTheme.darkSubtext : const Color(0xFF9999AA),
              size: 20),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.close_rounded,
                      color: isDark
                          ? AppTheme.darkSubtext
                          : const Color(0xFF9999AA),
                      size: 18),
                  onPressed: _clearSearch,
                )
              : null,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
        onSubmitted: (value) {
          FocusScope.of(context).unfocus();
          widget.onSearch(value);
        },
      ),
    );
  }
}