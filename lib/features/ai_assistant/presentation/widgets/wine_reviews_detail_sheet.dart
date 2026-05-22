import 'package:flutter/material.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';

/// Bottom sheet with tabbed panels showing detailed wine reviews from
/// Vivino, CellarTracker and/or web sources.
class WineReviewsDetailSheet extends StatelessWidget {
  final VivinoSearchResult? vivinoResult;
  final CellarTrackerResult? cellarTrackerResult;
  final List<String> webSources;

  const WineReviewsDetailSheet({
    super.key,
    this.vivinoResult,
    this.cellarTrackerResult,
    this.webSources = const [],
  });

  // ---------------------------------------------------------------------------

  static void show(
    BuildContext context, {
    VivinoSearchResult? vivinoResult,
    CellarTrackerResult? cellarTrackerResult,
    List<String> webSources = const [],
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => WineReviewsDetailSheet(
        vivinoResult: vivinoResult,
        cellarTrackerResult: cellarTrackerResult,
        webSources: webSources,
      ),
    );
  }

  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final tabs = _buildTabs();
    final panels = _buildPanels(context);

    return DefaultTabController(
      length: tabs.length,
      child: DraggableScrollableSheet(
        initialChildSize: 0.6,
        minChildSize: 0.35,
        maxChildSize: 0.9,
        expand: false,
        builder: (_, scrollController) => Column(
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Avis détaillés',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            const SizedBox(height: 8),
            TabBar(tabs: tabs),
            Expanded(
              child: TabBarView(children: panels),
            ),
          ],
        ),
      ),
    );
  }

  List<Tab> _buildTabs() {
    final tabs = <Tab>[];
    if (vivinoResult != null) {
      final avg = vivinoResult!.ratingsAverage;
      final label =
          avg != null ? 'Vivino  ★${avg.toStringAsFixed(1)}' : 'Vivino';
      tabs.add(Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wine_bar, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ));
    }
    if (cellarTrackerResult != null) {
      final score = cellarTrackerResult!.communityScore;
      final label = score != null
          ? 'CellarTracker  ${score.toStringAsFixed(0)}/100'
          : 'CellarTracker';
      tabs.add(Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2, size: 14),
            const SizedBox(width: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ));
    }
    if (webSources.isNotEmpty) {
      tabs.add(const Tab(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.travel_explore, size: 14),
            SizedBox(width: 4),
            Text('Sources web', style: TextStyle(fontSize: 12)),
          ],
        ),
      ));
    }
    return tabs;
  }

  List<Widget> _buildPanels(BuildContext context) {
    final panels = <Widget>[];
    if (vivinoResult != null) panels.add(_VivinoPanel(result: vivinoResult!));
    if (cellarTrackerResult != null) {
      panels.add(_CellarTrackerPanel(result: cellarTrackerResult!));
    }
    if (webSources.isNotEmpty) panels.add(_WebSourcesPanel(sources: webSources));
    return panels;
  }
}

// ---------------------------------------------------------------------------
// Vivino panel
// ---------------------------------------------------------------------------

class _VivinoPanel extends StatelessWidget {
  final VivinoSearchResult result;
  const _VivinoPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final reviews = result.reviews;
    if (reviews.isEmpty) {
      return const Center(child: Text('Aucun avis disponible.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: reviews.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = reviews[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  ...[
                    Icon(Icons.star_rounded,
                        size: 14, color: Colors.amber.shade700),
                    const SizedBox(width: 2),
                    Text(
                      r.rating.toStringAsFixed(1),
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (r.language != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        r.language!.toUpperCase(),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  const Spacer(),
                  if (r.createdAt != null)
                    Text(
                      _formatDate(r.createdAt!),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
              if (r.note != null && r.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(r.note!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        );
      },
    );
  }

  String _formatDate(String raw) {
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

// ---------------------------------------------------------------------------
// CellarTracker panel
// ---------------------------------------------------------------------------

class _CellarTrackerPanel extends StatelessWidget {
  final CellarTrackerResult result;
  const _CellarTrackerPanel({required this.result});

  @override
  Widget build(BuildContext context) {
    final notes = result.notes;
    if (notes.isEmpty) {
      return const Center(child: Text('Aucun avis disponible.'));
    }
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: notes.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final n = notes[i];
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (n.rating != null) ...[
                    const Icon(Icons.wine_bar, size: 14, color: Colors.purple),
                    const SizedBox(width: 2),
                    Text(
                      '${n.rating!.toStringAsFixed(0)}/100',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                  ],
                  if (n.author != null)
                    Text(
                      n.author!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            fontStyle: FontStyle.italic,
                          ),
                    ),
                ],
              ),
              if (n.note != null && n.note!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(n.note!, style: const TextStyle(fontSize: 13)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Web sources panel
// ---------------------------------------------------------------------------

class _WebSourcesPanel extends StatelessWidget {
  final List<String> sources;
  const _WebSourcesPanel({required this.sources});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: sources.length,
      itemBuilder: (_, i) => ListTile(
        leading: const Icon(Icons.link, size: 18),
        title: Text(sources[i], style: const TextStyle(fontSize: 13)),
        dense: true,
      ),
    );
  }
}
