import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:requests_inspector/requests_inspector.dart';

final navigatorKey = GlobalKey<NavigatorState>();

void main() {
  runApp(
    const MyApp(),
  );
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  List<Post> posts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    // IMPORTANT: `RequestsInspector` (further down the widget tree) is what
    // constructs the real `InspectorController(enabled: true, ...)` singleton.
    // Calling anything that touches `InspectorController()` before that widget
    // has actually built (e.g. synchronously here in initState) creates the
    // singleton early with the factory's defaults instead - silently
    // disabling logging for the rest of the app's lifetime. Deferring to a
    // post-frame callback guarantees `RequestsInspector` has mounted first.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      fetchPostsUsingInterceptor().then(
        (value) => setState(() {
          posts = value;
          isLoading = false;
        }),
      );
      /*for restful apis Interceptor example use => fetchPostsUsingInterceptor() */
      fetchPostsUsingHttpClient();
      _demoQueryMethod();
      _demoSseLogs();
      _demoFileLogging();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Fetch Data Example',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: false),
      builder: (context, child) {
        // Add your `navigatorKey` to enable `Stopper` feature
        return RequestsInspector(
          enabled: true,
          navigatorKey: navigatorKey,
          child: child!,
        );
      },
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Fetch Data Example'),
          leading: InkWell(
            child: const Padding(
              padding: EdgeInsets.all(8.0),
              child: Icon(Icons.refresh),
            ),
            onTap: () {
              setState(() => isLoading = true);
              fetchPostsUsingInterceptor().then(
                (value) => setState(() {
                  posts = value;
                  isLoading = false;
                }),
              );
            },
          ),
        ),
        body: Center(
          child: () {
            if (isLoading) return const CircularProgressIndicator();

            if (posts.isNotEmpty) {
              return PostsListWidget(
                postsList: posts,
                onRefresh: () => fetchPostsUsingInterceptor().then(
                  (value) => setState(() => posts = value),
                ),
              );
            }

            return const Text('Empty list (error)');

            // By default, show a loading spinner.
          }(),
        ),
      ),
    );
  }

  /// Demoes the automatic "Files" tab for file types beyond the avatar
  /// images already shown via `Image.network` in [_PostItemBuilder] - no
  /// wrapper needed, `RequestsInspectorHttpOverrides` observes every
  /// `dart:io` `HttpClient` request in the app. `HEAD` requests are used
  /// here purely to keep this demo lightweight (no body downloaded); the
  /// Files tab only ever inspects response headers regardless of verb.
  void _demoFileLogging() {
    const sampleFileUrls = [
      'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf', // PDF
      'https://www.w3schools.com/html/mov_bbb.mp4', // Video
      'https://www.w3schools.com/html/horse.mp3', // Audio
      'https://fonts.gstatic.com/s/roboto/v30/KFOmCnqEu92Fr1Mu4mxK.ttf', // Font
    ];

    for (final url in sampleFileUrls) {
      _headRequest(url);
    }
  }

  Future<void> _headRequest(String url) async {
    try {
      final request = await HttpClient().headUrl(Uri.parse(url));
      await request.close();
    } catch (_) {
      // Demo only - a flaky sample URL shouldn't break the example app.
    }
  }

  /// Demoes the SSE logs feature: each `SseLogController.log` call gets
  /// grouped into a connection item in the Inspector's "All" tab.
  void _demoSseLogs() {
    SseLogController.log('CONNECTING -> wss://example.com/stream/prices');
    SseLogController.log('event: price_update {"symbol":"BTC","price":67210}');
    SseLogController.log('event: price_update {"symbol":"ETH","price":3190}');
    Future.delayed(const Duration(seconds: 2), () {
      SseLogController.log('CONNECTING -> wss://example.com/stream/orders');
      SseLogController.log('event: order_filled {"id":42}');
      SseLogController.log('CLOSED');
    });
  }
}

// Fetching methods
/// Demoes the new `QUERY` method (a read-only request that carries a body,
/// unlike GET). Logged manually since dio/http don't have a `.query()` verb.
void _demoQueryMethod() {
  InspectorController().addNewRequest(
    RequestDetails(
      requestName: 'Search Posts',
      requestMethod: RequestMethod.QUERY,
      url: 'https://dummyjson.com/posts/search',
      requestBody: {'query': 'flutter', 'limit': 10},
      statusCode: 200,
      responseBody: {'total': 3},
    ),
  );
}

Future<List<Post>> fetchPostsUsingInterceptor() async {
  final dio = Dio(
    BaseOptions(
      validateStatus: (_) => true,
      // Headers added to bypass CloudFlare protection
      headers: {
        'User-Agent':
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
                '(KHTML, like Gecko) Chrome/115.0.0.0 Safari/537.36',
        'Accept': 'application/json, text/plain, */*',
        'Accept-Language': 'en-US,en;q=0.9',
      },
    ),
  )..interceptors.add(RequestsInspectorInterceptor());
  final params = {'userId': 1};

  final response = await dio.get(
    'https://dummyjson.com/posts',
    queryParameters: params,
    // The request does no need the body, but added for TESTING
  );

  final posts =
      List.from(response.data['posts']).map((e) => Post.fromMap(e)).toList();

  return posts;
}

/// for `package:http` Interceptor example use => fetchPostsUsingHttpClient()
Future<List<Post>> fetchPostsUsingHttpClient() async {
  final client = HttpInspectorClient(http.Client());
  final response = await client.get(
    Uri.parse('https://dummyjson.com/posts?userId=1'),
  );

  final posts = List.from(json.decode(response.body)['posts'])
      .map((e) => Post.fromMap(e))
      .toList();

  return posts;
}

// Post model
class Post {
  final int id;
  final String title;
  final String body;

  Post({
    required this.id,
    required this.title,
    required this.body,
  });

  Post copyWith({int? id, String? title, String? body}) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
    );
  }

  Map<String, dynamic> toMap() {
    return {'id': id, 'title': title, 'body': body};
  }

  factory Post.fromMap(Map<String, dynamic> map) {
    return Post(
      id: int.tryParse(map['id'].toString()) ?? 0,
      title: map['title'] ?? '',
      body: map['body'] ?? '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Post.fromJson(String source) => Post.fromMap(json.decode(source));

  @override
  String toString() {
    return 'Post(id: $id, title: $title, body: $body)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Post &&
        other.id == id &&
        other.title == title &&
        other.body == body;
  }

  @override
  int get hashCode {
    return id.hashCode ^ title.hashCode ^ body.hashCode;
  }
}

// Posts widget
class PostsListWidget extends StatelessWidget {
  const PostsListWidget({
    Key? key,
    required this.postsList,
    required this.onRefresh,
  }) : super(key: key);

  final RefreshCallback onRefresh;

  final List<Post> postsList;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.builder(
        shrinkWrap: true,
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: postsList.length,
        itemBuilder: (context, index) =>
            _PostItemBuilder(post: postsList[index]),
      ),
    );
  }
}

class _PostItemBuilder extends StatelessWidget {
  const _PostItemBuilder({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8.0),
        child: Image.network(
          'https://picsum.photos/seed/${post.id}/80/80',
          width: 48.0,
          height: 48.0,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            width: 48.0,
            height: 48.0,
            color: Colors.grey[300],
            child: const Icon(Icons.image_not_supported_outlined),
          ),
        ),
      ),
      title: Text(post.title),
      subtitle: Text(post.body),
    );
  }
}
