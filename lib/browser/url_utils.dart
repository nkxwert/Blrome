const homeUrl = 'https://www.google.com/';

/// 주소창 입력을 URL로 바꾼다. URL처럼 보이지 않으면 Google 검색 URL.
String inputToUrl(String input) {
  final text = input.trim();
  if (text.isEmpty) return homeUrl;

  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(text);
  if (hasScheme && !text.contains(' ')) {
    final uri = Uri.tryParse(text);
    if (uri != null && (uri.scheme == 'http' || uri.scheme == 'https' || uri.scheme == 'about')) {
      // "localhost:8080" 같은 입력은 스킴으로 오인되므로 아래로 넘긴다.
      if (uri.scheme != 'about' && uri.host.isEmpty) {
        return _search(text);
      }
      return text;
    }
  }

  final looksLikeHost = !text.contains(' ') &&
      RegExp(r'^(localhost|[^/\s]+\.[a-zA-Z]{2,}|\d{1,3}(\.\d{1,3}){3})(:\d+)?([/?#].*)?$')
          .hasMatch(text);
  if (looksLikeHost) return 'https://$text';

  return _search(text);
}

String _search(String query) =>
    'https://www.google.com/search?q=${Uri.encodeQueryComponent(query)}';
