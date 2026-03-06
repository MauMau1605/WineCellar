import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

/// Screen for editing an existing wine's fields
class WineEditScreen extends ConsumerStatefulWidget {
  final int wineId;

  const WineEditScreen({super.key, required this.wineId});

  @override
  ConsumerState<WineEditScreen> createState() => _WineEditScreenState();
}

class _WineEditScreenState extends ConsumerState<WineEditScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _loading = true;
  bool _saving = false;
  WineEntity? _wine;

  // Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _appellationCtrl;
  late final TextEditingController _producerCtrl;
  late final TextEditingController _regionCtrl;
  late final TextEditingController _countryCtrl;
  late final TextEditingController _vintageCtrl;
  late final TextEditingController _grapesCtrl;
  late final TextEditingController _quantityCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _drinkFromCtrl;
  late final TextEditingController _drinkUntilCtrl;
  late final TextEditingController _tastingNotesCtrl;
  late final TextEditingController _ratingCtrl;
  late final TextEditingController _notesCtrl;
  late final TextEditingController _locationCtrl;

  WineColor _selectedColor = WineColor.red;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _appellationCtrl = TextEditingController();
    _producerCtrl = TextEditingController();
    _regionCtrl = TextEditingController();
    _countryCtrl = TextEditingController();
    _vintageCtrl = TextEditingController();
    _grapesCtrl = TextEditingController();
    _quantityCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _drinkFromCtrl = TextEditingController();
    _drinkUntilCtrl = TextEditingController();
    _tastingNotesCtrl = TextEditingController();
    _ratingCtrl = TextEditingController();
    _notesCtrl = TextEditingController();
    _locationCtrl = TextEditingController();
    _loadWine();
  }

  Future<void> _loadWine() async {
    final result =
        await ref.read(getWineByIdUseCaseProvider).call(widget.wineId);
    result.fold(
      (failure) {
        if (mounted) context.pop();
      },
      (wine) {
        if (wine == null) {
          if (mounted) context.pop();
          return;
        }
        setState(() {
          _wine = wine;
          _nameCtrl.text = wine.name;
          _appellationCtrl.text = wine.appellation ?? '';
          _producerCtrl.text = wine.producer ?? '';
          _regionCtrl.text = wine.region ?? '';
          _countryCtrl.text = wine.country;
          _vintageCtrl.text = wine.vintage?.toString() ?? '';
          _grapesCtrl.text = wine.grapeVarieties.join(', ');
          _quantityCtrl.text = wine.quantity.toString();
          _priceCtrl.text = wine.purchasePrice?.toStringAsFixed(2) ?? '';
          _drinkFromCtrl.text = wine.drinkFromYear?.toString() ?? '';
          _drinkUntilCtrl.text = wine.drinkUntilYear?.toString() ?? '';
          _tastingNotesCtrl.text = wine.tastingNotes ?? '';
          _ratingCtrl.text = wine.rating?.toString() ?? '';
          _notesCtrl.text = wine.notes ?? '';
          _locationCtrl.text = wine.location ?? '';
          _selectedColor = wine.color;
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Modifier le vin'),
        actions: [
          IconButton(
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
            onPressed: _saving ? null : _save,
            tooltip: 'Enregistrer',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Informations principales'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom du vin *',
                prefixIcon: Icon(Icons.wine_bar),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Le nom est requis' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<WineColor>(
              value: _selectedColor,
              decoration: const InputDecoration(
                labelText: 'Couleur *',
                prefixIcon: Icon(Icons.palette),
              ),
              items: WineColor.values
                  .map((c) => DropdownMenuItem(
                        value: c,
                        child: Text('${c.emoji} ${c.label}'),
                      ))
                  .toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedColor = v);
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
                      labelText: 'Millésime',
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
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(r'^\d+\.?\d{0,2}')),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Localisation',
                prefixIcon: Icon(Icons.place),
                helperText: 'Ex: Cave maison, Garage, Cellier...',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ratingCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (1-5)',
                prefixIcon: Icon(Icons.star),
                helperText: 'Laisser vide si non noté',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              validator: (v) {
                if (v != null && v.isNotEmpty) {
                  final n = int.tryParse(v);
                  if (n == null || n < 1 || n > 5) return 'Entre 1 et 5';
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
            const SizedBox(height: 32),
          ],
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_wine == null) return;

    setState(() => _saving = true);

    final grapes = _grapesCtrl.text
        .split(',')
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final updated = _wine!.copyWith(
      name: _nameCtrl.text.trim(),
      appellation:
          _appellationCtrl.text.trim().isEmpty ? null : _appellationCtrl.text.trim(),
      producer:
          _producerCtrl.text.trim().isEmpty ? null : _producerCtrl.text.trim(),
      region: _regionCtrl.text.trim().isEmpty ? null : _regionCtrl.text.trim(),
      country:
          _countryCtrl.text.trim().isEmpty ? 'France' : _countryCtrl.text.trim(),
      color: _selectedColor,
      vintage: int.tryParse(_vintageCtrl.text),
      grapeVarieties: grapes,
      quantity: int.tryParse(_quantityCtrl.text) ?? _wine!.quantity,
      purchasePrice: double.tryParse(_priceCtrl.text),
      drinkFromYear: int.tryParse(_drinkFromCtrl.text),
      drinkUntilYear: int.tryParse(_drinkUntilCtrl.text),
      tastingNotes: _tastingNotesCtrl.text.trim().isEmpty
          ? null
          : _tastingNotesCtrl.text.trim(),
      rating: int.tryParse(_ratingCtrl.text),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      location: _locationCtrl.text.trim().isEmpty ? null : _locationCtrl.text.trim(),
      updatedAt: DateTime.now(),
    );

    try {
      final result = await ref.read(updateWineUseCaseProvider).call(updated);
      result.fold(
        (failure) {
          setState(() => _saving = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(failure.message)),
            );
          }
        },
        (_) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Vin mis à jour !')),
            );
            context.pop(true); // return true to signal update
          }
        },
      );
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }
}
