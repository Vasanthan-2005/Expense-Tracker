import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/models/app_version.dart';

void main() {
  group('Semantic Version Parsing & Comparison Tests (User Requirements)', () {
    test('1.2.0 < 1.3.0', () {
      final v1 = AppVersion.parse('1.2.0');
      final v2 = AppVersion.parse('1.3.0');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
      expect(v1 == v2, isFalse);
    });

    test('1.9.0 < 1.10.0', () {
      final v1 = AppVersion.parse('1.9.0');
      final v2 = AppVersion.parse('1.10.0');
      expect(v1 < v2, isTrue);
      expect(v2 > v1, isTrue);
    });

    test('1.10.0 > 1.9.0', () {
      final v1 = AppVersion.parse('1.10.0');
      final v2 = AppVersion.parse('1.9.0');
      expect(v1 > v2, isTrue);
      expect(v2 < v1, isTrue);
    });

    test('2.0.0 > 1.99.99', () {
      final v1 = AppVersion.parse('2.0.0');
      final v2 = AppVersion.parse('1.99.99');
      expect(v1 > v2, isTrue);
      expect(v2 < v1, isTrue);
    });

    test('Strip leading "v" or "V" from GitHub tags', () {
      final v1 = AppVersion.parse('v1.2.0');
      final v2 = AppVersion.parse('1.2.0');
      final v3 = AppVersion.parse('V1.2.0');

      expect(v1.major, equals(1));
      expect(v1.minor, equals(2));
      expect(v1.patch, equals(0));

      expect(v1 == v2, isTrue);
      expect(v3 == v2, isTrue);
      expect(v1.semVerOnly, equals('1.2.0'));
    });

    test('Handle pubspec version with build number e.g. 1.0.0+1', () {
      final v1 = AppVersion.parse('1.0.0+1');
      expect(v1.major, equals(1));
      expect(v1.minor, equals(0));
      expect(v1.patch, equals(0));
      expect(v1.buildNumber, equals(1));

      final v2 = AppVersion.parse('1.1.0');
      expect(v1 < v2, isTrue);

      final v3 = AppVersion.parse('1.0.0+2');
      expect(v1 < v3, isTrue);
    });

    test('Identical versions evaluate as equal', () {
      final v1 = AppVersion.parse('1.0.0');
      final v2 = AppVersion.parse('v1.0.0');
      expect(v1 >= v2, isTrue);
      expect(v1 <= v2, isTrue);
      expect(v1 > v2, isFalse);
      expect(v1 < v2, isFalse);
    });

    test('Short versions (e.g. 1.0) normalized with patch 0', () {
      final v1 = AppVersion.parse('1.0');
      expect(v1.major, equals(1));
      expect(v1.minor, equals(0));
      expect(v1.patch, equals(0));
    });
  });

  group('GitHub Release Info JSON Parsing Tests', () {
    test('Parses stable release with attached .apk asset', () {
      final json = {
        'tag_name': 'v1.1.0',
        'name': 'Release v1.1.0 - Monthly Balance',
        'body': 'What\'s new:\n• Added monthly balance\n• Bug fixes',
        'draft': false,
        'prerelease': false,
        'published_at': '2026-09-27T10:00:00Z',
        'html_url': 'https://github.com/Vasanthan-2005/Expense-Tracker/releases/tag/v1.1.0',
        'assets': [
          {
            'name': 'source_code.zip',
            'browser_download_url': 'https://github.com/downloads/src.zip',
            'size': 1024,
            'content_type': 'application/zip',
          },
          {
            'name': 'app-release.apk',
            'browser_download_url': 'https://github.com/downloads/app-release.apk',
            'size': 20971520, // 20 MB
            'content_type': 'application/vnd.android.package-archive',
          },
        ],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.version, equals(AppVersion.parse('1.1.0')));
      expect(release.hasApk, isTrue);
      expect(release.apkAsset!.name, equals('app-release.apk'));
      expect(release.apkAsset!.downloadUrl, equals('https://github.com/downloads/app-release.apk'));
      expect(release.apkAsset!.formattedSize, equals('20.0 MB'));
      expect(release.releaseNotes, contains('Added monthly balance'));
    });

    test('Release without .apk asset reports hasApk = false', () {
      final json = {
        'tag_name': 'v1.0.0',
        'name': 'Initial Release',
        'body': 'First release',
        'draft': false,
        'prerelease': false,
        'html_url': 'https://github.com/Vasanthan-2005/Expense-Tracker/releases/tag/v1.0.0',
        'assets': <dynamic>[],
      };

      final release = AppReleaseInfo.fromJson(json);
      expect(release.hasApk, isFalse);
      expect(release.apkAsset, isNull);
    });
  });
}
