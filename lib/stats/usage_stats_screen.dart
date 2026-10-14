import 'dart:math';

import 'package:flutter/material.dart';

import '../blrome_controller.dart';
import '../util/format.dart';

/// 날짜별 사이트 사용 시간: 왼쪽은 사이트 목록, 오른쪽은 10분 단위 시간표.
class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key, required this.controller});

  final BlromeController controller;

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

/// 사이트 구분색 (사용 시간 1~8위). 9위부터는 회색으로 묶는다.
const _lightColors = [
  Color(0xFF2A78D6), Color(0xFFEB6834), Color(0xFF1BAF7A), Color(0xFFEDA100),
  Color(0xFFE87BA4), Color(0xFF008300), Color(0xFF6250D6), Color(0xFFE34948),
];
const _darkColors = [
  Color(0xFF3987E5), Color(0xFFD95926), Color(0xFF199E70), Color(0xFFC98500),
  Color(0xFFD55181), Color(0xFF008300), Color(0xFF9085E9), Color(0xFFE66767),
];

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  late String _day = widget.controller.todayKey;

  BlromeController get _c => widget.controller;

  List<String> get _days {
    final days = {..._c.usageDays, _c.todayKey}.toList()..sort();
    return days;
  }

  void _move(int delta) {
    final days = _days;
    final i = days.indexOf(_day) + delta;
    if (i >= 0 && i < days.length) setState(() => _day = days[i]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('사용 시간')),
      body: ListenableBuilder(
        listenable: _c,
        builder: (context, _) => _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final palette = dark ? _darkColors : _lightColors;
    final other = theme.colorScheme.outline;

    final usage = _c.usageForDay(_day);
    final sites = usage.keys.toList()
      ..sort((a, b) => usage[b]!.compareTo(usage[a]!));
    final total = usage.values.fold(0, (a, b) => a + b);
    Color colorOf(String site) {
      final i = sites.indexOf(site);
      return i >= 0 && i < palette.length ? palette[i] : other;
    }

    final days = _days;
    final dayIndex = days.indexOf(_day);
    final date = DateTime.parse(_day);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 16, 8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: dayIndex > 0 ? () => _move(-1) : null,
              ),
              Text(formatDayLabel(date), style: theme.textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: dayIndex < days.length - 1 ? () => _move(1) : null,
              ),
              const Spacer(),
              Text(formatDuration(total), style: theme.textTheme.titleLarge),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 24),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final gridWidth = min(constraints.maxWidth * 0.48, 260.0);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: sites.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text('기록이 없어요',
                                  style: theme.textTheme.bodyMedium),
                            )
                          : Column(
                              children: [
                                for (final site in sites)
                                  _SiteRow(
                                    site: site,
                                    seconds: usage[site]!,
                                    color: colorOf(site),
                                  ),
                              ],
                            ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: gridWidth,
                      child: _TimeGrid(
                        slots: _c.slotsForDay(_day),
                        colorOf: colorOf,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _SiteRow extends StatelessWidget {
  const _SiteRow({required this.site, required this.seconds, required this.color});

  final String site;
  final int seconds;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(site,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium),
          ),
          Text(
            formatHms(seconds),
            style: theme.textTheme.bodySmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 24시간 × 6칸(10분). 각 칸은 그 10분 동안 쓴 시간만큼 왼쪽부터 사이트 색으로 채운다.
class _TimeGrid extends StatelessWidget {
  const _TimeGrid({required this.slots, required this.colorOf});

  final Map<int, Map<String, int>> slots;
  final Color Function(String site) colorOf;

  static const _cols = 60 ~/ BlromeController.slotMinutes;
  static const _slotSeconds = BlromeController.slotMinutes * 60;
  static const _cellHeight = 26.0;
  static const _labelWidth = 24.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final line = theme.colorScheme.outlineVariant;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: line)),
      child: Column(
        children: [
          for (var hour = 0; hour < 24; hour++)
            SizedBox(
              height: _cellHeight,
              child: Row(
                // 칸들이 줄 높이를 꽉 채우도록 늘린다.
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: _labelWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: line),
                        bottom: hour < 23 ? BorderSide(color: line) : BorderSide.none,
                      ),
                    ),
                    child: Text('$hour',
                        style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant)),
                  ),
                  for (var col = 0; col < _cols; col++)
                    Expanded(
                      child: _cell(
                        hour * _cols + col,
                        Border(
                          right: col < _cols - 1
                              ? BorderSide(color: line, width: 0.5)
                              : BorderSide.none,
                          bottom: hour < 23 ? BorderSide(color: line) : BorderSide.none,
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _cell(int slot, Border border) {
    final sites = slots[slot];
    if (sites == null || sites.isEmpty) {
      return DecoratedBox(decoration: BoxDecoration(border: border));
    }
    final entries = sites.entries.toList()..sort((a, b) => b.value - a.value);
    final start = slot * BlromeController.slotMinutes;
    final from = '${start ~/ 60}:${(start % 60).toString().padLeft(2, '0')}';
    return Tooltip(
      triggerMode: TooltipTriggerMode.tap,
      message: '$from~\n${entries.map((e) => '${e.key} ${formatDuration(e.value)}').join('\n')}',
      child: DecoratedBox(
        decoration: BoxDecoration(border: border),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              var left = width;
              final segments = <Widget>[];
              for (final e in entries) {
                if (left <= 0) break;
                // 몇 초만 써도 보이도록 최소 2px, 칸을 넘치지 않게 남은 폭까지.
                final w = min(left, max(2.0, width * e.value / _slotSeconds));
                segments.add(Container(width: w, color: colorOf(e.key)));
                left -= w;
              }
              return Row(children: segments);
            },
          ),
        ),
      ),
    );
  }
}
