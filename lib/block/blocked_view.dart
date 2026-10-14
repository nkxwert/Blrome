import 'package:flutter/material.dart';

import '../rules/rule_engine.dart';
import '../util/format.dart';

/// 차단된 사이트 대신 보여 주는 화면.
class BlockedView extends StatelessWidget {
  const BlockedView({
    super.key,
    required this.domain,
    required this.reason,
    this.limitMinutes,
    required this.onGoHome,
    required this.onOpenSettings,
  });

  final String domain;
  final BlockReason reason;
  final int? limitMinutes;
  final VoidCallback onGoHome;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = switch (reason) {
      BlockReason.alwaysBlocked => '설정에서 차단한 사이트예요.',
      BlockReason.limitReached =>
        '오늘 사용 시간(${formatDuration((limitMinutes ?? 0) * 60)})을 다 썼어요.\n'
            '자정(00:00)에 다시 열려요.',
    };

    return ColoredBox(
      color: theme.colorScheme.surface,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                reason == BlockReason.alwaysBlocked
                    ? Icons.block
                    : Icons.hourglass_bottom,
                size: 72,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 24),
              Text(domain, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 32),
              FilledButton.icon(
                onPressed: onGoHome,
                icon: const Icon(Icons.home),
                label: const Text('Google 홈으로'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: onOpenSettings,
                child: const Text('차단 설정'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
