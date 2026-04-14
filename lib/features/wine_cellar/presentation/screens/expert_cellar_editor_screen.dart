import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/cellar_cell_position.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';
import 'package:wine_cellar/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart';

enum _SelectionType { none, cells, row, column }

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
  _SelectionType _selectionType = _SelectionType.none;
  final Set<(int, int)> _selectedCells = <(int, int)>{};
  int? _selectedRow;
  int? _selectedCol;

  (int, int)? _dragAnchor;

  final List<List<List<bool>>> _undoStack = <List<List<bool>>>[];
  final List<List<List<bool>>> _redoStack = <List<List<bool>>>[];

  _DraftPayload? _pendingDraft;
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
    final src = widget.sourceCellar;
    final rows = src?.rows ?? widget.initialRows;
    final cols = src?.columns ?? widget.initialColumns;
    final grid = List<List<bool>>.generate(
      rows,
      (_) => List<bool>.filled(cols, true),
      growable: true,
    );

    if (src != null) {
      for (final cell in src.emptyCells) {
        final row = cell.row - 1;
        final col = cell.col - 1;
        if (row >= 0 && row < rows && col >= 0 && col < cols) {
          grid[row][col] = false;
        }
      }
    }

    return grid;
  }

  Future<void> _loadDraftIfAny() async {
    final storage = ref.read(secureStorageProvider);
    final raw = await storage.read(key: AppConstants.keyExpertCellarDraft);
    if (!mounted || raw == null || raw.trim().isEmpty) return;

    final draft = _DraftPayload.tryParse(raw);
    if (draft == null) return;

    setState(() {
      _pendingDraft = draft;
    });
  }

  Future<void> _saveDraft() async {
    final payload = _DraftPayload(
      name: _nameCtrl.text.trim(),
      rows: _grid.length,
      cols: _grid.isEmpty ? 0 : _grid.first.length,
      emptyCells: _extractEmptyCells(_grid),
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
        .map((c) => c.name.toLowerCase())
        .toSet();
    for (var i = 1;; i++) {
      final candidate = 'Cave $i';
      if (!names.contains(candidate.toLowerCase())) return candidate;
    }
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
    return source.map((row) => List<bool>.from(row)).toList(growable: true);
  }

  void _pushUndoSnapshot() {
    _undoStack.add(_cloneGrid(_grid));
    if (_undoStack.length > _maxHistory) {
      _undoStack.removeAt(0);
    }
    _redoStack.clear();
  }

  void _applyMutation(VoidCallback mutation) {
    _pushUndoSnapshot();
    mutation();
    _scheduleDraftSave();
  }

  void _clearSelection() {
    _selectionType = _SelectionType.none;
    _selectedCells.clear();
    _selectedRow = null;
    _selectedCol = null;
  }

  Set<(int, int)> _currentSelectionCells() {
    final rows = _grid.length;
    final cols = rows == 0 ? 0 : _grid.first.length;

    switch (_selectionType) {
      case _SelectionType.cells:
        return Set<(int, int)>.from(_selectedCells);
      case _SelectionType.row:
        final row = _selectedRow;
        if (row == null || row < 0 || row >= rows) return <(int, int)>{};
        return {for (var col = 0; col < cols; col++) (row, col)};
      case _SelectionType.column:
        final col = _selectedCol;
        if (col == null || col < 0 || col >= cols) return <(int, int)>{};
        return {for (var row = 0; row < rows; row++) (row, col)};
      case _SelectionType.none:
        return <(int, int)>{};
    }
  }

  void _toggleCellSelection(int row, int col) {
    setState(() {
      if (_selectionType != _SelectionType.cells) {
        _clearSelection();
        _selectionType = _SelectionType.cells;
      }
      final cell = (row, col);
      if (_selectedCells.contains(cell)) {
        _selectedCells.remove(cell);
      } else {
        _selectedCells.add(cell);
      }
      if (_selectedCells.isEmpty) {
        _selectionType = _SelectionType.none;
      }
    });
  }

  void _startDragSelection(int row, int col) {
    setState(() {
      _selectionType = _SelectionType.cells;
      _selectedCells
        ..clear()
        ..add((row, col));
      _selectedRow = null;
      _selectedCol = null;
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

    final targetRow = (anchor.$1 + rowDelta).clamp(0, rows - 1);
    final targetCol = (anchor.$2 + colDelta).clamp(0, cols - 1);

    final minRow = anchor.$1 < targetRow ? anchor.$1 : targetRow;
    final maxRow = anchor.$1 > targetRow ? anchor.$1 : targetRow;
    final minCol = anchor.$2 < targetCol ? anchor.$2 : targetCol;
    final maxCol = anchor.$2 > targetCol ? anchor.$2 : targetCol;

    setState(() {
      _selectedCells.clear();
      for (var r = minRow; r <= maxRow; r++) {
        for (var c = minCol; c <= maxCol; c++) {
          _selectedCells.add((r, c));
        }
      }
    });
  }

  void _markSelection(bool active) {
    final selected = _currentSelectionCells();
    if (selected.isEmpty) return;

    setState(() {
      _applyMutation(() {
        for (final (row, col) in selected) {
          _grid[row][col] = active;
        }
      });
    });
  }

  void _insertRow({required bool before}) {
    if (_selectionType != _SelectionType.row || _selectedRow == null) return;
    if (_grid.length >= _maxSize) return;

    final at = before ? _selectedRow! : _selectedRow! + 1;
    final cols = _grid.first.length;

    setState(() {
      _applyMutation(() {
        _grid.insert(at, List<bool>.filled(cols, true));
        _selectedRow = at;
      });
    });
  }

  void _insertColumn({required bool before}) {
    if (_selectionType != _SelectionType.column || _selectedCol == null) return;
    if (_grid.first.length >= _maxSize) return;

    final at = before ? _selectedCol! : _selectedCol! + 1;

    setState(() {
      _applyMutation(() {
        for (final row in _grid) {
          row.insert(at, true);
        }
        _selectedCol = at;
      });
    });
  }

  void _deleteRow() {
    if (_selectionType != _SelectionType.row || _selectedRow == null) return;
    if (_grid.length <= 1) return;

    setState(() {
      _applyMutation(() {
        _grid.removeAt(_selectedRow!);
        _selectedRow = _selectedRow!.clamp(0, _grid.length - 1);
      });
    });
  }

  void _deleteColumn() {
    if (_selectionType != _SelectionType.column || _selectedCol == null) return;
    if (_grid.first.length <= 1) return;

    setState(() {
      _applyMutation(() {
        for (final row in _grid) {
          row.removeAt(_selectedCol!);
        }
        _selectedCol = _selectedCol!.clamp(0, _grid.first.length - 1);
      });
    });
  }

  void _undo() {
    if (_undoStack.isEmpty) return;
    setState(() {
      _redoStack.add(_cloneGrid(_grid));
      _grid = _undoStack.removeLast();
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    setState(() {
      _undoStack.add(_cloneGrid(_grid));
      _grid = _redoStack.removeLast();
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  void _applyDimensionsReset() {
    final rows = int.tryParse(_rowsCtrl.text.trim());
    final cols = int.tryParse(_colsCtrl.text.trim());
    if (rows == null || cols == null) return;
    if (rows < 1 || cols < 1 || rows > _maxSize || cols > _maxSize) return;

    setState(() {
      _grid = List<List<bool>>.generate(
        rows,
        (_) => List<bool>.filled(cols, true),
        growable: true,
      );
      _undoStack.clear();
      _redoStack.clear();
      _clearSelection();
      _scheduleDraftSave();
    });
  }

  Set<CellarCellPosition> _extractEmptyCells(List<List<bool>> grid) {
    final cells = <CellarCellPosition>{};
    for (var row = 0; row < grid.length; row++) {
      for (var col = 0; col < grid[row].length; col++) {
        if (!grid[row][col]) {
          cells.add(CellarCellPosition(row: row + 1, col: col + 1));
        }
      }
    }
    return cells;
  }

  Future<void> _validateAndSave() async {
    final rows = _grid.length;
    final cols = _grid.first.length;
    final emptyCells = _extractEmptyCells(_grid);
    final total = rows * cols;
    final emptyCount = emptyCells.length;
    final activeCount = total - emptyCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Recapitulatif'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dimensions: $rows x $cols'),
            Text('Casiers actifs: $activeCount'),
            Text('Zones vides: $emptyCount'),
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

    final name = _nameCtrl.text.trim();
    final effectiveName = name.isNotEmpty
        ? name
        : await _generateDefaultCellarName();

    final base = widget.sourceCellar;
    final entity = VirtualCellarEntity(
      id: base?.id,
      name: effectiveName,
      rows: rows,
      columns: cols,
      emptyCells: emptyCells,
      theme: _theme,
      createdAt: base?.createdAt,
      updatedAt: DateTime.now(),
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
                '$rows x $cols - ${selectedCells.length} selection',
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
    final rowSelected = _selectionType == _SelectionType.row;
    final colSelected = _selectionType == _SelectionType.column;

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
                    _clearSelection();
                    _selectionType = _SelectionType.column;
                    _selectedCol = col;
                  });
                },
                child: Container(
                  width: 36,
                  height: 30,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color:
                        _selectionType == _SelectionType.column &&
                            _selectedCol == col
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
                    _clearSelection();
                    _selectionType = _SelectionType.row;
                    _selectedRow = row;
                  });
                },
                child: Container(
                  width: 34,
                  height: 36,
                  alignment: Alignment.center,
                  margin: const EdgeInsets.all(1),
                  decoration: BoxDecoration(
                    color:
                        _selectionType == _SelectionType.row &&
                            _selectedRow == row
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

class _DraftPayload {
  final String name;
  final int rows;
  final int cols;
  final Set<CellarCellPosition> emptyCells;

  const _DraftPayload({
    required this.name,
    required this.rows,
    required this.cols,
    required this.emptyCells,
  });

  List<List<bool>> toGrid() {
    final grid = List<List<bool>>.generate(
      rows,
      (_) => List<bool>.filled(cols, true),
      growable: true,
    );
    for (final cell in emptyCells) {
      final row = cell.row - 1;
      final col = cell.col - 1;
      if (row >= 0 && row < rows && col >= 0 && col < cols) {
        grid[row][col] = false;
      }
    }
    return grid;
  }

  String toJsonString() {
    return jsonEncode({
      'name': name,
      'rows': rows,
      'cols': cols,
      'emptyCells': emptyCells
          .map((cell) => {'row': cell.row, 'col': cell.col})
          .toList(growable: false),
    });
  }

  static _DraftPayload? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final name = (decoded['name'] ?? '').toString();
      final rows = decoded['rows'] is int
          ? decoded['rows'] as int
          : int.tryParse((decoded['rows'] ?? '').toString());
      final cols = decoded['cols'] is int
          ? decoded['cols'] as int
          : int.tryParse((decoded['cols'] ?? '').toString());

      if (rows == null || cols == null || rows < 1 || cols < 1) {
        return null;
      }

      final empty = <CellarCellPosition>{};
      final list = decoded['emptyCells'];
      if (list is List) {
        for (final item in list) {
          if (item is! Map) continue;
          final row = item['row'] is int
              ? item['row'] as int
              : int.tryParse((item['row'] ?? '').toString());
          final col = item['col'] is int
              ? item['col'] as int
              : int.tryParse((item['col'] ?? '').toString());
          if (row == null || col == null || row < 1 || col < 1) continue;
          empty.add(CellarCellPosition(row: row, col: col));
        }
      }

      return _DraftPayload(
        name: name,
        rows: rows,
        cols: cols,
        emptyCells: empty,
      );
    } catch (_) {
      return null;
    }
  }
}
