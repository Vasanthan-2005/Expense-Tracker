class AppVersion implements Comparable<AppVersion> {
  final int major;
  final int minor;
  final int patch;
  final int? buildNumber;
  final String raw;

  const AppVersion({
    required this.major,
    required this.minor,
    required this.patch,
    this.buildNumber,
    required this.raw,
  });

  /// Parses a version string like '1.2.0', 'v1.3.0', '1.0.0+1', or 'v2.1'.
  factory AppVersion.parse(String versionString) {
    String clean = versionString.trim();
    if (clean.toLowerCase().startsWith('v')) {
      clean = clean.substring(1).trim();
    }

    int? buildNum;
    if (clean.contains('+')) {
      final plusIndex = clean.indexOf('+');
      final buildStr = clean.substring(plusIndex + 1);
      clean = clean.substring(0, plusIndex);
      buildNum = int.tryParse(buildStr);
    }

    final segments = clean.split('.');
    final major = segments.isNotEmpty ? int.tryParse(segments[0]) ?? 0 : 0;
    final minor = segments.length > 1 ? int.tryParse(segments[1]) ?? 0 : 0;
    final patch = segments.length > 2 ? int.tryParse(segments[2]) ?? 0 : 0;

    return AppVersion(
      major: major,
      minor: minor,
      patch: patch,
      buildNumber: buildNum,
      raw: versionString,
    );
  }

  @override
  int compareTo(AppVersion other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    if (patch != other.patch) return patch.compareTo(other.patch);

    if (buildNumber != null && other.buildNumber != null) {
      return buildNumber!.compareTo(other.buildNumber!);
    }
    return 0;
  }

  bool operator >(AppVersion other) => compareTo(other) > 0;
  bool operator <(AppVersion other) => compareTo(other) < 0;
  bool operator >=(AppVersion other) => compareTo(other) >= 0;
  bool operator <=(AppVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppVersion &&
        major == other.major &&
        minor == other.minor &&
        patch == other.patch &&
        buildNumber == other.buildNumber;
  }

  @override
  int get hashCode => Object.hash(major, minor, patch, buildNumber);

  @override
  String toString() {
    if (buildNumber != null) {
      return '$major.$minor.$patch+$buildNumber';
    }
    return '$major.$minor.$patch';
  }

  String get semVerOnly => '$major.$minor.$patch';
}

class ReleaseAssetInfo {
  final String name;
  final String downloadUrl;
  final int sizeBytes;
  final String contentType;

  const ReleaseAssetInfo({
    required this.name,
    required this.downloadUrl,
    required this.sizeBytes,
    required this.contentType,
  });

  factory ReleaseAssetInfo.fromJson(Map<String, dynamic> json) {
    return ReleaseAssetInfo(
      name: json['name'] as String? ?? 'app-release.apk',
      downloadUrl: json['browser_download_url'] as String? ?? '',
      sizeBytes: (json['size'] as num?)?.toInt() ?? 0,
      contentType: json['content_type'] as String? ?? 'application/vnd.android.package-archive',
    );
  }

  String get formattedSize {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024 * 1024) {
      final kb = sizeBytes / 1024;
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = sizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class AppReleaseInfo {
  final AppVersion version;
  final String tagName;
  final String title;
  final String releaseNotes;
  final DateTime? publishedAt;
  final ReleaseAssetInfo? apkAsset;
  final String htmlUrl;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.releaseNotes,
    this.publishedAt,
    this.apkAsset,
    required this.htmlUrl,
  });

  bool get hasApk => apkAsset != null && apkAsset!.downloadUrl.isNotEmpty;

  factory AppReleaseInfo.fromJson(Map<String, dynamic> json) {
    final tagName = json['tag_name'] as String? ?? '';
    final version = AppVersion.parse(tagName);
    final title = json['name'] as String? ?? tagName;
    final notes = json['body'] as String? ?? '';
    final htmlUrl = json['html_url'] as String? ?? '';

    DateTime? publishedDate;
    final publishedStr = json['published_at'] as String?;
    if (publishedStr != null) {
      publishedDate = DateTime.tryParse(publishedStr);
    }

    // Find .apk asset
    ReleaseAssetInfo? apkAsset;
    final assets = json['assets'] as List<dynamic>? ?? [];
    for (final a in assets) {
      if (a is Map<String, dynamic>) {
        final name = (a['name'] as String? ?? '').toLowerCase();
        if (name.endsWith('.apk')) {
          apkAsset = ReleaseAssetInfo.fromJson(a);
          // If it's specifically app-release.apk, prefer it immediately
          if (name == 'app-release.apk') {
            break;
          }
        }
      }
    }

    return AppReleaseInfo(
      version: version,
      tagName: tagName,
      title: title,
      releaseNotes: notes,
      publishedAt: publishedDate,
      apkAsset: apkAsset,
      htmlUrl: htmlUrl,
    );
  }
}
