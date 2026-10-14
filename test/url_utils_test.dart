import 'package:blrome/browser/url_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('URL은 그대로, 도메인은 https를 붙인다', () {
    expect(inputToUrl('https://naver.com/a'), 'https://naver.com/a');
    expect(inputToUrl('youtube.com'), 'https://youtube.com');
    expect(inputToUrl('m.youtube.com/watch?v=1'), 'https://m.youtube.com/watch?v=1');
    expect(inputToUrl('localhost:8080'), 'https://localhost:8080');
  });

  test('나머지는 Google 검색', () {
    expect(inputToUrl('블롬 브라우저'),
        'https://www.google.com/search?q=${Uri.encodeQueryComponent('블롬 브라우저')}');
    expect(inputToUrl('flutter'), 'https://www.google.com/search?q=flutter');
    expect(inputToUrl(''), homeUrl);
  });
}
