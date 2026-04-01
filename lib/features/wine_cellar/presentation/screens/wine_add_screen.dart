import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/ai_assistant/presentation/screens/chat_screen.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/food_category_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';
import 'package:wine_cellar/features/wine_cellar/domain/usecases/update_wine_quantity.dart';

enum _DuplicateChoice { incrementExisting, createNew }

enum _PlacementChoice { none, associateOnly, placeInSlot }

class _CreateNewCellarChoice {
  const _CreateNewCellarChoice();
}

/// Screen used to choose between AI-assisted add and manual add.
class WineAddScreen extends ConsumerStatefulWidget {
  const WineAddScreen({super.key});

  @override
  ConsumerState<WineAddScreen> createState() => _WineAddScreenState();
}

class _WineAddScreenState extends ConsumerState<WineAddScreen> {
  static const _createNewCellarChoice = _CreateNewCellarChoice();

  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _appellationCtrl = TextEditingController();
  final _producerCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  final _countryCtrl = TextEditingController(text: 'France');
  final _vintageCtrl = TextEditingController();
  final _grapesCtrl = TextEditingController();
  final _quantityCtrl = TextEditingController(text: '1');
  final _priceCtrl = TextEditingController();
  final _drinkFromCtrl = TextEditingController();
  final _drinkUntilCtrl = TextEditingController();
  final _tastingNotesCtrl = TextEditingController();
  final _ratingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _cellarXCtrl = TextEditingController();
  final _cellarYCtrl = TextEditingController();
  final _aiDescriptionCtrl = TextEditingController();

  WineColor _selectedColor = WineColor.red;
  bool _saving = false;
  List<FoodCategoryEntity> _allPairingCategories = const [];
  Set<int> _selectedPairingIds = <int>{};
  List<String> _existingLocations = const [];

  bool get _canSubmit {
    final hasName = _nameCtrl.text.trim().isNotEmpty;
    final vintage = int.tryParse(_vintageCtrl.text.trim());
    return hasName && vintage != null;
  }

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(_refresh);
    _vintageCtrl.addListener(_refresh);
    _loadFoodCategories();
    _loadExistingLocations();
  }

  Future<void> _loadFoodCategories() async {
    final categories = await ref
        .read(foodCategoryRepositoryProvider)
        .getAllCategories();
    if (!mounted) return;
    setState(() {
      _allPairingCategories = categories;
    });
  }

  Future<void> _loadExistingLocations() async {
    final result = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    if (!mounted) return;
    final cellars = result.getOrElse((_) => const []);
    setState(() {
      _existingLocations = cellars.map((c) => c.name).toList();
    });
  }

  @override
  void dispose() {
    _nameCtrl.removeListener(_refresh);
    _vintageCtrl.removeListener(_refresh);
    _nameCtrl.dispose();
    _appellationCtrl.dispose();
    _producerCtrl.dispose();
    _regionCtrl.dispose();
    _countryCtrl.dispose();
    _vintageCtrl.dispose();
    _grapesCtrl.dispose();
    _quantityCtrl.dispose();
    _priceCtrl.dispose();
    _drinkFromCtrl.dispose();
    _drinkUntilCtrl.dispose();
    _tastingNotesCtrl.dispose();
    _ratingCtrl.dispose();
    _notesCtrl.dispose();
    _locationCtrl.dispose();
    _cellarXCtrl.dispose();
    _cellarYCtrl.dispose();
    _aiDescriptionCtrl.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final disabledMessage =
        'Vous devez au minimum renseigner le nom du vin et son millésime.';

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un vin')),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Fiche de vin',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Saisissez tout manuellement ou utilisez l\'IA pour compléter automatiquement.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              const SizedBox(height: 16),

              _sectionTitle('Informations principales'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du vin *',
                  prefixIcon: Icon(Icons.wine_bar),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<WineColor>(
                initialValue: _selectedColor,
                decoration: const InputDecoration(
                  labelText: 'Couleur *',
                  prefixIcon: Icon(Icons.palette),
                ),
                items: WineColor.values
                    .map(
                      (c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.emoji} ${c.label}'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedColor = value);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _appellationCtrl,
                decoration: const InputDecoration(
                  labelText: 'Appellation',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _producerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Producteur',
                  prefixIcon: Icon(Icons.business),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _regionCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Région',
                        prefixIcon: Icon(Icons.map),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _countryCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Pays',
                        prefixIcon: Icon(Icons.flag),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _vintageCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Millésime *',
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _grapesCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Cépages',
                        prefixIcon: Icon(Icons.grass),
                        helperText: 'Séparés par des virgules',
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionTitle('Accords mets-vins'),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _saving ? null : _editFoodPairings,
                icon: const Icon(Icons.restaurant_menu),
                label: Text(
                  _selectedPairingIds.isEmpty
                      ? 'Choisir les accords'
                      : 'Modifier les accords (${_selectedPairingIds.length})',
                ),
              ),
              if (_selectedPairingIds.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allPairingCategories
                      .where((c) => _selectedPairingIds.contains(c.id))
                      .map(
                        (pairing) => Chip(
                          label: Text(
                            '${pairing.icon ?? '🍽️'} ${pairing.name}',
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],

              const SizedBox(height: 24),
              _sectionTitle('Cave'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _quantityCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Quantité',
                        prefixIcon: Icon(Icons.inventory_2),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Prix d\'achat (€)',
                        prefixIcon: Icon(Icons.euro),
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Autocomplete<String>(
                optionsBuilder: (textEditingValue) {
                  if (textEditingValue.text.isEmpty) {
                    return _existingLocations;
                  }
                  final query = textEditingValue.text.toLowerCase();
                  return _existingLocations.where(
                    (loc) => loc.toLowerCase().contains(query),
                  );
                },
                fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
                  // Sync initial value
                  if (controller.text != _locationCtrl.text && _locationCtrl.text.isNotEmpty) {
                    controller.text = _locationCtrl.text;
                  }
                  controller.addListener(() {
                    _locationCtrl.text = controller.text;
                  });
                  return TextFormField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(
                      labelText: 'Localisation',
                      prefixIcon: Icon(Icons.place),
                      helperText: 'Sélectionner ou saisir un nouveau nom',
                    ),
                  );
                },
                onSelected: (String selection) {
                  _locationCtrl.text = selection;
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cellarXCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Position cave X',
                        prefixIcon: Icon(Icons.straighten),
                        helperText: 'Coordonnée plan (optionnel)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _cellarYCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Position cave Y',
                        prefixIcon: Icon(Icons.straighten),
                        helperText: 'Coordonnée plan (optionnel)',
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ratingCtrl,
                decoration: const InputDecoration(
                  labelText: 'Note (1-5)',
                  prefixIcon: Icon(Icons.star),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value != null && value.isNotEmpty) {
                    final parsed = int.tryParse(value);
                    if (parsed == null || parsed < 1 || parsed > 5) {
                      return 'Entrez une note entre 1 et 5';
                    }
                  }
                  return null;
                },
              ),

              const SizedBox(height: 24),
              _sectionTitle('Garde'),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _drinkFromCtrl,
                      decoration: const InputDecoration(
                        labelText: 'À boire dès',
                        prefixIcon: Icon(Icons.hourglass_top),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _drinkUntilCtrl,
                      decoration: const InputDecoration(
                        labelText: 'À boire jusqu\'à',
                        prefixIcon: Icon(Icons.hourglass_bottom),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),
              _sectionTitle('Notes'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tastingNotesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes de dégustation',
                  prefixIcon: Icon(Icons.local_bar),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notesCtrl,
                decoration: const InputDecoration(
                  labelText: 'Notes personnelles',
                  prefixIcon: Icon(Icons.note),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _aiDescriptionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Description (optionnelle)',
                  prefixIcon: Icon(Icons.description),
                  alignLabelWithHint: true,
                ),
                maxLines: 3,
              ),

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : () => context.go('/chat'),
                  icon: const Icon(Icons.auto_awesome),
                  label: const Text('Renseigner avec l\'assistant IA'),
                ),
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: _canSubmit ? '' : disabledMessage,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      foregroundColor: _canSubmit
                          ? null
                          : theme.colorScheme.surface.withValues(alpha: 0.9),
                    ),
                    onPressed: _saving ? null : _onCompleteWithAiPressed,
                    icon: const Icon(Icons.auto_fix_high),
                    label: const Text('Compléter cette fiche avec l\'IA'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Tooltip(
                message: _canSubmit ? '' : disabledMessage,
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: _canSubmit
                          ? null
                          : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                      foregroundColor: _canSubmit
                          ? null
                          : theme.colorScheme.surface.withValues(alpha: 0.9),
                    ),
                    onPressed: _saving ? null : _onManualAddPressed,
                    icon: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: const Text('Ajouter ce vin manuellement'),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.bold,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  /// If the location text doesn't match any existing virtual cellar name,
  /// create a new empty virtual cellar with that name.
  Future<void> _ensureVirtualCellarForLocation(String location) async {
    if (location.isEmpty) return;
    final exists = _existingLocations.any(
      (loc) => loc.toLowerCase() == location.toLowerCase(),
    );
    if (exists) return;

    final newCellar = VirtualCellarEntity(
      name: location,
      rows: 5,
      columns: 5,
    );
    await ref.read(createVirtualCellarUseCaseProvider).call(newCellar);
    await _loadExistingLocations();
  }

  Future<void> _onManualAddPressed() async {
    if (!_canSubmit) {
      await _showMissingInfoDialog();
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final entity = _buildEntityFromForm();

    final duplicate = await _findPotentialDuplicate(entity);
    if (!mounted) return;

    if (duplicate != null) {
      final choice = await _showDuplicateDialog(
        existingWine: duplicate,
        addedQuantity: entity.quantity,
      );
      if (!mounted || choice == null) return;

      if (choice == _DuplicateChoice.incrementExisting) {
        if (duplicate.id == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Impossible de mettre à jour ce vin.'),
            ),
          );
          return;
        }

        setState(() => _saving = true);

        final updatedQuantity = duplicate.quantity + entity.quantity;
        final result = await ref
            .read(updateWineQuantityUseCaseProvider)
            .call(
              UpdateQuantityParams(
                wineId: duplicate.id!,
                newQuantity: updatedQuantity,
              ),
            );

        result.fold(
          (failure) {
            if (!mounted) return;
            setState(() => _saving = false);
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(failure.message)));
          },
          (_) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Quantité mise à jour sur la fiche existante.'),
              ),
            );
            context.go('/cellar/wine/${duplicate.id}');
          },
        );
        return;
      }
    }

    setState(() => _saving = true);

    final location = _locationCtrl.text.trim();
    if (location.isNotEmpty) {
      await _ensureVirtualCellarForLocation(location);
      if (!mounted) return;
    }

    final result = await ref.read(addWineUseCaseProvider).call(entity);

    result.fold(
      (failure) {
        if (!mounted) return;
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(failure.message)));
      },
      (newId) {
        if (!mounted) return;
        setState(() => _saving = false);
        _askPlaceInCellar(newId);
      },
    );
  }

  Future<void> _askPlaceInCellar(int wineId) async {
    if (!mounted) return;

    // Show 3-option dialog
    final choice = await showDialog<_PlacementChoice>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Vin ajouté à la cave !'),
        content: const Text(
          'Comment souhaitez-vous gérer le stockage de ce vin ?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_PlacementChoice.none),
            child: const Text('Non merci'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(_PlacementChoice.associateOnly),
            child: const Text('Associer à une cave'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(_PlacementChoice.placeInSlot),
            child: const Text('Placer à un emplacement'),
          ),
        ],
      ),
    );

    if (!mounted || choice == null || choice == _PlacementChoice.none) {
      if (mounted) context.go('/cellar/wine/$wineId');
      return;
    }

    final selectedCellar = await _selectOrCreateCellar();
    if (!mounted || selectedCellar == null || selectedCellar.id == null) {
      if (mounted) context.go('/cellar/wine/$wineId');
      return;
    }

    // Update wine location to match selected cellar name
    await _updateWineLocation(wineId, selectedCellar.name);
    if (!mounted) return;

    if (choice == _PlacementChoice.associateOnly) {
      context.go('/cellar/wine/$wineId');
    } else {
      context.go('/cellars/${selectedCellar.id}?wineId=$wineId');
    }
  }

  Future<VirtualCellarEntity?> _selectOrCreateCellar() async {
    final cellarsResult = await ref
        .read(virtualCellarRepositoryProvider)
        .getAll();
    if (!mounted) return null;

    final cellars = cellarsResult.getOrElse((_) => const []);
    if (cellars.isEmpty) {
      // Auto-create a default cellar when none exists.
      return _createDefaultCellar(existingCellars: cellars);
    }

    final pickerResult = await _showCellarPicker(cellars);
    if (!mounted || pickerResult == null) return null;

    if (pickerResult == _createNewCellarChoice) {
      return _createDefaultCellar(existingCellars: cellars);
    }

    if (pickerResult is VirtualCellarEntity) {
      return pickerResult;
    }

    return null;
  }

  Future<VirtualCellarEntity?> _createDefaultCellar({
    required List<VirtualCellarEntity> existingCellars,
  }) async {
    final cellarName = _buildDefaultCellarName(existingCellars);
    final newCellar = VirtualCellarEntity(
      name: cellarName,
      rows: 5,
      columns: 5,
    );

    final createResult = await ref
        .read(createVirtualCellarUseCaseProvider)
        .call(newCellar);
    if (!mounted) return null;

    return createResult.fold(
      (failure) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(failure.message)),
          );
        }
        return null;
      },
      (id) {
        _loadExistingLocations();
        return newCellar.copyWith(id: id);
      },
    );
  }

  String _buildDefaultCellarName(List<VirtualCellarEntity> existingCellars) {
    final lowerNames = existingCellars
        .map((cellar) => cellar.name.trim().toLowerCase())
        .toSet();

    if (!lowerNames.contains('ma cave')) {
      return 'Ma cave';
    }

    var suffix = 2;
    while (lowerNames.contains('ma cave $suffix')) {
      suffix++;
    }
    return 'Ma cave $suffix';
  }

  Future<Object?> _showCellarPicker(
    List<VirtualCellarEntity> cellars,
  ) {
    return showDialog<Object>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Choisir une cave'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: cellars.length,
            itemBuilder: (context, index) {
              final cellar = cellars[index];
              return ListTile(
                leading: const Icon(Icons.grid_view_outlined),
                title: Text(cellar.name),
                subtitle: Text(
                  '${cellar.rows} × ${cellar.columns} — ${cellar.totalSlots} emplacements',
                ),
                onTap: () => Navigator.of(ctx).pop(cellar),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler'),
          ),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(_createNewCellarChoice),
            icon: const Icon(Icons.add),
            label: const Text('Créer une nouvelle cave (5×5)'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateWineLocation(int wineId, String cellarName) async {
    final wineResult = await ref.read(getWineByIdUseCaseProvider).call(wineId);
    if (!mounted) return;

    final wine = wineResult.getOrElse((_) => null);
    if (wine == null) return;

    final updated = wine.copyWith(location: cellarName);
    await ref.read(updateWineUseCaseProvider).call(updated);
  }

  Future<WineEntity?> _findPotentialDuplicate(WineEntity candidate) async {
    final allWines = await ref.read(wineRepositoryProvider).getAllWines();

    final normalizedName = _normalizeForDuplicate(candidate.name);
    final normalizedProducer = _normalizeForDuplicate(candidate.producer ?? '');
    final candidateVintage = candidate.vintage;

    for (final wine in allWines) {
      if (_normalizeForDuplicate(wine.name) != normalizedName) continue;
      if (wine.vintage != candidateVintage) continue;
      if (_normalizeForDuplicate(wine.producer ?? '') != normalizedProducer) {
        continue;
      }
      return wine;
    }

    return null;
  }

  Future<_DuplicateChoice?> _showDuplicateDialog({
    required WineEntity existingWine,
    required int addedQuantity,
  }) {
    return showDialog<_DuplicateChoice>(
      context: context,
      builder: (dialogContext) {
        final producer = (existingWine.producer ?? '').trim();
        final producerText = producer.isEmpty ? 'Non renseigné' : producer;

        return AlertDialog(
          title: const Text('Doublon probable détecté'),
          content: Text(
            'Une bouteille semblable existe probablement déjà dans votre cave :\n'
            '- Nom : ${existingWine.name}\n'
            '- Millésime : ${existingWine.vintage ?? '-'}\n'
            '- Domaine/Producteur : $producerText\n\n'
            'Souhaitez-vous incrémenter la quantité de cette fiche '
            '(+${addedQuantity <= 0 ? 1 : addedQuantity}) '
            'ou créer une nouvelle référence ?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(_DuplicateChoice.createNew),
              child: const Text('Créer une nouvelle référence'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(_DuplicateChoice.incrementExisting),
              child: const Text('Incrémenter la quantité'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _onCompleteWithAiPressed() async {
    if (!_canSubmit) {
      await _showMissingInfoDialog();
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final displayText = _buildFieldSummary();
    final aiPrompt = _buildAiCompletionPrompt(displayText);

    ChatScreen.pendingPrefill = PrefillData(
      displayText: displayText,
      aiPrompt: aiPrompt,
    );

    context.go('/chat');
  }

  Future<void> _showMissingInfoDialog() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Informations manquantes'),
        content: const Text(
          'Vous devez renseigner au minimum le nom du vin et son millésime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  WineEntity _buildEntityFromForm() {
    final grapes = _grapesCtrl.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList();

    return WineEntity(
      name: _nameCtrl.text.trim(),
      appellation: _emptyToNull(_appellationCtrl.text),
      producer: _emptyToNull(_producerCtrl.text),
      region: _emptyToNull(_regionCtrl.text),
      country: _emptyToNull(_countryCtrl.text) ?? 'France',
      color: _selectedColor,
      vintage: int.tryParse(_vintageCtrl.text.trim()),
      grapeVarieties: grapes,
      quantity: int.tryParse(_quantityCtrl.text.trim()) ?? 1,
      purchasePrice: double.tryParse(_priceCtrl.text.trim()),
      drinkFromYear: int.tryParse(_drinkFromCtrl.text.trim()),
      aiSuggestedDrinkFromYear: false,
      drinkUntilYear: int.tryParse(_drinkUntilCtrl.text.trim()),
      aiSuggestedDrinkUntilYear: false,
      tastingNotes: _emptyToNull(_tastingNotesCtrl.text),
      rating: int.tryParse(_ratingCtrl.text.trim()),
      notes: _emptyToNull(_notesCtrl.text),
      location: _emptyToNull(_locationCtrl.text),
      cellarPositionX: double.tryParse(_cellarXCtrl.text.trim()),
      cellarPositionY: double.tryParse(_cellarYCtrl.text.trim()),
      aiDescription: _emptyToNull(_aiDescriptionCtrl.text),
      foodCategoryIds: _selectedPairingIds.toList(),
      aiSuggestedFoodPairings: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Returns a human-readable list of the fields already filled in.
  /// This text is shown in the chat bubble.
  String _buildFieldSummary() {
    final fields = <String>[];

    void addField(String label, String? value) {
      if (value == null || value.trim().isEmpty) return;
      fields.add('- $label: ${value.trim()}');
    }

    addField('Nom', _nameCtrl.text);
    addField('Millésime', _vintageCtrl.text);
    addField('Couleur', _selectedColor.label);
    addField('Appellation', _appellationCtrl.text);
    addField('Producteur', _producerCtrl.text);
    addField('Région', _regionCtrl.text);
    addField('Pays', _countryCtrl.text);
    addField('Cépages', _grapesCtrl.text);
    addField('Quantité', _quantityCtrl.text);
    addField('Prix d\'achat', _priceCtrl.text);
    addField('À boire dès', _drinkFromCtrl.text);
    addField('À boire jusqu\'à', _drinkUntilCtrl.text);
    addField('Localisation', _locationCtrl.text);
    addField('Position cave X', _cellarXCtrl.text);
    addField('Position cave Y', _cellarYCtrl.text);
    addField('Note', _ratingCtrl.text);
    addField('Notes de dégustation', _tastingNotesCtrl.text);
    addField('Notes personnelles', _notesCtrl.text);
    addField('Description', _aiDescriptionCtrl.text);

    if (_selectedPairingIds.isNotEmpty) {
      final pairings = _allPairingCategories
          .where((c) => _selectedPairingIds.contains(c.id))
          .map((c) => c.name)
          .join(', ');
      addField('Accords mets-vins', pairings);
    }

    return fields.join('\n');
  }

  /// Wraps the field summary with instructions for the AI.
  String _buildAiCompletionPrompt(String fieldSummary) {
    final hasLocation = _locationCtrl.text.trim().isNotEmpty;

    final buffer = StringBuffer();
    buffer.writeln(
      'Complète la fiche de ce vin à partir des informations '
      'déjà saisies ci-dessous.',
    );
    buffer.writeln(
      'Conserve les valeurs fournies et complète uniquement '
      'les champs manquants.',
    );
    if (hasLocation) {
      buffer.writeln(
        'Note : le champ « Localisation » correspond à l\'emplacement '
        'physique de stockage dans la cave de l\'utilisateur. '
        'Ne l\'utilise pas comme indication sur la provenance, '
        'la région ou toute autre information relative au vin lui-même. '
        'Reporte sa valeur telle quelle dans la fiche finale.',
      );
    }
    buffer.writeln();
    buffer.write(fieldSummary);
    return buffer.toString().trim();
  }

  String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  String _normalizeForDuplicate(String value) {
    var normalized = value.trim().toLowerCase();

    const replacements = <String, String>{
      'à': 'a',
      'á': 'a',
      'â': 'a',
      'ã': 'a',
      'ä': 'a',
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
      'õ': 'o',
      'ö': 'o',
      'œ': 'oe',
      'ù': 'u',
      'ú': 'u',
      'û': 'u',
      'ü': 'u',
      'ÿ': 'y',
    };

    replacements.forEach((accented, plain) {
      normalized = normalized.replaceAll(accented, plain);
    });

    return normalized.replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<void> _editFoodPairings() async {
    final selected = Set<int>.from(_selectedPairingIds);
    final customCtrl = TextEditingController();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Accords mets-vins'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ..._allPairingCategories.map(
                      (category) => CheckboxListTile(
                        value: selected.contains(category.id),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${category.icon ?? '🍽️'} ${category.name}',
                        ),
                        onChanged: (checked) {
                          setDialogState(() {
                            if (checked == true) {
                              selected.add(category.id);
                            } else {
                              selected.remove(category.id);
                            }
                          });
                        },
                      ),
                    ),
                    const Divider(height: 20),
                    TextField(
                      controller: customCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Autre accord personnalisé',
                        hintText: 'Ex: Raclette',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Annuler'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Valider'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final customName = customCtrl.text.trim();
    if (customName.isNotEmpty) {
      final created = await ref
          .read(foodCategoryRepositoryProvider)
          .createOrGetCategory(customName, icon: '🍽️');
      if (!mounted) return;
      if (_allPairingCategories.every((c) => c.id != created.id)) {
        _allPairingCategories = [..._allPairingCategories, created];
      }
      selected.add(created.id);
    }

    if (!mounted) return;
    setState(() {
      _selectedPairingIds = selected;
    });
  }
}
