import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/helpers/expert_cellar_editor_helper.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

class ExpertCellarEditorScreen extends ConsumerStatefulWidget {
  final String initialName;
  final int initialRows;
  final int initialColumns;
  final VirtualCellarTheme initialTheme;
  final VirtualCellarEntity? sourceCellar;

  const ExpertCellarEditorScreen({
    super.key,
    required this.initialName,
    required this.initialRows,
    required this.initialColumns,
    required this.initialTheme,
    this.sourceCellar,
  });

  @override
  ConsumerState<ExpertCellarEditorScreen> createState() =>
      _ExpertCellarEditorScreenState();
}

class _ExpertCellarEditorScreenState
    extends ConsumerState<ExpertCellarEditorScreen> {
  static const int _maxHistory = 50;
  static const int _maxSize = 30;

  late final TextEditingController _nameCtrl;
  late final TextEditingController _rowsCtrl;
  late final TextEditingController _colsCtrl;
  final ScrollController _toolbarScrollController = ScrollController();
  late VirtualCellarTheme _theme;

  List<List<bool>> _grid = <List<bool>>[];
  ExpertSelectionState _selectionState = ExpertSelectionState.empty();

  (int, int)? _dragAnchor;

  final List<List<List<bool>>> _undoStack = <List<List<bool>>>[];
  final List<List<List<bool>>> _redoStack = <List<List<bool>>>[];

  ExpertCellarDraftPayload? _pendingDraft;
  Timer? _saveDebounce;
  Timer? _periodicSave;
  bool _dirtySinceLastSave = false;
  bool _validated = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.initialName);
    _rowsCtrl = TextEditingController(text: widget.initialRows.toString());
    _colsCtrl = TextEditingController(text: widget.initialColumns.toString());
    _theme = widget.sourceCellar?.theme ?? widget.initialTheme;
    _grid = _buildInitialGrid();
    _loadDraftIfAny();
    _periodicSave = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_dirtySinceLastSave) {
        _saveDraft();
      }
    });
  }

  @override
  void dispose() {
    _saveDebounce?.cancel();
    _periodicSave?.cancel();
    if (!_validated && _dirtySinceLastSave) {
      _saveDraft();
    }
    _nameCtrl.dispose();
    _rowsCtrl.dispose();
    _colsCtrl.dispose();
    _toolbarScrollController.dispose();
    super.dispose();
  }

  List<List<bool>> _buildInitialGrid() {
    return ExpertCellarEditorHelper.buildInitialGrid(
      initialRows: widget.initialRows,
      initialColumns: widget.initialColumns,
      sourceCellar: widget.sourceCellar,
    );
  }

  Future<void> _loadDraftIfAny() async {
    final storage = ref.read(secureStorageProvider);
    final raw = await storage.read(key: AppConstants.keyExpertCellarDraft);
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    final draft = ExpertCellarDraftPayload.tryParse(raw);
    if (draft == null) return;

    setState(() {
      _pendingDraft = draft;
    });
  }

  Future<void> _saveDraft() async {
    final payload = ExpertCellarDraftPayload(
      name: _nameCtrl.text.trim(),
      rows: _grid.length,
      cols: _grid.isEmpty ? 0 : _grid.first.length,
      emptyCells: ExpertCellarEditorHelper.extractEmptyCells(_grid),
    );

    final storage = ref.read(secureStorageProvider);
    await storage.write(
      key: AppConstants.keyExpertCellarDraft,
      value: payload.toJsonString(),
    );

    _dirtySinceLastSave = false;
  }

  Future<String> _generateDefaultCellarName() async {
    final result = await ref.read(virtualCellarRepositoryProvider).getAll();
    final names = result
        .getOrElse((_) => const [])
        .map((c) => c.name);
    return ExpertCellarEditorHelper.generateDefaultCellarName(names);
  }

  Future<void> _clearDraft() async {
    final storage = ref.read(secureStorageProvider);
    await storage.delete(key: AppConstants.keyExpertCellarDraft);
  }

  void _scheduleDraftSave() {
    _dirtySinceLastSave = true;
    _saveDebounce?.cancel();
    _saveDebounce = Timer(const Duration(milliseconds: 600), () {
      _saveDraft();
    });
  }

  List<List<bool>> _cloneGrid(List<List<bool>> source) {
    return ExpertCellarEditorHelper.cloneGrid(source);
  }

  void _pushUndoSnapshot() {
    final history = ExpertCellarEditorHelper.pushUndoSnapshot(
      grid: _grid,
      undoStack: _undoStack,
      redoStack: _redoStack,
      maxHistory: _maxHistory,
    );
    _undoStack
      ..clear()
      ..addAll(history.undoStack);
    _redoStack
      ..clear()
      ..addAll(history.redoStack);
  }

  void _applyMutation(VoidCallback mutation) {
    _pushUndoSnapshot();
    mutation();
    _scheduleDraftSave();
  }

  void _clearSelection() {
    _selectionState = ExpertSelectionState.empty();
  }

  Set<(int, int)> _currentSelectionCells() {
    final rows = _grid.length;
    final cols = rows == 0 ? 0 : _grid.first.length;
    return ExpertCellarEditorHelper.currentSelectionCells(
      selectionState: _selectionState,
      rowCount: rows,
      colCount: cols,
    );
  }

  void _toggleCellSelection(int row, int col) {
    setState(() {
      _selectionState = ExpertCellarEditorHelper.toggleCellSelection(
        selectionState: _selectionState,
        row: row,
        col: col,
      );
    });
  }

  void _startDragSelection(int row, int col) {
    setState(() {
      _selectionState = ExpertCellarEditorHelper.startCellSelection(
        row: row,
        col: col,
      );
      _dragAnchor = (row, col);
    });
  }

  void _updateDragSelection(DragUpdateDetails details) {
    final anchor = _dragAnchor;
    if (anchor == null) return;

    final rows = _grid.length;
    final cols = _grid.first.length;

    final rowDelta = (details.localPosition.dy / 36).floor();
    final colDelta = (details.localPosition.dx / 36).floor();

    setState(() {
      _selectionState = ExpertCellarEditorHelper.dragSelection(
        anchor: anchor,
        rowDelta: rowDelta,
        colDelta: colDelta,
        rowCount: rows,
        colCount: cols,
      );
    });
  }

  void _markSelection(bool active) {
    final selected = _currentSelectionCells();
    if (selected.isEmpty) return;

    setState(() {
      _applyMutation(() {
        _grid = ExpertCellarEditorHelper.applySelectionValue(
          grid: _grid,
          selectedCells: selected,
          active: active,
        );
      });
    });
  }

  void _insertRow({required bool before}) {
    final result = ExpertCellarEditorHelper.insertRow(
      grid: _grid,
      selectionState: _selectionState,
      before: before,
      maxGridSize: _maxSize,
    );
    if (result == null) return;

    setState(() {
      _applyMutation(() {
        _grid = result.grid;
        _selectionState = result.selectionState;
      });
    });
  }

  void _insertColumn({required bool before}) {
    final result = ExpertCellarEditorHelper.insertColumn(
      grid: _grid,
      selectionState: _selectionState,
      before: before,
      maxGridSize: _maxSize,
    );
    if (result == null) return;

    setState(() {
      _applyMutation(() {
        _grid = result.grid;
        _selectionState = result.selectionState;
      });
    });
  }

  void _deleteRow() {
    final result = ExpertCellarEditorHelper.deleteRow(
      grid: _grid,
      selectionState: _selectionState,
    );
    if (result == null) return;

    setState(() {
      _applyMutation(() {
        _grid = result.grid;
        _selectionState = result.selectionState;
      });
    });
  }

  void _deleteColumn() {
    final result = ExpertCellarEditorHelper.deleteColumn(
      grid: _grid,
      selectionState: _selectionState,
    );
    if (result == null) return;

    setState(() {
      _applyMutation(() {
        _grid = result.grid;
        _selectionState = result.selectionState;
      });
    });
  }

  void _undo() {
    final history = ExpertCellarEditorHelper.applyUndo(
      grid: _grid,
      undoStack: _undoStack,
      redoStack: _redoStack,
    );
    if (history == null) return;

    setState(() {
      _grid = history.grid;
      _undoStack
        ..clear()
        ..addAll(history.undoStack);
      _redoStack
        ..clear()
        ..addAll(history.redoStack);
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  void _redo() {
    final history = ExpertCellarEditorHelper.applyRedo(
      grid: _grid,
      undoStack: _undoStack,
      redoStack: _redoStack,
    );
    if (history == null) return;

    setState(() {
      _grid = history.grid;
      _undoStack
        ..clear()
        ..addAll(history.undoStack);
      _redoStack
        ..clear()
        ..addAll(history.redoStack);
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  void _applyDimensionsReset() {
    final resetGrid = ExpertCellarEditorHelper.buildResetGrid(
      rowsText: _rowsCtrl.text,
      colsText: _colsCtrl.text,
      maxGridSize: _maxSize,
    );
    if (resetGrid == null) return;

    setState(() {
      _grid = resetGrid;
      _undoStack.clear();
      _redoStack.clear();
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  Set<CellarCellPosition> _extractEmptyCells(List<List<bool>> grid) {
    return ExpertCellarEditorHelper.extractEmptyCells(grid);
  }

  Future<void> _validateAndSave() async {
    final rows = _grid.length;
    final cols = _grid.first.length;
    final emptyCells = _extractEmptyCells(_grid);
    final summaryLines = ExpertCellarEditorHelper.validationSummaryLines(_grid);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recapitulatif'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final line in summaryLines) Text(line),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final effectiveName = ExpertCellarEditorHelper.normalizeCellarName(
          _nameCtrl.text,
        )
        .isNotEmpty
        ? ExpertCellarEditorHelper.normalizeCellarName(_nameCtrl.text)
        : await _generateDefaultCellarName();

    final base = widget.sourceCellar;
    final entity = ExpertCellarEditorHelper.buildValidatedCellarEntity(
      grid: _grid,
      effectiveName: effectiveName,
      theme: _theme,
      now: DateTime.now(),
      sourceCellar: base,
    );

    final result = base?.id == null
        ? await ref.read(createVirtualCellarUseCaseProvider).call(entity)
        : await ref.read(updateVirtualCellarUseCaseProvider).call(entity);

    if (!mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (_) async {
        _validated = true;
        await _clearDraft();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final rows = _grid.length;
    final cols = _grid.isEmpty ? 0 : _grid.first.length;
    final selectedCells = _currentSelectionCells();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mode expert'),
        actions: [
          IconButton(
            onPressed: _undoStack.isEmpty ? null : _undo,
            icon: const Icon(Icons.undo),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: _redoStack.isEmpty ? null : _redo,
            icon: const Icon(Icons.redo),
            tooltip: 'Redo',
          ),
        ],
      ),
      body: Column(
        children: [
          if (_pendingDraft != null)
            MaterialBanner(
              content: const Text(
                'Un brouillon expert existe. Reprendre ou recommencer ?',
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    final draft = _pendingDraft;
                    if (draft == null) return;
                    setState(() {
                      _nameCtrl.text = draft.name;
                      _rowsCtrl.text = draft.rows.toString();
                      _colsCtrl.text = draft.cols.toString();
                      _grid = draft.toGrid();
                      _undoStack.clear();
                      _redoStack.clear();
                      _clearSelection();
                      _pendingDraft = null;
                    });
                  },
                  child: const Text('Reprendre'),
                ),
                TextButton(
                  onPressed: () async {
                    await _clearDraft();
                    if (!mounted) return;
                    setState(() {
                      _pendingDraft = null;
                    });
                  },
                  child: const Text('Recommencer'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Scrollbar(
              controller: _toolbarScrollController,
              thumbVisibility: true,
              scrollbarOrientation: ScrollbarOrientation.bottom,
              child: SingleChildScrollView(
                controller: _toolbarScrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nom',
                          isDense: true,
                        ),
                        onChanged: (_) => _scheduleDraftSave(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 320,
                      child: VirtualCellarThemeSelector(
                        selectedTheme: _theme,
                        onChanged: (theme) {
                          setState(() {
                            _theme = theme;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 76,
                      child: TextField(
                        controller: _rowsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Lignes',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 90,
                      child: TextField(
                        controller: _colsCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Colonnes',
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton(
                      onPressed: _applyDimensionsReset,
                      child: const Text('Remise a zero grille'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: _validateAndSave,
                      child: const Text('Valider'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 16,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Attention: la remise a zero grille applique les nouvelles dimensions et efface la configuration actuelle.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (selectedCells.isNotEmpty) _buildSelectionToolbar(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  ExpertCellarEditorHelper.selectionSummaryLabel(
                    rows: rows,
                    cols: cols,
                    selectedCount: selectedCells.length,
                  ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Expanded(
            child: InteractiveViewer(
              minScale: 0.7,
              maxScale: 2.2,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: _buildGridTable(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionToolbar() {
    final rowSelected =
      ExpertCellarEditorHelper.shouldShowRowActions(_selectionState);
    final colSelected =
      ExpertCellarEditorHelper.shouldShowColumnActions(_selectionState);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        children: [
          TextButton.icon(
            onPressed: () => _markSelection(false),
            icon: const Icon(Icons.block),
            label: const Text('Marquer vide'),
          ),
          TextButton.icon(
            onPressed: () => _markSelection(true),
            icon: const Icon(Icons.check_circle_outline),
            label: const Text('Marquer active'),
          ),
          if (rowSelected) ...[
            TextButton(
              onPressed: () => _insertRow(before: true),
              child: const Text('Inserer ligne avant'),
            ),
            TextButton(
              onPressed: () => _insertRow(before: false),
              child: const Text('Inserer ligne apres'),
            ),
            TextButton(
              onPressed: _deleteRow,
              child: const Text('Supprimer ligne'),
            ),
          ],
          if (colSelected) ...[
            TextButton(
              onPressed: () => _insertColumn(before: true),
              child: const Text('Inserer colonne avant'),
            ),
            TextButton(
              onPressed: () => _insertColumn(before: false),
              child: const Text('Inserer colonne apres'),
            ),
            TextButton(
              onPressed: _deleteColumn,
              child: const Text('Supprimer colonne'),
            ),
          ],
          TextButton(
            onPressed: () => setState(_clearSelection),
            child: const Text('Effacer selection'),
          ),
        ],
      ),
    );
  }

  Widget _buildGridTable() {
    final rows = _grid.length;
    final cols = _grid.first.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const SizedBox(width: 34),
            for (var col = 0; col < cols; col++)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectionState = ExpertSelectionState.column(col);
                  });
                },
                child: Container(
                  width: 36,
                  height: 30,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color:
                      _selectionState.type == ExpertSelectionType.column &&
                        _selectionState.selectedCol == col
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${col + 1}'),
                ),
              ),
          ],
        ),
        for (var row = 0; row < rows; row++)
          Row(
            children: [
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectionState = ExpertSelectionState.row(row);
                  });
                },
                child: Container(
                  width: 34,
                  height: 36,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color:
                      _selectionState.type == ExpertSelectionType.row &&
                        _selectionState.selectedRow == row
                        ? Theme.of(context).colorScheme.primaryContainer
                        : Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${row + 1}'),
                ),
              ),
              for (var col = 0; col < cols; col++) _buildCell(row, col),
            ],
          ),
      ],
    );
  }

  Widget _buildCell(int row, int col) {
    final isSelected = _currentSelectionCells().contains((row, col));
    final active = _grid[row][col];

    return GestureDetector(
      onTap: () => _toggleCellSelection(row, col),
      onPanStart: (_) => _startDragSelection(row, col),
      onPanUpdate: _updateDragSelection,
      onPanEnd: (_) => _dragAnchor = null,
      child: Container(
        width: 36,
        height: 36,
        margin: const EdgeInsets.all(1),
        decoration: BoxDecoration(
          color: active
              ? Theme.of(context).colorScheme.surface
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        child: active
            ? Icon(
                Icons.wine_bar,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              )
            : Icon(
                Icons.block,
                size: 14,
                color: Theme.of(context).colorScheme.outline,
              ),
      ),
    );
  }
}
