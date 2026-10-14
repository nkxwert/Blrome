import 'package:flutter/material.dart';

import '../rules/domain_matcher.dart';
import '../rules/site_rule.dart';

/// 규칙을 추가하거나 고치는 대화상자. 취소하면 null.
Future<SiteRule?> showRuleEditDialog(BuildContext context, {SiteRule? initial}) {
  return showDialog<SiteRule>(
    context: context,
    builder: (_) => _RuleEditDialog(initial: initial),
  );
}

class _RuleEditDialog extends StatefulWidget {
  const _RuleEditDialog({this.initial});

  final SiteRule? initial;

  @override
  State<_RuleEditDialog> createState() => _RuleEditDialogState();
}

class _RuleEditDialogState extends State<_RuleEditDialog> {
  static const presets = [15, 30, 60, 120];

  late final _domain = TextEditingController(text: widget.initial?.domain);
  late final _minutes = TextEditingController(
      text: '${widget.initial?.limitMinutes ?? 30}');
  late RuleMode _mode = widget.initial?.mode ?? RuleMode.dailyLimit;
  String? _domainError;
  String? _minutesError;

  @override
  void dispose() {
    _domain.dispose();
    _minutes.dispose();
    super.dispose();
  }

  void _save() {
    final domain = normalizeDomain(_domain.text);
    final minutes = int.tryParse(_minutes.text.trim());
    setState(() {
      _domainError = domain == null ? '올바른 도메인을 입력하세요 (예: youtube.com)' : null;
      _minutesError = _mode == RuleMode.dailyLimit &&
              (minutes == null || minutes < 1 || minutes > 24 * 60)
          ? '1 ~ 1440분 사이로 입력하세요'
          : null;
    });
    if (_domainError != null || _minutesError != null) return;
    Navigator.pop(
      context,
      SiteRule(
        domain: domain!,
        mode: _mode,
        limitMinutes: _mode == RuleMode.dailyLimit ? minutes : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.initial == null ? '사이트 추가' : '사이트 수정'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _domain,
              autofocus: widget.initial == null,
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
              TextField(
                controller: _minutes,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: '하루 사용 시간 (분)',
                  helperText: '매일 자정(00:00)에 초기화돼요',
                  errorText: _minutesError,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in presets)
                    ActionChip(
                      label: Text(m < 60 ? '$m분' : '${m ~/ 60}시간'),
                      onPressed: () => setState(() => _minutes.text = '$m'),
                    ),
                ],
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
        FilledButton(onPressed: _save, child: const Text('저장')),
      ],
    );
  }
}
