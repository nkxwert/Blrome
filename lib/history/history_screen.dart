import 'package:flutter/material.dart';

import '../blrome_controller.dart';
import '../util/format.dart';
import 'history_store.dart';

/// 방문 기록 화면. 항목을 누르면 그 주소를 돌려준다.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key, required this.history});

  final HistoryStore history;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _query = '';

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('방문 기록 전체 삭제'),
        content: const Text('모든 방문 기록을 지울까요?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok ?? false) await widget.history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('방문 기록'),
        actions: [
          IconButton(
            tooltip: '전체 삭제',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: TextField(
              decoration: const InputDecoration(
                isDense: true,
                prefixIcon: Icon(Icons.search, size: 20),
                hintText: '제목이나 주소로 검색',
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: ListenableBuilder(
              listenable: widget.history,
              builder: (context, _) {
                final entries = widget.history.entries
                    .where((e) =>
                        _query.isEmpty ||
                        e.url.toLowerCase().contains(_query) ||
                        e.title.toLowerCase().contains(_query))
                    .toList();
                if (entries.isEmpty) {
                  return const Center(child: Text('방문 기록이 없어요'));
                }
                final rows = <Widget>[];
                String? day;
                for (final e in entries) {
                  final d = BlromeController.dateKey(e.time);
                  if (d != day) {
                    day = d;
                    rows.add(Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                      child: Text(formatDayLabel(e.time),
                          style: theme.textTheme.titleSmall
                              ?.copyWith(color: theme.colorScheme.primary)),
                    ));
                  }
                  rows.add(ListTile(
                    dense: true,
                    leading: const Icon(Icons.public, size: 20),
                    title: Text(
                      e.title.isEmpty ? e.url : e.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${formatClock(e.time)} · ${Uri.tryParse(e.url)?.host ?? e.url}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: IconButton(
                      tooltip: '삭제',
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => widget.history.remove(e),
                    ),
                    onTap: () => Navigator.pop(context, e.url),
                  ));
                }
                return ListView(children: rows);
              },
            ),
          ),
        ],
      ),
    );
  }
}
