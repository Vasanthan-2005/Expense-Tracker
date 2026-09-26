import 'package:flutter_test/flutter_test.dart';

import 'package:expense_tracker/models/app_version.dart';
import 'package:expense_tracker/services/app_update_service.dart';

void main() {
  group('AppUpdateService Update Check Tests (Part 14 Requirements)', () {
    test('Test 1: Current 1.0.0 vs GitHub v1.0.0 -> Up to date (returns null)', () {
      final releasesJson = [
        {
          'tag_name': 'v1.0.0',
          'name': 'Release 1.0.0',
          'body': 'Initial release',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://github.com/Vasanthan-2005/Expense-Tracker/releases/download/v1.0.0/app-release.apk',
              'size': 15000000,
            }
          ],
        }
      ];

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk && release.version > current) {
          availableUpdate = release;
        }
      }

      expect(availableUpdate, isNull);
    });

    test('Test 2: Current 1.0.0 vs GitHub v1.1.0 -> Update available', () {
      final releasesJson = [
        {
          'tag_name': 'v1.1.0',
          'name': 'Release v1.1.0',
          'body': '• Added monthly balance\n• Bug fixes',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://github.com/Vasanthan-2005/Expense-Tracker/releases/download/v1.1.0/app-release.apk',
              'size': 18500000,
            }
          ],
        }
      ];

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk && release.version > current) {
          availableUpdate = release;
        }
      }

      expect(availableUpdate, isNotNull);
      expect(availableUpdate!.version, equals(AppVersion.parse('1.1.0')));
      expect(availableUpdate.apkAsset!.name, equals('app-release.apk'));
      expect(availableUpdate.releaseNotes, contains('Added monthly balance'));
    });

    test('Test 3: Current 1.9.0 vs GitHub v1.10.0 -> Update available (1.10.0 > 1.9.0)', () {
      final releasesJson = [
        {
          'tag_name': 'v1.10.0',
          'name': 'Release v1.10.0',
          'body': 'Major improvements',
          'draft': false,
          'prerelease': false,
          'assets': [
            {
              'name': 'app-release.apk',
              'browser_download_url': 'https://github.com/Vasanthan-2005/Expense-Tracker/releases/download/v1.10.0/app-release.apk',
              'size': 20000000,
            }
          ],
        }
      ];

      final current = AppVersion.parse('1.9.0');
      AppReleaseInfo? availableUpdate;
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk && release.version > current) {
          availableUpdate = release;
        }
      }

      expect(availableUpdate, isNotNull);
      expect(availableUpdate!.version, equals(AppVersion.parse('1.10.0')));
    });

    test('Test 4: Ignores draft releases and pre-releases', () {
      final releasesJson = [
        {
          'tag_name': 'v2.0.0-beta',
          'name': 'Beta 2.0.0',
          'draft': false,
          'prerelease': true,
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://github.com/beta.apk', 'size': 1000}
          ],
        },
        {
          'tag_name': 'v3.0.0',
          'name': 'Draft 3.0.0',
          'draft': true,
          'prerelease': false,
          'assets': [
            {'name': 'app-release.apk', 'browser_download_url': 'https://github.com/draft.apk', 'size': 1000}
          ],
        }
      ];

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk && release.version > current) {
          availableUpdate = release;
        }
      }

      expect(availableUpdate, isNull);
    });

    test('Test 5: Ignores releases without .apk asset', () {
      final releasesJson = [
        {
          'tag_name': 'v1.5.0',
          'name': 'Source only release',
          'draft': false,
          'prerelease': false,
          'assets': [
            {'name': 'source_code.tar.gz', 'browser_download_url': 'https://github.com/src.tar.gz', 'size': 1000}
          ],
        }
      ];

      final current = AppVersion.parse('1.0.0');
      AppReleaseInfo? availableUpdate;
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk && release.version > current) {
          availableUpdate = release;
        }
      }

      expect(availableUpdate, isNull);
    });

    test('Test 6: Multiple releases sorted descending by semantic version', () {
      final releasesJson = [
        {
          'tag_name': 'v1.1.0',
          'name': 'v1.1.0',
          'draft': false,
          'prerelease': false,
          'assets': [{'name': 'app-release.apk', 'browser_download_url': 'url1', 'size': 1000}],
        },
        {
          'tag_name': 'v1.3.0',
          'name': 'v1.3.0',
          'draft': false,
          'prerelease': false,
          'assets': [{'name': 'app-release.apk', 'browser_download_url': 'url3', 'size': 1000}],
        },
        {
          'tag_name': 'v1.2.0',
          'name': 'v1.2.0',
          'draft': false,
          'prerelease': false,
          'assets': [{'name': 'app-release.apk', 'browser_download_url': 'url2', 'size': 1000}],
        },
      ];

      final List<AppReleaseInfo> stableReleases = [];
      for (final item in releasesJson) {
        if (item['draft'] == true || item['prerelease'] == true) continue;
        final release = AppReleaseInfo.fromJson(item);
        if (release.hasApk) stableReleases.add(release);
      }

      stableReleases.sort((a, b) => b.version.compareTo(a.version));
      expect(stableReleases.first.version, equals(AppVersion.parse('1.3.0')));
    });

    test('Test 7: UpdateException formats message correctly', () {
      const ex = UpdateException('Network connection failed');
      expect(ex.toString(), equals('Network connection failed'));
      expect(ex.message, equals('Network connection failed'));
    });

    test('Test 8: AppUpdateService constants are properly configured', () {
      expect(AppUpdateService.repoOwner, equals('Vasanthan-2005'));
      expect(AppUpdateService.repoName, equals('Expense-Tracker'));
      expect(AppUpdateService.releasesApiUrl, contains('api.github.com/repos/Vasanthan-2005/Expense-Tracker/releases'));
    });
  });
}
