import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:multi_split_view/multi_split_view.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_sort.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/export_wines.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_csv.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/parse_csv_import.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_card.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_detail_panel.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/providers/wine_list_provider.dart';
import 'package:wine_cellar/features/ai_assistant/data/ai_prompts.dart';
import 'package:wine_cellar/features/ai_assistant/domain/repositories/ai_service.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/ai_request_strategy.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/csv_batch_validation_dialog.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/csv_column_mapping_dialog.dart';

enum _CsvImportMode { direct, withAi }

class _CsvImportChoice {
  final _CsvImportMode mode;
  final String? locationOverride;

  const _CsvImportChoice({required this.mode, this.locationOverride});
}

/// Main cellar screen - displays all wines with filtering
class WineListScreen extends ConsumerStatefulWidget {
  const WineListScreen({super.key});

  @override
  ConsumerState<WineListScreen> createState() => _WineListScreenState();
}

class _WineListScreenState extends ConsumerState<WineListScreen> {
  final _searchController = TextEditingController();
  WineFilter _filter = const WineFilter();
  WineSort? _sort;
  List<String> _availableLocations = const [];
  int? _selectedWineId;

  static const double _autoBreakpoint = 900;

  MultiSplitViewController? _hSplitController;
  MultiSplitViewController? _vSplitController;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    final result = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    if (!mounted) return;
    final cellars = result.getOrElse((_) => const []);
    setState(() {
      _availableLocations = cellars.map((c) => c.name).toList()..sort();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _hSplitController?.dispose();
    _vSplitController?.dispose();
    super.dispose();
  }

  bool _computeIsMasterDetail(WineListLayout layout) {
    return switch (layout) {
      WineListLayout.list => false,
      WineListLayout.masterDetail => true,
      WineListLayout.masterDetailVertical => true,
      WineListLayout.auto =>
          MediaQuery.of(context).size.width >= _autoBreakpoint,
    };
  }

  @override
  Widget build(BuildContext context) {
    final winesAsync = ref.watch(filteredWinesProvider(_filter));
    final layout = ref.watch(wineListLayoutProvider);
    final isMasterDetail = _computeIsMasterDetail(layout);

    // On narrow screen with a selected wine, show detail view
    if (!isMasterDetail && _selectedWineId != null) {
      return _buildNarrowDetailView();
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ma cave'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: 'Manuel utilisateur',
            onPressed: () => context.go('/manual'),
          ),
          IconButton(
            icon: Icon(
              Icons.sort,
              color: _sort != null
                  ? Theme.of(context).colorScheme.primary
                  : null,
            ),
            tooltip: 'Trier',
            onPressed: _showSortSheet,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: _handleMenuAction,
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
              const PopupMenuItem(
                value: 'import_csv',
                child: ListTile(
                  leading: Icon(Icons.upload_file),
                  title: Text('Importer CSV'),
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
                    _filter = _filter.copyWith(
                      searchQuery: value,
                      clearColor: true,
                      clearMaturity: true,
                    );
                  }
                });
              },
            ),
          ),
          // Filter chips
          _buildFilterChips(),
          // Location filter chips
          if (_availableLocations.isNotEmpty)
            _buildLocationFilterChips(),
          // Wine list (+ detail panel on wide)
          Expanded(
            child: winesAsync.when(
              data: (wines) {
                // Apply maturity filter in-memory if needed
                var filtered = _filter.maturity != null
                    ? wines
                          .where((w) => w.maturity == _filter.maturity)
                          .toList()
                    : wines;

                // Apply location filter in-memory
                if (_filter.locations.isNotEmpty) {
                  filtered = filtered
                      .where((w) =>
                          w.location != null &&
                          _filter.locations.contains(w.location))
                      .toList();
                }

                // Apply sort
                if (_sort != null) {
                  filtered = _sort!.apply(filtered);
                }

                if (filtered.isEmpty) {
                  return _buildEmptyState();
                }

                if (isMasterDetail) {
                  return _buildMasterDetail(context, filtered, layout);
                }
                return _buildWineList(context, filtered);
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('Erreur: $err')),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/cellar/add'),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un vin'),
      ),
    );
  }

  Future<void> _showSortSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Text(
                          'Trier par',
                          style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        if (_sort != null)
                          TextButton(
                            onPressed: () {
                              setState(() => _sort = null);
                              Navigator.of(ctx).pop();
                            },
                            child: const Text('Réinitialiser'),
                          ),
                      ],
                    ),
                  ),
                  const Divider(),
                  ...WineSortField.values.map((field) {
                    final isSelected = _sort?.field == field;
                    return ListTile(
                      leading: Icon(
                        isSelected
                            ? (_sort!.ascending
                                  ? Icons.arrow_upward
                                  : Icons.arrow_downward)
                            : Icons.remove,
                        color: isSelected
                            ? Theme.of(ctx).colorScheme.primary
                            : null,
                      ),
                      title: Text(field.label),
                      selected: isSelected,
                      onTap: () {
                        setSheetState(() {
                          setState(() {
                            if (isSelected) {
                              // Toggle direction
                              _sort = _sort!.copyWith(
                                ascending: !_sort!.ascending,
                              );
                            } else {
                              _sort = WineSort(field: field);
                            }
                          });
                        });
                      },
                    );
                  }),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          // Color filter chips
          ...WineColor.values.map(
            (color) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text('${color.emoji} ${color.label}'),
                selected: _filter.color == color,
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _filter = _filter.copyWith(
                        color: color,
                        clearMaturity: true,
                      );
                    } else {
                      _filter = _filter.copyWith(clearColor: true);
                    }
                  });
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Maturity filter chips
          ...WineMaturity.values
              .where((m) => m != WineMaturity.unknown)
              .map(
                (maturity) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text('${maturity.emoji} ${maturity.label}'),
                    selected: _filter.maturity == maturity,
                    onSelected: (selected) {
                      setState(() {
                        if (selected) {
                          _filter = _filter.copyWith(
                            maturity: maturity,
                            clearColor: true,
                          );
                        } else {
                          _filter = _filter.copyWith(clearMaturity: true);
                        }
                      });
                    },
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildLocationFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Row(
        children: [
          Icon(
            Icons.place,
            size: 16,
            color: Theme.of(context).colorScheme.outline,
          ),
          const SizedBox(width: 6),
          ..._availableLocations.map(
            (location) => Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilterChip(
                label: Text(location),
                selected: _filter.locations.contains(location),
                onSelected: (selected) {
                  setState(() {
                    final newLocations = {..._filter.locations};
                    if (selected) {
                      newLocations.add(location);
                    } else {
                      newLocations.remove(location);
                    }
                    _filter = _filter.copyWith(
                      locations: newLocations,
                    );
                  });
                },
              ),
            ),
          ),
          if (_filter.locations.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ActionChip(
                label: const Text('Tout effacer'),
                onPressed: () {
                  setState(() {
                    _filter = _filter.copyWith(clearLocations: true);
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  /// Narrow screen: detail view replaces the list
  Widget _buildNarrowDetailView() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Détail'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _selectedWineId = null),
        ),
      ),
      body: WineDetailPanel(
        key: ValueKey(_selectedWineId),
        wineId: _selectedWineId!,
        onWineDeleted: () {
          setState(() => _selectedWineId = null);
        },
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Utilisez l\'assistant IA pour ajouter votre premier vin',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  /// Master-detail split layout (horizontal or vertical) with resizable divider.
  Widget _buildMasterDetail(
    BuildContext context,
    List<WineEntity> wines,
    WineListLayout layout,
  ) {
    final theme = Theme.of(context);
    final isVertical = layout == WineListLayout.masterDetailVertical;
    final axis = isVertical ? Axis.vertical : Axis.horizontal;

    // Lazily create and reuse controllers so state survives rebuilds.
    final controller = isVertical
        ? (_vSplitController ??= _createSplitController(isVertical: true))
        : (_hSplitController ??= _createSplitController(isVertical: false));

    final detailWidget = _selectedWineId != null
        ? WineDetailPanel(
            key: ValueKey(_selectedWineId),
            wineId: _selectedWineId!,
            onWineDeleted: () {
              setState(() => _selectedWineId = null);
            },
          )
        : _buildDetailPlaceholder(theme);

    final panels = [
      _buildWineList(context, wines, compact: true),
      detailWidget,
    ];

    return MultiSplitViewTheme(
      data: MultiSplitViewThemeData(
        dividerThickness: 8,
        dividerPainter: DividerPainters.grooved2(
          color: theme.colorScheme.outlineVariant,
          highlightedColor: theme.colorScheme.primary,
          thickness: 3,
          size: 32,
        ),
      ),
      child: MultiSplitView(
        axis: axis,
        controller: controller,
        onDividerDragEnd: (_) => _persistSplitRatio(controller, isVertical),
        builder: (BuildContext context, Area area) {
          final index = controller.areas.indexOf(area);
          return panels[index];
        },
      ),
    );
  }

  MultiSplitViewController _createSplitController({required bool isVertical}) {
    final ratio = isVertical
        ? ref.read(splitRatioVerticalProvider)
        : ref.read(splitRatioHorizontalProvider);

    return MultiSplitViewController(
      areas: [
        Area(flex: ratio, min: isVertical ? 120 : 200),
        Area(flex: 1 - ratio, min: isVertical ? 120 : 250),
      ],
    );
  }

  void _persistSplitRatio(
    MultiSplitViewController controller,
    bool isVertical,
  ) {
    final areas = controller.areas;
    if (areas.length != 2) return;
    final flex0 = areas[0].flex ?? 0;
    final flex1 = areas[1].flex ?? 0;
    final total = flex0 + flex1;
    if (total <= 0) return;
    final ratio = flex0 / total;

    if (isVertical) {
      ref.read(splitRatioVerticalProvider.notifier).setRatio(ratio);
    } else {
      ref.read(splitRatioHorizontalProvider.notifier).setRatio(ratio);
    }
  }

  Widget _buildDetailPlaceholder(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.wine_bar_outlined,
            size: 64,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 16),
          Text(
            'Sélectionnez un vin',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWineList(
    BuildContext context,
    List<WineEntity> wines, {
    bool compact = false,
  }) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      itemCount: wines.length,
      itemBuilder: (context, index) {
        final wine = wines[index];
        return WineCard(
          wine: wine,
          selected: _selectedWineId == wine.id,
          compact: compact,
          onTap: () {
            setState(() => _selectedWineId = wine.id);
          },
          onQuantityChanged: (newQty) => _updateQuantity(wine, newQty),
        );
      },
    );
  }

  Future<void> _updateQuantity(WineEntity wine, int newQty) async {
    if (wine.id == null) return;

    final useCase = ref.read(updateWineQuantityUseCaseProvider);
    final params = UpdateQuantityParams(wineId: wine.id!, newQuantity: newQty);

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

      final zeroAction = action == 'delete'
          ? ZeroQuantityAction.delete
          : ZeroQuantityAction.keep;

      final result = await useCase.callWithAction(params, zeroAction);
      result.fold(
        (failure) {
          if (mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          }
        },
        (_) {
          if (mounted && action == 'delete') {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('"${wine.displayName}" supprimé')),
            );
          }
        },
      );
      return;
    }

    final result = await useCase(params);
    result.fold((failure) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }, (_) {});
  }

  Future<void> _handleMenuAction(String action) async {
    switch (action) {
      case 'export_json':
        await _handleExport(
          format: ExportFormat.json,
          suggestedFileName: 'cave_export.json',
          successMessage: 'Export JSON réalisé !',
        );
        return;
      case 'export_csv':
        await _handleExport(
          format: ExportFormat.csv,
          suggestedFileName: 'cave_export.csv',
          successMessage: 'Export CSV réalisé !',
        );
        return;
      case 'import_json':
        await _importJsonFlow();
        return;
      case 'import_csv':
        await _importCsvFlow();
        return;
    }
  }

  Future<void> _handleExport({
    required ExportFormat format,
    required String suggestedFileName,
    required String successMessage,
  }) async {
    final exportUseCase = ref.read(exportWinesUseCaseProvider);
    final result = await exportUseCase(format);

    await result.fold(
      (failure) async {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (content) async {
        final saved = await _saveExport(content, suggestedFileName);
        if (!mounted || !saved) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(successMessage)));
      },
    );
  }

  Future<bool> _saveExport(String content, String fileName) async {
    // On Android/iOS, the native save dialog is often unavailable.
    // Share the generated file so the user can save it to Drive/Files/etc.
    if (Platform.isAndroid || Platform.isIOS) {
      final tmpDir = await getTemporaryDirectory();
      final file = File('${tmpDir.path}/$fileName');
      await file.writeAsString(content);

      final result = await SharePlus.instance.share(
        ShareParams(
          text: 'Export Wine Cellar',
          files: [XFile(file.path)],
          title: fileName,
        ),
      );

      return result.status != ShareResultStatus.unavailable;
    }

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Enregistrer l\'export',
      fileName: fileName,
      type: FileType.custom,
      allowedExtensions: [fileName.split('.').last],
    );

    if (path == null) {
      return false;
    }

    final file = File(path);
    await file.writeAsString(content);
    return true;
  }

  Future<void> _importJsonFlow() async {
    final path = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir un fichier JSON',
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (path == null || path.files.single.path == null) {
      return;
    }

    final jsonPath = path.files.single.path!;
    final content = await File(jsonPath).readAsString();
    final importMode = _inspectJsonImport(content);
    final importApproved = importMode.isFullSnapshot
        ? await _confirmJsonSnapshotRestore(importMode)
        : await _confirmVirtualCellarImportSafety(
            formatLabel: 'JSON',
            importedPlacementsWillBeIgnored: true,
          );
    if (!mounted || !importApproved) return;

    final importUseCase = ref.read(importWinesFromJsonUseCaseProvider);
    final result = await importUseCase(content);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (count) {
        final message = importMode.isFullSnapshot
            ? 'Instantané JSON restauré : $count vin(s) et ${importMode.cellarCount} cellier(s).'
            : '$count vin(s) importé(s) depuis le JSON.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));

        if (importMode.hasCompatibilityAdjustments) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Compatibilité détectée: certaines valeurs ont été adaptées et la position en cave a été ignorée pour préserver les données vin.',
              ),
            ),
          );
        }
      },
    );
  }

  Future<void> _importCsvFlow() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: 'Choisir un fichier CSV',
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );

    if (picked == null || picked.files.single.path == null) {
      return;
    }

    final csvPath = picked.files.single.path!;
    final csvContent = await File(csvPath).readAsString();
    final importApproved = await _confirmVirtualCellarImportSafety(
      formatLabel: 'CSV',
      importedPlacementsWillBeIgnored: false,
    );
    if (!mounted || !importApproved) return;

    final previewRows = _extractCsvPreviewRows(csvContent, maxRows: 20);
    final allRows = _extractCsvPreviewRows(csvContent, maxRows: 100);

    if (!mounted) return;
    final mappingResult = await showDialog<CsvMappingDialogResult>(
      context: context,
      builder: (_) => CsvColumnMappingDialog(
        previewRows: previewRows,
        allRows: allRows,
        onRequestAiMapping: (rows, {allRows}) =>
            _requestAiMapping(rows, allRows: allRows),
      ),
    );

    if (mappingResult == null || !mounted) {
      return;
    }

    final parseUseCase = ref.read(parseCsvImportUseCaseProvider);
    final parseResult = await parseUseCase(
      ParseCsvImportParams(
        csvContent: csvContent,
        mapping: mappingResult.mapping,
        headerLine: mappingResult.headerLine,
      ),
    );

    if (!mounted) return;

    await parseResult.fold(
      (failure) async {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (rows) async {
        final previewOk = await _confirmCsvPreview(rows);
        if (!mounted || !previewOk) return;

        final choice = await _askCsvImportMode();
        if (!mounted || choice == null) return;

        // Create virtual cellar if location specified and doesn't exist
        if (choice.locationOverride != null) {
          await _ensureVirtualCellarForLocation(choice.locationOverride!);
        }

        if (choice.mode == _CsvImportMode.direct) {
          final directConfirmed = await _confirmDirectImportRecap(rows);
          if (!mounted || !directConfirmed) return;

          await _importCsvDirectly(
            csvContent: csvContent,
            mappingResult: mappingResult,
            locationOverride: choice.locationOverride,
          );
          return;
        }

        await _importCsvWithAi(rows, locationOverride: choice.locationOverride);
      },
    );
  }

  /// Ask the AI to detect header line and column mapping.
  /// Receives both preview rows (for display) and all rows (for AI analysis).
  Future<Map<String, dynamic>?> _requestAiMapping(
    List<List<String>> previewRows, {
    List<List<String>>? allRows,
  }) async {
    final analyzeUseCase = await _resolveAnalyzeWineUseCase();
    if (analyzeUseCase == null) return null;

    final prompt = AiPrompts.buildCsvMappingPrompt(
      previewRows: previewRows,
      allRows: allRows,
    );
    final result = await analyzeUseCase(
      AnalyzeWineParams(userMessage: prompt),
    );

    return result.fold(
      (failure) => null,
      (chatResult) {
        final text = chatResult.textResponse;
        try {
          // Try <json>...</json> first
          final xmlMatch =
              RegExp(r'<json>(.*?)</json>', dotAll: true).firstMatch(text);
          if (xmlMatch != null) {
            return jsonDecode(xmlMatch.group(1)!) as Map<String, dynamic>;
          }
          // Try ```json...```
          final mdMatch =
              RegExp(r'```json\s*(.*?)```', dotAll: true).firstMatch(text);
          if (mdMatch != null) {
            return jsonDecode(mdMatch.group(1)!) as Map<String, dynamic>;
          }
          // Try raw JSON
          return jsonDecode(text) as Map<String, dynamic>;
        } catch (_) {
          return null;
        }
      },
    );
  }

  Future<bool> _confirmCsvPreview(List<CsvImportRow> rows) async {
    final sample = rows.take(5).toList();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vérification de l\'extraction CSV'),
        content: SizedBox(
          width: 720,
          child: _BidirectionalScrollableDataTable(
            columns: const [
              DataColumn(label: Text('Ligne')),
              DataColumn(label: Text('Nom')),
              DataColumn(label: Text('Millésime')),
              DataColumn(label: Text('Producteur')),
              DataColumn(label: Text('Appellation')),
              DataColumn(label: Text('Qté')),
              DataColumn(label: Text('Couleur')),
              DataColumn(label: Text('Région')),
              DataColumn(label: Text('Pays')),
            ],
            rows: sample
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(Text(row.sourceRowNumber.toString())),
                      DataCell(Text(row.name ?? '—')),
                      DataCell(Text(row.vintage?.toString() ?? '—')),
                      DataCell(Text(row.producer ?? '—')),
                      DataCell(Text(row.appellation ?? '—')),
                      DataCell(Text(row.quantity?.toString() ?? '—')),
                      DataCell(Text(row.color ?? '—')),
                      DataCell(Text(row.region ?? '—')),
                      DataCell(Text(row.country ?? '—')),
                    ],
                  ),
                )
                .toList(),
            height: 260,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Extraction correcte'),
          ),
        ],
      ),
    );

    return confirmed ?? false;
  }

  Future<bool> _confirmVirtualCellarImportSafety({
    required String formatLabel,
    required bool importedPlacementsWillBeIgnored,
  }) async {
    final wines = await ref.read(wineRepositoryProvider).getAllWines();
    final placedCount = wines
        .where(
          (wine) =>
              wine.cellarId != null &&
              wine.cellarPositionX != null &&
              wine.cellarPositionY != null,
        )
        .length;

    if (!mounted || placedCount == 0) {
      return true;
    }

    final message = importedPlacementsWillBeIgnored
        ? '$placedCount bouteille(s) sont déjà placée(s) dans un cellier virtuel. '
              'Pour préserver la cave actuelle, les placements contenus dans ce fichier $formatLabel '
              'seront ignorés à l\'import. Les vins importés seront ajoutés sans emplacement virtuel.'
        : '$placedCount bouteille(s) sont déjà placée(s) dans un cellier virtuel. '
              'L\'import $formatLabel n\'écrasera pas la cave actuelle : les vins importés '
              'seront ajoutés sans emplacement virtuel.';

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Préserver la cave virtuelle actuelle'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Continuer l\'import'),
          ),
        ],
      ),
    );

    return approved ?? false;
  }

  _JsonImportMode _inspectJsonImport(String content) {
    try {
      final decoded = jsonDecode(content);

      List<dynamic> wines;
      List<dynamic> cellars;
      bool isFullSnapshot;
      bool hasCompatibilityAdjustments;

      if (decoded is List<dynamic>) {
        wines = decoded;
        cellars = const [];
        isFullSnapshot = false;
        hasCompatibilityAdjustments = true;
      } else if (decoded is Map<String, dynamic>) {
        wines = (decoded['wines'] as List<dynamic>? ?? const []);
        cellars = (decoded['virtualCellars'] as List<dynamic>? ?? const []);
        isFullSnapshot =
            decoded['snapshotType'] == 'full_cellar' ||
            decoded.containsKey('virtualCellars');
        hasCompatibilityAdjustments = _hasCompatibilityHints(wines);
      } else {
        return const _JsonImportMode(
          isFullSnapshot: false,
          wineCount: 0,
          cellarCount: 0,
          hasCompatibilityAdjustments: true,
        );
      }

      return _JsonImportMode(
        isFullSnapshot: isFullSnapshot,
        wineCount: wines.length,
        cellarCount: cellars.length,
        hasCompatibilityAdjustments: hasCompatibilityAdjustments,
      );
    } catch (_) {
      return const _JsonImportMode(
        isFullSnapshot: false,
        wineCount: 0,
        cellarCount: 0,
        hasCompatibilityAdjustments: false,
      );
    }
  }

  bool _hasCompatibilityHints(List<dynamic> wines) {
    for (final wine in wines) {
      if (wine is! Map<String, dynamic>) {
        return true;
      }

      if (wine.containsKey('nom') ||
          wine.containsKey('couleur') ||
          wine.containsKey('millesime') ||
          wine.containsKey('pays') ||
          wine.containsKey('cepages')) {
        return true;
      }

      if (wine['quantity'] is String ||
          wine['vintage'] is String ||
          wine['purchasePrice'] is String ||
          wine['drinkFromYear'] is String ||
          wine['drinkUntilYear'] is String ||
          wine['aiSuggestedFoodPairings'] is String ||
          wine['aiSuggestedDrinkFromYear'] is String ||
          wine['aiSuggestedDrinkUntilYear'] is String) {
        return true;
      }

      // Non-snapshot JSON import intentionally drops legacy placement fields.
      if (wine['cellarId'] != null ||
          wine['cellarPositionX'] != null ||
          wine['cellarPositionY'] != null) {
        return true;
      }
    }

    return false;
  }

  Future<bool> _confirmJsonSnapshotRestore(_JsonImportMode importMode) async {
    final currentWines = await ref.read(wineRepositoryProvider).getAllWines();
    final currentCellarsResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    final currentCellars = currentCellarsResult.getOrElse((_) => const []);
    if (!mounted) return false;

    final currentPlacedCount = currentWines
        .where(
          (wine) =>
              wine.cellarId != null &&
              wine.cellarPositionX != null &&
              wine.cellarPositionY != null,
        )
        .length;

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Restaurer un instantané complet'),
        content: Text(
          'Ce fichier JSON contient un instantané complet de cave. '
          'L\'import remplacera la cave actuelle : ${currentWines.length} vin(s), '
          '${currentCellars.length} cellier(s) et $currentPlacedCount placement(s) seront supprimés, '
          'puis ${importMode.wineCount} vin(s) et ${importMode.cellarCount} cellier(s) '
          'seront restaurés avec leurs placements.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Restaurer la cave'),
          ),
        ],
      ),
    );

    return approved ?? false;
  }

  Future<_CsvImportChoice?> _askCsvImportMode() {
    final locationCtrl = TextEditingController();
    return showDialog<_CsvImportChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choisissez le mode d\'import'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Souhaitez-vous enrichir les données manquantes avec l\'IA,\n'
              'ou ajouter directement ces vins à la cave ?',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Localisation commune (optionnel)',
                hintText: 'Ex : Cave principale, Garage…',
                prefixIcon: Icon(Icons.place_outlined),
                helperText:
                    'Si renseigné, tous les vins importés auront cette '
                    'localisation et un cellier vide sera créé si nécessaire.',
                helperMaxLines: 3,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () {
              final loc = locationCtrl.text.trim();
              Navigator.of(dialogContext).pop(
                _CsvImportChoice(
                  mode: _CsvImportMode.direct,
                  locationOverride: loc.isEmpty ? null : loc,
                ),
              );
            },
            child: const Text('Ajouter directement'),
          ),
          FilledButton(
            onPressed: () {
              final loc = locationCtrl.text.trim();
              Navigator.of(dialogContext).pop(
                _CsvImportChoice(
                  mode: _CsvImportMode.withAi,
                  locationOverride: loc.isEmpty ? null : loc,
                ),
              );
            },
            child: const Text('Compléter avec IA'),
          ),
        ],
      ),
    );
  }

  /// Creates a virtual cellar with the given name if one doesn't already exist.
  Future<void> _ensureVirtualCellarForLocation(String cellarName) async {
    final repo = ref.read(virtualCellarRepositoryProvider);
    final result = await repo.getAll();
    final cellars = result.getOrElse((_) => const []);
    final exists = cellars.any(
      (c) => c.name.toLowerCase() == cellarName.toLowerCase(),
    );
    if (!exists) {
      await ref.read(createVirtualCellarUseCaseProvider).call(
            VirtualCellarEntity(
              name: cellarName,
              rows: 5,
              columns: 5,
            ),
          );
      // Refresh locations filter
      await _loadLocations();
    }
  }

  Future<void> _importCsvDirectly({
    required String csvContent,
    required CsvMappingDialogResult mappingResult,
    String? locationOverride,
  }) async {
    final useCase = ref.read(importWinesFromCsvUseCaseProvider);
    final result = await useCase(
      ImportWinesFromCsvParams(
        csvContent: csvContent,
        mapping: mappingResult.mapping,
        headerLine: mappingResult.headerLine,
        locationOverride: locationOverride,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (count) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count vin(s) importé(s) depuis le CSV.')),
        );
      },
    );
  }

  Future<bool> _confirmDirectImportRecap(List<CsvImportRow> rows) async {
    final importableRows = rows
        .where((row) => (row.name ?? '').trim().isNotEmpty)
        .toList();
    final ignoredRowsCount = rows.length - importableRows.length;

    if (importableRows.isEmpty) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Aucun vin importable (nom manquant sur toutes les lignes).',
          ),
        ),
      );
      return false;
    }

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Validation import direct'),
        content: SizedBox(
          width: 760,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${importableRows.length} vin(s) seront importés. Vérifiez les informations ci-dessous.',
                  ),
                  if (ignoredRowsCount > 0) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '$ignoredRowsCount ligne(s) seront ignorées (nom manquant).',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _showIgnoredRowsDetails(rows),
                          icon: const Icon(Icons.info_outline, size: 18),
                          label: const Text('Détail'),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 10),
                  for (var i = 0; i < importableRows.length; i++) ...[
                    Text(
                      'Vin ${i + 1} (ligne CSV ${importableRows[i].sourceRowNumber})',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    _BidirectionalScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Champ')),
                        DataColumn(label: Text('Valeur')),
                      ],
                      rows: _buildDirectRecapRows(importableRows[i]),
                      height: 220,
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Importer en direct'),
          ),
        ],
      ),
    );

    return approved ?? false;
  }

  Future<void> _showIgnoredRowsDetails(List<CsvImportRow> rows) async {
    final ignoredRows = rows
        .where((row) => (row.name ?? '').trim().isEmpty)
        .toList();

    if (ignoredRows.isEmpty || !mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Lignes ignorées'),
        content: SizedBox(
          width: 420,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ces lignes ont été ignorées car le nom du vin est vide :',
                ),
                const SizedBox(height: 10),
                ...ignoredRows.map(
                  (row) => ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.warning_amber, size: 18),
                    title: Text('Ligne CSV ${row.sourceRowNumber}'),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  Future<void> _importCsvWithAi(List<CsvImportRow> rows, {String? locationOverride}) async {
    final analyzeUseCase = await _resolveAnalyzeWineUseCase();
    if (analyzeUseCase == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vérifiez les paramètres IA dans Paramètres, puis réessayez.',
          ),
        ),
      );
      return;
    }

    final meaningfulRows = rows
        .where(
          (row) =>
              (row.name ?? '').trim().isNotEmpty ||
              (row.appellation ?? '').trim().isNotEmpty ||
              (row.producer ?? '').trim().isNotEmpty,
        )
        .toList();

    if (meaningfulRows.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucune ligne exploitable pour l\'IA.')),
      );
      return;
    }

    final allCategories = await ref
        .read(foodCategoryRepositoryProvider)
        .getAllCategories();

    var totalImported = 0;
    var totalDeleted = 0;
    var batchesCompleted = 0;
    final totalBatches = (meaningfulRows.length / 20).ceil();

    for (var batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final start = batchIndex * 20;
      final end = (start + 20 > meaningfulRows.length)
          ? meaningfulRows.length
          : start + 20;
      final batch = meaningfulRows.sublist(start, end);

      var shouldRetry = true;
      while (shouldRetry) {
        shouldRetry = false;

        // Build enrichment prompt
        final rowDescriptions = batch.map((row) {
          final fields = _csvRowToFieldsMap(row);
          return AiPrompts.buildCsvRowDescription(
            fields,
            row.sourceRowNumber,
          );
        }).toList();

        final prompt = AiPrompts.buildCsvEnrichmentPrompt(
          rowDescriptions: rowDescriptions,
          batchNumber: batchIndex + 1,
          totalBatches: totalBatches,
        );

        final result = await _runWithAiWorkingDialog(
          message:
              'L\'IA enrichit le lot ${batchIndex + 1}/$totalBatches '
              '(${batch.length} vin(s))…\nMerci de patienter.',
          task: () => analyzeUseCase(AnalyzeWineParams(userMessage: prompt)),
        );

        if (!mounted) return;

        final shouldContinue = await result.fold(
          (failure) async {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('IA: ${failure.message}')));
            return false;
          },
          (chatResult) async {
            if (chatResult.wineDataList.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Le lot ${batchIndex + 1}/$totalBatches n\'a pas produit '
                    'de tableau exploitable.',
                  ),
                ),
              );
              return false;
            }

            // Web search refinement pass (if Gemini available)
            var refinedWines = chatResult.wineDataList;
            final geminiService = ref.read(geminiWebSearchServiceProvider);
            if (geminiService != null) {
              refinedWines = await _refineWinesWithWebSearch(
                refinedWines,
                geminiService,
                batchIndex + 1,
                totalBatches,
              );
              if (!mounted) return false;
            }

            // Show batch validation dialog with inline editing
            final batchResult =
                await showDialog<CsvBatchValidationResult>(
              context: context,
              barrierDismissible: false,
              builder: (_) => CsvBatchValidationDialog(
                batchNumber: batchIndex + 1,
                totalBatches: totalBatches,
                wines: refinedWines,
                onReevaluateSingleWine: (wine) =>
                    _reevaluateSingleWine(wine, analyzeUseCase),
              ),
            );

            if (batchResult == null || !mounted) return false;

            switch (batchResult.action) {
              case CsvBatchAction.cancel:
                return false;
              case CsvBatchAction.retry:
                shouldRetry = true;
                return true; // continue the outer loop
              case CsvBatchAction.validate:
                final addWineUseCase = ref.read(addWineUseCaseProvider);
                final winesInBatch = batchResult.wines;
                final deletedInBatch =
                    refinedWines.length - winesInBatch.length;
                totalDeleted += deletedInBatch;

                for (final aiWine in winesInBatch) {
                  if (!aiWine.isComplete) continue;
                  final matchedCategoryIds = _matchFoodCategoryIds(
                    aiWine.suggestedFoodPairings,
                    allCategories,
                  );
                  final wine = _aiWineToEntity(
                    aiWine,
                    matchedCategoryIds,
                    locationOverride: locationOverride,
                  );
                  final addResult = await addWineUseCase(wine);
                  addResult.fold((_) {}, (_) => totalImported++);
                }

                batchesCompleted++;
                return true;
            }
          },
        );

        if (!shouldContinue && !shouldRetry) {
          // Show partial summary even if import was stopped early
          if (totalImported > 0 || totalDeleted > 0) {
            if (mounted) {
              await _showImportSummaryDialog(
                totalProcessed: meaningfulRows.length,
                totalImported: totalImported,
                totalDeleted: totalDeleted,
                totalBatches: totalBatches,
                batchesCompleted: batchesCompleted,
              );
            }
          }
          return;
        }
      }
    }

    if (!mounted) return;
    await _showImportSummaryDialog(
      totalProcessed: meaningfulRows.length,
      totalImported: totalImported,
      totalDeleted: totalDeleted,
      totalBatches: totalBatches,
      batchesCompleted: batchesCompleted,
    );
  }

  /// Re-evaluate a single wine via the AI after user modifications.
  Future<WineAiResponse?> _reevaluateSingleWine(
    WineAiResponse wine,
    AnalyzeWineUseCase analyzeUseCase,
  ) async {
    final fields = _wineAiResponseToFieldsMap(wine);
    final prompt = AiPrompts.buildSingleWineReevaluationPrompt(
      wineFields: fields,
    );
    final result = await analyzeUseCase(
      AnalyzeWineParams(userMessage: prompt),
    );
    return result.fold(
      (failure) => null,
      (chatResult) => chatResult.wineDataList.isNotEmpty
          ? chatResult.wineDataList.first
          : null,
    );
  }

  /// Refine wines with Gemini web search to complete estimated fields.
  /// Similar to the web search pass in standard wine addition.
  Future<List<WineAiResponse>> _refineWinesWithWebSearch(
    List<WineAiResponse> wines,
    AiService webSearchService,
    int batchNumber,
    int totalBatches,
  ) async {
    final eligible = <int>[];
    for (var i = 0; i < wines.length; i++) {
      final decision =
          AiRequestStrategy.decideWebSearchForWineCompletion(wines[i]);
      if (decision.shouldUseWebSearch) {
        eligible.add(i);
      }
    }

    if (eligible.isEmpty) return wines;

    final refined = List<WineAiResponse>.from(wines);
    var completed = 0;

    for (final idx in eligible) {
      if (!mounted) return refined;

      final wine = refined[idx];
      completed++;

      // Show progress dialog for web search
      final result = await _runWithAiWorkingDialog(
        message:
            '🌐 Recherche web $completed/${eligible.length} '
            '(lot $batchNumber/$totalBatches)\n'
            '${wine.name ?? "Vin inconnu"}…',
        task: () async {
          final message = AiPrompts.buildFieldCompletionMessage(
            wineName: wine.name!,
            vintage: wine.vintage,
            color: wine.color,
            appellation: wine.appellation,
            fieldsToComplete: wine.estimatedFields,
          );
          return webSearchService.analyzeWineWithWebSearch(
            userMessage: message,
            systemPromptOverride: AiPrompts.fieldCompletionSystemPrompt,
          );
        },
      );

      if (result.isError) continue;

      final complementData = _extractCompletionJson(result.textResponse);
      if (complementData == null) continue;

      final complement = WineAiResponse.fromJson(complementData);
      final completedFields = wine.estimatedFields
          .where((f) => WineAiResponse.fieldWasCompleted(f, complement))
          .toList();

      if (completedFields.isNotEmpty) {
        refined[idx] = wine.mergeWith(complement);
      }
    }

    return refined;
  }

  /// Extract JSON from a Gemini response that may contain markdown code blocks.
  Map<String, dynamic>? _extractCompletionJson(String text) {
    final jsonBlockRegex = RegExp(r'```json\s*([\s\S]*?)\s*```');
    final match = jsonBlockRegex.firstMatch(text);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(1)!);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    final braceStart = text.indexOf('{');
    final braceEnd = text.lastIndexOf('}');
    if (braceStart >= 0 && braceEnd > braceStart) {
      try {
        final decoded = jsonDecode(text.substring(braceStart, braceEnd + 1));
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }

    return null;
  }

  /// Convert a CsvImportRow to a map for AI prompts.
  Map<String, String?> _csvRowToFieldsMap(CsvImportRow row) {
    return {
      'name': row.name,
      'vintage': row.vintage?.toString(),
      'producer': row.producer,
      'appellation': row.appellation,
      'quantity': row.quantity?.toString(),
      'color': row.color,
      'region': row.region,
      'country': row.country,
      'grapeVarieties': row.grapeVarieties.isNotEmpty
          ? row.grapeVarieties.join(', ')
          : null,
      'purchasePrice': row.purchasePrice?.toString(),
      'location': row.location,
      'notes': row.notes,
    };
  }

  /// Convert a WineAiResponse to a map for AI prompts.
  Map<String, String?> _wineAiResponseToFieldsMap(WineAiResponse wine) {
    return {
      'name': wine.name,
      'appellation': wine.appellation,
      'producer': wine.producer,
      'region': wine.region,
      'country': wine.country,
      'color': wine.color,
      'vintage': wine.vintage?.toString(),
      'grapeVarieties': wine.grapeVarieties.isNotEmpty
          ? wine.grapeVarieties.join(', ')
          : null,
      'quantity': wine.quantity?.toString(),
      'purchasePrice': wine.purchasePrice?.toString(),
      'drinkFromYear': wine.drinkFromYear?.toString(),
      'drinkUntilYear': wine.drinkUntilYear?.toString(),
      'tastingNotes': wine.tastingNotes,
      'description': wine.description,
    };
  }

  /// Show a detailed summary of the CSV import results.
  Future<void> _showImportSummaryDialog({
    required int totalProcessed,
    required int totalImported,
    required int totalDeleted,
    required int totalBatches,
    required int batchesCompleted,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Résumé de l\'import CSV'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SummaryRow(
              icon: Icons.checklist,
              text: '$batchesCompleted / $totalBatches lot(s) traité(s)',
            ),
            const SizedBox(height: 8),
            _SummaryRow(
              icon: Icons.wine_bar,
              text:
                  '$totalImported vin(s) importé(s) sur $totalProcessed proposé(s)',
            ),
            if (totalDeleted > 0) ...[
              const SizedBox(height: 8),
              _SummaryRow(
                icon: Icons.delete_outline,
                text: '$totalDeleted vin(s) supprimé(s)',
              ),
            ],
          ],
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  List<DataRow> _buildDirectRecapRows(CsvImportRow row) {
    String valueOrDash(String? value) {
      final trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? '—' : trimmed;
    }

    String intOrDash(int? value) => value?.toString() ?? '—';
    String doubleOrDash(double? value) => value?.toStringAsFixed(2) ?? '—';

    return [
      DataRow(
        cells: [
          DataCell(const Text('Nom')),
          DataCell(Text(valueOrDash(row.name))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Appellation')),
          DataCell(Text(valueOrDash(row.appellation))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Producteur')),
          DataCell(Text(valueOrDash(row.producer))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Région')),
          DataCell(Text(valueOrDash(row.region))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Pays')),
          DataCell(Text(valueOrDash(row.country))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Couleur')),
          DataCell(Text(valueOrDash(row.color))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Millésime')),
          DataCell(Text(intOrDash(row.vintage))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Cépages')),
          DataCell(
            Text(
              row.grapeVarieties.isEmpty ? '—' : row.grapeVarieties.join(', '),
            ),
          ),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Quantité')),
          DataCell(Text(intOrDash(row.quantity))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Prix achat (€)')),
          DataCell(Text(doubleOrDash(row.purchasePrice))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Localisation')),
          DataCell(Text(valueOrDash(row.location))),
        ],
      ),
      DataRow(
        cells: [
          DataCell(const Text('Notes')),
          DataCell(Text(valueOrDash(row.notes))),
        ],
      ),
    ];
  }

  Future<T> _runWithAiWorkingDialog<T>({
    required String message,
    required Future<T> Function() task,
  }) async {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(message)),
              const SizedBox(width: 8),
              const Text('⏳', style: TextStyle(fontSize: 20)),
            ],
          ),
        ),
      ),
    );

    try {
      return await task();
    } finally {
      if (mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
    }
  }

  Future<AnalyzeWineUseCase?> _resolveAnalyzeWineUseCase() async {
    var useCase = ref.read(analyzeWineUseCaseProvider);
    if (useCase != null) return useCase;

    for (var i = 0; i < 6; i++) {
      await Future.delayed(const Duration(milliseconds: 250));
      ref.invalidate(aiServiceProvider);
      ref.invalidate(analyzeWineUseCaseProvider);
      useCase = ref.read(analyzeWineUseCaseProvider);
      if (useCase != null) {
        return useCase;
      }
    }

    return null;
  }

  List<List<String>> _extractCsvPreviewRows(
    String csvContent, {
    int maxRows = 5,
  }) {
    try {
      final separator = _detectCsvSeparator(csvContent);
      final rawRows = CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
        fieldDelimiter: separator,
      ).convert(csvContent);

      final preview = <List<String>>[];
      for (final row in rawRows) {
        if (preview.length >= maxRows) break;
        preview.add(row.map((cell) => cell.toString()).toList());
      }
      return preview;
    } catch (_) {
      final lines = csvContent
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .take(maxRows)
          .toList();
      return lines.map((line) => line.split(';')).toList();
    }
  }

  /// Simple CSV separator detection for preview purposes.
  String _detectCsvSeparator(String csvContent) {
    final lines = csvContent
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(5)
        .toList();
    if (lines.isEmpty) return ',';

    var bestSep = ',';
    var bestScore = 0;
    for (final sep in [',', ';', '\t']) {
      final counts = lines.map((l) => sep.allMatches(l).length).toList();
      final minCount = counts.reduce((a, b) => a < b ? a : b);
      final maxCount = counts.reduce((a, b) => a > b ? a : b);
      // Score: total occurrences, bonus for consistency across lines
      final total = counts.fold<int>(0, (s, c) => s + c);
      final consistency = (maxCount - minCount <= 1) ? 10 : 0;
      final score = total + consistency;
      if (score > bestScore) {
        bestScore = score;
        bestSep = sep;
      }
    }
    return bestSep;
  }

  List<int> _matchFoodCategoryIds(
    List<String> pairingNames,
    List<FoodCategoryEntity> categories,
  ) {
    final matched = <int>[];

    for (final pairingName in pairingNames) {
      final normalizedPairing = _normalizeForMatching(pairingName);
      if (normalizedPairing.isEmpty) continue;

      for (final category in categories) {
        final normalizedCategory = _normalizeForMatching(category.name);
        if (normalizedCategory.isEmpty) continue;

        if (normalizedCategory.contains(normalizedPairing) ||
            normalizedPairing.contains(normalizedCategory)) {
          final id = category.id;
          if (!matched.contains(id)) {
            matched.add(id);
          }
          break;
        }
      }
    }

    return matched;
  }

  String _normalizeForMatching(String value) {
    var normalized = value.toLowerCase().trim();

    const replacements = {
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ä': 'a',
      'ã': 'a',
      'å': 'a',
      'æ': 'ae',
      'ç': 'c',
      'è': 'e',
      'é': 'e',
      'ê': 'e',
      'ë': 'e',
      'ì': 'i',
      'í': 'i',
      'î': 'i',
      'ï': 'i',
      'ñ': 'n',
      'ò': 'o',
      'ó': 'o',
      'ô': 'o',
      'ö': 'o',
      'õ': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ý': 'y',
      'ÿ': 'y',
    };

    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });

    return normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
  }

  WineEntity _aiWineToEntity(
    WineAiResponse wine,
    List<int> matchedCategoryIds, {
    String? locationOverride,
  }) {
    return WineEntity(
      name: wine.name!.trim(),
      appellation: wine.appellation,
      producer: wine.producer,
      region: wine.region,
      country: wine.country ?? 'France',
      color: WineColor.values.firstWhere(
        (color) => color.name == wine.color,
        orElse: () => WineColor.red,
      ),
      vintage: wine.vintage,
      grapeVarieties: wine.grapeVarieties,
      quantity: (wine.quantity ?? 1) <= 0 ? 1 : wine.quantity!,
      purchasePrice: wine.purchasePrice,
      drinkFromYear: wine.drinkFromYear,
      aiSuggestedDrinkFromYear: wine.drinkFromYear != null,
      drinkUntilYear: wine.drinkUntilYear,
      aiSuggestedDrinkUntilYear: wine.drinkUntilYear != null,
      tastingNotes: wine.tastingNotes,
      aiDescription: wine.description,
      aiSuggestedFoodPairings: matchedCategoryIds.isNotEmpty,
      foodCategoryIds: matchedCategoryIds,
      location: locationOverride,
    );
  }
}

class _JsonImportMode {
  final bool isFullSnapshot;
  final int wineCount;
  final int cellarCount;
  final bool hasCompatibilityAdjustments;

  const _JsonImportMode({
    required this.isFullSnapshot,
    required this.wineCount,
    required this.cellarCount,
    required this.hasCompatibilityAdjustments,
  });
}

class _BidirectionalScrollableDataTable extends StatefulWidget {
  final List<DataColumn> columns;
  final List<DataRow> rows;
  final double height;

  const _BidirectionalScrollableDataTable({
    required this.columns,
    required this.rows,
    this.height = 260,
  });

  @override
  State<_BidirectionalScrollableDataTable> createState() =>
      _BidirectionalScrollableDataTableState();
}

class _BidirectionalScrollableDataTableState
    extends State<_BidirectionalScrollableDataTable> {
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height,
      child: Scrollbar(
        controller: _verticalController,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _verticalController,
          child: Scrollbar(
            controller: _horizontalController,
            thumbVisibility: true,
            notificationPredicate: (notification) =>
                notification.metrics.axis == Axis.horizontal,
            child: SingleChildScrollView(
              controller: _horizontalController,
              scrollDirection: Axis.horizontal,
              child: DataTable(columns: widget.columns, rows: widget.rows),
            ),
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SummaryRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Expanded(child: Text(text)),
      ],
    );
  }
}
