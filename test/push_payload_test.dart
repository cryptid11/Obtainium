import 'package:flutter_test/flutter_test.dart';
import 'package:obtainium/utils/push_payload.dart';

void main() {
  const apps = {
    'com.example.app': 'https://github.com/Owner/Repo',
    'com.example.other': 'https://github.com/owner/other-repo',
    'org.fdroid.thing': 'https://f-droid.org/packages/org.fdroid.thing',
    'com.example.free': 'https://gitlab.com/group/split',
    'com.example.pro': 'https://gitlab.com/group/split',
  };
  List<String> match(String payload) => matchPushPayload(payload, apps);

  group('matchPushPayload', () {
    test('matches an exact package ID', () {
      expect(match('com.example.app'), ['com.example.app']);
    });

    test('trims surrounding whitespace and newlines', () {
      expect(match('  com.example.app\n'), ['com.example.app']);
    });

    test('does not match a package ID case-insensitively', () {
      expect(match('COM.EXAMPLE.APP'), isEmpty);
    });

    test('matches a repository URL regardless of case and decoration', () {
      const expected = ['com.example.app'];
      for (final payload in [
        'https://github.com/owner/repo',
        'http://www.github.com/OWNER/REPO/',
        'https://github.com/owner/repo.git',
        'github.com/owner/repo',
        'https://github.com/owner/repo?tab=readme#top',
      ]) {
        expect(match(payload), expected, reason: payload);
      }
    });

    test('matches a release page below the repository URL', () {
      const release = 'https://github.com/owner/repo/releases/tag/v1.2.3';
      expect(match(release), ['com.example.app']);
    });

    test('matches GitHub owner/repo shorthand', () {
      expect(match('owner/other-repo'), ['com.example.other']);
    });

    test('does not match a repository that only shares a prefix', () {
      expect(match('https://github.com/owner/rep'), isEmpty);
      expect(match('https://github.com/owner/repository'), isEmpty);
    });

    test('returns every app tracked from the same URL', () {
      const both = ['com.example.free', 'com.example.pro'];
      expect(match('https://gitlab.com/group/split'), unorderedEquals(both));
    });

    test('prefers the most specific app URL', () {
      const nested = {
        'com.example.root': 'https://example.com/apps',
        'com.example.child': 'https://example.com/apps/child',
      };
      const child = 'https://example.com/apps/child/v2';
      const other = 'https://example.com/apps/other';
      expect(matchPushPayload(child, nested), ['com.example.child']);
      expect(matchPushPayload(other, nested), ['com.example.root']);
    });

    test('ignores unknown, empty, oversized or multi-word payloads', () {
      expect(match('com.unknown.app'), isEmpty);
      expect(match(''), isEmpty);
      expect(match('   '), isEmpty);
      expect(match('com.example.app extra'), isEmpty);
      expect(match('a' * (maxPushPayloadLength + 1)), isEmpty);
      expect(match('https://gitlab.com/other/x'), isEmpty);
    });
  });

  group('normalizePushUrl', () {
    test('rejects values that are not URLs', () {
      expect(normalizePushUrl('com.example.app'), isNull);
      expect(normalizePushUrl('owner/repo'), isNull);
      expect(normalizePushUrl(''), isNull);
    });

    test('strips scheme, www, query, fragment, slashes and .git', () {
      const url = 'HTTPS://www.GitHub.com/Owner/Repo.git/?x=1#y';
      expect(normalizePushUrl(url), 'github.com/owner/repo');
    });
  });

  test('pushCheckParams builds a check-and-install task', () {
    const a = {'key': 'a', 'value': 0};
    const b = {'key': 'b', 'value': 0};
    final params = pushCheckParams(['a', 'b']);
    expect(params['toCheck'], [a, b]);
    expect(params[pushInstallParam], isTrue);
  });
}
