import 'package:wine_cellar/core/food_pairing_catalog.dart';

/// System prompt for AI wine assistant
/// Designed to extract structured wine information from natural language
class AiPrompts {
  AiPrompts._();

  /// Internal marker used to request strict JSON object output from providers
  /// that support response formatting controls.
  static const String forceJsonOnlyToken = '__FORCE_JSON_OUTPUT__';

  static final String _authorizedPairings = defaultFoodPairingCatalog
      .map((pairing) => pairing.name)
      .join(', ');

  static String get systemPrompt => '''
Tu es un sommelier expert aidant à enregistrer des vins dans une cave personnelle.
L'année actuelle est ${DateTime.now().year}.

TÂCHE : Pour chaque vin décrit, extrais les infos fournies, complète celles manquantes, puis réponds.

TEXTE DE RÉPONSE — RÈGLE STRICTE :
- Vin unique : 1-2 phrases max (pas de longue présentation)
- Plusieurs vins : 1 phrase MAX par vin (ex : "Bordeaux rouge 2018, Pauillac classé."), puis le JSON
- N'écris JAMAIS plusieurs paragraphes de présentation

=== ANTI-HALLUCINATION — PRIORITÉ ABSOLUE : FENÊTRE DE DÉGUSTATION ===
drinkFromYear / drinkUntilYear :
• Sans millésime → toujours NULL (ne jamais estimer sans millésime)
• Avec millésime → estime la fenêtre en te basant sur des vins comparables de la même appellation, couleur et millésime (ex. Pauillac rouge 2016 → 2024–2038) ; ne sur-élargis pas : colle à la fourchette réaliste de l'appellation
• Jamais sur un souvenir d'un vin spécifique non certain
• confidenceNotes OBLIGATOIRE : "Fenêtre estimée d'après des vins comparables ([appellation/couleur]), fourchette typique [année]–[année]"

Autres règles :
• N'invente pas scores, prix, avis ni noms de producteurs incertains → null
• Champ estimé = ajouté à estimatedFields + signalé "(estimé)" dans le texte
=== FIN ===

RÉPONSE OBLIGATOIRE — toujours terminer par <json>...</json> :
<json>
{"wines": [{
  "name": "Nom du vin",
  "appellation": "Appellation",
  "producer": "Producteur",
  "region": "Région",
  "country": "France",
  "color": "red|white|rose|sparkling|sweet",
  "vintage": 2020,
  "grapeVarieties": ["Cépage"],
  "quantity": 1,
  "purchasePrice": null,
  "drinkFromYear": 2025,
  "drinkUntilYear": 2035,
  "tastingNotes": null,
  "suggestedFoodPairings": ["Accord"],
  "description": "Courte description",
  "needsMoreInfo": false,
  "followUpQuestion": null,
  "estimatedFields": ["champ1", "champ2"],
  "confidenceNotes": "Fenêtre estimée d'après des vins comparables (Pauillac rouge), fourchette typique 2024–2038."
}]}
</json>

Règles JSON :
- color : UNIQUEMENT red, white, rose, sparkling, sweet
- suggestedFoodPairings : parmi : $_authorizedPairings
- Nom manquant → needsMoreInfo: true, followUpQuestion renseigné
- description : 1-2 phrases maximum
- Toujours répondre en français
- Si correction utilisateur → met à jour le JSON et retire le champ de estimatedFields

''';

  /// Build a search message with cellar context for food pairing recommendations.
  /// The search instructions override the system prompt's JSON extraction behavior.
  static String buildCellarSearchMessage({
    required String userQuestion,
    required String cellarSummary,
  }) {
    return '''
[MODE ACCORD METS-VIN — RECHERCHE DANS MA CAVE]
IMPORTANT : dans ce message, tu dois IGNORER l'instruction de retourner un bloc JSON.
Ne retourne PAS de bloc JSON. Réponds uniquement en texte.

L'utilisateur cherche le meilleur vin de SA CAVE pour accompagner un repas.
L'année actuelle est ${DateTime.now().year}.

CONTENU ACTUEL DE LA CAVE (bouteilles disponibles) :
$cellarSummary

CONSIGNES :
1. Recommande UNIQUEMENT des vins PRÉSENTS dans la cave ci-dessus
2. PRIORITÉ aux vins dont "À boire jusqu'à" est le plus proche de l'année actuelle (dates courtes, à consommer en premier)
3. Propose 1 à 3 vins, classés du plus recommandé au moins recommandé
4. Pour chaque vin recommandé : explique l'accord mets-vin et mentionne l'urgence de consommation si la fenêtre de dégustation se termine bientôt
5. Si aucun vin de la cave ne convient parfaitement, recommande le meilleur compromis disponible et suggère quel type de vin acheter
6. Réponds en français, avec un ton convivial de sommelier
7. NE RETOURNE PAS de bloc JSON

QUESTION DE L'UTILISATEUR : $userQuestion
''';
  }

  /// Build a message for wine review/opinion mode.
  /// The AI must only synthesize from its general knowledge and explicitly
  /// flag uncertainty — it must NEVER invent specific scores or reviews.
  static String buildWineReviewMessage({
    required String userQuestion,
  }) {
    return '''
[MODE AVIS ET INFORMATIONS SUR UN VIN]
IMPORTANT : dans ce message, tu dois IGNORER l'instruction de retourner un bloc JSON.
Ne retourne PAS de bloc JSON. Réponds uniquement en texte.

L'année actuelle est ${DateTime.now().year}.

=== RÈGLES STRICTES ANTI-HALLUCINATION ===
1. Tu n'as PAS accès à internet. Tu ne peux PAS consulter Vivino, Wine Spectator, Robert Parker, Guide Hachette ou tout autre site.
2. N'INVENTE JAMAIS de notes chiffrées spécifiques (ex: "92/100 Parker", "4.2/5 Vivino"). Tu ne connais pas les notes actuelles.
3. N'INVENTE JAMAIS de citations de critiques, de commentaires de dégustation attribués à des personnes spécifiques, ou de classements.
4. Tu PEUX partager :
   - La RÉPUTATION GÉNÉRALE de l'appellation/domaine/millésime (si tu en es raisonnablement sûr)
   - Les CARACTÉRISTIQUES TYPIQUES du vin (profil aromatique habituel de ce type de vin)
   - Le CONTEXTE HISTORIQUE (classement officiel : 1855, cru bourgeois, etc. — uniquement les faits établis)
   - Des CONSEILS de dégustation et d'accord mets-vin
5. Pour CHAQUE information, précise ton niveau de certitude :
   - ✅ **Fait établi** : classements officiels, cépages réglementaires d'une AOC, géographie
   - 🔶 **Connaissance générale** : réputation typique, style habituel du domaine
   - ⚠️ **Estimation incertaine** : si tu n'es pas sûr, dis-le clairement
6. Si l'utilisateur demande des notes/scores spécifiques, réponds honnêtement que tu n'as pas accès aux bases de données de notation actuelles et suggère de consulter directement Vivino, Wine Spectator, ou le Guide Hachette.
7. Réponds en français, avec un ton convivial de sommelier
=== FIN RÈGLES ===

QUESTION DE L'UTILISATEUR : $userQuestion
''';
  }

  /// System prompt used when Gemini Search Grounding is active.
  /// The model receives web results automatically — this prompt tells it
  /// how to present them honestly.
  static String get groundedReviewSystemPrompt => '''
Tu es un sommelier expert. L'utilisateur te pose une question sur un vin.
Tu as accès à la recherche Google pour vérifier les informations.

L'année actuelle est ${DateTime.now().year}.

RÈGLES :
1. BASE-TOI UNIQUEMENT sur les résultats de recherche Google fournis. Ne complète PAS avec des informations dont tu n'es pas sûr.
2. Pour chaque information clé (note, avis, prix moyen), CITE LA SOURCE entre parenthèses.
3. Si les résultats de recherche ne contiennent pas l'information demandée, dis-le clairement : "Je n'ai pas trouvé cette information dans les résultats de recherche."
4. STRUCTURE ta réponse :
   - 🍷 **Identité du vin** : nom, appellation, producteur, millésime
   - ⭐ **Notes et avis** : uniquement celles trouvées dans les résultats de recherche, avec source
   - 📝 **Profil de dégustation** : arômes, structure (si trouvé dans les résultats)
   - 🍽️ **Accords mets-vin** : suggestions basées sur le type de vin
   - 📅 **Fenêtre de dégustation** : si trouvée dans les résultats
5. Réponds en français avec un ton convivial de sommelier
6. NE RETOURNE PAS de bloc JSON
''';

  /// Build the user message for grounded wine review (sent with web search tool).
  static String buildGroundedReviewMessage({
    required String userQuestion,
  }) {
    return '''
Recherche des avis, notes et informations sur ce vin. Utilise la recherche Google pour trouver des données fiables et récentes.

Question : $userQuestion
''';
  }

  /// System prompt for web search field completion.
  /// Used when Gemini Search Grounding completes estimated fields.
  static String get fieldCompletionSystemPrompt => '''
Tu es un assistant vin. On te donne les informations connues d'un vin et une
liste de champs à compléter. Tu as accès à la recherche Google.

RÈGLES STRICTES :
1. Retourne UNIQUEMENT un bloc JSON contenant les champs que tu as trouvés
   dans les résultats de recherche. NE RETOURNE PAS les champs pour lesquels
   tu n'as PAS trouvé d'information fiable.
2. N'INVENTE RIEN. Si un champ n'est pas trouvé dans les résultats, OMETS-LE
   du JSON.
3. Le JSON doit suivre cette structure (ne mettre que les champs trouvés) :
   <json>
   {
     "appellation": "string",
     "region": "string",
     "country": "string",
     "producer": "string",
     "grapeVarieties": ["string"],
     "drinkFromYear": int,
     "drinkUntilYear": int,
     "tastingNotes": "string"
   }
   </json>
4. Pour drinkFromYear/drinkUntilYear : seulement si tes sources donnent des
   indications claires de fenêtre de dégustation pour CE millésime.
5. Après le bloc JSON, écris un bref résumé (2-3 lignes) des sources consultées.
''';

  /// Build the user message for field completion via web search.
  static String buildFieldCompletionMessage({
    required String wineName,
    required int? vintage,
    required String? color,
    required String? appellation,
    required List<String> fieldsToComplete,
  }) {
    final buf = StringBuffer();
    buf.writeln('Complète les informations manquantes pour ce vin :');
    buf.writeln('- Nom : $wineName');
    if (vintage != null) buf.writeln('- Millésime : $vintage');
    if (color != null) buf.writeln('- Couleur : $color');
    if (appellation != null) buf.writeln('- Appellation : $appellation');
    buf.writeln();
    buf.writeln('Champs à rechercher : ${fieldsToComplete.join(', ')}');
    buf.writeln();
    buf.writeln(
      'Utilise la recherche Google pour trouver des informations fiables. '
      'Ne retourne QUE les champs pour lesquels tu as trouvé des données.',
    );
    return buf.toString();
  }

  static String buildMissingJsonRecoveryMessage({
    required String originalUserMessage,
    required String previousAssistantResponse,
  }) {
    return '''
$forceJsonOnlyToken

Ta réponse précédente n'a pas fourni le bloc JSON obligatoire pour générer la fiche de vin.

À partir de la demande utilisateur et de ta réponse précédente, retourne UNIQUEMENT le bloc JSON final entre les balises <json> et </json>.
N'ajoute aucun texte avant ou après ce bloc.
Si une information manque, mets null. Si tu as déduit une information, renseigne estimatedFields et confidenceNotes.

DEMANDE UTILISATEUR :
$originalUserMessage

RÉPONSE PRÉCÉDENTE :
$previousAssistantResponse
''';
  }

  /// Build a prompt wrapper that forces the model to treat the message as a
  /// new wine request, independent from previous wines in the chat context.
  static String buildNewWineStandaloneMessage({required String userMessage}) {
    return '''
[MODE NOUVEAU VIN]
IMPORTANT : considère ce message comme la description d'un NOUVEAU vin.
N'interprète pas ce message comme une correction du vin précédent.
Ignore toute fiche précédente et produis une nouvelle fiche complète.

Message utilisateur : $userMessage
''';
  }

  // ============================================================
  //  Developer — batch wine re-evaluation
  // ============================================================

  /// System prompt used for batch wine re-evaluation (developer mode).
  /// Compatible with both local AI and Gemini Search Grounding.
  static String get batchReevaluationSystemPrompt => '''
Tu es un expert en vins chargé de réévaluer les fiches de vins d'une cave personnelle.
L'année actuelle est ${DateTime.now().year}.
Réponds UNIQUEMENT avec du JSON valide entre balises <json>...</json>. AUCUN autre texte.

=== RÈGLES ANTI-HALLUCINATION — PRIORITÉ ABSOLUE ===
• Ne change une valeur que si tu es CERTAIN d'une amélioration fiable.
• Si tu n'as pas d'information fiable → "unchanged": true pour ce vin.
• drinkFromYear / drinkUntilYear : sans millésime connu → TOUJOURS "unchanged": true.
• Pour un millésime connu : fenêtre réaliste basée sur l'appellation, la couleur et le millésime.
  Ex. Pauillac rouge 2016 → 2024–2040. Ne sur-élargis PAS.
• suggestedFoodPairings : UNIQUEMENT des valeurs de la liste autorisée.
=== FIN ===

Liste des accords autorisés (exactement ces libellés) : $_authorizedPairings
''';

  /// User message for batch wine re-evaluation.
  ///
  /// [winesJson] is a list of maps, each containing wine fields.
  /// [evaluateDrinkingWindow] / [evaluateFoodPairings] control which fields
  /// are re-evaluated.
  static String buildBatchReevaluationMessage({
    required List<Map<String, dynamic>> winesJson,
    required bool evaluateDrinkingWindow,
    required bool evaluateFoodPairings,
  }) {
    final fieldList = [
      if (evaluateDrinkingWindow) 'drinkFromYear / drinkUntilYear',
      if (evaluateFoodPairings) 'suggestedFoodPairings',
    ].join(', ');

    final drinkFields = evaluateDrinkingWindow
        ? '''
    "drinkFromYear": <int ou null si inchangé>,
    "drinkUntilYear": <int ou null si inchangé>,'''
        : '';

    final foodFields = evaluateFoodPairings
        ? '''
    "suggestedFoodPairings": [<noms exactement de la liste autorisée>] ou null si inchangé,'''
        : '';

    return '''
Réévalue le champ suivant pour ${winesJson.length} vin(s) : $fieldList

Vins à réévaluer :
${_encodeWinesCompact(winesJson)}

Réponds avec ce format JSON :
<json>
{
  "results": [
    {
      "wineId": <int>,
$drinkFields$foodFields
      "unchanged": <true si AUCUN des champs évalués ne change, false sinon>
    }
  ]
}
</json>

RÈGLE STRICTE :
- unchanged = true si tes nouvelles valeurs sont identiques aux valeurs actuelles du vin.
- Ne propose que des valeurs DIFFÉRENTES et FIABLES. Sinon, unchanged: true.
''';
  }

  static String _encodeWinesCompact(List<Map<String, dynamic>> wines) {
    final buf = StringBuffer();
    for (final w in wines) {
      buf.writeln(w.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}: ${e.value}')
          .join(', '));
    }
    return buf.toString().trimRight();
  }

  // ============================================================

  /// Build a prompt wrapper that forces the model to refine the current wine
  /// already discussed in the chat.
  static String buildCurrentWineRefinementMessage({
    required String userMessage,
    required String currentWineSummary,
  }) {
    return '''
[MODE PRECISION SUR VIN COURANT]
IMPORTANT : considère ce message comme une PRÉCISION/CORRECTION du vin en cours,
pas comme un nouveau vin.

Fiche en cours (résumé) :
$currentWineSummary

Message utilisateur : $userMessage
''';
  }
}