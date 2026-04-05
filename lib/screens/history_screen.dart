import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/history_entry.dart';
import '../data/history_repository.dart';
import '../models/analysis_models.dart';
import '../theme/agri_theme.dart';
import 'results_screen.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<HistoryEntry> _entries = [];
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await HistoryRepository.loadEntries();
    if (!mounted) return;
    setState(() {
      _entries = list;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMd().add_jm();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan history'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      'No saved scans yet.\nComplete an analysis — it is stored here automatically.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _entries.length,
                    itemBuilder: (context, i) {
                      final e = _entries[i];
                      final h = CropHealthLevel.values[e.cropHealthIndex.clamp(0, 2)];
                      final hc = AgriTheme.healthColor(h);
                      return Dismissible(
                        key: Key(e.id),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          color: Theme.of(context).colorScheme.errorContainer,
                          child: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
                        ),
                        onDismissed: (_) async {
                          await HistoryRepository.deleteEntry(e);
                          setState(() => _entries.removeAt(i));
                        },
                        child: Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: hc.withValues(alpha: 0.2),
                              child: Icon(Icons.eco, color: hc, size: 22),
                            ),
                            title: Text(e.diseaseLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              '${df.format(e.createdAt.toLocal())} · Q${e.photoQualityScore} · '
                              '${(e.diseaseConfidence * 100).toStringAsFixed(0)}% confidence',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final report = await HistoryRepository.reportForEntry(e);
                              if (!context.mounted || report == null) return;
                              await Navigator.of(context).push<void>(
                                MaterialPageRoute<void>(
                                  builder: (_) => ResultsScreen(report: report, persistToHistory: false),
                                ),
                              );
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
