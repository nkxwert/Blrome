import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'quotes.dart';

/// 버튼을 [hold] 동안 계속 누르고 있어야 확인되는 대화상자.
/// 누르는 동안 명언을 보여 준다. 중간에 손을 떼면 처음부터 다시.
Future<bool> showHoldConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
  Duration hold = const Duration(seconds: 10),
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (_) => _HoldConfirmDialog(
      title: title,
      message: message,
      action: action,
      hold: hold,
    ),
  );
  return result ?? false;
}

class _HoldConfirmDialog extends StatefulWidget {
  const _HoldConfirmDialog({
    required this.title,
    required this.message,
    required this.action,
    required this.hold,
  });

  final String title;
  final String message;
  final String action;
  final Duration hold;

  @override
  State<_HoldConfirmDialog> createState() => _HoldConfirmDialogState();
}

class _HoldConfirmDialogState extends State<_HoldConfirmDialog>
    with SingleTickerProviderStateMixin {
  late final _progress = AnimationController(vsync: this, duration: widget.hold)
    ..addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        HapticFeedback.heavyImpact();
        Navigator.pop(context, true);
      }
    });
  (String, String)? _quote;

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _start() {
    HapticFeedback.selectionClick();
    setState(() => _quote = randomQuote());
    _progress.forward(from: 0);
  }

  void _stop() {
    if (_progress.isCompleted) return;
    _progress.stop();
    _progress.animateBack(0, duration: const Duration(milliseconds: 250));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final quote = _quote;
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.message),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: quote == null
                ? Text(
                    '아래 버튼을 ${widget.hold.inSeconds}초 동안 꾹 누르세요',
                    key: const ValueKey('hint'),
                    style: theme.textTheme.bodySmall,
                  )
                : Column(
                    key: ValueKey(quote),
                    children: [
                      Text(
                        '“${quote.$1}”',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontStyle: FontStyle.italic),
                      ),
                      const SizedBox(height: 6),
                      Text('— ${quote.$2}', style: theme.textTheme.bodySmall),
                    ],
                  ),
          ),
          const SizedBox(height: 20),
          Listener(
            onPointerDown: (_) => _start(),
            onPointerUp: (_) => _stop(),
            onPointerCancel: (_) => _stop(),
            child: AnimatedBuilder(
              animation: _progress,
              builder: (context, _) {
                final left = (widget.hold.inMilliseconds *
                            (1 - _progress.value) /
                            1000)
                        .ceil();
                return SizedBox(
                  width: 96,
                  height: 96,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox.expand(
                        child: CircularProgressIndicator(
                          value: _progress.value,
                          strokeWidth: 6,
                          backgroundColor:
                              theme.colorScheme.surfaceContainerHighest,
                          color: theme.colorScheme.error,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.touch_app, color: theme.colorScheme.error),
                          Text(
                            _progress.value == 0 ? widget.action : '$left',
                            style: theme.textTheme.labelLarge,
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
      ],
    );
  }
}
