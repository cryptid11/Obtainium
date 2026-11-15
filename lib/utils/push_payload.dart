const int maxPushPayloadLength = 2048;
const String pushPayloadParam = 'pushPayload';
const String pushInstallParam = 'pushInstall';

final RegExp _githubShorthand = RegExp(r'^[A-Za-z0-9-]+/[A-Za-z0-9._-]+$');
final RegExp _scheme = RegExp(r'^[a-z][a-z0-9+.-]*://');
final RegExp _trailingSlashes = RegExp(r'/+$');

String? normalizePushUrl(String url) {
  var s = url.trim().toLowerCase();
  if (s.isEmpty || (!_scheme.hasMatch(s) && !s.contains('/'))) {
    return null;
  }
  s = s.replaceFirst(_scheme, '').split(RegExp(r'[?#]')).first;
  if (s.startsWith('www.')) {
    s = s.substring(4);
  }
  s = s.replaceFirst(_trailingSlashes, '');
  if (s.endsWith('.git')) {
    s = s.substring(0, s.length - 4).replaceFirst(_trailingSlashes, '');
  }
  if (!s.split('/').first.contains('.')) {
    return null;
  }
  return s;
}

List<String> matchPushPayload(String payload, Map<String, String> appUrlsById) {
  final text = payload.trim();
  if (text.isEmpty ||
      text.length > maxPushPayloadLength ||
      text.contains(RegExp(r'\s'))) {
    return [];
  }
  if (appUrlsById.containsKey(text)) {
    return [text];
  }
  final target = normalizePushUrl(
    _githubShorthand.hasMatch(text) ? 'github.com/$text' : text,
  );
  if (target == null) {
    return [];
  }
  var bestLength = 0;
  var matches = <String>[];
  appUrlsById.forEach((id, url) {
    final appUrl = normalizePushUrl(url);
    if (appUrl == null ||
        (target != appUrl && !target.startsWith('$appUrl/'))) {
      return;
    }
    if (appUrl.length > bestLength) {
      bestLength = appUrl.length;
      matches = [id];
    } else if (appUrl.length == bestLength) {
      matches.add(id);
    }
  });
  return matches;
}

Map<String, dynamic> pushCheckParams(List<String> appIds) => {
  'toCheck': appIds.map((id) => {'key': id, 'value': 0}).toList(),
  pushInstallParam: true,
};
