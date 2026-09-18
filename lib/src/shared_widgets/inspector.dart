import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:requests_inspector/src/filters_dialog.dart';
import 'package:requests_inspector/src/shared_widgets/inspector_theme.dart';
import 'package:requests_inspector/src/shared_widgets/request_details_page.dart';
import 'package:requests_inspector/src/shared_widgets/request_item.dart';
import 'package:requests_inspector/src/shared_widgets/run_again_widget.dart';
import 'package:requests_inspector/src/shared_widgets/slack_icon.dart';
import 'package:requests_inspector/src/shared_widgets/sse_connection_details_page.dart';
import 'package:requests_inspector/src/shared_widgets/sse_connection_item.dart';
import '../../requests_inspector.dart';
import '../enums/share_type_enum.dart';

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
            floatingActionButton: _buildShareFloatingButton(),
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
          if (selectedTab == 0) {
            return TextButton(
              onPressed: () => _showAreYouSureDialog(
                context,
                onYes: () {
                  InspectorController().clearAllRequests();
                  SseLogController.clear();
                },
              ),
              child: Text(
                'Clear All',
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black87,
                ),
              ),
            );
          }

          // Details tab: search + run-again only make sense for an HTTP
          // request, not for a selected SSE connection.
          return Selector<InspectorController, RequestDetails?>(
            selector: (_, c) => c.selectedRequest,
            builder: (context, selectedRequest, _) {
              if (selectedRequest == null) return const SizedBox();
              return Row(
                children: [
                  IconButton(
                    onPressed: InspectorController().toggleSearchVisibility,
                    icon: const Icon(Icons.search),
                    tooltip: 'Search',
                  ),
                  RunAgainButton(
                    key: ValueKey(selectedRequest.hashCode),
                    onTap: InspectorController().runAgain,
                    isDarkMode: isDarkMode,
                  ),
                ],
              );
            },
          );
        },
      ),
    ];
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
    return [_buildDetailsTab(isDarkMode)];
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
            return const Expanded(
              child: Center(
                child: Text('Please select a request first to view details'),
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
    required VoidCallback onYes,
  }) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Are you sure? 🤔'),
        content: const Text(
          'This will clear all requests added to the inspector',
        ),
        actions: [
          TextButton(
            child: const Text('Yes', style: TextStyle(color: Colors.red)),
            onPressed: () {
              Navigator.of(context).pop();
              onYes();
            },
          ),
          TextButton(
            onPressed: Navigator.of(context).pop,
            child: const Text('No', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  Widget _buildShareFloatingButton() {
    return Selector<InspectorController, bool>(
      selector: (_, inspectorController) =>
          inspectorController.selectedTab == 1 &&
          inspectorController.selectedRequest != null,
      builder: (context, showShareButton, _) => showShareButton
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              elevation: 2,
              tooltip: 'Share to Slack',
              child: const SlackIcon(size: 26.0),
              onPressed: () async {
                final box = context.findRenderObject() as RenderBox?;

                final selectedRequest = InspectorController().selectedRequest!;
                final isHttp = _isHttp(selectedRequest);

                var shareType =
                    isHttp ? await _showDialogShareType(context) : null;

                if (shareType == null) return;

                if (shareType == ShareType.Har) {
                  shareType = await _showHarFormatDialog(context);
                  if (shareType == null) return;
                }

                InspectorController().shareSelectedRequest(
                  sharePositionOrigin: box == null
                      ? null
                      : box.localToGlobal(Offset.zero) & box.size,
                  shareType: shareType,
                );
              },
            )
          : const SizedBox(),
    );
  }

  bool _isHttp(RequestDetails selectedRequest) {
    return selectedRequest.requestMethod == RequestMethod.GET ||
        selectedRequest.requestMethod == RequestMethod.POST ||
        selectedRequest.requestMethod == RequestMethod.PUT ||
        selectedRequest.requestMethod == RequestMethod.PATCH ||
        selectedRequest.requestMethod == RequestMethod.DELETE;
  }

  Future<ShareType?> _showDialogShareType(BuildContext context) {
    return showDialog<ShareType?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share as Normal Log, cURL or HAR? 🤔'),
        content: const Text('Choose your preferred share format'),
        actions: [
          TextButton(
            child: const Text(
              'cURL Command',
              style: TextStyle(color: Colors.green),
            ),
            onPressed: () => Navigator.of(context).pop(ShareType.CurlCommand),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ShareType.NormalLog),
            child: const Text(
              'Normal Log',
              style: TextStyle(color: Colors.yellow),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ShareType.Both),
            child: const Text('Both', style: TextStyle(color: Colors.red)),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ShareType.Har),
            child: const Text('HAR'),
          ),
        ],
      ),
    );
  }

  Future<ShareType?> _showHarFormatDialog(BuildContext context) {
    return showDialog<ShareType?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('HAR format'),
        content: const Text('Do you want the HAR as text or as a .har file?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(ShareType.Har),
            child: const Text('HAR text copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(ShareType.HarFile),
            child: const Text('HAR file (.har)'),
          ),
        ],
      ),
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
                return Center(
                  child: Text(
                    InspectorController().areAnyFiltersApplied
                        ? 'No requests can be found with applied filters'
                        : 'No requests added yet',
                  ),
                );
              }

              return Selector<InspectorController, RequestDetails?>(
                selector: (_, controller) => controller.selectedRequest,
                builder: (context, selectedRequest, _) {
                  final selectedSseId =
                      InspectorController().selectedSseConnection?.id;
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12.0, 4.0, 12.0, 12.0),
                    separatorBuilder: (_, __) => const SizedBox(height: 8.0),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final sseConnection = item.sseConnection;
                      if (sseConnection != null) {
                        return SseConnectionItemWidget(
                          connection: sseConnection,
                          isSelected: sseConnection.id == selectedSseId,
                          isDarkMode: isDarkMode,
                          onTap: () => InspectorController()
                              .selectSseConnection(sseConnection),
                        );
                      }
                      final request = item.request!;
                      return RequestItemWidget(
                        request: request,
                        isSelected: selectedRequest == request,
                        isDarkMode: isDarkMode,
                        onTap: (itemContext, tappedRequest) {
                          InspectorController().selectedRequest = tappedRequest;
                        },
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
