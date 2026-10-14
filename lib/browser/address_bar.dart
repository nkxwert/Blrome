import 'package:flutter/material.dart';

/// 상단 주소 표시줄: [왼쪽 아이콘] [입력칸] [trailing...].
///
/// 입력칸은 높이를 고정한 둥근 상자 안에 테두리·여백 없는 TextField를 세로 가운데로
/// 놓는다. TextField 자체 여백에 맡기면 글꼴 크기·화면 밀도에 따라 글자가 위아래로
/// 치우치거나 잘린다.
class AddressBar extends StatelessWidget {
  const AddressBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.leadingIcon,
    required this.onLeadingPressed,
    this.trailing = const [],
  });

  static const height = 40.0;

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final IconData leadingIcon;
  final VoidCallback onLeadingPressed;
  final List<Widget> trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 4, 6),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(height / 2),
              ),
              child: Row(
                children: [
                  // 아이콘을 상자 안쪽 왼쪽에 둔다.
                  SizedBox(
                    width: height,
                    height: height,
                    child: IconButton(
                      tooltip: '사이트 정보',
                      padding: EdgeInsets.zero,
                      iconSize: 18,
                      icon: Icon(leadingIcon, color: scheme.onSurfaceVariant),
                      onPressed: onLeadingPressed,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.go,
                      autocorrect: false,
                      maxLines: 1,
                      textAlignVertical: TextAlignVertical.center,
                      style: TextStyle(fontSize: 15, color: scheme.onSurface),
                      onSubmitted: onSubmitted,
                      decoration: InputDecoration(
                        isCollapsed: true,
                        border: InputBorder.none,
                        hintText: 'Google 검색 또는 URL 입력',
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
              ),
            ),
          ),
          ...trailing,
        ],
      ),
    );
  }
}
