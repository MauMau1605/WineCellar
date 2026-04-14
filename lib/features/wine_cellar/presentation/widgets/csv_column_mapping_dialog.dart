import 'package:flutter/material.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';

class CsvMappingDialogResult {
  final CsvColumnMapping mapping;
  final int? headerLine;

  const CsvMappingDialogResult({
    required this.mapping,
    required this.headerLine,
  });
}

/// Callback used to let the dialog request AI-assisted mapping analysis.
/// Returns a map of fieldName → 1-based column number, plus optionally
/// 'headerLine' → detected header line (1-based).
/// [allRows] carries up to 100 rows for deeper AI analysis.
typedef AiMappingCallback = Future<Map<String, dynamic>?> Function(
  List<List<String>> previewRows, {
  List<List<String>>? allRows,
});

class CsvColumnMappingDialog extends StatefulWidget {
  final List<List<String>> previewRows;

  /// Larger sample of rows (up to 100) sent to the AI for deeper analysis.
  /// Falls back to [previewRows] when null.
  final List<List<String>>? allRows;

  /// Optional callback for AI-assisted mapping. When non-null the dialog shows
  /// a "Pré-analyse IA" button that delegates mapping detection to the AI.
  final AiMappingCallback? onRequestAiMapping;

  const CsvColumnMappingDialog({
    super.key,
    this.previewRows = const [],
    this.allRows,
    this.onRequestAiMapping,
  });

  @override
  State<CsvColumnMappingDialog> createState() => _CsvColumnMappingDialogState();
}

class _CsvColumnMappingDialogState extends State<CsvColumnMappingDialog> {
  /// Maps fieldName → 1-based column number (or null).
  final Map<String, int?> _fieldMapping = {};

  /// Tracks how each field was assigned ('auto', 'ai', or 'manual').
  final Map<String, String> _assignmentSource = {};

  /// 1-based header line number, or null if no header.
  int? _headerLine = 1;

  bool _isAiAnalysing = false;

  /// Whether the field assignments panel is expanded.
  bool _isFieldPanelExpanded = true;

  @override
  void initState() {
    super.initState();
    // Default: header on line 1.
    _headerLine = widget.previewRows.isNotEmpty ? 1 : null;
    _applyAutoMappingFromPreview();
  }

  // ------------------------------------------------------------------
  // Build
  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxColumns = widget.previewRows.fold<int>(
      0,
      (max, row) => row.length > max ? row.length : max,
    );

    final assignedCount = _fieldMapping.values.where((v) => v != null).length;
    final totalFields = CsvColumnMapping.fieldNames.length;

    return AlertDialog(
      title: const Text('Mapping des colonnes CSV'),
      content: SizedBox(
        width: 660,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ------ Instructions ------
              Text(
                'Cliquez sur un en-tête de colonne pour l\'assigner à un champ, '
                'ou sur un champ ci-dessous pour lui assigner une colonne.',
                style: theme.textTheme.bodyMedium,
              ),

              // ------ AI mapping button + Reset ------
              if (widget.onRequestAiMapping != null) ...[
                const SizedBox(height: 8),
                _buildAiMappingRow(),
              ],

              // ------ CSV Preview Table ------
              if (widget.previewRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      'Aperçu du CSV',
                      style: theme.textTheme.titleSmall,
                    ),
                    const Spacer(),
                    Text(
                      '${widget.previewRows.length} ligne(s)',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _CsvInteractivePreview(
                  rows: widget.previewRows,
                  headerLine: _headerLine,
                  maxColumns: maxColumns,
                  fieldMapping: _fieldMapping,
                  onHeaderLineTap: _onHeaderLineTap,
                  onColumnTap: _onColumnTap,
                ),
              ],

              // ------ Header line selector ------
              const SizedBox(height: 12),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: _headerLine != null,
                        onChanged: (value) {
                          setState(() {
                            _headerLine = (value ?? false) ? 1 : null;
                            _clearMappingsAndReapply();
                          });
                        },
                      ),
                      const Text('Ligne d\'en-tête :'),
                    ],
                  ),
                  SizedBox(
                    width: 56,
                    child: TextField(
                      enabled: _headerLine != null,
                      keyboardType: TextInputType.number,
                      controller: TextEditingController(
                        text: _headerLine?.toString() ?? '',
                      ),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
                        ),
                      ),
                      onChanged: (value) {
                        final parsed = int.tryParse(value);
                        if (parsed != null &&
                            parsed >= 1 &&
                            parsed <= widget.previewRows.length) {
                          setState(() {
                            _headerLine = parsed;
                            _clearMappingsAndReapply();
                          });
                        }
                      },
                    ),
                  ),
                  if (_headerLine != null &&
                      _headerLine! <= widget.previewRows.length)
                    Text(
                      '(cliquez sur une ligne dans l\'aperçu)',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                ],
              ),

              // ------ Collapsible field assignments summary ------
              const SizedBox(height: 16),
              _buildCollapsibleFieldPanel(maxColumns, assignedCount, totalFields),

              // ------ Data validation warnings ------
              if (_headerLine != null) ...[
                const SizedBox(height: 12),
                _buildDataValidationWarnings(),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _submit,
          child: const Text('Valider'),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // AI mapping
  // ------------------------------------------------------------------

  Widget _buildAiMappingRow() {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          OutlinedButton.icon(
            onPressed: _isAiAnalysing ? null : _runAiMapping,
            icon: _isAiAnalysing
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.smart_toy, size: 18),
            label: Text(
              _isAiAnalysing
                  ? 'Analyse IA en cours…'
                  : 'Pré-analyse IA du mapping',
            ),
          ),
          const SizedBox(width: 8),
          if (_fieldMapping.values.any((v) => v != null))
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _fieldMapping.clear();
                  _assignmentSource.clear();
                });
              },
              icon: const Icon(Icons.restart_alt, size: 18),
              label: const Text('Réinitialiser'),
            ),
        ],
      ),
    );
  }

  Future<void> _runAiMapping() async {
    if (widget.onRequestAiMapping == null) return;
    setState(() => _isAiAnalysing = true);

    try {
      final result = await widget.onRequestAiMapping!(
        widget.previewRows,
        allRows: widget.allRows,
      );
      if (result == null || !mounted) return;

      setState(() {
        // Apply header line if detected.
        if (result.containsKey('headerLine') && result['headerLine'] is int) {
          _headerLine = result['headerLine'] as int;
        }

        // Apply mapping from AI.
        final mapping = result['mapping'];
        if (mapping is Map) {
          for (final fieldName in CsvColumnMapping.fieldNames) {
            final value = mapping[fieldName];
            if (value is int && value > 0) {
              _fieldMapping[fieldName] = value;
              _assignmentSource[fieldName] = 'ai';
            }
          }
        }
      });
    } finally {
      if (mounted) setState(() => _isAiAnalysing = false);
    }
  }

  // ------------------------------------------------------------------
  // Auto-detection (keyword-based fallback)
  // ------------------------------------------------------------------

  void _applyAutoMappingFromPreview() {
    if (widget.previewRows.isEmpty || _headerLine == null) return;
    final headerIndex = _headerLine! - 1;
    if (headerIndex >= widget.previewRows.length) return;

    final headerRow = widget.previewRows[headerIndex];
    for (var colIndex = 0; colIndex < headerRow.length; colIndex++) {
      final fieldName = _detectFieldFromHeader(headerRow[colIndex]);
      if (fieldName == null) continue;
      if (_fieldMapping[fieldName] != null) continue; // Don't overwrite.
      _fieldMapping[fieldName] = colIndex + 1;
      _assignmentSource[fieldName] = 'auto';
    }
  }

  void _clearMappingsAndReapply() {
    _fieldMapping.clear();
    _assignmentSource.clear();
    _applyAutoMappingFromPreview();
  }

  // ------------------------------------------------------------------
  // Header row keywords (same as before, used as AI fallback)
  // ------------------------------------------------------------------

  static const _headerKeywords = <String, List<String>>{
    'name': ['nom', 'vin', 'wine', 'cuvee', 'nomvin', 'nomcuvee'],
    'vintage': ['millesime', 'vintage', 'annee', 'year'],
    'producer': [
      'producteur',
      'producer',
      'domaine',
      'chateau',
      'maison',
      'winery',
    ],
    'appellation': ['appellation', 'aoc', 'doc', 'igp'],
    'quantity': [
      'quantite',
      'qte',
      'qty',
      'quantity',
      'stock',
      'bouteilles',
      'nbbouteilles',
    ],
    'color': ['couleur', 'color', 'typevin', 'type'],
    'region': ['region', 'area', 'zone'],
    'country': ['pays', 'country'],
    'grapeVarieties': [
      'cepage',
      'cepages',
      'grape',
      'grapes',
      'variete',
      'varietes',
      'assemblage',
    ],
    'purchasePrice': [
      'prix',
      'price',
      'cout',
      'coutachat',
      'prixachat',
      'purchaseprice',
      'achat',
    ],
    'location': [
      'localisation',
      'location',
      'emplacement',
      'casier',
      'etagere',
      'cave',
    ],
    'notes': [
      'notes',
      'note',
      'commentaire',
      'commentaires',
      'remarque',
      'description',
    ],
  };

  String? _detectFieldFromHeader(String header) {
    final normalized = _normalizeHeader(header);
    if (normalized.isEmpty) return null;

    for (final entry in _headerKeywords.entries) {
      for (final keyword in entry.value) {
        if (normalized.contains(keyword)) return entry.key;
      }
    }
    return null;
  }

  // ------------------------------------------------------------------
  // Interactions
  // ------------------------------------------------------------------

  void _onHeaderLineTap(int lineNumber) {
    setState(() {
      _headerLine = lineNumber;
      _clearMappingsAndReapply();
    });
  }

  void _onColumnTap(int columnNumber) {
    // Show a popup menu to assign the column to a field.
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final alreadyAssignedField = _fieldMapping.entries
        .where((e) => e.value == columnNumber)
        .map((e) => e.key)
        .firstOrNull;

    final items = <PopupMenuEntry<String>>[
      if (alreadyAssignedField != null)
        PopupMenuItem(
          value: '__clear__',
          child: Row(
            children: [
              const Icon(Icons.clear, size: 16),
              const SizedBox(width: 8),
              Text(
                'Retirer "${CsvColumnMapping.fieldLabels[alreadyAssignedField]}"',
              ),
            ],
          ),
        ),
      if (alreadyAssignedField != null) const PopupMenuDivider(),
      ...CsvColumnMapping.fieldNames.map(
        (fieldName) {
          final currentCol = _fieldMapping[fieldName];
          final label = CsvColumnMapping.fieldLabels[fieldName] ?? fieldName;
          final isRequired = fieldName == 'name';
          return PopupMenuItem(
            value: fieldName,
            child: Row(
              children: [
                if (currentCol == columnNumber)
                  const Icon(Icons.check, size: 16, color: Colors.green)
                else if (currentCol != null)
                  const Icon(Icons.swap_horiz, size: 16, color: Colors.orange)
                else
                  const SizedBox(width: 16),
                const SizedBox(width: 8),
                Text(
                  isRequired ? '$label *' : label,
                  style: isRequired
                      ? const TextStyle(fontWeight: FontWeight.bold)
                      : null,
                ),
                if (currentCol != null && currentCol != columnNumber) ...[
                  const Spacer(),
                  Text(
                    '(col $currentCol)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    ];

    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(100, 200, 200, 300),
      items: items,
    ).then((selectedField) {
      if (selectedField == null) return;
      setState(() {
        if (selectedField == '__clear__' && alreadyAssignedField != null) {
          _fieldMapping.remove(alreadyAssignedField);
          _assignmentSource.remove(alreadyAssignedField);
        } else {
          _fieldMapping[selectedField] = columnNumber;
          _assignmentSource[selectedField] = 'manual';
        }
      });
    });
  }

  Widget _buildCollapsibleFieldPanel(
    int maxColumns,
    int assignedCount,
    int totalFields,
  ) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() => _isFieldPanelExpanded = !_isFieldPanelExpanded);
          },
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(
                  _isFieldPanelExpanded
                      ? Icons.expand_less
                      : Icons.expand_more,
                  size: 20,
                ),
                const SizedBox(width: 4),
                Text('Champs assignés', style: theme.textTheme.titleSmall),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: assignedCount == totalFields
                        ? Colors.green.withValues(alpha: 0.15)
                        : theme.colorScheme.primaryContainer
                            .withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$assignedCount / $totalFields',
                    style: theme.textTheme.labelSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: assignedCount == totalFields
                          ? Colors.green.shade700
                          : theme.colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_isFieldPanelExpanded) ...[
          const SizedBox(height: 8),
          _buildFieldAssignmentsSummary(maxColumns),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Field assignments summary (chips) — clickable for bidirectional mapping
  // ------------------------------------------------------------------

  Widget _buildFieldAssignmentsSummary(int maxColumns) {
    final assigned = <String>[];
    final notAssigned = <String>[];

    for (final fieldName in CsvColumnMapping.fieldNames) {
      if (_fieldMapping[fieldName] != null) {
        assigned.add(fieldName);
      } else {
        notAssigned.add(fieldName);
      }
    }

    return Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        ...assigned.map((fieldName) {
          final col = _fieldMapping[fieldName]!;
          final label = CsvColumnMapping.fieldLabels[fieldName] ?? fieldName;
          final source = _assignmentSource[fieldName];
          final icon = source == 'ai'
              ? Icons.smart_toy
              : source == 'auto'
                  ? Icons.auto_awesome
                  : Icons.touch_app;
          final tooltip = source == 'ai'
              ? 'Détecté par l\'IA'
              : source == 'auto'
                  ? 'Auto-détecté depuis l\'en-tête'
                  : 'Assigné manuellement';

          return Tooltip(
            message: tooltip,
            child: GestureDetector(
              onTap: () => _onFieldTap(fieldName, maxColumns),
              child: Chip(
                avatar: Icon(icon, size: 14),
                label: Text('$label → Col $col'),
                deleteIcon: const Icon(Icons.close, size: 14),
                onDeleted: () {
                  setState(() {
                    _fieldMapping.remove(fieldName);
                    _assignmentSource.remove(fieldName);
                  });
                },
                visualDensity: VisualDensity.compact,
              ),
            ),
          );
        }),
        ...notAssigned.map((fieldName) {
          final label = CsvColumnMapping.fieldLabels[fieldName] ?? fieldName;
          final isRequired = fieldName == 'name';
          return GestureDetector(
            onTap: () => _onFieldTap(fieldName, maxColumns),
            child: Chip(
              label: Text(
                isRequired ? '$label *' : label,
                style: TextStyle(
                  color: isRequired ? Colors.red : Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              backgroundColor:
                  isRequired ? Colors.red.withValues(alpha: 0.1) : null,
              visualDensity: VisualDensity.compact,
            ),
          );
        }),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Bidirectional mapping: click on a field → choose a column
  // ------------------------------------------------------------------

  void _onFieldTap(String fieldName, int maxColumns) {
    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || maxColumns == 0) return;

    final currentCol = _fieldMapping[fieldName];
    final dataRows = _getDataRows();
    final fieldLabel = CsvColumnMapping.fieldLabels[fieldName] ?? fieldName;

    // Build column→field reverse mapping
    final columnToField = <int, String>{};
    for (final entry in _fieldMapping.entries) {
      if (entry.value != null) {
        columnToField[entry.value!] = entry.key;
      }
    }

    final items = <PopupMenuEntry<int?>>[
      if (currentCol != null) ...[
        PopupMenuItem(
          value: -1,
          child: Row(
            children: [
              const Icon(Icons.clear, size: 16),
              const SizedBox(width: 8),
              Text('Retirer l\'assignation (Col $currentCol)'),
            ],
          ),
        ),
        const PopupMenuDivider(),
      ],
      ...List.generate(maxColumns, (index) {
        final colNum = index + 1;
        final assignedTo = columnToField[colNum];
        final isCurrent = currentCol == colNum;

        // Get 2-3 sample values from this column
        final samples = <String>[];
        for (final row in dataRows.take(3)) {
          final val = _readCell(row, colNum);
          if (val != null && val.length <= 30) {
            samples.add(val);
          }
        }
        final sampleText =
            samples.isEmpty ? '' : samples.join(', ');

        return PopupMenuItem(
          value: colNum,
          child: Row(
            children: [
              if (isCurrent)
                const Icon(Icons.check, size: 16, color: Colors.green)
              else if (assignedTo != null)
                Icon(Icons.swap_horiz, size: 16, color: Colors.orange.shade700)
              else
                const SizedBox(width: 16),
              const SizedBox(width: 8),
              Text(
                'Col $colNum',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (assignedTo != null && !isCurrent) ...[
                const SizedBox(width: 4),
                Text(
                  '(${CsvColumnMapping.fieldLabels[assignedTo]})',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.orange.shade700,
                  ),
                ),
              ],
              if (sampleText.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    sampleText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                          fontStyle: FontStyle.italic,
                        ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        );
      }),
    ];

    // Position the popup near the chip
    final offset = renderBox.localToGlobal(Offset.zero);
    showMenu<int?>(
      context: context,
      position: RelativeRect.fromLTRB(
        offset.dx + 100,
        offset.dy + 200,
        offset.dx + 400,
        offset.dy + 400,
      ),
      items: items,
    ).then((selectedCol) {
      if (selectedCol == null) return;
      setState(() {
        if (selectedCol == -1) {
          _fieldMapping.remove(fieldName);
          _assignmentSource.remove(fieldName);
        } else {
          _fieldMapping[fieldName] = selectedCol;
          _assignmentSource[fieldName] = 'manual';
        }
      });
    });
  }

  // ------------------------------------------------------------------
  // Data validation warnings
  // ------------------------------------------------------------------

  Widget _buildDataValidationWarnings() {
    final warnings = <String>[];
    final dataRows = _getDataRows();

    if (dataRows.isEmpty) return const SizedBox.shrink();

    // Check vintage out of range
    final vintageCol = _fieldMapping['vintage'];
    if (vintageCol != null) {
      for (final row in dataRows.take(10)) {
        final val = _readCell(row, vintageCol);
        if (val == null) continue;
        final year = int.tryParse(val.replaceAll(RegExp(r'[^0-9]'), ''));
        if (year != null && (year < 1900 || year > DateTime.now().year + 2)) {
          warnings.add('Millésime suspect : "$val" (ligne)');
          break;
        }
      }
    }

    // Check negative quantity
    final qtyCol = _fieldMapping['quantity'];
    if (qtyCol != null) {
      for (final row in dataRows.take(10)) {
        final val = _readCell(row, qtyCol);
        if (val == null) continue;
        final qty = int.tryParse(val.replaceAll(RegExp(r'[^0-9-]'), ''));
        if (qty != null && qty < 0) {
          warnings.add('Quantité négative détectée : "$val"');
          break;
        }
      }
    }

    if (warnings.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.amber.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber, size: 16, color: Colors.amber),
              const SizedBox(width: 6),
              Text(
                'Avertissements',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...warnings.map(
            (w) => Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(w, style: Theme.of(context).textTheme.bodySmall),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Helpers
  // ------------------------------------------------------------------

  List<List<String>> _getDataRows() {
    if (widget.previewRows.isEmpty) return [];
    if (_headerLine == null) return widget.previewRows;
    return widget.previewRows.skip(_headerLine!).toList();
  }

  String? _readCell(List<String> row, int column1Based) {
    final index = column1Based - 1;
    if (index < 0 || index >= row.length) return null;
    final val = row[index].trim();
    return val.isEmpty ? null : val;
  }

  void _submit() {
    final mapping = CsvColumnMapping.fromFieldMap(_fieldMapping);

    if (!mapping.hasMinimumFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La colonne "Nom" est obligatoire.')),
      );
      return;
    }

    Navigator.of(context).pop(
      CsvMappingDialogResult(mapping: mapping, headerLine: _headerLine),
    );
  }

  String _normalizeHeader(String value) {
    var output = value.toLowerCase().trim();

    const replacements = {
      'à': 'a', 'á': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
      'æ': 'ae', 'ç': 'c',
      'è': 'e', 'é': 'e', 'ê': 'e', 'ë': 'e',
      'ì': 'i', 'í': 'i', 'î': 'i', 'ï': 'i',
      'ñ': 'n',
      'ò': 'o', 'ó': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o', 'œ': 'oe',
      'ù': 'u', 'ú': 'u', 'û': 'u', 'ü': 'u',
      'ý': 'y', 'ÿ': 'y',
    };

    replacements.forEach((from, to) {
      output = output.replaceAll(from, to);
    });

    output = output.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return output;
  }
}

// ====================================================================
// Interactive CSV Preview Table
// ====================================================================

class _CsvInteractivePreview extends StatefulWidget {
  final List<List<String>> rows;
  final int? headerLine;
  final int maxColumns;
  final Map<String, int?> fieldMapping;
  final ValueChanged<int> onHeaderLineTap;
  final ValueChanged<int> onColumnTap;

  const _CsvInteractivePreview({
    required this.rows,
    required this.headerLine,
    required this.maxColumns,
    required this.fieldMapping,
    required this.onHeaderLineTap,
    required this.onColumnTap,
  });

  @override
  State<_CsvInteractivePreview> createState() =>
      _CsvInteractivePreviewState();
}

class _CsvInteractivePreviewState extends State<_CsvInteractivePreview> {
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
    final theme = Theme.of(context);

    // Build reverse mapping: column → fieldName
    final columnToField = <int, String>{};
    for (final entry in widget.fieldMapping.entries) {
      if (entry.value != null) {
        columnToField[entry.value!] = entry.key;
      }
    }

    // Column headers: clickable for field assignment
    final columns = <DataColumn>[
      const DataColumn(label: Text('')),
      ...List.generate(widget.maxColumns, (index) {
        final colNum = index + 1;
        final assignedField = columnToField[colNum];
        final fieldLabel = assignedField != null
            ? CsvColumnMapping.fieldLabels[assignedField] ?? assignedField
            : null;

        return DataColumn(
          label: InkWell(
            onTap: () => widget.onColumnTap(colNum),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Col $colNum',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (fieldLabel != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        fieldLabel,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.onPrimaryContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    ];

    // Data rows: clickable row number for header selection
    final dataRows = List.generate(widget.rows.length, (rowIndex) {
      final row = widget.rows[rowIndex];
      final lineNum = rowIndex + 1;
      final isHeader = widget.headerLine == lineNum;
      final isBeforeHeader =
          widget.headerLine != null && lineNum < widget.headerLine!;

      final rowColor = isHeader
          ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
          : isBeforeHeader
              ? theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5)
              : null;

      return DataRow(
        color: rowColor != null
            ? WidgetStatePropertyAll(rowColor)
            : null,
        cells: [
          DataCell(
            InkWell(
              onTap: () => widget.onHeaderLineTap(lineNum),
              borderRadius: BorderRadius.circular(4),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      lineNum.toString(),
                      style: TextStyle(
                        fontWeight:
                            isHeader ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    if (isHeader) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.table_rows,
                        size: 14,
                        color: theme.colorScheme.primary,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          ...List.generate(
            widget.maxColumns,
            (colIndex) => DataCell(
              Text(
                colIndex < row.length ? row[colIndex] : '—',
                style: TextStyle(
                  fontStyle: isBeforeHeader ? FontStyle.italic : null,
                  color: isBeforeHeader ? Colors.grey : null,
                ),
              ),
            ),
          ),
        ],
      );
    });

    return SizedBox(
      height: 220,
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
                columnSpacing: 12,
                columns: columns,
                rows: dataRows,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
