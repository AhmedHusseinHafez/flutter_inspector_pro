import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';

import '../requests_inspector.dart';
import 'curl_command_generator.dart';
import 'json_pretty_converter.dart';
import 'helpers/inspector_helper.dart';
import 'requests_filter.dart';

typedef StoppingRequestCallback = Future<RequestDetails?> Function(
    RequestDetails requestDetails);

typedef StoppingResponseCallback = Future<ResponseDetails?> Function(
    ResponseDetails responseDetails);

typedef ShowInspectorCallback = void Function();

///Singleton
///
/// NOTE: the singleton is created by whichever caller invokes this factory
/// first. [RequestsInspector] does so with its real config, but if any code
/// calls `InspectorController()` (e.g. `addNewRequest`) before that widget
/// has built, the singleton locks in these defaults instead. Defaulting
/// `enabled` to `true` here (matching [RequestsInspector]'s own default)
/// keeps that accident from silently disabling logging.
class InspectorController extends ChangeNotifier {
  factory InspectorController({
    bool enabled = true,
    ShowInspectorOn showInspectorOn = ShowInspectorOn.LongPress,
    StoppingRequestCallback? onStoppingRequest,
    StoppingResponseCallback? onStoppingResponse,
    ShowInspectorCallback? onShowInspector,
    bool defaultTreeViewEnabled = true,
    bool defaultExpandChildren = true,
    bool defaultIsDarkMode = true,
  }) =>
      _singleton ??= InspectorController._internal(
        enabled: enabled,
        showInspectorOn: showInspectorOn,
        onStoppingRequest: onStoppingRequest,
        onStoppingResponse: onStoppingResponse,
        onShowInspector: onShowInspector,
        defaultTreeViewEnabled: defaultTreeViewEnabled,
        defaultExpandChildren: defaultExpandChildren,
        defaultIsDarkMode: defaultIsDarkMode,
      );

  InspectorController._internal({
    required bool enabled,
    required ShowInspectorOn showInspectorOn,
    StoppingRequestCallback? onStoppingRequest,
    StoppingResponseCallback? onStoppingResponse,
    ShowInspectorCallback? onShowInspector,
    required bool defaultTreeViewEnabled,
    required bool defaultExpandChildren,
    required bool defaultIsDarkMode,
  })  : _enabled = enabled,
        _onStoppingRequest = onStoppingRequest,
        _onShowInspector = onShowInspector,
        _isTreeView = defaultTreeViewEnabled,
        _expandChildren = defaultExpandChildren,
        _isDarkMode = defaultIsDarkMode,
        _onStoppingResponse = onStoppingResponse;

  static InspectorController? _singleton;

  late final bool _enabled;
  StoppingRequestCallback? _onStoppingRequest;
  StoppingResponseCallback? _onStoppingResponse;
  ShowInspectorCallback? _onShowInspector;
  bool _isInspectorOpen = false;

  final _dio = Dio(BaseOptions(validateStatus: (_) => true));
  final pageController = PageController(
    initialPage: 0,
    // if the viewportFraction is 1.0, the child pages will rebuild automatically
    // but if it less than 1.0, the pages will stay alive
    viewportFraction: 0.9999999,
  );

  int _selectedTab = 0;
  bool _requestStopperEnabled = false;
  bool _responseStopperEnabled = false;
  bool _isDarkMode;
  bool _isTreeView;
  bool _expandChildren;

  final _requestsList = <RequestDetails>[];
  RequestDetails? _selectedRequest;
  SseConnectionLog? _selectedSseConnection;
  FirebaseMessagingEvent? _selectedFirebaseMessagingEvent;
  ImageRequestDetails? _selectedImage;

  // Bumped whenever _requestsList is mutated, used to cache filteredRequestsList
  // so it isn't recomputed on every unrelated notifyListeners() (e.g. dark mode toggle).
  int _requestsVersion = 0;
  List<RequestDetails>? _cachedFilteredList;
  String? _cachedFilterKey;

  bool _isSearchVisible = false;
  String _searchQuery = '';
  int _totalMatches = 0;
  int _currentMatchIndex = -1;

  // Search & Filters state
  String _searchUrlQuery = '';
  RequestMethod? _filterRequestMethod;
  int? _filterStatusCode;
  ItemTypeFilter _filterItemType = ItemTypeFilter.all;

  // ------------------------------

  int get selectedTab => _selectedTab;

  bool get requestStopperEnabled => _requestStopperEnabled;

  bool get responseStopperEnabled => _responseStopperEnabled;

  bool get isDarkMode => _isDarkMode;

  bool get isTreeView => _isTreeView;

  bool get expandChildren => _expandChildren;

  List<RequestDetails> get requestsList => _requestsList;

  RequestDetails? get selectedRequest => _selectedRequest;

  SseConnectionLog? get selectedSseConnection => _selectedSseConnection;

  FirebaseMessagingEvent? get selectedFirebaseMessagingEvent =>
      _selectedFirebaseMessagingEvent;

  ImageRequestDetails? get selectedImage => _selectedImage;

  bool get isSearchVisible => _isSearchVisible;

  String get searchQuery => _searchQuery;

  int get totalMatches => _totalMatches;

  int get currentMatchIndex => _currentMatchIndex;

  String get searchUrlQuery => _searchUrlQuery;

  RequestMethod? get filterRequestMethod => _filterRequestMethod;

  int? get filterStatusCode => _filterStatusCode;

  ItemTypeFilter get filterItemType => _filterItemType;

  bool get areAnyFiltersApplied =>
      searchUrlQuery.trim().isNotEmpty ||
      filterRequestMethod != null ||
      filterStatusCode != null ||
      filterItemType != ItemTypeFilter.all;

  /// Key identifying the inputs that affect [filteredRequestsList]'s result.
  /// Used to skip recomputation when unrelated state changes (e.g. dark mode).
  String get requestsListCacheKey =>
      '$_requestsVersion|$_filterRequestMethod|$_filterStatusCode|$_searchUrlQuery|$_filterItemType';

  // Computed filtered + searched list (cached until its inputs change)
  List<RequestDetails> get filteredRequestsList {
    final key = requestsListCacheKey;
    if (_cachedFilteredList != null && _cachedFilterKey == key) {
      return _cachedFilteredList!;
    }

    if (_filterItemType == ItemTypeFilter.sse ||
        _filterItemType == ItemTypeFilter.firebaseMessaging) {
      _cachedFilteredList = const [];
      _cachedFilterKey = key;
      return _cachedFilteredList!;
    }

    Iterable<RequestDetails> list = _requestsList;

    if (_filterRequestMethod != null)
      list =
          list.where(RequestMethodFilter(_filterRequestMethod!).requestFilter);

    if (_filterStatusCode != null)
      list =
          list.where(RequestStatusCodeFilter(_filterStatusCode!).requestFilter);

    if (_searchUrlQuery.trim().isNotEmpty)
      list = list.where(RequestUrlFilter(_searchUrlQuery).requestFilter);

    _cachedFilteredList = list.toList(growable: false);
    _cachedFilterKey = key;
    return _cachedFilteredList!;
  }

  set selectedTab(int value) {
    if (_selectedTab == value) return;
    _selectedTab = value;
    notifyListeners();
  }

  set requestStopperEnabled(bool value) {
    if (_requestStopperEnabled == value) return;
    _requestStopperEnabled = value;
    notifyListeners();
  }

  set responseStopperEnabled(bool value) {
    if (_responseStopperEnabled == value) return;
    _responseStopperEnabled = value;
    notifyListeners();
  }

  set selectedRequest(RequestDetails? value) {
    if (_selectedRequest == value &&
        _selectedSseConnection == null &&
        _selectedFirebaseMessagingEvent == null &&
        _selectedImage == null &&
        _selectedTab == 1) return;
    _selectedRequest = value;
    _selectedSseConnection = null;
    _selectedFirebaseMessagingEvent = null;
    _selectedImage = null;
    _selectedTab = 1;
    _updateTotalMatches();
    notifyListeners();
  }

  void selectSseConnection(SseConnectionLog connection) {
    if (_selectedSseConnection?.id == connection.id &&
        _selectedRequest == null &&
        _selectedFirebaseMessagingEvent == null &&
        _selectedImage == null &&
        _selectedTab == 1) return;
    _selectedSseConnection = connection;
    _selectedRequest = null;
    _selectedFirebaseMessagingEvent = null;
    _selectedImage = null;
    _selectedTab = 1;
    notifyListeners();
  }

  void selectFirebaseMessagingEvent(FirebaseMessagingEvent event) {
    if (_selectedFirebaseMessagingEvent?.id == event.id &&
        _selectedRequest == null &&
        _selectedSseConnection == null &&
        _selectedImage == null &&
        _selectedTab == 1) return;
    _selectedFirebaseMessagingEvent = event;
    _selectedRequest = null;
    _selectedSseConnection = null;
    _selectedImage = null;
    _selectedTab = 1;
    notifyListeners();
  }

  void selectImage(ImageRequestDetails image) {
    if (_selectedImage == image &&
        _selectedRequest == null &&
        _selectedSseConnection == null &&
        _selectedFirebaseMessagingEvent == null &&
        _selectedTab == 1) return;
    _selectedImage = image;
    _selectedRequest = null;
    _selectedSseConnection = null;
    _selectedFirebaseMessagingEvent = null;
    _selectedTab = 1;
    notifyListeners();
  }

  // setters for search & filters
  void searchForRequests(String value) {
    if (_searchUrlQuery == value) return;
    _searchUrlQuery = value;
    notifyListeners();
  }

  void setRequestMethodFilter(RequestMethod? method) {
    if (_filterRequestMethod == method) return;
    _filterRequestMethod = method;
    notifyListeners();
  }

  void setStatusCodeFilter(int? statusCode) {
    if (_filterStatusCode == statusCode) return;
    _filterStatusCode = statusCode;
    notifyListeners();
  }

  void setItemTypeFilter(ItemTypeFilter itemType) {
    if (_filterItemType == itemType) return;
    _filterItemType = itemType;
    notifyListeners();
  }

  void clearFilters() {
    _filterRequestMethod = null;
    _filterStatusCode = null;
    _filterItemType = ItemTypeFilter.all;
    notifyListeners();
  }

  void clearSearch() {
    if (_searchUrlQuery.isEmpty) return;
    _searchUrlQuery = '';
    notifyListeners();
  }

  bool shouldStopRequest(RequestDetails requestDetails) => true;

  bool shouldStopResponse(ResponseDetails responseDetails) => true;

  bool get isInspectorOpen => _isInspectorOpen;

  void showInspector() {
    if (_isInspectorOpen) return;
    if (_onShowInspector != null) {
      _onShowInspector!();
      return;
    }
    pageController.jumpToPage(1);
  }

  void markInspectorOpened() {
    _isInspectorOpen = true;
  }

  void markInspectorClosed() {
    _isInspectorOpen = false;
  }

  void hideInspector(BuildContext context) => Navigator.pop(context);

  void addNewRequest(RequestDetails request) {
    if (!_enabled) return;
    _requestsList.insert(0, request);
    _requestsVersion++;
    notifyListeners();
  }

  void clearAllRequests() {
    if (_requestsList.isEmpty && _selectedRequest == null) return;
    _requestsList.clear();
    _requestsVersion++;
    _selectedRequest = null;
    notifyListeners();
  }

  void removeRequest(RequestDetails request) {
    if (!_requestsList.remove(request)) return;
    _requestsVersion++;
    if (_selectedRequest == request) _selectedRequest = null;
    notifyListeners();
  }

  Future<void> runAgain() async {
    if (_selectedRequest == null) return;

    var currentRequest = _selectedRequest!;
    final sentTime = DateTime.now();
    final response = await _dio.request(
      currentRequest.url,
      queryParameters: currentRequest.queryParameters,
      data: currentRequest.requestBody,
      options: Options(
        method: currentRequest.requestMethod.name,
        headers: currentRequest.headers,
      ),
    );
    if (currentRequest != _selectedRequest) return;

    _selectedRequest = currentRequest.copyWith(
      responseBody: response.data,
      statusCode: response.statusCode,
      sentTime: sentTime,
      receivedTime: DateTime.now(),
    );

    notifyListeners();
  }

  /// Shares the selected HTTP request directly to Slack (or the platform
  /// share sheet) in a single, backend-engineer-friendly format: a
  /// reproducible cURL command followed by the full request/response log.
  void shareSelectedRequest({Rect? sharePositionOrigin}) {
    final curlCommandGenerator = CurlCommandGenerator(_selectedRequest!);
    final curlContent = curlCommandGenerator.generate();

    final requestMap = _selectedRequest!.toMap();
    final normalLogContent = _formatMap(requestMap);

    final requestShareContent =
        '================[cURL Command]=================\n$curlContent\n\n==================[Request / Response]===================\n$normalLogContent';

    SharePlus.instance.share(
      ShareParams(
        text: requestShareContent,
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Shares the selected SSE connection directly to Slack (or the platform
  /// share sheet) as a plain, chronological event log.
  void shareSelectedSseConnection({Rect? sharePositionOrigin}) {
    final connection = _selectedSseConnection!;
    final startedAtText = InspectorHelper.extractTimeText(connection.startedAt);
    final status = connection.hasError
        ? 'ERROR'
        : connection.isClosed
            ? 'CLOSED'
            : 'OPEN';

    final buffer = StringBuffer()
      ..writeln('================[SSE Connection]=================')
      ..writeln('URL: ${connection.url}')
      ..writeln('Started at: $startedAtText')
      ..writeln('Status: $status')
      ..writeln()
      ..writeln('==================[Event Log]===================')
      ..writeln(connection.lines.join('\n'));

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  /// Shares the selected Firebase Messaging event directly to Slack (or the
  /// platform share sheet) as a structured, human-readable log entry.
  void shareSelectedFirebaseMessagingEvent({Rect? sharePositionOrigin}) {
    final event = _selectedFirebaseMessagingEvent!;
    final receivedAtText = InspectorHelper.extractTimeText(event.receivedAt);

    final headerLines = [
      'Event: ${event.type.label}',
      'Received at: $receivedAtText',
      if (event.messageId != null) 'Message ID: ${event.messageId}',
      if (event.senderId != null) 'Sender ID: ${event.senderId}',
      if (event.from != null) 'From: ${event.from}',
      if (event.messageType != null) 'Message type: ${event.messageType}',
      if (event.collapseKey != null) 'Collapse key: ${event.collapseKey}',
      if (event.ttl != null) 'TTL: ${event.ttl}',
      if (event.sentTime != null) 'Sent at: ${event.sentTime}',
    ];

    final buffer = StringBuffer()
      ..writeln('================[Firebase Messaging]=================')
      ..writeln(headerLines.join('\n'));

    if (event.hasNotification) {
      final notificationLines = [
        if (event.notificationTitle != null)
          'Title: ${event.notificationTitle}',
        if (event.notificationBody != null) 'Body: ${event.notificationBody}',
      ];
      buffer
        ..writeln()
        ..writeln('==================[Notification]===================')
        ..writeln(notificationLines.join('\n'));
    }

    if (event.data != null) {
      buffer
        ..writeln()
        ..writeln('=====================[Data]========================')
        ..writeln(event.dataPretty);
    }

    SharePlus.instance.share(
      ShareParams(
        text: buffer.toString(),
        sharePositionOrigin: sharePositionOrigin,
      ),
    );
  }

  @override
  void dispose() {
    _singleton = null;
    super.dispose();
  }

  String _formatMap(Map<String, dynamic> requestMap) {
    final converter = JsonPrettyConverter();
    final listOfContent = [
      for (final entry in requestMap.entries) ...[
        '=[ ${entry.key} ]===================\n',
        converter.convert(entry.value),
        '\n\n',
      ],
    ];

    return listOfContent.join();
  }

  Future<RequestDetails?> editRequest(RequestDetails requestDetails) {
    if (!_enabled || _onStoppingRequest == null) return Future.value(null);
    return _onStoppingRequest!(requestDetails);
  }

  Future<ResponseDetails?> editResponse(ResponseDetails responseDetails) {
    if (!_enabled || _onStoppingResponse == null) return Future.value(null);

    if (!['Map', 'String', 'List'].any((e) => responseDetails
        .responseBody.runtimeType
        .toString()
        .replaceFirst('_', '')
        .startsWith(e))) return Future.value(null);

    return _onStoppingResponse!(responseDetails);
  }

  void toggleInspectorTheme() {
    _isDarkMode = !_isDarkMode;
    notifyListeners();
  }

  void toggleInspectorJsonView() {
    _isTreeView = !_isTreeView;
    notifyListeners();
  }

  void toggleSearchVisibility() {
    _isSearchVisible = !_isSearchVisible;
    if (!_isSearchVisible) {
      _searchQuery = '';
      _totalMatches = 0;
    }
    notifyListeners();
  }

  void updateMatchCount(int count) {
    if (_totalMatches == count) return;
    _totalMatches = count;
    notifyListeners();
  }

  void updateSearchQuery(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    _updateTotalMatches();
    notifyListeners();
  }

  void nextMatch() {
    if (_totalMatches == 0) return;
    _currentMatchIndex = (_currentMatchIndex + 1) % _totalMatches;
    notifyListeners();
  }

  void previousMatch() {
    if (_totalMatches == 0) return;
    _currentMatchIndex =
        (_currentMatchIndex - 1 + _totalMatches) % _totalMatches;
    notifyListeners();
  }

  void _updateTotalMatches() {
    if (_searchQuery.isEmpty || _selectedRequest == null) {
      _totalMatches = 0;
      return;
    }

    final allText = _extractAllText(_selectedRequest!);
    final query = _searchQuery.toLowerCase();
    final text = allText.toLowerCase();

    var count = 0;
    var index = text.indexOf(query);
    while (index != -1) {
      count++;
      index = text.indexOf(query, index + query.length);
    }
    _totalMatches = count;
    _currentMatchIndex = count > 0 ? 0 : -1;
  }

  String _extractAllText(RequestDetails request) {
    final converter = JsonPrettyConverter();
    final parts = <String>[];

    final sentTimeText = InspectorHelper.extractTimeText(request.sentTime);
    var text = 'Sent at: $sentTimeText';

    if (request.receivedTime != null) {
      final receivedTimeText =
          InspectorHelper.extractTimeText(request.receivedTime!);
      final durationText = InspectorHelper.calculateDuration(
          request.sentTime, request.receivedTime!);
      text += '\nReceived at: $receivedTimeText\nDuration: $durationText';
    }

    text += '\n\nURL: ${request.url}';
    parts.add(text);

    if (request.headers != null) parts.add(converter.convert(request.headers));
    if (request.queryParameters != null) {
      parts.add(converter.convert(request.queryParameters));
    }
    if (request.requestBody != null) {
      parts.add(converter.convert(request.requestBody));
    }
    if (request.graphqlRequestVars != null) {
      parts.add(converter.convert(request.graphqlRequestVars));
    }
    if (request.responseBody != null) {
      parts.add(converter.convert(request.responseBody));
    }

    return parts.join('\n');
  }

  void toggleExpandChildren() {
    _expandChildren = !_expandChildren;
    notifyListeners();
  }
}
