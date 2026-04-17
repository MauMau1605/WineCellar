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
          'Navigation desktop: panneau lateral repliable pour liberer de l espace de travail.',
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
          'Le separateur est detecte automatiquement (virgule, point-virgule, tabulation).',
          'Un apercu interactif de 5 lignes permet de verifier le decoupage.',
          'Le mapping des colonnes se fait par clic sur les en-tetes ou par pre-analyse IA.',
          'La ligne d en-tete est selectionnable (clic ou saisie numerique).',
          'Vous choisissez ensuite: import direct ou enrichissement/correction par IA.',
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
          'Detection automatique du separateur (virgule, point-virgule, tabulation).',
          'Previsualisation interactive de 20 lignes avant mapping.',
          'Validation visuelle et edition avant ajout (par lot ou individuellement).',
        ]),
        _BlockTitle('Etape 1 - Mapping des colonnes'),
        _Paragraph(
          'Apres selection du fichier CSV, une boite de dialogue affiche '
          'un apercu des 20 premieres lignes de donnees. Vous pouvez :',
        ),
        _Bullets([
          'Cliquer sur un en-tete de colonne pour l assigner a un champ via menu deroulant.',
          'Cliquer sur un champ (chip) pour lui assigner une colonne avec apercu des donnees.',
          'Utiliser le bouton "Pre-analyse IA" : l IA analyse jusqu a 100 lignes pour detecter l en-tete et le mapping, meme si l en-tete n est pas la premiere ligne.',
          'Selectionner la ligne d en-tete en cliquant sur le numero de ligne ou en saisissant le numero.',
          'Decocher l en-tete si votre fichier n en contient pas.',
          'Replier/deplier le panneau des champs assignes pour gagner de l espace.',
          'Reinitialiser le mapping avec le bouton dedie.',
          'Des avertissements s affichent si des colonnes importantes manquent.',
        ]),
        _BlockTitle('Etape 2 - Choix du mode d import'),
        _Paragraph(
          'Apres validation du mapping, vous choisissez entre deux modes :',
        ),
        _Bullets([
          'Import direct : les vins sont ajoutes tels quels en base.',
          'Import avec IA : l IA corrige, normalise et complete chaque vin.',
        ]),
        _BlockTitle('Import avec IA - Enrichissement par lot'),
        _Paragraph(
          'Si vous choisissez l enrichissement IA, une boite de validation '
          'par lot s affiche avec une carte par vin :',
        ),
        _Bullets([
          'Chaque champ est editable directement dans la carte.',
          'Supprimez un vin de l import avec l icone corbeille.',
          'Re-evaluez un vin individuellement avec l icone rafraichir.',
          'L IA corrige les fautes, normalise les couleurs/regions, et complete les champs vides.',
          'Validez le lot entier ou relancez l IA avec "Reessayer tout".',
        ]),
        _BlockTitle('Etape 3 - Resume d import'),
        _Paragraph(
          'Apres import, un dialogue resume les resultats :',
        ),
        _Bullets([
          'Nombre de vins importes avec succes.',
          'Nombre de vins ignores (nom manquant).',
          'Nombre d erreurs eventuelles.',
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
              'Vous pouvez completer manuellement ou via enrichissement IA.',
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
          label: 'Mauvaise ligne d en-tete selectionnee',
          isValid: false,
          headers: ['Pomerol', '2015', 'Chateau Petrus', 'Rouge', '6'],
          rows: [
            ['Chablis', '2020', 'Domaine Testut', 'Blanc', '12'],
            ['Meursault', '2019', 'Coche-Dury', 'Blanc', '3'],
          ],
          note:
              'Solution: dans la boite de mapping, cliquez sur le bon numero '
              'de ligne ou decochez "Ligne d en-tete" si votre fichier n en a pas.',
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
              'Solution: gardez une seule ligne d en-tete. '
              'Supprimez les lignes de titre de groupe ou les cellules fusionnees.',
        ),
        _BlockTitle('Conseils pour faciliter l import'),
        _Bullets([
          'Evitez les abreviations ambigues dans les en-tetes.',
          'Uniformisez les valeurs (ex: Rouge/Blanc/Rose).',
          'Renseignez le nom du vin sur chaque ligne pour eviter les ignores.',
          'Utilisez la pre-analyse IA si vos en-tetes sont non standards.',
          'Profitez de l enrichissement IA pour completer les champs manquants automatiquement.',
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
          'Apres ajout d un vin, vous pouvez l associer a un cellier existant, le placer directement sur une case, ou creer un nouveau cellier standard 5x5.',
        ]),
        _BlockTitle('Surbrillance de consommation'),
        _Bullets([
          'Par defaut, les vins en derniere annee theorique de consommation sont marques "A boire cette annee" avec une couleur ambre.',
          'Les vins au-dela de la fenetre optimale sont marques "Fenetre depassee" avec une couleur rouge.',
          'Ces indicateurs apparaissent dans la liste de cave et dans la grille de cave virtuelle.',
          'Vous pouvez activer/desactiver chaque indicateur separement dans Parametres > Affichage > Alertes de consommation.',
        ]),
        _BlockTitle('Placer des bouteilles'),
        _Paragraph(
          'Pour ajouter une bouteille dans votre cellar, tapez sur une cellule vide. '
          'Un formulaire vous permettra de selectionner le vin et sa quantite a placer.',
        ),
        _BlockTitle('Deplacer des bouteilles'),
        _Paragraph(
          'Utilisez le mode de deplacement pour reorganiser vos bouteilles rapidement.',
        ),
        _Bullets([
          'Appuyez longtemps (2+ secondes) sur une bouteille pour entrer en mode deplacement. '
          'La bouteille se surligne en bleu.',
          'En mode deplacement, tapez simplement sur d autres bouteilles pour les ajouter a la selection (pas besoin de long press).',
          'Pour deplacer la selection: faites un nouvel appui long sur une bouteille selectionnee, puis glissez vers la zone voulue.',
          'Sur Linux, Windows et macOS, selectionnez d abord les bouteilles, puis appuyez sur le bouton deplacement en haut avant de cliquer-glisser a la souris.',
          'Pendant le glisser, les positions cibles sont previsualisees en temps reel.',
          'Pendant le glisser, la grille defile automatiquement si vous approchez les bords (auto-scroll).',
          'Relachez pour deposer la selection. Si une case cible est deja occupee, le depot est refuse.',
          'Apres un depot reussi, utilisez le bouton "Annuler" dans le message pour revenir en arriere.',
          'Utilisez le bouton menu (icone main) en haut pour basculer le mode deplacement on/off.',
          'Le principe de non-superposition est applique au relachement (drop).',
        ]),
        _BlockTitle('Redimensionner votre cave'),
        _Paragraph(
          'Vous pouvez augmenter le nombre de lignes et colonnes. Lors de l ajout, vous serez '
          'demande a quel endroit les inserer.',
        ),
        _Bullets([
          'Appuyez sur le bouton editer (icone crayon) en haut a droite.',
          'Modifiez les dimensions souhaitees.',
          'Si vous augmentez les lignes ou colonnes, selectionnez leur position d insertion.',
          'Les positions d insertion peuvent etre au debut, a la fin, ou entre deux lignes/colonnes existantes.',
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
          'Seul Gemini avec gemini-2.5-flash-lite a pour le moment ete teste en version gratuite.',
        ]),
        _BlockTitle('Les 3 modes de chat IA'),
        _Paragraph(
          'L assistant IA propose trois modes accessibles via le selecteur en haut du chat :',
        ),
        _Bullets([
          'Ajouter un vin : decrivez un vin et l IA extrait les informations structurees pour l ajouter a votre cave.',
          'Accord mets-vin : demandez des suggestions d accords avec les vins de votre cave.',
          'Avis sur un vin : obtenez un avis detaille sur un vin avec recherche internet (necessite Gemini).',
        ]),
        _BlockTitle('Recherche web et Gemini'),
        _Paragraph(
          'Actuellement, seul Google Gemini peut acceder a internet '
          'pour verifier et completer les informations sur un vin '
          '(grace au Search Grounding). Les autres fournisseurs '
          '(OpenAI, Mistral, Ollama) ne disposent pas de cette '
          'fonctionnalite.',
        ),
        _Bullets([
          'En mode "Avis sur un vin", si Gemini est votre fournisseur principal, la recherche web est automatique.',
          'Si vous utilisez un autre fournisseur, vous pouvez configurer une cle Gemini dediee dans Parametres > Recherche web (Gemini). L IA utilisera alors Gemini en complement pour les recherches internet.',
          'Apres l ajout d un vin, la verification web est declenchee automatiquement seulement si des champs critiques restent estimes (ex: producteur, appellation, fenetre de degustation).',
          'Le bouton "Completer via Google" reste disponible pour forcer la verification manuelle quand vous le jugez utile.',
          'Si votre message est ambigu apres une fiche deja en cours, l assistant vous demande si c est un nouveau vin ou une precision sur le vin actuel.',
        ]),
        _BlockTitle('Champs estimes et anti-hallucination'),
        _Bullets([
          'L IA signale les champs qu elle a estimes ou deduits (et non directement fournis par vous) avec une icone etoile.',
          'Une note de confiance explique le raisonnement de l IA pour ses estimations.',
          'Utilisez le bouton "Completer via Google" pour faire verifier ces estimations par une recherche internet.',
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
