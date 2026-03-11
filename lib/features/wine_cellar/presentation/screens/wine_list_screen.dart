import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/ai_assistant/domain/usecases/analyze_wine.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_import_row.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_filter.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_sort.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/export_wines.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_csv.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/import_wines_from_json.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/parse_csv_import.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/wine_card.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/providers/wine_list_provider.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/csv_column_mapping_dialog.dart';

enum _CsvImportMode { direct, withAi }

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
                var filtered = _filter.maturity != null
                    ? wines
                        .where((w) => w.maturity == _filter.maturity)
                        .toList()
                    : wines;

                // Apply sort
                if (_sort != null) {
                  filtered = _sort!.apply(filtered);
                }

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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
                              _sort = _sort!.copyWith(ascending: !_sort!.ascending);
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

    final useCase = ref.read(updateWineQuantityUseCaseProvider);
    final params = UpdateQuantityParams(
      wineId: wine.id!,
      newQuantity: newQty,
    );

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
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
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
    result.fold(
      (failure) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
      },
      (_) {},
    );
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (content) async {
        final saved = await _saveExport(content, suggestedFileName);
        if (!mounted || !saved) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(successMessage)),
        );
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
    final importUseCase = ref.read(importWinesFromJsonUseCaseProvider);
    final result = await importUseCase(content);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (count) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$count vin(s) importé(s) depuis le JSON.')),
        );
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
    final previewRows = _extractCsvPreviewRows(csvContent, maxRows: 2);

    if (!mounted) return;
    final mappingResult = await showDialog<CsvMappingDialogResult>(
      context: context,
      builder: (_) => CsvColumnMappingDialog(previewRows: previewRows),
    );

    if (mappingResult == null || !mounted) {
      return;
    }

    final parseUseCase = ref.read(parseCsvImportUseCaseProvider);
    final parseResult = await parseUseCase(
      ParseCsvImportParams(
        csvContent: csvContent,
        mapping: mappingResult.mapping,
        hasHeader: mappingResult.hasHeader,
      ),
    );

    if (!mounted) return;

    await parseResult.fold(
      (failure) async {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
      },
      (rows) async {
        final previewOk = await _confirmCsvPreview(rows);
        if (!mounted || !previewOk) return;

        final mode = await _askCsvImportMode();
        if (!mounted || mode == null) return;

        if (mode == _CsvImportMode.direct) {
          final directConfirmed = await _confirmDirectImportRecap(rows);
          if (!mounted || !directConfirmed) return;

          await _importCsvDirectly(
            csvContent: csvContent,
            mappingResult: mappingResult,
          );
          return;
        }

        await _importCsvWithAi(rows);
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

  Future<_CsvImportMode?> _askCsvImportMode() {
    return showDialog<_CsvImportMode>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Choisissez le mode d\'import'),
        content: const Text(
          'Souhaitez-vous enrichir les données manquantes avec l\'IA,\n'
          'ou ajouter directement ces vins à la cave ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CsvImportMode.direct),
            child: const Text('Ajouter directement'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(dialogContext).pop(_CsvImportMode.withAi),
            child: const Text('Compléter avec IA'),
          ),
        ],
      ),
    );
  }

  Future<void> _importCsvDirectly({
    required String csvContent,
    required CsvMappingDialogResult mappingResult,
  }) async {
    final useCase = ref.read(importWinesFromCsvUseCaseProvider);
    final result = await useCase(
      ImportWinesFromCsvParams(
        csvContent: csvContent,
        mapping: mappingResult.mapping,
        hasHeader: mappingResult.hasHeader,
      ),
    );

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failure.message)),
        );
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
          content: Text('Aucun vin importable (nom manquant sur toutes les lignes).'),
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
                            style:
                                Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                const Text('Ces lignes ont été ignorées car le nom du vin est vide :'),
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

  Future<void> _importCsvWithAi(List<CsvImportRow> rows) async {
    final analyzeUseCase = await _resolveAnalyzeWineUseCase();
    if (analyzeUseCase == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérifiez les paramètres IA dans Paramètres, puis réessayez.'),
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

    final allCategories =
      await ref.read(foodCategoryRepositoryProvider).getAllCategories();

    var importedCount = 0;
    final totalBatches = (meaningfulRows.length / 20).ceil();

    for (var batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
      final start = batchIndex * 20;
      final end = (start + 20 > meaningfulRows.length)
          ? meaningfulRows.length
          : start + 20;
      final batch = meaningfulRows.sublist(start, end);

      final prompt = _buildAiCsvPrompt(batch, batchIndex + 1, totalBatches);
      final result = await _runWithAiWorkingDialog(
        message:
            'L\'IA travaille sur le lot ${batchIndex + 1}/$totalBatches...\nMerci de patienter.',
        task: () => analyzeUseCase(
          AnalyzeWineParams(userMessage: prompt),
        ),
      );

      if (!mounted) return;

      final shouldContinue = await result.fold(
        (failure) async {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('IA: ${failure.message}')),
          );
          return false;
        },
        (chatResult) async {
          if (chatResult.wineDataList.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Le lot ${batchIndex + 1}/$totalBatches n\'a pas produit de tableau exploitable.',
                ),
              ),
            );
            return false;
          }

          final approved = await _confirmAiBatch(
            batchNumber: batchIndex + 1,
            totalBatches: totalBatches,
            wines: chatResult.wineDataList,
          );

          if (!approved) {
            return false;
          }

          final addWineUseCase = ref.read(addWineUseCaseProvider);
          for (final aiWine in chatResult.wineDataList) {
            if (!aiWine.isComplete) continue;
            final matchedCategoryIds =
                _matchFoodCategoryIds(aiWine.suggestedFoodPairings, allCategories);
            final wine = _aiWineToEntity(
              aiWine,
              matchedCategoryIds,
            );
            final addResult = await addWineUseCase(wine);
            addResult.fold((_) {}, (_) => importedCount++);
          }

          return true;
        },
      );

      if (!shouldContinue) {
        break;
      }
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$importedCount vin(s) ajouté(s) après validation IA.',
        ),
      ),
    );
  }

  Future<bool> _confirmAiBatch({
    required int batchNumber,
    required int totalBatches,
    required List<WineAiResponse> wines,
  }) async {
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Validation lot IA $batchNumber/$totalBatches'),
        content: SizedBox(
          width: 760,
          child: Scrollbar(
            thumbVisibility: true,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < wines.length; i++) ...[
                    Text(
                      'Vin ${i + 1}',
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    const SizedBox(height: 6),
                    _BidirectionalScrollableDataTable(
                      columns: const [
                        DataColumn(label: Text('Champ')),
                        DataColumn(label: Text('Valeur')),
                      ],
                      rows: _buildAiRecapRows(wines[i]),
                      height: 230,
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
            child: const Text('Annuler l\'import IA'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Valider ce lot'),
          ),
        ],
      ),
    );

    return approved ?? false;
  }

  String _buildAiCsvPrompt(
    List<CsvImportRow> rows,
    int batchNumber,
    int totalBatches,
  ) {
    final rowsText = rows
        .map(
          (row) =>
              '- ligne ${row.sourceRowNumber}: '
              'name=${row.name ?? ''}; '
              'vintage=${row.vintage?.toString() ?? ''}; '
              'producer=${row.producer ?? ''}; '
              'appellation=${row.appellation ?? ''}; '
              'quantity=${row.quantity?.toString() ?? ''}; '
              'color=${row.color ?? ''}; '
              'region=${row.region ?? ''}; '
              'country=${row.country ?? ''}; '
              'grapes=${row.grapeVarieties.join(', ')}; '
              'price=${row.purchasePrice?.toString() ?? ''}; '
              'location=${row.location ?? ''}; '
              'notes=${row.notes ?? ''}',
        )
        .join('\n');

    return '''
[MODE IMPORT CSV]
Lot $batchNumber/$totalBatches.
Tu dois enrichir les vins ci-dessous.

IMPORTANT:
- Réponds UNIQUEMENT avec un bloc ```json.
- Retourne la structure: {"wines": [...]} avec les mêmes clés qu'habituellement.
- Si des informations restent manquantes, mets needsMoreInfo=true et complète followUpQuestion.
- N'ajoute aucun texte hors JSON.

VINS CSV:
$rowsText
''';
  }

  String _missingInfoLabel(WineAiResponse wine) {
    final missing = <String>[];
    if ((wine.name ?? '').trim().isEmpty) missing.add('nom');
    if ((wine.color ?? '').trim().isEmpty) missing.add('couleur');
    if ((wine.region ?? '').trim().isEmpty) missing.add('région');
    if ((wine.country ?? '').trim().isEmpty) missing.add('pays');
    if (wine.needsMoreInfo && (wine.followUpQuestion ?? '').trim().isNotEmpty) {
      missing.add(wine.followUpQuestion!.trim());
    }
    if (missing.isEmpty) return 'Complet';
    return missing.join(' • ');
  }

  List<DataRow> _buildAiRecapRows(WineAiResponse wine) {
    String valueOrDash(String? value) {
      final trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? '—' : trimmed;
    }

    String intOrDash(int? value) => value?.toString() ?? '—';
    String doubleOrDash(double? value) => value?.toStringAsFixed(2) ?? '—';

    return [
      DataRow(cells: [DataCell(const Text('Nom')), DataCell(Text(valueOrDash(wine.name)))]),
      DataRow(cells: [DataCell(const Text('Appellation')), DataCell(Text(valueOrDash(wine.appellation)))]),
      DataRow(cells: [DataCell(const Text('Producteur')), DataCell(Text(valueOrDash(wine.producer)))]),
      DataRow(cells: [DataCell(const Text('Région')), DataCell(Text(valueOrDash(wine.region)))]),
      DataRow(cells: [DataCell(const Text('Pays')), DataCell(Text(valueOrDash(wine.country)))]),
      DataRow(cells: [DataCell(const Text('Couleur')), DataCell(Text(valueOrDash(wine.color)))]),
      DataRow(cells: [DataCell(const Text('Millésime')), DataCell(Text(intOrDash(wine.vintage)))]),
      DataRow(
        cells: [
          DataCell(const Text('Cépages')),
          DataCell(Text(
            wine.grapeVarieties.isEmpty ? '—' : wine.grapeVarieties.join(', '),
          )),
        ],
      ),
      DataRow(cells: [DataCell(const Text('Quantité')), DataCell(Text(intOrDash(wine.quantity)))]),
      DataRow(cells: [DataCell(const Text('Prix achat (€)')), DataCell(Text(doubleOrDash(wine.purchasePrice)))]),
      DataRow(cells: [DataCell(const Text('Boire dès')), DataCell(Text(intOrDash(wine.drinkFromYear)))]),
      DataRow(cells: [DataCell(const Text('Boire jusqu\'à')), DataCell(Text(intOrDash(wine.drinkUntilYear)))]),
      DataRow(cells: [DataCell(const Text('Notes dégustation')), DataCell(Text(valueOrDash(wine.tastingNotes)))]),
      DataRow(cells: [DataCell(const Text('Description IA')), DataCell(Text(valueOrDash(wine.description)))]),
      DataRow(
        cells: [
          DataCell(const Text('Infos à compléter')),
          DataCell(Text(_missingInfoLabel(wine))),
        ],
      ),
    ];
  }

  List<DataRow> _buildDirectRecapRows(CsvImportRow row) {
    String valueOrDash(String? value) {
      final trimmed = (value ?? '').trim();
      return trimmed.isEmpty ? '—' : trimmed;
    }

    String intOrDash(int? value) => value?.toString() ?? '—';
    String doubleOrDash(double? value) => value?.toStringAsFixed(2) ?? '—';

    return [
      DataRow(cells: [DataCell(const Text('Nom')), DataCell(Text(valueOrDash(row.name)))]),
      DataRow(cells: [DataCell(const Text('Appellation')), DataCell(Text(valueOrDash(row.appellation)))]),
      DataRow(cells: [DataCell(const Text('Producteur')), DataCell(Text(valueOrDash(row.producer)))]),
      DataRow(cells: [DataCell(const Text('Région')), DataCell(Text(valueOrDash(row.region)))]),
      DataRow(cells: [DataCell(const Text('Pays')), DataCell(Text(valueOrDash(row.country)))]),
      DataRow(cells: [DataCell(const Text('Couleur')), DataCell(Text(valueOrDash(row.color)))]),
      DataRow(cells: [DataCell(const Text('Millésime')), DataCell(Text(intOrDash(row.vintage)))]),
      DataRow(
        cells: [
          DataCell(const Text('Cépages')),
          DataCell(Text(
            row.grapeVarieties.isEmpty ? '—' : row.grapeVarieties.join(', '),
          )),
        ],
      ),
      DataRow(cells: [DataCell(const Text('Quantité')), DataCell(Text(intOrDash(row.quantity)))]),
      DataRow(cells: [DataCell(const Text('Prix achat (€)')), DataCell(Text(doubleOrDash(row.purchasePrice)))]),
      DataRow(cells: [DataCell(const Text('Localisation')), DataCell(Text(valueOrDash(row.location)))]),
      DataRow(cells: [DataCell(const Text('Notes')), DataCell(Text(valueOrDash(row.notes)))]),
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
              Expanded(
                child: Text(message),
              ),
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
    int maxRows = 2,
  }) {
    try {
      final rawRows = const CsvToListConverter(
        shouldParseNumbers: false,
        eol: '\n',
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
    List<int> matchedCategoryIds,
  ) {
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
    );
  }
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
              child: DataTable(
                columns: widget.columns,
                rows: widget.rows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
