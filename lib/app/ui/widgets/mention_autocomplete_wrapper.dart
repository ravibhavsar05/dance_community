import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:dance_pulse/app/controllers/auth_controller.dart';
import 'package:dance_pulse/app/data/models/dance_models.dart';
import 'package:dance_pulse/app/data/services/supabase_store.dart';
import 'package:dance_pulse/app/ui/theme/app_theme.dart';

class MentionAutocompleteWrapper extends StatefulWidget {
  final TextEditingController controller;
  final Widget child;
  final bool showAbove;

  const MentionAutocompleteWrapper({
    super.key,
    required this.controller,
    required this.child,
    this.showAbove = false,
  });

  @override
  State<MentionAutocompleteWrapper> createState() => _MentionAutocompleteWrapperState();
}

class _MentionAutocompleteWrapperState extends State<MentionAutocompleteWrapper> {
  List<DancerProfile> _suggestions = [];
  bool _isSearching = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    if (selection.start <= 0) {
      _clearSuggestions();
      return;
    }

    final textBeforeCursor = text.substring(0, selection.start);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final isAtStartOrAfterWhitespace = lastAt == 0 ||
          RegExp(r'\s').hasMatch(textBeforeCursor.substring(lastAt - 1, lastAt));

      if (isAtStartOrAfterWhitespace) {
        final queryText = textBeforeCursor.substring(lastAt + 1);
        // Mentions must be single words without spaces
        if (!queryText.contains(' ')) {
          _debounceSearch(queryText);
          return;
        }
      }
    }

    _clearSuggestions();
  }

  void _debounceSearch(String query) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      setState(() {
        _isSearching = true;
      });

      try {
        final results = await SupabaseStore.instance.searchUsers(query);
        final currentUser = Get.find<AuthController>().currentUserProfile;
        
        // Exclude current logged-in user from mention suggestions
        final filtered = results.where((user) => user.uid != currentUser?.uid).toList();

        if (mounted) {
          setState(() {
            _suggestions = filtered;
            _isSearching = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    });
  }

  void _clearSuggestions() {
    _debounceTimer?.cancel();
    if (_suggestions.isNotEmpty || _isSearching) {
      setState(() {
        _suggestions = [];
        _isSearching = false;
      });
    }
  }

  void _insertMention(DancerProfile user) {
    final text = widget.controller.text;
    final selection = widget.controller.selection;
    final textBeforeCursor = text.substring(0, selection.start);
    final lastAt = textBeforeCursor.lastIndexOf('@');

    if (lastAt != -1) {
      final newText = text.replaceRange(lastAt, selection.start, '@${user.username} ');
      widget.controller.text = newText;
      
      // Position cursor after the mention
      final newCursorPos = lastAt + user.username.length + 2; // @ + username + space
      widget.controller.selection = TextSelection.fromPosition(
        TextPosition(offset: newCursorPos),
      );
    }

    _clearSuggestions();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final suggestionsWidget = _suggestions.isEmpty && !_isSearching
        ? const SizedBox.shrink()
        : Container(
            constraints: const BoxConstraints(maxHeight: 180),
            margin: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkCardBg : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? AppTheme.darkBorder : Colors.grey[300]!, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: _isSearching
                ? const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary),
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.zero,
                    itemCount: _suggestions.length,
                    itemBuilder: (context, index) {
                      final dancer = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundImage: NetworkImage(
                            dancer.avatarUrl,
                            headers: SupabaseStore.getHeadersForUrl(dancer.avatarUrl),
                          ),
                        ),
                        title: Text(
                          dancer.displayName,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                        subtitle: Text(
                          "@${dancer.username}",
                          style: const TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                        ),
                        onTap: () => _insertMention(dancer),
                      );
                    },
                  ),
          );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.showAbove) suggestionsWidget,
        widget.child,
        if (!widget.showAbove) suggestionsWidget,
      ],
    );
  }
}
