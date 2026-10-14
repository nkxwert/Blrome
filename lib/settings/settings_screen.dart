import 'package:flutter/material.dart';

import '../blrome_controller.dart';
import '../rules/site_rule.dart';
import '../util/format.dart';
import '../widgets/hold_confirm.dart';
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
    if (updated == null || !context.mounted) return;
    // 더 엄하게 바꾸는 건 바로, 느슨하게 바꾸는 건 꾹 눌러야 적용.
    if (loosens(rule, updated)) {
      final ok = await showHoldConfirm(
        context,
        title: '${rule.domain} 규칙 완화',
        message: '${_describe(rule)} → ${_describe(updated)}\n정말 바꿀까요?',
        action: '변경',
      );
      if (!ok) return;
    }
    await controller.upsertRule(updated, replacing: rule.domain);
  }

  Future<void> _remove(BuildContext context, SiteRule rule) async {
    final ok = await showHoldConfirm(
      context,
      title: '${rule.domain} 규칙 삭제',
      message: '정말 이 사이트의 제한을 없앨까요?',
      action: '삭제',
    );
    if (ok) await controller.removeRule(rule.domain);
  }

  Future<void> _unlock(BuildContext context, SiteRule rule) async {
    final ok = await showHoldConfirm(
      context,
      title: '${rule.domain} 오늘만 해제',
      message: '오늘 자정(00:00)까지 이 사이트를 제한 없이 쓸 수 있어요.\n정말 해제할까요?',
      action: '해제',
    );
    if (ok) await controller.unlockToday(rule.domain);
  }

  static String _describe(SiteRule r) => r.mode == RuleMode.alwaysBlock
      ? '${r.domain} 항상 차단'
      : '${r.domain} 하루 ${formatDuration(r.limitSeconds!)}';

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
