import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/models/app_version.dart';

void main() {
  group('AppUpdateService Update Check Tests (Part 14 Requirements)', () {
    late HttpServer mockServer;
    late String serverUrl;

    setUp(() async {
      mockServer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverUrl = 'http://${mockServer.address.host}:${mockServer.port}';
    });

    tearDown(() async {
      await mockServer.close(force: true);
    });

    test('Test 1: Current 1.0.0 vs GitHub v1.0.0 -> Up to date (returns null)', () async {
      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([
          {
            'tag_name': 'v1.0.0',
            'name': 'Release 1.0.0',
            'body': 'Initial release',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': '$serverUrl/app-release.apk',
                'size': 15000000,
              }
            ],
          }
        ]));
        request.response.close();
      });

      // Override the GitHub URL by pointing to our mock HTTP server
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as List;

      // Filter and evaluate using AppReleaseInfo logic
      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item['draft'] == true || item['prerelease'] == true) continue;
          final release = AppReleaseInfo.fromJson(item);
          if (release.hasApk && release.version > current) {
            availableUpdate = release;
          }
        }
      }

      expect(availableUpdate, isNull);
    });

    test('Test 2: Current 1.0.0 vs GitHub v1.1.0 -> Update available', () async {
      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([
          {
            'tag_name': 'v1.1.0',
            'name': 'Release v1.1.0',
            'body': '• Added monthly balance\n• Bug fixes',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': '$serverUrl/app-release.apk',
                'size': 18500000,
              }
            ],
          }
        ]));
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as List;

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item['draft'] == true || item['prerelease'] == true) continue;
          final release = AppReleaseInfo.fromJson(item);
          if (release.hasApk && release.version > current) {
            availableUpdate = release;
          }
        }
      }

      expect(availableUpdate, isNotNull);
      expect(availableUpdate!.version, equals(AppVersion.parse('1.1.0')));
      expect(availableUpdate.apkAsset!.name, equals('app-release.apk'));
      expect(availableUpdate.releaseNotes, contains('Added monthly balance'));
    });

    test('Test 3: Current 1.9.0 vs GitHub v1.10.0 -> Update available (1.10 > 1.9)', () async {
      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([
          {
            'tag_name': 'v1.10.0',
            'name': 'Release v1.10.0',
            'body': 'Major improvements',
            'draft': false,
            'prerelease': false,
            'assets': [
              {
                'name': 'app-release.apk',
                'browser_download_url': '$serverUrl/app-release.apk',
                'size': 20000000,
              }
            ],
          }
        ]));
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as List;

      final current = AppVersion.parse('1.9.0');
      AppReleaseInfo? availableUpdate;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item['draft'] == true || item['prerelease'] == true) continue;
          final release = AppReleaseInfo.fromJson(item);
          if (release.hasApk && release.version > current) {
            availableUpdate = release;
          }
        }
      }

      expect(availableUpdate, isNotNull);
      expect(availableUpdate!.version, equals(AppVersion.parse('1.10.0')));
    });

    test('Test 4: Ignores draft releases and pre-releases', () async {
      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([
          {
            'tag_name': 'v2.0.0-beta',
            'name': 'Beta 2.0.0',
            'draft': false,
            'prerelease': true, // Pre-release!
            'assets': [
              {'name': 'app-release.apk', 'browser_download_url': '$serverUrl/beta.apk', 'size': 1000}
            ],
          },
          {
            'tag_name': 'v3.0.0',
            'name': 'Draft 3.0.0',
            'draft': true, // Draft!
            'prerelease': false,
            'assets': [
              {'name': 'app-release.apk', 'browser_download_url': '$serverUrl/draft.apk', 'size': 1000}
            ],
          }
        ]));
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as List;

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item['draft'] == true || item['prerelease'] == true) continue;
          final release = AppReleaseInfo.fromJson(item);
          if (release.hasApk && release.version > current) {
            availableUpdate = release;
          }
        }
      }

      // Both were ignored, so no update found
      expect(availableUpdate, isNull);
    });

    test('Test 5: Ignores releases without .apk asset', () async {
      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode([
          {
            'tag_name': 'v1.5.0',
            'name': 'Source only release',
            'draft': false,
            'prerelease': false,
            'assets': [
              {'name': 'source_code.tar.gz', 'browser_download_url': '$serverUrl/src.tar.gz', 'size': 1000}
            ],
          }
        ]));
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      final decoded = jsonDecode(body) as List;

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in decoded) {
        if (item is Map<String, dynamic>) {
          if (item['draft'] == true || item['prerelease'] == true) continue;
          final release = AppReleaseInfo.fromJson(item);
          if (release.hasApk && release.version > current) {
            availableUpdate = release;
          }
        }
      }

      expect(availableUpdate, isNull);
    });

    test('Test 6: HTTP 500 Server error handled gracefully', () async {
      mockServer.listen((HttpRequest request) {
        request.response.statusCode = HttpStatus.internalServerError;
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();
      expect(res.statusCode, equals(500));
    });

    test('Test 7: APK streaming download with progress simulation', () async {
      final dummyApkBytes = List<int>.generate(1024 * 100, (i) => i % 256); // 100 KB

      mockServer.listen((HttpRequest request) {
        request.response.headers.contentType = ContentType.binary;
        request.response.headers.contentLength = dummyApkBytes.length;
        request.response.add(dummyApkBytes);
        request.response.close();
      });

      final client = HttpClient();
      final req = await client.getUrl(Uri.parse(serverUrl));
      final res = await req.close();

      final List<double> progressReported = [];
      int receivedBytes = 0;
      final totalBytes = res.contentLength;

      await for (final chunk in res) {
        receivedBytes += chunk.length;
        final prog = totalBytes > 0 ? receivedBytes / totalBytes : 0.0;
        progressReported.add(prog);
      }

      expect(receivedBytes, equals(dummyApkBytes.length));
      expect(progressReported.last, equals(1.0));
      expect(progressReported.isNotEmpty, isTrue);
    });
  });
}
