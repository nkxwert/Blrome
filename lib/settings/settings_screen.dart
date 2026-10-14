import 'dart:async';

import 'package:flutter/material.dart';

import '../blrome_controller.dart';
import '../rules/site_rule.dart';
import '../util/format.dart';
import 'rule_edit_dialog.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final BlromeController controller;

  Future<void> _add(BuildContext context) async {
    final rule = await showRuleEditDialog(context);
    if (rule != null) await controller.upsertRule(rule);
  }

  Future<void> _edit(BuildContext context, SiteRule rule) async {
    final updated = await showRuleEditDialog(context, initial: rule);
    if (updated != null) {
      await controller.upsertRule(updated, replacing: rule.domain);
    }
  }

  Future<void> _remove(BuildContext context, SiteRule rule) async {
    final ok = await _confirmWithDelay(
      context,
      title: '${rule.domain} 규칙 삭제',
      message: '정말 이 사이트의 제한을 없앨까요?',
      action: '삭제',
    );
    if (ok) await controller.removeRule(rule.domain);
  }

  Future<void> _unlock(BuildContext context, SiteRule rule) async {
    final ok = await _confirmWithDelay(
      context,
      title: '${rule.domain} 오늘만 해제',
      message: '오늘 자정(00:00)까지 이 사이트를 제한 없이 쓸 수 있어요.\n정말 해제할까요?',
      action: '해제',
    );
    if (ok) await controller.unlockToday(rule.domain);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사이트 차단 · 시간 제한')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('사이트 추가'),
      ),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final rules = controller.rules;
          if (rules.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  '아직 등록한 사이트가 없어요.\n'
                  '"사이트 추가"로 차단하거나 하루 사용 시간을 정해 보세요.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 96),
            itemCount: rules.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _RuleTile(
              rule: rules[i],
              controller: controller,
              onEdit: () => _edit(context, rules[i]),
              onRemove: () => _remove(context, rules[i]),
              onUnlock: () => _unlock(context, rules[i]),
            ),
          );
        },
      ),
    );
  }
}

class _RuleTile extends StatelessWidget {
  const _RuleTile({
    required this.rule,
    required this.controller,
    required this.onEdit,
    required this.onRemove,
    required this.onUnlock,
  });

  final SiteRule rule;
  final BlromeController controller;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  final VoidCallback onUnlock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final unlocked = controller.isUnlockedToday(rule.domain);
    final decision = controller.decide(rule.domain);

    final Widget subtitle;
    if (rule.mode == RuleMode.alwaysBlock) {
      subtitle = Text(unlocked ? '항상 차단 · 오늘은 해제됨' : '항상 차단');
    } else {
      final used = controller.usedSecondsToday(rule.domain);
      final limit = rule.limitSeconds!;
      subtitle = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('하루 ${formatDuration(limit)} · 오늘 ${formatDuration(used)} 사용'
              '${unlocked ? ' · 오늘은 해제됨' : ''}'),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: (used / limit).clamp(0.0, 1.0),
            color: decision.blocked ? theme.colorScheme.error : null,
          ),
        ],
      );
    }

    return ListTile(
      leading: Icon(
        rule.mode == RuleMode.alwaysBlock ? Icons.block : Icons.hourglass_bottom,
        color: decision.blocked ? theme.colorScheme.error : null,
      ),
      title: Text(rule.domain),
      subtitle: subtitle,
      onTap: onEdit,
      trailing: PopupMenuButton<String>(
        onSelected: (v) => switch (v) {
          'edit' => onEdit(),
          'unlock' => onUnlock(),
          _ => onRemove(),
        },
        itemBuilder: (_) => [
          const PopupMenuItem(value: 'edit', child: Text('수정')),
          if (!unlocked)
            const PopupMenuItem(value: 'unlock', child: Text('오늘만 해제')),
          const PopupMenuItem(value: 'remove', child: Text('삭제')),
        ],
      ),
    );
  }
}

/// 충동적으로 해제하지 않도록 [seconds]초를 기다려야 확인 버튼이 눌리는 대화상자.
Future<bool> _confirmWithDelay(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  int seconds = 10,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _DelayedConfirmDialog(
      title: title,
      message: message,
      action: action,
      seconds: seconds,
    ),
  );
  return result ?? false;
}

class _DelayedConfirmDialog extends StatefulWidget {
  const _DelayedConfirmDialog({
    required this.title,
    required this.message,
    required this.action,
    required this.seconds,
  });

  final String title;
  final String message;
  final String action;
  final int seconds;

  @override
  State<_DelayedConfirmDialog> createState() => _DelayedConfirmDialogState();
}

class _DelayedConfirmDialogState extends State<_DelayedConfirmDialog> {
  late int _left = widget.seconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      setState(() => _left--);
      if (_left <= 0) t.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Text(widget.message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _left > 0 ? null : () => Navigator.pop(context, true),
          child: Text(_left > 0 ? '${widget.action} ($_left)' : widget.action),
        ),
      ],
    );
  }
}
