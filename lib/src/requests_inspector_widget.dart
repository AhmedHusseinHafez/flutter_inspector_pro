import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:requests_inspector/src/request_stopper_editor_dialog.dart';
import 'package:requests_inspector/src/response_stopper_editor_dialog.dart';
import 'package:requests_inspector/src/shared_widgets/inspector.dart';
import 'package:requests_inspector/src/shared_widgets/log_storage_prompt_dialog.dart';
import '../requests_inspector.dart';

///You can show the Inspector by long-pressing the screen.
class RequestsInspector extends StatefulWidget {
  /// Pass your `navigatorKey` of your MaterialApp to enable Request & Response `Stopper` Dialogs.
  /// And if you don't want to use it, you can pass it as `null`.
  const RequestsInspector({
    super.key,
    bool enabled = true,
    bool hideInspectorBanner = false,
    ShowInspectorOn showInspectorOn = ShowInspectorOn.LongPress,
    required Widget child,
    bool defaultTreeViewEnabled = true,
    required GlobalKey<NavigatorState> navigatorKey,
    bool defaultExpandChildren = true,
    bool defaultIsDarkMode = true,
    this.onInspectorOpened,
    this.onInspectorClosed,
    FirebaseMessagingInspectorConfig firebaseMessaging =
        const FirebaseMessagingInspectorConfig(),
    LogPersistenceConfig logPersistence = const LogPersistenceConfig(),
  })  : _enabled = enabled,
        _hideInspectorBanner = hideInspectorBanner,
        _showInspectorOn = showInspectorOn,
        _child = child,
        _navigatorKey = navigatorKey,
        _defaultTreeViewEnabled = defaultTreeViewEnabled,
        _defaultExpandChildren = defaultExpandChildren,
        _defaultIsDarkMode = defaultIsDarkMode,
        _firebaseMessaging = firebaseMessaging,
        _logPersistence = logPersistence;

  final bool _enabled;
  final bool _hideInspectorBanner;
  final ShowInspectorOn _showInspectorOn;
  final Widget _child;
  final bool _defaultTreeViewEnabled;
  final bool _defaultExpandChildren;
  final bool _defaultIsDarkMode;
  final GlobalKey<NavigatorState>? _navigatorKey;

  /// Opt-in config to auto-capture Firebase Messaging events
  /// (`onMessage`/`onMessageOpenedApp`) into the inspector. Disabled by
  /// default; see [FirebaseMessagingInspectorConfig].
  final FirebaseMessagingInspectorConfig _firebaseMessaging;

  /// Controls saving logs to disk: which categories are saved by default,
  /// whether to ask on first open, and how much is kept. Enabled (but saving
  /// nothing) by default - see [LogPersistenceConfig].
  final LogPersistenceConfig _logPersistence;

  /// Called when the inspector screen is opened (long-press).
  final VoidCallback? onInspectorOpened;

  /// Called when the inspector screen is closed.
  final VoidCallback? onInspectorClosed;

  @override
  State<RequestsInspector> createState() => _RequestsInspectorState();
}

class _RequestsInspectorState extends State<RequestsInspector>
    with WidgetsBindingObserver {
  /// Completes once disk logging has finished initializing.
  Future<void>? _persistenceReady;

  @override
  void initState() {
    super.initState();
    // Saved logs are buffered and flushed on a timer, so a pause/kill could
    // otherwise drop the last couple of seconds of traffic.
    WidgetsBinding.instance.addObserver(this);
    // Automatically observes non-API network file traffic (images, videos,
    // PDFs, fonts, downloads, ...) via dart:io's HttpOverrides, the same
    // mechanism Flutter DevTools' network view uses - no changes required
    // from the app using this package.
    if (widget._enabled) RequestsInspectorHttpOverrides.install();

    // Automatically attaches to FirebaseMessaging.instance's streams when
    // opted in - no listener code required from the app. No-ops (and never
    // throws) if Firebase hasn't been initialized yet.
    if (widget._enabled)
      FirebaseMessagingInspector.attach(widget._firebaseMessaging);

    // Resolves the on-disk log directory and restores which categories the
    // user chose to save. Kept as a future so the first-open prompt can wait
    // for it instead of racing it.
    _persistenceReady = widget._enabled
        ? LogPersistenceController.instance.init(widget._logPersistence)
        : Future<void>.value();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) return;
    LogPersistenceController.instance.flush();
  }

  @override
  Widget build(BuildContext context) {
    var child = widget._enabled
        ? ChangeNotifierProvider(
            create: (context) => InspectorController(
              enabled: widget._enabled,
              showInspectorOn: widget._showInspectorOn,
              defaultTreeViewEnabled: widget._defaultTreeViewEnabled,
              defaultExpandChildren: widget._defaultExpandChildren,
              defaultIsDarkMode: widget._defaultIsDarkMode,
              onShowInspector: _openInspector,
              onStoppingRequest: (requestDetails) => _showRequestEditorDialog(
                context,
                requestDetails: requestDetails,
              ),
              onStoppingResponse: (responseDetails) =>
                  _showResponseEditorDialog(
                context,
                responseDetails: responseDetails,
              ),
            ),
            lazy: false,
            builder: (context, _) {
              return PopScope(
                canPop: false,
                onPopInvokedWithResult: (didPop, result) {
                  if (didPop) return;
                  if (InspectorController().pageController.page == 0) {
                    Navigator.of(context).maybePop();
                  }
                },
                child: GestureDetector(
                  onLongPress: _openInspector,
                  child: widget._child,
                ),
              );
            },
          )
        : widget._child;

    if (!widget._hideInspectorBanner && widget._enabled) {
      child = Banner(
        message: 'INSPECTOR',
        textDirection: TextDirection.ltr,
        location: BannerLocation.topEnd,
        child: child,
      );
    }

    return child;
  }

  void _openInspector() {
    final navigatorContext = widget._navigatorKey?.currentContext;
    if (navigatorContext == null || InspectorController().isInspectorOpen) {
      return;
    }

    InspectorController().markInspectorOpened();
    widget.onInspectorOpened?.call();

    Navigator.push<void>(
      navigatorContext,
      PageRouteBuilder<void>(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        pageBuilder: (_, __, ___) => Directionality(
          textDirection: TextDirection.ltr,
          child: Inspector(navigatorKey: widget._navigatorKey),
        ),
      ),
    ).whenComplete(() {
      InspectorController().markInspectorClosed();
      widget.onInspectorClosed?.call();
    });

    _maybeAskAboutDiskLogging();
  }

  /// Shows the one-time "save logs to disk?" prompt on top of the inspector,
  /// once disk logging has finished initializing (so a slow directory lookup
  /// doesn't silently skip the prompt).
  Future<void> _maybeAskAboutDiskLogging() async {
    final persistence = LogPersistenceController.instance;
    if (!persistence.isFeatureEnabled) return;

    await _persistenceReady;
    if (!mounted || !persistence.shouldPromptOnOpen) return;
    if (!InspectorController().isInspectorOpen) return;

    final dialogContext = widget._navigatorKey?.currentContext;
    if (dialogContext == null || !dialogContext.mounted) return;

    await LogStoragePromptDialog.showIfNeeded(
      dialogContext,
      isDarkMode: InspectorController().isDarkMode,
    );
  }

  Future<RequestDetails?> _showRequestEditorDialog(
    BuildContext context, {
    required RequestDetails requestDetails,
  }) {
    if (widget._navigatorKey?.currentContext == null) return Future.value(null);
    if (!InspectorController().shouldStopRequest(requestDetails)) {
      return Future.value(null);
    }

    return showDialog<RequestDetails?>(
      context: widget._navigatorKey!.currentContext!,
      builder: (context) =>
          RequestStopperEditorDialog(requestDetails: requestDetails),
    );
  }

  Future<ResponseDetails?> _showResponseEditorDialog(
    BuildContext context, {
    required ResponseDetails responseDetails,
  }) {
    if (widget._navigatorKey?.currentContext == null) return Future.value(null);
    if (!InspectorController().shouldStopResponse(responseDetails)) {
      return Future.value(null);
    }

    return showDialog<ResponseDetails>(
      context: widget._navigatorKey!.currentContext!,
      builder: (context) =>
          ResponseStopperEditorDialog(responseDetails: responseDetails),
    );
  }
}
