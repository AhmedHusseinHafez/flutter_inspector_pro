import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:requests_inspector/src/filters_dialog.dart';
import 'package:requests_inspector/src/shared_widgets/empty_state.dart';
import 'package:requests_inspector/src/shared_widgets/image_log_item.dart';
import 'package:requests_inspector/src/shared_widgets/inspector_theme.dart';
import 'package:requests_inspector/src/shared_widgets/request_details_page.dart';
import 'package:requests_inspector/src/shared_widgets/request_item.dart';
import 'package:requests_inspector/src/shared_widgets/slack_icon.dart';
import 'package:requests_inspector/src/shared_widgets/sse_connection_details_page.dart';
import 'package:requests_inspector/src/shared_widgets/sse_connection_item.dart';
import '../../requests_inspector.dart';

class Inspector extends StatelessWidget {
  const Inspector({super.key, GlobalKey<NavigatorState>? navigatorKey})
      : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState>? _navigatorKey;

  @override
  Widget build(BuildContext context) {
    return Selector<InspectorController, bool>(
      selector: (_, controller) => controller.isDarkMode,
      builder: (context, isDarkMode, child) {
        return Theme(
          data: ThemeData(
            useMaterial3: true,
            brightness: isDarkMode ? Brightness.dark : Brightness.light,
            colorScheme: ColorScheme.fromSeed(
              seedColor: InspectorTheme.primary,
              brightness: isDarkMode ? Brightness.dark : Brightness.light,
            ),
            scaffoldBackgroundColor: InspectorTheme.background(isDarkMode),
          ),
          child: Scaffold(
            backgroundColor: InspectorTheme.background(isDarkMode),
            appBar: _buildAppBar(isDarkMode),
            body: _buildBody(isDarkMode: isDarkMode),
            floatingActionButton: _buildFloatingActionButtons(isDarkMode),
          ),
        );
      },
    );
  }

  AppBar _buildAppBar(bool isDarkMode) {
    return AppBar(
      backgroundColor: InspectorTheme.surface(isDarkMode),
      elevation: 0,
      scrolledUnderElevation: 0,
      surfaceTintColor: Colors.transparent,
      shape:
          Border(bottom: BorderSide(color: InspectorTheme.border(isDarkMode))),

      // Set default icon color for all icons inside AppBar (instead of per icon)
      iconTheme: IconThemeData(
        color: isDarkMode ? Colors.white : Colors.black87,
      ),

      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.api_rounded, color: InspectorTheme.primary),
          const SizedBox(width: 8.0),
          Text(
            'Inspector',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: isDarkMode ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),

      leading: IconButton(
        // Use method from controller (doesn't require listening)
        onPressed: () {
          _closeKeyboard();
          InspectorController().hideInspector(_navigatorKey!.currentContext!);
        },
        icon: const Icon(Icons.close), // Icon color handled by iconTheme
      ),

      // Build action buttons, separating logic for better readability
      actions: _buildActions(isDarkMode),
    );
  }

  void _closeKeyboard() {
    SystemChannels.textInput.invokeMethod('TextInput.hide');
  }

  List<Widget> _buildActions(bool isDarkMode) {
    return [
      Selector<InspectorController, int>(
        selector: (_, c) => c.selectedTab,
        builder: (context, selectedTab, _) {
          // Images tab only has image logs to clear; every other tab clears
          // the full inspector state so "Clear All" behaves consistently
          // wherever it's shown.
          final clearAllButton = selectedTab == 2
              ? _buildClearAllButton(
                  context,
                  isDarkMode: isDarkMode,
                  message: 'This will clear all logged image requests.',
                  onYes: ImageLogController.clear,
                )
              : _buildClearAllButton(
                  context,
                  isDarkMode: isDarkMode,
                  message:
                      'This will clear all requests added to the inspector.',
                  onYes: () {
                    InspectorController().clearAllRequests();
                    SseLogController.clear();
                    ImageLogController.clear();
                  },
                );

          // Run Again now lives inline on the details page itself, next to
          // the request's method/status chips.
          return clearAllButton;
        },
      ),
    ];
  }

  Widget _buildClearAllButton(
    BuildContext context, {
    required bool isDarkMode,
    required String message,
    required VoidCallback onYes,
  }) {
    return TextButton(
      onPressed: () => _showAreYouSureDialog(
        context,
        isDarkMode: isDarkMode,
        message: message,
        onYes: onYes,
      ),
      child: Text(
        'Clear All',
        style: TextStyle(color: isDarkMode ? Colors.white : Colors.black87),
      ),
    );
  }

  Widget _buildBody({required bool isDarkMode}) {
    return Selector<InspectorController, int>(
      selector: (_, inspectorController) => inspectorController.selectedTab,
      builder: (context, selectedTab, _) => Column(
        children: [
          _buildTabBar(isDarkMode: isDarkMode, selectedTab: selectedTab),
          ..._buildSelectedTabBody(
            isDarkMode: isDarkMode,
            selectedTab: selectedTab,
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar({required int selectedTab, required bool isDarkMode}) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: InspectorTheme.border(isDarkMode)),
        ),
      ),
      child: Row(
        children: [
          _buildTabItem(
            title: 'All',
            isDarkMode: isDarkMode,
            isSelected: selectedTab == 0,
            onTap: () => InspectorController().selectedTab = 0,
          ),
          _buildTabItem(
            title: 'Details',
            isDarkMode: isDarkMode,
            isSelected: selectedTab == 1,
            onTap: () => InspectorController().selectedTab = 1,
          ),
          _buildTabItem(
            title: 'Images',
            isDarkMode: isDarkMode,
            isSelected: selectedTab == 2,
            onTap: () => InspectorController().selectedTab = 2,
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem({
    required String title,
    required bool isSelected,
    required bool isDarkMode,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isSelected ? InspectorTheme.primary : Colors.transparent,
                width: 2.0,
              ),
            ),
          ),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13.0,
              color: isSelected
                  ? InspectorTheme.primary
                  : (isDarkMode ? Colors.white70 : Colors.black54),
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Iterable<Widget> _buildSelectedTabBody({
    required int selectedTab,
    required bool isDarkMode,
  }) {
    if (selectedTab == 0) {
      return _buildAllRequests(isDarkMode: isDarkMode);
    }
    if (selectedTab == 2) {
      return [_buildImagesTab(isDarkMode)];
    }
    return [_buildDetailsTab(isDarkMode)];
  }

  Widget _buildImagesTab(bool isDarkMode) {
    return Expanded(
      child: ValueListenableBuilder<List<ImageRequestDetails>>(
        valueListenable: ImageLogController.images,
        builder: (context, images, _) {
          if (images.isEmpty) {
            return EmptyState(
              icon: Icons.image_outlined,
              title: 'No image requests yet',
              message:
                  'Images fetched by your app will show up here as they\'re loaded.',
              isDarkMode: isDarkMode,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12.0),
            itemCount: images.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8.0),
            itemBuilder: (context, index) => ImageLogItemWidget(
              details: images[index],
              isDarkMode: isDarkMode,
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailsTab(bool isDarkMode) {
    return Selector<InspectorController, RequestDetails?>(
      selector: (_, c) => c.selectedRequest,
      builder: (context, selectedRequest, _) {
        if (selectedRequest != null) return const RequestDetailsPage();

        return Selector<InspectorController, SseConnectionLog?>(
          selector: (_, c) => c.selectedSseConnection,
          builder: (context, selectedSseConnection, __) {
            if (selectedSseConnection != null) {
              return SseConnectionDetailsPage(
                connection: selectedSseConnection,
                isDarkMode: isDarkMode,
              );
            }
            return Expanded(
              child: EmptyState(
                icon: Icons.touch_app_outlined,
                title: 'Nothing selected',
                message: 'Select an item to view its details here.',
                isDarkMode: isDarkMode,
              ),
            );
          },
        );
      },
    );
  }

  Iterable<Widget> _buildAllRequests({required bool isDarkMode}) {
    return [
      // Search field at top
      _buildSearchField(isDarkMode),
      _buildRequestsList(isDarkMode),
    ];
  }

  Future<void> _showAreYouSureDialog(
    BuildContext context, {
    required bool isDarkMode,
    required String message,
    required VoidCallback onYes,
  }) {
    final textColor = isDarkMode ? Colors.white : Colors.black87;
    final subtitleColor = isDarkMode ? Colors.white54 : Colors.black54;

    return showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: InspectorTheme.surface(isDarkMode),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44.0,
                height: 44.0,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: InspectorTheme.statusError.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: const Icon(
                  Icons.delete_outline,
                  color: InspectorTheme.statusError,
                ),
              ),
              const SizedBox(height: 16.0),
              Text(
                'Clear all?',
                style: TextStyle(
                  fontSize: 17.0,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 6.0),
              Text(
                message,
                style: TextStyle(fontSize: 13.0, color: subtitleColor),
              ),
              const SizedBox(height: 20.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textColor,
                        side: BorderSide(
                            color: InspectorTheme.border(isDarkMode)),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(InspectorTheme.radius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onPressed: Navigator.of(context).pop,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12.0),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: InspectorTheme.statusError,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(InspectorTheme.radius),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12.0),
                      ),
                      onPressed: () {
                        Navigator.of(context).pop();
                        onYes();
                      },
                      child: const Text('Clear'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Stacks the search toggle above the Slack share button, both styled as
  /// matching floating action buttons in the bottom-right corner of the
  /// details screen. Search only applies to HTTP requests; share applies to
  /// both HTTP requests and SSE connections.
  Widget _buildFloatingActionButtons(bool isDarkMode) {
    return Selector<InspectorController, bool>(
      selector: (_, c) =>
          c.selectedTab == 1 &&
          (c.selectedRequest != null || c.selectedSseConnection != null),
      builder: (context, showButtons, _) {
        if (!showButtons) return const SizedBox();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSearchFloatingButton(isDarkMode),
            const SizedBox(height: 12.0),
            _buildShareFloatingButton(context),
          ],
        );
      },
    );
  }

  Widget _buildSearchFloatingButton(bool isDarkMode) {
    return Selector<InspectorController, RequestDetails?>(
      selector: (_, c) => c.selectedRequest,
      builder: (context, selectedRequest, _) {
        if (selectedRequest == null) return const SizedBox();
        return Selector<InspectorController, bool>(
          selector: (_, c) => c.isSearchVisible,
          builder: (context, isSearchVisible, _) => FloatingActionButton(
            heroTag: 'inspector_search_fab',
            mini: true,
            backgroundColor: isSearchVisible
                ? InspectorTheme.primary
                : InspectorTheme.surface(isDarkMode),
            foregroundColor: isSearchVisible
                ? Colors.white
                : (isDarkMode ? Colors.white70 : Colors.black87),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.0),
              side: isSearchVisible
                  ? BorderSide.none
                  : BorderSide(color: InspectorTheme.border(isDarkMode)),
            ),
            elevation: isSearchVisible ? 4 : 2,
            tooltip: isSearchVisible ? 'Close search' : 'Search',
            onPressed: InspectorController().toggleSearchVisibility,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 150),
              child: Icon(
                isSearchVisible ? Icons.close_rounded : Icons.search_rounded,
                key: ValueKey(isSearchVisible),
                size: 22.0,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildShareFloatingButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'inspector_share_fab',
      backgroundColor: Colors.white,
      elevation: 2,
      tooltip: 'Share to Slack',
      child: const SlackIcon(size: 26.0),
      onPressed: () {
        final box = context.findRenderObject() as RenderBox?;
        final sharePositionOrigin =
            box == null ? null : box.localToGlobal(Offset.zero) & box.size;

        final controller = InspectorController();
        if (controller.selectedRequest != null) {
          controller.shareSelectedRequest(
            sharePositionOrigin: sharePositionOrigin,
          );
        } else if (controller.selectedSseConnection != null) {
          controller.shareSelectedSseConnection(
            sharePositionOrigin: sharePositionOrigin,
          );
        }
      },
    );
  }

  Widget _buildRequestsList(bool isDarkMode) {
    return Expanded(
      child: ValueListenableBuilder<List<String>>(
        valueListenable: SseLogController.logs,
        builder: (context, _, __) {
          return Selector<InspectorController, String>(
            selector: (_, controller) => controller.requestsListCacheKey,
            builder: (context, _, __) {
              final requests = InspectorController().filteredRequestsList;
              final sseConnections =
                  InspectorController().filterItemType == ItemTypeFilter.http
                      ? const <SseConnectionLog>[]
                      : SseLogController.connections;
              final items = _TimelineItem.merge(requests, sseConnections);

              if (items.isEmpty) {
                final filtersApplied =
                    InspectorController().areAnyFiltersApplied;
                return EmptyState(
                  icon: filtersApplied
                      ? Icons.filter_alt_off_outlined
                      : Icons.inbox_outlined,
                  title: filtersApplied
                      ? 'No matching requests'
                      : 'No requests yet',
                  message: filtersApplied
                      ? 'Try adjusting or clearing your filters to see more results.'
                      : 'Requests made by your app will appear here as they happen.',
                  isDarkMode: isDarkMode,
                );
              }

              final rows = _groupByDay(items);

              return Selector<InspectorController, RequestDetails?>(
                selector: (_, controller) => controller.selectedRequest,
                builder: (context, selectedRequest, _) {
                  final selectedSseId =
                      InspectorController().selectedSseConnection?.id;
                  return ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 12.0),
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final row = rows[index];
                      if (row is String) {
                        return Padding(
                          padding: EdgeInsets.only(
                            top: index == 0 ? 0.0 : 16.0,
                            bottom: 8.0,
                          ),
                          child: Text(
                            row,
                            style: TextStyle(
                              fontSize: 12.0,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color:
                                  isDarkMode ? Colors.white38 : Colors.black38,
                            ),
                          ),
                        );
                      }

                      final item = row as _TimelineItem;
                      final sseConnection = item.sseConnection;
                      if (sseConnection != null) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Dismissible(
                            key: ValueKey(sseConnection.id),
                            direction: DismissDirection.endToStart,
                            background: _deleteBackground(),
                            onDismissed: (_) =>
                                SseLogController.removeConnection(
                                    sseConnection),
                            child: SseConnectionItemWidget(
                              connection: sseConnection,
                              isSelected: sseConnection.id == selectedSseId,
                              isDarkMode: isDarkMode,
                              onTap: () => InspectorController()
                                  .selectSseConnection(sseConnection),
                            ),
                          ),
                        );
                      }
                      final request = item.request!;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Dismissible(
                          key: ValueKey(request.id),
                          direction: DismissDirection.endToStart,
                          background: _deleteBackground(),
                          onDismissed: (_) =>
                              InspectorController().removeRequest(request),
                          child: RequestItemWidget(
                            request: request,
                            isSelected: selectedRequest == request,
                            isDarkMode: isDarkMode,
                            onTap: (itemContext, tappedRequest) {
                              InspectorController().selectedRequest =
                                  tappedRequest;
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _deleteBackground() {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 20.0),
      decoration: BoxDecoration(
        color: InspectorTheme.statusError,
        borderRadius: BorderRadius.circular(InspectorTheme.radius),
      ),
      child: const Icon(Icons.delete_outline, color: Colors.white),
    );
  }

  /// Inserts "Today" / "Yesterday" / date-string headers ahead of each
  /// group of same-day items, in the already time-sorted [items] list.
  List<Object> _groupByDay(List<_TimelineItem> items) {
    final rows = <Object>[];
    DateTime? lastDay;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    for (final item in items) {
      final day = DateTime(item.time.year, item.time.month, item.time.day);
      if (lastDay == null || day != lastDay) {
        lastDay = day;
        String label;
        if (day == today) {
          label = 'TODAY';
        } else if (day == yesterday) {
          label = 'YESTERDAY';
        } else {
          label =
              '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
        }
        rows.add(label);
      }
      rows.add(item);
    }
    return rows;
  }

  Widget _buildSearchField(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Selector<InspectorController, String>(
        selector: (_, c) => c.searchUrlQuery,
        builder: (context, searchQuery, _) {
          return _SearchField(
            searchQuery: searchQuery,
            onFiltersTap: () {
              _showFiltersDialog(context, isDarkMode);
            },
            isDarkMode: isDarkMode,
          );
        },
      ),
    );
  }

  void _showFiltersDialog(BuildContext context, bool isDarkMode) {
    showDialog<void>(
      context: context,
      builder: (context) => FiltersDialog(isDarkMode: isDarkMode),
    );
  }
}

class _SearchField extends StatefulWidget {
  const _SearchField({
    required this.searchQuery,
    required this.onFiltersTap,
    required this.isDarkMode,
  });

  final String searchQuery;
  final void Function() onFiltersTap;
  final bool isDarkMode;

  @override
  State<_SearchField> createState() => __SearchFieldState();
}

class __SearchFieldState extends State<_SearchField> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: TextStyle(
        color: widget.isDarkMode ? Colors.white : Colors.black87,
        fontSize: 14.0,
      ),
      decoration: InputDecoration(
        hintText: 'Search by URL',
        hintStyle: TextStyle(
          color: widget.isDarkMode ? Colors.white38 : Colors.black38,
        ),
        fillColor: InspectorTheme.surface(widget.isDarkMode),
        filled: true,
        prefixIcon: Icon(
          Icons.search,
          color: widget.isDarkMode ? Colors.white54 : Colors.black45,
        ),
        suffixIcon: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.searchQuery.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  InspectorController().clearSearch();
                  _controller.clear();
                },
              ),
            Selector<InspectorController, bool>(
              selector: (_, c) => c.areAnyFiltersApplied,
              builder: (context, areAnyFiltersApplied, _) => IconButton(
                icon: Icon(
                  Icons.filter_list,
                  color: areAnyFiltersApplied ? InspectorTheme.primary : null,
                ),
                onPressed: widget.onFiltersTap,
              ),
            ),
          ],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          borderSide: BorderSide(
            color: InspectorTheme.border(widget.isDarkMode),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          borderSide: BorderSide(
            color: InspectorTheme.border(widget.isDarkMode),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(InspectorTheme.radius),
          borderSide:
              const BorderSide(color: InspectorTheme.primary, width: 1.5),
        ),
        isDense: true,
      ),
      onChanged: InspectorController().searchForRequests,
    );
  }
}

/// A single row in the merged "All" timeline: either an HTTP [RequestDetails]
/// or an [SseConnectionLog], sorted together by time (newest first).
class _TimelineItem {
  const _TimelineItem._({this.request, this.sseConnection, required this.time});

  final RequestDetails? request;
  final SseConnectionLog? sseConnection;
  final DateTime time;

  static List<_TimelineItem> merge(
    List<RequestDetails> requests,
    List<SseConnectionLog> sseConnections,
  ) {
    final items = <_TimelineItem>[
      ...requests.map(
        (r) => _TimelineItem._(request: r, time: r.sentTime),
      ),
      ...sseConnections.map(
        (c) => _TimelineItem._(sseConnection: c, time: c.startedAt),
      ),
    ];
    items.sort((a, b) => b.time.compareTo(a.time));
    return items;
  }
}
