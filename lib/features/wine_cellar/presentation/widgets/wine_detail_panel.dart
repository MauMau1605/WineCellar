import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/theme.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/bottle_placement_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/tasting_window_timeline.dart';

/// Detail panel used in the master-detail layout.
/// Displays a rich summary of the selected wine.
class WineDetailPanel extends ConsumerStatefulWidget {
  final int wineId;
  final VoidCallback? onWineDeleted;

  const WineDetailPanel({
    super.key,
    required this.wineId,
    this.onWineDeleted,
  });

  @override
  ConsumerState<WineDetailPanel> createState() => _WineDetailPanelState();
}

class _WineDetailPanelState extends ConsumerState<WineDetailPanel> {
  WineEntity? _wine;
  List<FoodCategoryEntity> _pairings = const [];
  List<BottlePlacementEntity> _placements = const [];
  Map<int, VirtualCellarEntity> _cellarsById = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadWine();
  }

  @override
  void didUpdateWidget(covariant WineDetailPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.wineId != widget.wineId) {
      setState(() => _loading = true);
      _loadWine();
    }
  }

  Future<void> _loadWine() async {
    final result =
        await ref.read(getWineByIdUseCaseProvider).call(widget.wineId);
    if (!mounted) return;
    result.fold(
      (failure) => setState(() {
        _wine = null;
        _loading = false;
      }),
      (wine) {
        if (wine == null) {
          setState(() {
            _wine = null;
            _loading = false;
          });
          return;
        }
        _loadExtras(wine);
      },
    );
  }

  Future<void> _loadExtras(WineEntity wine) async {
    final categories =
        await ref.read(foodCategoryRepositoryProvider).getAllCategories();
    final pairings = categories
        .where((c) => wine.foodCategoryIds.contains(c.id))
        .toList();

    if (!mounted) return;

    final placementsResult =
        await ref.read(getWinePlacementsUseCaseProvider).call(wine.id!);
    final cellarsResult =
        await ref.read(virtualCellarRepositoryProvider).getAll();

    if (!mounted) return;

    final placements = placementsResult.getOrElse((_) => const []);
    final cellars = cellarsResult.getOrElse((_) => const []);

    setState(() {
      _wine = wine;
      _pairings = pairings;
      _placements = placements;
      _cellarsById = {
        for (final c in cellars)
          if (c.id != null) c.id!: c,
      };
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final wine = _wine;
    if (wine == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wine_bar,
                size: 48,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text('Vin introuvable',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                )),
          ],
        ),
      );
    }

    final wineColor = AppTheme.colorForWine(wine.color.name);

    return GestureDetector(
      onDoubleTap: () => context.go('/cellar/wine/${wine.id}'),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Wine icon
            _buildWineIcon(theme, wine, wineColor),
            const SizedBox(height: 16),

            // Wine name
            Text(
              wine.name,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),

            // Subtitle: appellation · year · color
            Text(
              _buildSubtitle(wine),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Info cards grid
            _buildInfoCards(theme, wine),
            const SizedBox(height: 24),

            // Tasting window timeline
            TastingWindowTimeline(
              vintage: wine.vintage,
              drinkFromYear: wine.drinkFromYear,
              drinkUntilYear: wine.drinkUntilYear,
            ),
            const SizedBox(height: 24),

            // Quantity buttons
            _buildQuantityButtons(theme, wine),
            const SizedBox(height: 24),

            // Additional info sections (scrollable)
            if (wine.grapeVarieties.isNotEmpty)
              _buildChipSection(
                theme,
                'Cépages',
                wine.grapeVarieties
                    .map((g) => Chip(label: Text(g)))
                    .toList(),
              ),

            if (_pairings.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildChipSection(
                theme,
                'Accords mets-vins',
                _pairings
                    .map((p) => Chip(
                          label: Text('${p.icon ?? '🍽️'} ${p.name}'),
                        ))
                    .toList(),
              ),
            ],

            if (wine.tastingNotes != null &&
                wine.tastingNotes!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTextSection(theme, 'Notes de dégustation', wine.tastingNotes!),
            ],

            if (wine.aiDescription != null &&
                wine.aiDescription!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildTextSection(theme, 'Description IA', wine.aiDescription!,
                  italic: true),
            ],

            if (_placements.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildPlacementsSection(theme, wine),
            ],

            // Hint for double-tap
            const SizedBox(height: 24),
            Text(
              'Double-cliquez pour voir la fiche complète',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildWineIcon(ThemeData theme, WineEntity wine, Color wineColor) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: wineColor.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: wineColor.withValues(alpha: 0.3), width: 2),
      ),
      child: Center(
        child: Text(wine.color.emoji, style: const TextStyle(fontSize: 36)),
      ),
    );
  }

  String _buildSubtitle(WineEntity wine) {
    final parts = <String>[];
    if (wine.appellation != null) parts.add(wine.appellation!);
    if (wine.vintage != null) parts.add('${wine.vintage}');
    parts.add(wine.color.label);
    return parts.join(' · ');
  }

  Widget _buildInfoCards(ThemeData theme, WineEntity wine) {
    final placedCount = _placements.length;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _InfoCard(
          label: 'Quantité',
          value: '${wine.quantity}',
          theme: theme,
        ),
        if (wine.location != null)
          _InfoCard(
            label: 'Cellier',
            value: wine.location!,
            theme: theme,
          ),
        _InfoCard(
          label: 'Appellation',
          value: wine.appellation ?? '—',
          theme: theme,
        ),
        _InfoCard(
          label: 'Statut',
          value: wine.maturity.label,
          theme: theme,
          valueColor: _maturityColor(wine.maturity),
        ),
        if (wine.rating != null)
          _InfoCard(
            label: 'Note',
            value: '${'★' * wine.rating!}${'☆' * (5 - wine.rating!)}',
            theme: theme,
          ),
        if (wine.purchasePrice != null)
          _InfoCard(
            label: 'Prix',
            value: '${wine.purchasePrice!.toStringAsFixed(2)} €',
            theme: theme,
          ),
        if (placedCount > 0)
          _InfoCard(
            label: 'Placées',
            value: '$placedCount / ${wine.quantity}',
            theme: theme,
          ),
      ],
    );
  }

  Widget _buildQuantityButtons(ThemeData theme, WineEntity wine) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OutlinedButton.icon(
          onPressed: wine.quantity > 0
              ? () => _updateQuantity(wine, wine.quantity - 1)
              : null,
          icon: const Icon(Icons.remove, size: 18),
          label: const Text('Retirer'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
        const SizedBox(width: 16),
        FilledButton.icon(
          onPressed: () => _updateQuantity(wine, wine.quantity + 1),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildChipSection(
    ThemeData theme,
    String title,
    List<Widget> chips,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: chips),
      ],
    );
  }

  Widget _buildTextSection(
    ThemeData theme,
    String title,
    String text, {
    bool italic = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          text.trim(),
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: italic ? FontStyle.italic : FontStyle.normal,
          ),
        ),
      ],
    );
  }

  Widget _buildPlacementsSection(ThemeData theme, WineEntity wine) {
    final cellarNames = _placements
        .map((p) => _cellarsById[p.cellarId]?.name ?? 'Cellier ${p.cellarId}')
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Emplacements en cave',
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: cellarNames
              .map((name) => Chip(
                    avatar: const Icon(Icons.grid_view_outlined, size: 16),
                    label: Text(name),
                  ))
              .toList(),
        ),
      ],
    );
  }

  Future<void> _updateQuantity(WineEntity wine, int newQty) async {
    if (wine.id == null) return;

    if (newQty <= 0) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dernière bouteille !'),
          content: Text(
            'La quantité de "${wine.displayName}" va passer à 0.\n'
            'Que souhaitez-vous faire ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop('cancel'),
              child: const Text('Annuler'),
            ),
            OutlinedButton(
              onPressed: () => Navigator.of(ctx).pop('zero'),
              child: const Text('Garder à 0'),
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

      final useCase = ref.read(updateWineQuantityUseCaseProvider);
      final params = UpdateQuantityParams(
        wineId: wine.id!,
        newQuantity: newQty,
      );
      final zeroAction = action == 'delete'
          ? ZeroQuantityAction.delete
          : ZeroQuantityAction.keep;

      final result = await useCase.callWithAction(params, zeroAction);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
        (_) {
          if (mounted && action == 'delete') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${wine.displayName}" supprimé')),
            );
            widget.onWineDeleted?.call();
            return;
          }
        },
      );
      if (action == 'delete') return;
    } else {
      final useCase = ref.read(updateWineQuantityUseCaseProvider);
      final params = UpdateQuantityParams(
        wineId: wine.id!,
        newQuantity: newQty,
      );
      await useCase(params);
    }

    await _loadWine();
  }

  Color _maturityColor(WineMaturity maturity) {
    switch (maturity) {
      case WineMaturity.tooYoung:
        return Colors.blue;
      case WineMaturity.ready:
        return Colors.green;
      case WineMaturity.peak:
        return Colors.amber;
      case WineMaturity.pastPeak:
        return const Color(0xFFE57373);
      case WineMaturity.unknown:
        return Colors.grey;
    }
  }
}

class _InfoCard extends StatelessWidget {
  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;

  const _InfoCard({
    required this.label,
    required this.value,
    required this.theme,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
