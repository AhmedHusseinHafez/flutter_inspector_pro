import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:requests_inspector/src/inspector_controller.dart';

import 'inspector_theme.dart';

class SearchWidget extends StatefulWidget {
  final bool isDarkMode;

  const SearchWidget({super.key, required this.isDarkMode});

  @override
  State<SearchWidget> createState() => _SearchWidgetState();
}

class _SearchWidgetState extends State<SearchWidget> {
  late final TextEditingController _textController;
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();

      final controller = InspectorController();
      controller.addListener(_onControllerChanged);
    });
  }

  void _onFocusChanged() {
    if (_isFocused == _focusNode.hasFocus) return;
    setState(() => _isFocused = _focusNode.hasFocus);
  }

  void _onControllerChanged() {
    if (!InspectorController().isSearchVisible &&
        _textController.text.isNotEmpty) {
      _textController.clear();
    }
  }

  @override
  void dispose() {
    InspectorController().removeListener(_onControllerChanged);
    _focusNode.removeListener(_onFocusChanged);
    _textController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = widget.isDarkMode;
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final iconColor = isDarkMode ? Colors.white54 : Colors.black45;

    return Selector<InspectorController, bool>(
      selector: (_, controller) => controller.isSearchVisible,
      builder: (context, isVisible, _) {
        return AnimatedSize(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: !isVisible
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(8.0, 4.0, 8.0, 8.0),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: InspectorTheme.surface(isDarkMode),
                      borderRadius: BorderRadius.circular(14.0),
                      border: Border.all(
                        color: _isFocused
                            ? InspectorTheme.primary
                            : InspectorTheme.border(isDarkMode),
                        width: _isFocused ? 1.5 : 1.0,
                      ),
                      boxShadow: _isFocused
                          ? [
                              BoxShadow(
                                color: InspectorTheme.primary
                                    .withValues(alpha: 0.18),
                                blurRadius: 12.0,
                                spreadRadius: 1.0,
                              ),
                            ]
                          : null,
                    ),
                    child: TextField(
                      controller: _textController,
                      focusNode: _focusNode,
                      style: TextStyle(color: textColor, fontSize: 14.0),
                      cursorColor: InspectorTheme.primary,
                      decoration: InputDecoration(
                        hintText: 'Search headers, body, response…',
                        hintStyle: TextStyle(
                          color: isDarkMode ? Colors.white38 : Colors.black38,
                          fontSize: 13.5,
                        ),
                        prefixIcon: Icon(
                          Icons.search_rounded,
                          color:
                              _isFocused ? InspectorTheme.primary : iconColor,
                        ),
                        suffixIcon: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Selector<InspectorController, InspectorController>(
                              selector: (_, controller) => controller,
                              builder: (context, controller, _) {
                                final current = controller.currentMatchIndex;
                                final total = controller.totalMatches;
                                final query = controller.searchQuery;

                                if (query.isEmpty)
                                  return const SizedBox.shrink();

                                if (total <= 0) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 4.0),
                                    child: Text(
                                      'No matches',
                                      style: TextStyle(
                                        color: isDarkMode
                                            ? Colors.white38
                                            : Colors.black38,
                                        fontSize: 11.5,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  );
                                }

                                return Container(
                                  margin: const EdgeInsets.only(right: 2.0),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8.0,
                                    vertical: 3.0,
                                  ),
                                  decoration: BoxDecoration(
                                    color: InspectorTheme.primary
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  child: Text(
                                    '${current + 1} / $total',
                                    style: const TextStyle(
                                      color: InspectorTheme.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.keyboard_arrow_up_rounded,
                                  size: 20, color: iconColor),
                              onPressed: InspectorController().previousMatch,
                              tooltip: 'Previous match',
                              splashRadius: 18.0,
                            ),
                            IconButton(
                              icon: Icon(Icons.keyboard_arrow_down_rounded,
                                  size: 20, color: iconColor),
                              onPressed: InspectorController().nextMatch,
                              tooltip: 'Next match',
                              splashRadius: 18.0,
                            ),
                          ],
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12.0,
                        ),
                        isDense: true,
                      ),
                      onChanged: (value) {
                        InspectorController().updateSearchQuery(value);
                      },
                      onSubmitted: (_) {
                        final isShiftPressed =
                            HardwareKeyboard.instance.isShiftPressed;
                        if (isShiftPressed) {
                          InspectorController().previousMatch();
                        } else {
                          InspectorController().nextMatch();
                        }
                        _focusNode.requestFocus();
                      },
                    ),
                  ),
                ),
        );
      },
    );
  }
}
