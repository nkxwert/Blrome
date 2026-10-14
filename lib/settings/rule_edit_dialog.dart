import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../rules/domain_matcher.dart';
import '../rules/site_rule.dart';

/// 규칙을 추가하거나 고치는 대화상자. 취소하면 null.
///
/// [domain]을 주면 새 규칙의 도메인 칸을 채워 둔다.
Future<SiteRule?> showRuleEditDialog(
  BuildContext context, {
  SiteRule? initial,
  String? domain,
}) {
  return showDialog<SiteRule>(
    context: context,
    builder: (_) => _RuleEditDialog(initial: initial, domain: domain),
  );
}

class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog({this.initial, this.domain});

  final SiteRule? initial;
  final String? domain;

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  static const presets = [15, 30, 60, 120];
  static const step = 5;

  late final _domain =
      TextEditingController(text: widget.initial?.domain ?? widget.domain);
  late RuleMode _mode = widget.initial?.mode ?? RuleMode.dailyLimit;

  /// 다이얼 값(분). 다이얼이 5분 단위라 그에 맞춘다.
  late int _minutes = _snap(widget.initial?.limitMinutes ?? 30);

  /// 프리셋을 누르면 다이얼을 새로 만들어 위치를 옮긴다.
  int _pickerKey = 0;
  String? _domainError;

  static int _snap(int m) => ((m / step).round() * step).clamp(step, 23 * 60 + 55);

  @override
  void dispose() {
    _domain.dispose();
    super.dispose();
  }

  void _save() {
    final domain = normalizeDomain(_domain.text);
    setState(() {
      _domainError = domain == null ? '올바른 도메인을 입력하세요 (예: youtube.com)' : null;
    });
    if (domain == null) return;
    Navigator.pop(
      context,
      SiteRule(
        domain: domain,
        mode: _mode,
        limitMinutes: _mode == RuleMode.dailyLimit ? _minutes : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(widget.initial == null ? '사이트 추가' : '사이트 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: widget.initial == null && widget.domain == null,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: '도메인',
                hintText: 'youtube.com',
                helperText: '하위 도메인(m.youtube.com 등)도 함께 적용돼요',
                errorText: _domainError,
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<RuleMode>(
              segments: const [
                ButtonSegment(
                  value: RuleMode.dailyLimit,
                  icon: Icon(Icons.hourglass_bottom),
                  label: Text('하루 제한'),
                ),
                ButtonSegment(
                  value: RuleMode.alwaysBlock,
                  icon: Icon(Icons.block),
                  label: Text('항상 차단'),
                ),
              ],
              selected: {_mode},
              onSelectionChanged: (s) => setState(() => _mode = s.first),
            ),
            if (_mode == RuleMode.dailyLimit) ...[
              const SizedBox(height: 16),
              Text('하루 사용 시간', style: theme.textTheme.labelLarge),
              SizedBox(
                height: 150,
                child: CupertinoTheme(
                  data: CupertinoThemeData(brightness: theme.brightness),
                  child: CupertinoTimerPicker(
                    key: ValueKey(_pickerKey),
                    mode: CupertinoTimerPickerMode.hm,
                    minuteInterval: step,
                    initialTimerDuration: Duration(minutes: _minutes),
                    onTimerDurationChanged: (d) =>
                        setState(() => _minutes = d.inMinutes),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in presets)
                    ChoiceChip(
                      label: Text(m < 60 ? '$m분' : '${m ~/ 60}시간'),
                      selected: _minutes == m,
                      onSelected: (_) => setState(() {
                        _minutes = m;
                        _pickerKey++;
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _minutes == 0 ? '0분은 설정할 수 없어요' : '매일 자정(00:00)에 초기화돼요',
                style: theme.textTheme.bodySmall?.copyWith(
                    color: _minutes == 0 ? theme.colorScheme.error : null),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed:
              _mode == RuleMode.dailyLimit && _minutes == 0 ? null : _save,
          child: const Text('저장'),
        ),
      ],
    );
  }
}
