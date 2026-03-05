import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_card.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/providers/wine_list_provider.dart';

/// Main cellar screen - displays all wines with filtering
class WineListScreen extends ConsumerStatefulWidget {
  const WineListScreen({super.key});

  @override
  ConsumerState<WineListScreen> createState() => _WineListScreenState();
}

class _WineListScreenState extends ConsumerState<WineListScreen> {
  final _searchController = TextEditingController();
  WineFilter _filter = const WineFilter();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final winesAsync = ref.watch(filteredWinesProvider(_filter));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma Cave à Vin'),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'export_json',
                child: ListTile(
                  leading: Icon(Icons.file_download),
                  title: Text('Exporter JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'export_csv',
                child: ListTile(
                  leading: Icon(Icons.table_chart),
                  title: Text('Exporter CSV'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'import_json',
                child: ListTile(
                  leading: Icon(Icons.file_upload),
                  title: Text('Importer JSON'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _filter = _filter.copyWith(clearSearch: true);
                          });
                        },
                      )
                    : null,
              ),
              onChanged: (value) {
                setState(() {
                  if (value.isEmpty) {
                    _filter = _filter.copyWith(clearSearch: true);
                  } else {
                    _filter = WineFilter(searchQuery: value);
                  }
                });
              },
            ),
          ),
          // Filter chips
          _buildFilterChips(),
          // Wine list
          Expanded(
            child: winesAsync.when(
              data: (wines) {
                // Apply maturity filter in-memory if needed
                final filtered = _filter.maturity != null
                    ? wines
                        .where((w) => w.maturity == _filter.maturity)
                        .toList()
                    : wines;

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildWineGrid(context, filtered);
              },
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(
                child: Text('Erreur: $err'),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/chat'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un vin'),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Color filter chips
          ...WineColor.values.map((color) => Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text('${color.emoji} ${color.label}'),
                  selected: _filter.color == color,
                  onSelected: (selected) {
                    setState(() {
                      _filter = selected
                          ? WineFilter(color: color)
                          : const WineFilter();
                    });
                  },
                ),
              )),
          const SizedBox(width: 8),
          // Maturity filter chips
          ...WineMaturity.values
              .where((m) => m != WineMaturity.unknown)
              .map((maturity) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      label: Text('${maturity.emoji} ${maturity.label}'),
                      selected: _filter.maturity == maturity,
                      onSelected: (selected) {
                        setState(() {
                          _filter = selected
                              ? WineFilter(maturity: maturity)
                              : const WineFilter();
                        });
                      },
                    ),
                  )),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wine_bar,
            size: 80,
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucun vin dans votre cave',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Utilisez l\'assistant IA pour ajouter votre premier vin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildWineGrid(BuildContext context, List<WineEntity> wines) {
    final isWide = MediaQuery.of(context).size.width > 600;
    final crossAxisCount = isWide ? 3 : 1;

    if (!isWide) {
      // Mobile: simple list
      return ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: wines.length,
        itemBuilder: (context, index) => WineCard(
          wine: wines[index],
          onTap: () => context.go('/cellar/wine/${wines[index].id}'),
          onQuantityChanged: (newQty) => _updateQuantity(wines[index], newQty),
        ),
      );
    }

    // Desktop: grid
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.5,
      ),
      itemCount: wines.length,
      itemBuilder: (context, index) => WineCard(
        wine: wines[index],
        onTap: () => context.go('/cellar/wine/${wines[index].id}'),
        onQuantityChanged: (newQty) => _updateQuantity(wines[index], newQty),
      ),
    );
  }

  Future<void> _updateQuantity(WineEntity wine, int newQty) async {
    if (wine.id == null) return;

    if (newQty <= 0) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Derni\u00e8re bouteille !'),
          content: Text(
            'La quantit\u00e9 de "${wine.displayName}" va passer \u00e0 0.\n'
            'Que souhaitez-vous faire ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Annuler'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('zero'),
              child: const Text('Garder \u00e0 0'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop('delete'),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Supprimer'),
            ),
          ],
        ),
      );

      if (!mounted || action == null || action == 'cancel') return;

      if (action == 'delete') {
        await ref.read(wineRepositoryProvider).deleteWine(wine.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${wine.displayName}" supprim\u00e9')),
          );
        }
        return;
      }
      // action == 'zero'
    }

    await ref.read(wineRepositoryProvider).updateQuantity(wine.id!, newQty < 0 ? 0 : newQty);
  }

  Future<void> _handleMenuAction(BuildContext context, String action) async {
    final repo = ref.read(wineRepositoryProvider);
    try {
      switch (action) {
        case 'export_json':
          final json = await repo.exportToJson();
          await _saveExport(json, 'cave_export.json');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export JSON réalisé !')),
            );
          }
        case 'export_csv':
          final csv = await repo.exportToCsv();
          await _saveExport(csv, 'cave_export.csv');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Export CSV réalisé !')),
            );
          }
        case 'import_json':
          // TODO: Implement file picker for import
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Import : bientôt disponible')),
            );
          }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: $e')),
        );
      }
    }
  }

  Future<void> _saveExport(String content, String fileName) async {
    // Save to documents directory
    // In a real implementation, use path_provider + File.writeAsString
    // For now the export data is generated, we'll add file saving next
  }
}
