import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// The system as the API sees it: `GET /api/status`.
class SystemStatus {
  const SystemStatus({
    required this.name,
    required this.version,
    required this.startedAt,
    required this.uptime,
    required this.database,
    required this.openMetadata,
    this.dataSources = 0,
  });

  factory SystemStatus.fromJson(Map<String, Object?> json) => SystemStatus(
    name: json['name'] as String? ?? '',
    version: json['version'] as String? ?? '',
    startedAt: DateTime.tryParse(json['startedAt'] as String? ?? ''),
    uptime: Duration(seconds: (json['uptimeSeconds'] as num?)?.toInt() ?? 0),
    database: Dependency.fromJson(json['database']),
    openMetadata: Dependency.fromJson(json['openmetadata']),
    dataSources: (json['dataSources'] as num?)?.toInt() ?? 0,
  );

  final String name;
  final String version;
  final DateTime? startedAt;
  final Duration uptime;
  final Dependency database;
  final Dependency openMetadata;
  final int dataSources;
}

/// A dependency's part of the status: ok, its version, or the error.
class Dependency {
  const Dependency({required this.ok, this.version, this.url, this.error});

  factory Dependency.fromJson(Object? json) {
    final map = (json as Map?)?.cast<String, Object?>() ?? const {};
    return Dependency(
      ok: map['ok'] == true,
      version: map['version'] as String?,
      url: map['url'] as String?,
      error: map['error'] as String?,
    );
  }

  final bool ok;
  final String? version;
  final String? url;
  final String? error;
}

/// How the API authenticates: `GET /api/auth/config`. Off until the API
/// has a client id; on, the issuer (Google) and the OpenID Connect client id
/// the app signs in with.
class AuthConfig {
  const AuthConfig({required this.enabled, required this.issuer, this.clientId});

  factory AuthConfig.fromJson(Map<String, Object?> json) => AuthConfig(
    enabled: json['enabled'] == true,
    issuer: json['issuer'] as String? ?? '',
    clientId: json['clientId'] as String?,
  );

  final bool enabled;
  final String issuer;
  final String? clientId;
}

/// Who the API says is calling: `GET /api/me`.
class Me {
  const Me({required this.authenticated, this.subject, this.email, this.name, this.picture});

  factory Me.fromJson(Map<String, Object?> json) => Me(
    authenticated: json['authenticated'] == true,
    subject: json['subject'] as String?,
    email: json['email'] as String?,
    name: json['name'] as String?,
    picture: json['picture'] as String?,
  );

  final bool authenticated;
  final String? subject;
  final String? email;
  final String? name;
  final String? picture;
}

/// The kinds of data source the API keeps, as its JSON names them.
enum DataSourceType {
  database('database', 'Database'),
  s3('s3', 'S3 bucket'),
  filesystem('filesystem', 'Filesystem');

  const DataSourceType(this.json, this.label);
  final String json;
  final String label;

  static DataSourceType parse(String? json) =>
      values.firstWhere((t) => t.json == json, orElse: () => filesystem);
}

/// A data source on record: `GET /api/datasources`. The access details come
/// under a key named after the type, without their secrets (the API answers
/// `passwordSet` and `secretAccessKeySet` instead).
class DataSource {
  const DataSource({
    required this.id,
    required this.name,
    required this.type,
    this.description,
    this.createdAt,
    this.createdBy,
    this.createdByName,
    this.details = const {},
  });

  factory DataSource.fromJson(Map<String, Object?> json) {
    final type = DataSourceType.parse(json['type'] as String?);
    return DataSource(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      type: type,
      description: json['description'] as String?,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? ''),
      createdBy: json['createdBy'] as String?,
      createdByName: json['createdByName'] as String?,
      details: (json[type.json] as Map?)?.cast<String, Object?>() ?? const {},
    );
  }

  final int id;
  final String name;
  final DataSourceType type;
  final String? description;
  final DateTime? createdAt;
  final String? createdBy;
  final String? createdByName;
  final Map<String, Object?> details;

  /// One line saying where it points, as the API describes it.
  String get summary {
    switch (type) {
      case DataSourceType.database:
        final user = details['username'];
        return '${details['engine']}://${details['host']}:${details['port']}/${details['database']}'
            '${user == null ? '' : ' as $user'}';
      case DataSourceType.s3:
        final region = details['region'];
        final endpoint = details['endpoint'];
        return 's3://${details['bucket']}/${details['prefix'] ?? ''}'
            '${region == null ? '' : ' ($region)'}${endpoint == null ? '' : ' at $endpoint'}';
      case DataSourceType.filesystem:
        return '${details['path']}';
    }
  }
}

/// What `POST /api/datasources` takes: the name, the type, a description and
/// the access details of that type, which the body carries under the type's
/// own key.
class NewDataSource {
  const NewDataSource({
    required this.name,
    required this.type,
    this.description,
    required this.details,
  });

  final String name;
  final DataSourceType type;
  final String? description;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => {
    'name': name,
    'type': type.json,
    if (description != null && description!.isNotEmpty) 'description': description,
    type.json: details,
  };
}

/// One call to the API, as the calls panel shows it.
class ApiCall {
  ApiCall({
    required this.method,
    required this.path,
    required this.startedAt,
    this.requestBody,
  });

  final String method;
  final String path;
  final DateTime startedAt;
  final String? requestBody;
  int? status;
  String? responseBody;
  String? error;
  Duration? elapsed;

  bool get ok => error == null && status != null && status! >= 200 && status! < 300;
  bool get pending => elapsed == null;
}

/// Every call made, newest first; the calls panel listens.
class CallLog extends ChangeNotifier {
  static const int keep = 100;
  final List<ApiCall> _calls = [];

  List<ApiCall> get calls => List.unmodifiable(_calls);

  ApiCall start(String method, String path, {String? requestBody}) {
    final call = ApiCall(
      method: method,
      path: path,
      startedAt: DateTime.now(),
      requestBody: requestBody,
    );
    _calls.insert(0, call);
    if (_calls.length > keep) _calls.removeRange(keep, _calls.length);
    notifyListeners();
    return call;
  }

  void finish(ApiCall call, {int? status, String? body, String? error}) {
    call.status = status;
    call.responseBody = body;
    call.error = error;
    call.elapsed = DateTime.now().difference(call.startedAt);
    notifyListeners();
  }

  void clear() {
    _calls.clear();
    notifyListeners();
  }
}

/// Thrown when the API answers outside 2xx, or can't be reached.
class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  @override
  String toString() => message;
}

/// What the dashboard asks the API. [HttpDatyxApi] is the real one; tests
/// pass a fake.
abstract class DatyxApi {
  CallLog get log;
  Future<AuthConfig> authConfig();
  Future<Me> me();
  Future<SystemStatus> status();
  Future<List<DataSource>> dataSources({int limit = 100});
  Future<DataSource> addDataSource(NewDataSource source);
  Future<void> removeDataSource(int id);
}

/// Gives the bearer token for a call, or null for none.
typedef TokenProvider = Future<String?> Function();

/// The keys whose values never reach the calls panel.
const secretKeys = {'password', 'secretAccessKey'};

/// A copy of a request body with its secrets replaced, for the log.
Object? redacted(Object? body) {
  if (body is Map) {
    return {
      for (final entry in body.entries)
        entry.key: secretKeys.contains(entry.key) && entry.value != null
            ? '••••••'
            : redacted(entry.value),
    };
  }
  if (body is List) return [for (final item in body) redacted(item)];
  return body;
}

/// The API over HTTP. [baseUrl] is API_BASE_URL at build time: empty, the
/// app's own origin (the dev server and the web server proxy /api/ there).
/// [token] gives the signed-in user's ID token, sent as `Authorization:
/// Bearer` when there is one; after a 401, [refreshToken] is asked once for
/// a fresh one and the call is retried. A call that takes longer than
/// [timeout] fails. The log gets request bodies with their secrets
/// replaced ([redacted]).
class HttpDatyxApi implements DatyxApi {
  HttpDatyxApi({
    String? baseUrl,
    http.Client? client,
    CallLog? log,
    this.token,
    this.refreshToken,
    this.timeout = const Duration(seconds: 20),
  }) : baseUrl = baseUrl ?? const String.fromEnvironment('API_BASE_URL'),
       _client = client ?? http.Client(),
       log = log ?? CallLog();

  final String baseUrl;
  final http.Client _client;
  final TokenProvider? token;
  final TokenProvider? refreshToken;
  final Duration timeout;
  @override
  final CallLog log;

  Uri _uri(String path, [Map<String, String>? query]) {
    final base = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    return Uri.parse('$base$path').replace(queryParameters: query);
  }

  Future<Object?> _send(
    String method,
    String path, {
    Map<String, String>? query,
    Object? body,
  }) async {
    final uri = _uri(path, query);
    final requestBody = body == null ? null : jsonEncode(body);
    final loggedBody = body == null ? null : jsonEncode(redacted(body));
    final shown = query == null || query.isEmpty
        ? path
        : '$path?${Uri(queryParameters: query).query}';
    var bearer = await token?.call();
    var retried = false;
    while (true) {
      final call = log.start(method, shown, requestBody: loggedBody);
      http.Response response;
      try {
        final request = http.Request(method, uri);
        if (requestBody != null) {
          request.headers['content-type'] = 'application/json';
          request.body = requestBody;
        }
        if (bearer != null && bearer.isNotEmpty) {
          request.headers['authorization'] = 'Bearer $bearer';
        }
        response = await http.Response.fromStream(
          await _client.send(request).timeout(timeout),
        ).timeout(timeout);
      } catch (e) {
        log.finish(call, error: e.toString());
        throw ApiException('$method $path failed: $e');
      }
      log.finish(call, status: response.statusCode, body: response.body);
      if (response.statusCode == 401 && bearer != null && !retried && refreshToken != null) {
        // An expired token: a fresh one, once.
        retried = true;
        final fresh = await refreshToken!.call();
        if (fresh != null && fresh != bearer) {
          bearer = fresh;
          continue;
        }
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw ApiException(
          '$method $path answered ${response.statusCode}',
          status: response.statusCode,
        );
      }
      return response.body.isEmpty ? null : jsonDecode(response.body);
    }
  }

  @override
  Future<AuthConfig> authConfig() async =>
      AuthConfig.fromJson((await _send('GET', '/api/auth/config') as Map).cast());

  @override
  Future<Me> me() async => Me.fromJson((await _send('GET', '/api/me') as Map).cast());

  @override
  Future<List<DataSource>> dataSources({int limit = 100}) async {
    final json = await _send('GET', '/api/datasources', query: {'limit': '$limit'});
    return [
      for (final item in json as List)
        DataSource.fromJson((item as Map).cast<String, Object?>()),
    ];
  }

  @override
  Future<DataSource> addDataSource(NewDataSource source) async {
    final json = await _send('POST', '/api/datasources', body: source.toJson());
    return DataSource.fromJson((json as Map).cast<String, Object?>());
  }

  @override
  Future<void> removeDataSource(int id) async {
    await _send('DELETE', '/api/datasources/$id');
  }

  @override
  Future<SystemStatus> status() async =>
      SystemStatus.fromJson((await _send('GET', '/api/status') as Map).cast());
}
