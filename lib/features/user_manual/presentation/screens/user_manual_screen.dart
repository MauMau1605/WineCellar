import 'package:flutter/material.dart';

/// Sections available in the user manual.
enum UserManualSection {
  overview('overview', 'Vue generale'),
  importExport('imports-exports', 'Imports / Exports'),
  csvImport('csv-import', 'Import CSV detaille'),
  aiImport('ai-import', 'Import par IA'),
  pairings('food-pairing', 'Accords mets-vins'),
  virtualCellar('virtual-cellar', 'Cave virtuelle'),
  aiTokens('ai-tokens', 'Tokens et connexion IA'),
  troubleshooting('troubleshooting', 'Bonnes pratiques');

  final String queryValue;
  final String tabLabel;

  const UserManualSection(this.queryValue, this.tabLabel);

  static UserManualSection fromQuery(String? value) {
    return UserManualSection.values.firstWhere(
      (section) => section.queryValue == value,
      orElse: () => UserManualSection.overview,
    );
  }
}

/// Global in-app user manual.
class UserManualScreen extends StatelessWidget {
  const UserManualScreen({
    super.key,
    this.initialSection = UserManualSection.overview,
  });

  final UserManualSection initialSection;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: UserManualSection.values.length,
      initialIndex: initialSection.index,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Manuel utilisateur'),
          bottom: TabBar(
            isScrollable: true,
            tabs: UserManualSection.values
                .map((section) => Tab(text: section.tabLabel))
                .toList(),
          ),
        ),
        body: Column(
          children: [
            _ManualIntroCard(initialSection: initialSection),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: const [
                  _OverviewTab(),
                  _ImportExportTab(),
                  _CsvImportTab(),
                  _AiImportTab(),
                  _PairingsTab(),
                  _VirtualCellarTab(),
                  _AiTokensTab(),
                  _BestPracticesTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ManualIntroCard extends StatelessWidget {
  const _ManualIntroCard({required this.initialSection});

  final UserManualSection initialSection;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.help_outline, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ce guide vous aide a utiliser toutes les fonctions de Ma Cave a Vin. '
              'Section ouverte: ${initialSection.tabLabel}.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

class _ManualSection extends StatelessWidget {
  const _ManualSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...children,
        const SizedBox(height: 24),
      ],
    );
  }
}

class _BlockTitle extends StatelessWidget {
  const _BlockTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Paragraph extends StatelessWidget {
  const _Paragraph(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets(this.items);

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('- $item'),
            ),
          )
          .toList(),
    );
  }
}

/// Displays a CSV example table with a valid/invalid badge and an optional note.
class _CsvExampleTable extends StatelessWidget {
  const _CsvExampleTable({
    required this.label,
    required this.headers,
    required this.rows,
    this.isValid = true,
    this.note,
  });

  final String label;
  final bool isValid;
  final List<String> headers;
  final List<List<String>> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = isValid
        ? const Color(0xFF388E3C)
        : theme.colorScheme.error;
    final headerBg = isValid
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.errorContainer;
    final borderColor = theme.colorScheme.outlineVariant;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isValid ? Icons.check_circle_outline : Icons.cancel_outlined,
                color: accentColor,
                size: 15,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: accentColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: IntrinsicWidth(
              child: Table(
                border: TableBorder.all(color: borderColor, width: 1),
                defaultColumnWidth: const IntrinsicColumnWidth(),
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: headerBg),
                    children: [
                      for (final h in headers)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          child: Text(
                            h,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                    ],
                  ),
                  for (final row in rows)
                    TableRow(
                      children: [
                        for (final cell in row)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            child: Text(
                              cell,
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          if (note != null) ...<Widget>[
            const SizedBox(height: 4),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 14, color: accentColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    note!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  const _OverviewTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Presentation generale',
      children: [
        _Paragraph(
          'Ma Cave a Vin centralise votre inventaire, vos accords mets-vins, '
          'vos importations de donnees et des fonctions d aide par IA.',
        ),
        _BlockTitle('Fonctions principales'),
        _Bullets([
          'Gestion de cave: ajout, modification, suppression, tri, recherche.',
          'Imports/exports: JSON et CSV pour sauvegarder ou migrer vos donnees.',
          'Assistant IA: analyse de texte et d image pour accelerer la saisie.',
          'Accords mets-vins: categories d accords modifiables.',
          'Cave virtuelle: placements de bouteilles dans des celliers.',
        ]),
        _BlockTitle('Par ou commencer'),
        _Bullets([
          '1) Configurez votre fournisseur IA dans Parametres.',
          '2) Ajoutez quelques vins manuellement ou via import.',
          '3) Organisez ensuite votre cave virtuelle et vos accords.',
        ]),
      ],
    );
  }
}

class _ImportExportTab extends StatelessWidget {
  const _ImportExportTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Imports / Exports JSON et CSV',
      children: [
        _Paragraph(
          'Les imports/exports sont accessibles depuis le menu (3 points) '
          'de la page principale de cave.',
        ),
        _BlockTitle('Export JSON'),
        _Bullets([
          'Conserve le maximum de donnees metier.',
          'Format recommande pour sauvegarde complete de vos vins.',
          'Partage simple sur mobile (Drive/Fichiers/mail).',
        ]),
        _BlockTitle('Export CSV'),
        _Bullets([
          'Format pratique pour tableurs (Excel, LibreOffice, Google Sheets).',
          'Ideale pour relire ou enrichir les informations en masse.',
          'Permet une reimportation rapide.',
        ]),
        _BlockTitle('Import JSON'),
        _Bullets([
          'Mode nominal: JSON exporte par l application.',
          'Si le fichier est detecte comme instantane complet, une restauration remplace la cave actuelle.',
          'Compatibilite legacy: certains anciens champs peuvent etre adaptes automatiquement.',
        ]),
        _BlockTitle('Import CSV'),
        _Bullets([
          'Le CSV est d abord previsualise puis mappe colonne par colonne.',
          'Vous choisissez ensuite: import direct ou enrichissement avec IA.',
          'Les lignes sans nom de vin sont ignorees a l import.',
        ]),
      ],
    );
  }
}

class _CsvImportTab extends StatelessWidget {
  const _CsvImportTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Import CSV detaille',
      children: [
        _BlockTitle('Ce que gere l import CSV'),
        _Bullets([
          'Nom (obligatoire), millesime, producteur, appellation, quantite.',
          'Couleur, region, pays, cepages, prix, localisation, notes.',
          'Validation visuelle avant ajout (tableau recapitulatif).',
        ]),
        _BlockTitle('Format ideal - ce qui fonctionne'),
        _Paragraph(
          'Les exemples ci-dessous sont reconnus et importes automatiquement '
          'sans intervention manuelle.',
        ),
        _CsvExampleTable(
          label: 'En-tetes standard reconnus automatiquement',
          isValid: true,
          headers: ['nom', 'millesime', 'producteur', 'couleur', 'quantite'],
          rows: [
            ['Pomerol', '2015', 'Chateau Petrus', 'Rouge', '6'],
            ['Chablis 1er Cru', '2020', 'Domaine Testut', 'Blanc', '12'],
            ['Cotes du Rhone', '2022', 'Chapoutier', 'Rouge', '3'],
          ],
        ),
        _CsvExampleTable(
          label:
              'Variantes d en-tetes reconnues (wine, vintage, producer, qty)',
          isValid: true,
          headers: ['wine', 'vintage', 'producer', 'region', 'qty'],
          rows: [
            ['Chambolle-Musigny', '2018', 'Mugnier', 'Bourgogne', '4'],
            ['Sancerre', '2021', 'H. Bourgeois', 'Loire', '2'],
          ],
        ),
        _CsvExampleTable(
          label: 'Colonnes minimales (seul nom est obligatoire)',
          isValid: true,
          headers: ['nom', 'millesime'],
          rows: [
            ['Saint-Emilion Grand Cru', '2016'],
            ['Pouilly-Fume', '2022'],
          ],
          note:
              'Les colonnes absentes restent vides dans la fiche vin. '
              'Vous pouvez completer manuellement apres import.',
        ),
        _BlockTitle('Ce qui ne fonctionne pas'),
        _Paragraph(
          'Ces structures generent des erreurs ou des importations incompletes.',
        ),
        _CsvExampleTable(
          label: 'Colonne nom absente - tous les vins sont ignores',
          isValid: false,
          headers: ['millesime', 'producteur', 'couleur', 'quantite'],
          rows: [
            ['2015', 'Chateau X', 'Rouge', '6'],
            ['2020', 'Domaine Y', 'Blanc', '12'],
          ],
          note:
              'Solution: ajoutez une colonne nom, wine ou cuvee. '
              'Sans elle, chaque ligne est ignoree lors de l import.',
        ),
        _CsvExampleTable(
          label: 'Premiere ligne de donnees traitee comme en-tete',
          isValid: false,
          headers: ['Pomerol', '2015', 'Chateau Petrus', 'Rouge', '6'],
          rows: [
            ['Chablis', '2020', 'Domaine Testut', 'Blanc', '12'],
            ['Meursault', '2019', 'Coche-Dury', 'Blanc', '3'],
          ],
          note:
              'Solution: ajoutez une ligne d en-tete ou decochez '
              '"Premiere ligne = en-tete" dans la boite de dialogue.',
        ),
        _CsvExampleTable(
          label: 'Separateurs inconsistants - colonnes mal decoupees',
          isValid: false,
          headers: ['nom;millesime', 'producteur;quantite'],
          rows: [
            ['Pomerol;2015', 'Chateau X;6'],
            ['Chablis;2020', 'Domaine Y;12'],
          ],
          note:
              'Solution: utilisez un seul type de separateur (, ou ;) '
              'dans tout le fichier. Ne melangez pas les deux.',
        ),
        _CsvExampleTable(
          label: 'En-tetes en plusieurs lignes ou cellules fusionnees',
          isValid: false,
          headers: ['', 'Informations vin', '', 'Stock'],
          rows: [
            ['nom', 'millesime', 'producteur', 'quantite'],
            ['Pomerol', '2015', 'Chateau X', '6'],
          ],
          note:
              'Solution: gardez une seule ligne d en-tete en premiere ligne. '
              'Supprimez les lignes de titre de groupe ou les cellules fusionnees.',
        ),
        _BlockTitle('Detection automatique des colonnes'),
        _Paragraph(
          'L application lit les en-tetes et propose un mapping automatique '
          '(exemples reconnus: nom/wine/cuvee, millesime/vintage/year, '
          'producteur/producer/domaine, quantite/qty/stock, etc.).',
        ),
        _Paragraph(
          'Les champs detectes automatiquement sont marques "Auto" dans la boite de dialogue.',
        ),
        _BlockTitle('Importation manuelle (si auto-detection insuffisante)'),
        _Bullets([
          'Videz/corrigez les numeros de colonnes proposes.',
          'Saisissez les index de colonnes (1 = premiere colonne).',
          'Confirmez si votre fichier contient une ligne d en-tete.',
          'Validez puis controlez le tableau d extraction avant import final.',
        ]),
        _BlockTitle('Conseils pour faciliter l import'),
        _Bullets([
          'Evitez les abreviations ambigues dans les en-tetes.',
          'Uniformisez les valeurs (ex: Rouge/Blanc/Rose).',
          'Renseignez le nom du vin sur chaque ligne pour eviter les ignores.',
        ]),
      ],
    );
  }
}

class _AiImportTab extends StatelessWidget {
  const _AiImportTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Import des vins par IA',
      children: [
        _BlockTitle('Ce que fait l IA'),
        _Bullets([
          'Analyse votre texte libre pour extraire des fiches vin structurees.',
          'Peut analyser une image de bouteille/etiquette via vision IA ou OCR local.',
          'Complete des donnees manquantes (region, cepages, garde, description).',
        ]),
        _BlockTitle('Comment elle trouve les informations'),
        _Bullets([
          'Elle s appuie sur les donnees que vous fournissez (texte/photo).',
          'Selon le fournisseur configure, elle inferre les champs manquants.',
          'Vous validez toujours avant l ajout final des vins.',
        ]),
        _BlockTitle('Utilisation: texte'),
        _Bullets([
          'Ouvrez Assistant IA puis decrivez le vin ou votre lot CSV.',
          'Relisez les cartes de previsualisation.',
          'Ajoutez le vin, ou corrigez avant ajout.',
        ]),
        _BlockTitle('Utilisation: image'),
        _Bullets([
          'Depuis l Assistant IA, utilisez le bouton appareil photo.',
          'Choisissez camera ou galerie.',
          'Patientez pendant l analyse, puis validez les informations proposees.',
        ]),
        _Paragraph(
          'Important: l IA assiste mais ne remplace pas la validation humaine. '
          'Verifiez millesime, appellation et producteur avant enregistrement.',
        ),
      ],
    );
  }
}

class _PairingsTab extends StatelessWidget {
  const _PairingsTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Accords mets-vins',
      children: [
        _Paragraph(
          'Chaque vin peut etre associe a des categories d accords (poisson, viande, fromage, etc.).',
        ),
        _Bullets([
          'Edition possible depuis la fiche de vin.',
          'Les suggestions IA sont marquees pour etre distinguees des choix manuels.',
          'Vous pouvez toujours corriger/supprimer un accord apres coup.',
        ]),
        _BlockTitle('Bon usage'),
        _Bullets([
          'Conservez vos categories les plus utiles et coherentes.',
          'Utilisez des intitules simples pour des filtres lisibles.',
          'Validez les suggestions IA selon vos preferences gustatives.',
        ]),
      ],
    );
  }
}

class _VirtualCellarTab extends StatelessWidget {
  const _VirtualCellarTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Cave virtuelle',
      children: [
        _Paragraph(
          'La cave virtuelle vous permet de modeliser des celliers et de positionner '
          'vos bouteilles dans une grille.',
        ),
        _Bullets([
          'Creez un ou plusieurs celliers (taille configurable).',
          'Placez une bouteille sur une position libre.',
          'Visualisez rapidement ou se trouve chaque vin.',
        ]),
        _BlockTitle('Comportement pendant les imports'),
        _Bullets([
          'Import CSV: n ecrase pas les placements existants.',
          'Import JSON classique: ajoute les vins sans imposer de placement legacy.',
          'Restauration JSON instantane complet: remplace cave, celliers et placements.',
        ]),
      ],
    );
  }
}

class _AiTokensTab extends StatelessWidget {
  const _AiTokensTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Creation des tokens et appairage IA',
      children: [
        _Paragraph(
          'Pour activer l assistant IA, vous devez configurer un fournisseur et une cle API '
          '(token) dans Parametres.',
        ),
        _BlockTitle('Etapes communes'),
        _Bullets([
          '1) Ouvrez Parametres > Fournisseur d IA.',
          '2) Selectionnez OpenAI, Gemini, Mistral ou Ollama.',
          '3) Renseignez votre cle API et le modele recommande.',
          '4) Enregistrez puis utilisez le bouton "Tester la connexion".',
        ]),
        _BlockTitle('OpenAI'),
        _Bullets([
          'Creez un compte sur OpenAI si ce n est pas deja fait.',
          'Creez une cle dans la console OpenAI (Platform/API Keys).',
          'Copiez-la dans "Cle API OpenAI".',
          'Modele conseille: gpt-4o-mini.',
        ]),
        _BlockTitle('Gemini'),
        _Bullets([
          'Creez un compte sur AI Studio Google si ce n est pas deja fait sur https://aistudio.google.com.',
          'Creez une cle sur AI Studio Google en selectionnant "Get API Key" -> "Creer une cle API".',
          'Collez-la dans "Cle API Gemini" et renseignez le nom du modele a utiliser.',
          'Modele conseille: gemini-2.5-flash-lite, le seul teste pour la vision.',
        ]),
        _BlockTitle('Mistral'),
        _Bullets([
          'Creez un compte sur Mistral AI si ce n est pas deja fait sur https://console.mistral.ai/home.',
          'Une fois connecte, accedez a la section "Cles API" -> "Mes cles API" -> "Ajoutez une nouvelle cle".',
          'Copiez la cle generee et collez-la dans "Cle API Mistral" de l application.',
          'Collez-la dans "Cle API Mistral" et renseignez le modele a utiliser.',
          'Modele conseille: mistral-small-latest/mistral-large-latest.',
        ]),
        _BlockTitle('Ollama (sans token cloud)'),
        _Bullets([
          'Installez Ollama localement.',
          'Renseignez l URL du serveur (ex: http://localhost:11434).',
          'Choisissez un modele local disponible (ex: llama3).',
        ]),
        _BlockTitle('Vision et OCR'),
        _Bullets([
          'OCR local: lit le texte de l etiquette sans envoyer l image.',
          'Vision IA: possible avec un fournisseur/modele vision compatible.',
          'Vous pouvez definir un token et un modele dedies a la vision.',
          'Seul Gemini avec gemini-2.5-flash-lite a pour le moment ete teste en version gratuite.'
        ]),
      ],
    );
  }
}

class _BestPracticesTab extends StatelessWidget {
  const _BestPracticesTab();

  @override
  Widget build(BuildContext context) {
    return const _ManualSection(
      title: 'Bonnes pratiques et points d attention',
      children: [
        _Bullets([
          'Faites un export JSON regulier pour la sauvegarde.',
          'Verifiez les donnees enrichies par IA avant validation.',
          'Uniformisez les noms dans vos CSV pour maximiser l auto-detection.',
          'Conservez des quantites coherentes pour eviter les doublons.',
          'Testez la connexion IA apres tout changement de token ou modele.',
        ]),
        _BlockTitle('Problemes frequents'),
        _Bullets([
          'Erreur IA: verifier cle API, quota ou modele.',
          'Import CSV incomplet: revoir mapping et presence de la colonne Nom.',
          'Image non exploitable: reprendre une photo plus nette ou passer en OCR.',
        ]),
      ],
    );
  }
}
