import 'package:flutter/material.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/csv_column_mapping.dart';

class CsvMappingDialogResult {
  final CsvColumnMapping mapping;
  final bool hasHeader;

  const CsvMappingDialogResult({
    required this.mapping,
    required this.hasHeader,
  });
}

class CsvColumnMappingDialog extends StatefulWidget {
  final List<List<String>> previewRows;

  const CsvColumnMappingDialog({
    super.key,
    this.previewRows = const [],
  });

  @override
  State<CsvColumnMappingDialog> createState() => _CsvColumnMappingDialogState();
}

class _CsvColumnMappingDialogState extends State<CsvColumnMappingDialog> {
  final _nameCtrl = TextEditingController();
  final _vintageCtrl = TextEditingController();
  final _producerCtrl = TextEditingController();
  final _appellationCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController();
  final _colorCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  final _grapeVarietiesCtrl = TextEditingController();
  final _purchasePriceCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final Set<TextEditingController> _autoDetectedControllers = {};
  bool _hasHeader = true;

  @override
  void initState() {
    super.initState();
    _applyAutoMappingFromPreview();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _vintageCtrl.dispose();
    _producerCtrl.dispose();
    _appellationCtrl.dispose();
    _quantityCtrl.dispose();
    _colorCtrl.dispose();
    _regionCtrl.dispose();
    _countryCtrl.dispose();
    _grapeVarietiesCtrl.dispose();
    _purchasePriceCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Mapping des colonnes CSV'),
      content: SizedBox(
        width: 580,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Renseignez le numéro de colonne pour chaque champ (1-based).\nLaissez vide si absent.',
              ),
              if (widget.previewRows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Aperçu du CSV (2 premières lignes)',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                _CsvPreviewTable(rows: widget.previewRows),
              ],
              const SizedBox(height: 12),
              SwitchListTile(
                value: _hasHeader,
                contentPadding: EdgeInsets.zero,
                title: const Text('Le CSV contient une ligne d\'en-tête'),
                onChanged: (value) => setState(() => _hasHeader = value),
              ),
              const SizedBox(height: 8),
              _mappingField('Nom *', _nameCtrl),
              _mappingField('Millésime', _vintageCtrl),
              _mappingField('Producteur', _producerCtrl),
              _mappingField('Appellation', _appellationCtrl),
              _mappingField('Quantité', _quantityCtrl),
              _mappingField('Couleur', _colorCtrl),
              _mappingField('Région', _regionCtrl),
              _mappingField('Pays', _countryCtrl),
              _mappingField('Cépages', _grapeVarietiesCtrl),
              _mappingField('Prix achat', _purchasePriceCtrl),
              _mappingField('Localisation', _locationCtrl),
              _mappingField('Notes', _notesCtrl),
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

  Widget _mappingField(String label, TextEditingController controller) {
    final isAutoDetected = _autoDetectedControllers.contains(controller);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
          labelText: label,
          hintText: 'Ex: 1',
          suffixText: isAutoDetected ? 'Auto' : null,
          suffixIcon: isAutoDetected
              ? const Tooltip(
                  message: 'Champ auto-détecté depuis l\'en-tête CSV',
                  child: Icon(Icons.auto_awesome, size: 18),
                )
              : null,
        ),
      ),
    );
  }

  void _submit() {
    final mapping = CsvColumnMapping(
      name: _parseColumn(_nameCtrl.text),
      vintage: _parseColumn(_vintageCtrl.text),
      producer: _parseColumn(_producerCtrl.text),
      appellation: _parseColumn(_appellationCtrl.text),
      quantity: _parseColumn(_quantityCtrl.text),
      color: _parseColumn(_colorCtrl.text),
      region: _parseColumn(_regionCtrl.text),
      country: _parseColumn(_countryCtrl.text),
      grapeVarieties: _parseColumn(_grapeVarietiesCtrl.text),
      purchasePrice: _parseColumn(_purchasePriceCtrl.text),
      location: _parseColumn(_locationCtrl.text),
      notes: _parseColumn(_notesCtrl.text),
    );

    if (!mapping.hasMinimumFields) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('La colonne "Nom" est obligatoire.')),
      );
      return;
    }

    Navigator.of(context).pop(
      CsvMappingDialogResult(mapping: mapping, hasHeader: _hasHeader),
    );
  }

  void _applyAutoMappingFromPreview() {
    if (widget.previewRows.isEmpty) {
      return;
    }

    final headerRow = widget.previewRows.first;

    for (var index = 0; index < headerRow.length; index++) {
      final header = headerRow[index];
      final controller = _targetControllerForHeader(header);
      if (controller == null || controller.text.trim().isNotEmpty) {
        continue;
      }
      controller.text = (index + 1).toString();
      _autoDetectedControllers.add(controller);
    }
  }

  TextEditingController? _targetControllerForHeader(String header) {
    final normalized = _normalizeHeader(header);
    if (normalized.isEmpty) {
      return null;
    }

    if (_matchesAny(normalized, const [
      'nom',
      'vin',
      'wine',
      'cuvee',
      'nomvin',
      'nomcuvee',
    ])) {
      return _nameCtrl;
    }

    if (_matchesAny(normalized, const [
      'millesime',
      'vintage',
      'annee',
      'year',
    ])) {
      return _vintageCtrl;
    }

    if (_matchesAny(normalized, const [
      'producteur',
      'producer',
      'domaine',
      'chateau',
      'maison',
      'winery',
    ])) {
      return _producerCtrl;
    }

    if (_matchesAny(normalized, const [
      'appellation',
      'aoc',
      'doc',
      'igp',
    ])) {
      return _appellationCtrl;
    }

    if (_matchesAny(normalized, const [
      'quantite',
      'qte',
      'qty',
      'quantity',
      'stock',
      'bouteilles',
      'nbbouteilles',
    ])) {
      return _quantityCtrl;
    }

    if (_matchesAny(normalized, const [
      'couleur',
      'color',
      'typevin',
      'type',
    ])) {
      return _colorCtrl;
    }

    if (_matchesAny(normalized, const [
      'region',
      'area',
      'zone',
    ])) {
      return _regionCtrl;
    }

    if (_matchesAny(normalized, const [
      'pays',
      'country',
    ])) {
      return _countryCtrl;
    }

    if (_matchesAny(normalized, const [
      'cepage',
      'cepages',
      'grape',
      'grapes',
      'variete',
      'varietes',
      'assemblage',
    ])) {
      return _grapeVarietiesCtrl;
    }

    if (_matchesAny(normalized, const [
      'prix',
      'price',
      'cout',
      'coutachat',
      'prixachat',
      'purchaseprice',
      'achat',
    ])) {
      return _purchasePriceCtrl;
    }

    if (_matchesAny(normalized, const [
      'localisation',
      'location',
      'emplacement',
      'casier',
      'etagere',
      'cave',
    ])) {
      return _locationCtrl;
    }

    if (_matchesAny(normalized, const [
      'notes',
      'note',
      'commentaire',
      'commentaires',
      'remarque',
      'description',
    ])) {
      return _notesCtrl;
    }

    return null;
  }

  bool _matchesAny(String source, List<String> needles) {
    for (final needle in needles) {
      if (source.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  String _normalizeHeader(String value) {
    var output = value.toLowerCase().trim();

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
      output = output.replaceAll(from, to);
    });

    output = output.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return output;
  }

  int? _parseColumn(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    final parsed = int.tryParse(trimmed);
    if (parsed == null || parsed <= 0) return null;
    return parsed;
  }
}

class _CsvPreviewTable extends StatefulWidget {
  final List<List<String>> rows;

  const _CsvPreviewTable({required this.rows});

  @override
  State<_CsvPreviewTable> createState() => _CsvPreviewTableState();
}

class _CsvPreviewTableState extends State<_CsvPreviewTable> {
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
    final maxColumns = widget.rows.fold<int>(0, (max, row) {
      return row.length > max ? row.length : max;
    });

    final columns = <DataColumn>[
      const DataColumn(label: Text('Ligne')),
      ...List.generate(
        maxColumns,
        (index) => DataColumn(label: Text('Col ${index + 1}')),
      ),
    ];

    final rows = List.generate(widget.rows.length, (rowIndex) {
      final row = widget.rows[rowIndex];
      return DataRow(
        cells: [
          DataCell(Text((rowIndex + 1).toString())),
          ...List.generate(
            maxColumns,
            (columnIndex) => DataCell(Text(
              columnIndex < row.length ? row[columnIndex] : '—',
            )),
          ),
        ],
      );
    });

    return SizedBox(
      height: 170,
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
              child: DataTable(columns: columns, rows: rows),
            ),
          ),
        ),
      ),
    );
  }
}
