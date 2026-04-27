# Backlog de refactorisation et de sécurisation

Ce document résume les chantiers à reprendre plus tard.
Il part de l'état actuel du dépôt après :

- nettoyage de la documentation d'architecture
- correction des violations de couches les plus nettes
- maintien d'un périmètre sans refactor profond pour l'instant

## Stratégie générale

Ne pas démarrer par un gros refactor transversal.
Avant les extractions importantes, sécuriser les comportements par des tests unitaires fonctionnels ciblés.

Ordre recommandé :

1. Ajouter les tests sur les zones critiques et instables.
2. Refactorer les plus gros fichiers de présentation par extractions ciblées.
3. Réduire ensuite les gros fichiers de data, providers et use cases.
4. Réévaluer enfin la centralisation dans `lib/core/providers.dart`.

## Priorité 1 — sécuriser avant refactor

Objectif : verrouiller les comportements visibles ou métier qui casseraient facilement pendant une extraction.

Zones à tester en priorité :

- `lib/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart`
- `lib/features/ai_assistant/presentation/screens/chat_screen.dart`
- `lib/features/wine_cellar/presentation/screens/wine_list_screen.dart`
- `lib/features/wine_cellar/data/repositories/wine_repository_impl.dart`
- `lib/features/settings/presentation/screens/ai_settings_screen.dart`
- `lib/features/developer/presentation/providers/reevaluation_provider.dart`

Types de tests à privilégier ici :

- logique de transformation et d'orchestration
- règles métier implicites
- transitions d'état des notifiers/providers
- cas limites et erreurs métier

## Priorité 2 — gros écrans de présentation

### `virtual_cellar_detail_screen.dart`

Constat : très gros écran, mélange chargement, thème immersif, actions, filtres, rendu et workflow utilisateur.

Découpage candidat :

- orchestration de chargement et actions de cave
- barre d'actions / commandes utilisateur
- rendu de grille / emplacement / sélections
- panneaux secondaires ou dialogs spécifiques

Risque : élevé si le découpage est fait en une seule passe.
Approche recommandée : extractions successives de widgets et helpers UI, sans changer les contrats métier au départ.

### `chat_screen.dart`

Constat : très gros écran, mélange gestion de session, préfill, envoi de messages, analyse image, enrichissement web et ajout de vin.

Découpage candidat :

- état de session de chat
- composition du message à envoyer
- pipeline d'analyse image
- pipeline d'ajout/confirmation de vin
- widgets ou sections d'interface secondaires

Risque : élevé, car beaucoup d'états croisés et de branches fonctionnelles.
Approche recommandée : commencer par extraire la logique non UI vers des helpers ou services locaux testables.

### `wine_list_screen.dart`

Constat : gros écran mêlant liste, split view, import/export CSV, actions IA et navigation.

Découpage candidat :

- toolbar et actions de liste
- logique import/export CSV
- logique IA liée à l'import ou à la réévaluation locale
- orchestration du split view et sélection

Risque : élevé, mais inférieur à `chat_screen.dart` si on isole d'abord le CSV et les actions latérales.

## Priorité 3 — couches data, providers et use cases trop volumineux

### `wine_repository_impl.dart`

Constat : fichier data volumineux mélange mapping, import/export, CRUD et comportements de cave.

Découpage candidat :

- mappers entité ↔ Drift
- helpers import/export JSON/CSV
- opérations CRUD simples
- opérations liées aux caves virtuelles si elles restent ici

Risque : moyen, avec bon potentiel de gain rapide si les helpers sont extraits sans modifier l'API publique.

### `ai_settings_screen.dart`

Constat : écran de configuration long et dense, avec beaucoup de champs, contrôleurs et actions.

Découpage candidat :

- section fournisseur principal
- section modèle et connectivité
- section overrides vision
- section fallback Gemini

Risque : moyen.

### `reevaluation_provider.dart`

Constat : provider avec plusieurs états et orchestration de workflow.

Découpage candidat :

- état et types séparés
- actions métier isolées
- sélection / preview / application regroupées par responsabilité

Risque : moyen.

### `reevaluate_batch_usecase.dart`

Constat : use case au-dessus du seuil recommandé, avec formatage de message, appel IA et parsing.

Découpage candidat :

- builder de payload de réévaluation
- parsing / mapping de réponse
- orchestration du call principal

Risque : moyen.

### `ai_request_strategy.dart`

Constat : logique heuristique dense, mais localisée.

Découpage candidat :

- marqueurs et dictionnaires séparés
- analyse d'intention
- décision web search séparée

Risque : faible à moyen.

## Priorité 4 — centralisation transverse

### `lib/core/providers.dart`

Constat : le fichier reste très centralisé et dépasse les seuils documentés, même s'il n'est plus en violation nette de couche sur le périmètre déjà corrigé.

Pistes possibles plus tard :

- segmenter par thème tout en gardant une façade stable
- séparer infrastructure, préférences d'affichage, IA et repositories métier
- ne pas casser les imports partout d'un coup ; privilégier une migration incrémentale

Risque : moyen.

## Règles de reprise

- Toujours commencer par lire les tests déjà en place autour de la zone visée.
- Ajouter les tests manquants avant la première extraction structurelle.
- Ne pas faire plusieurs gros fichiers à la fois.
- Après chaque extraction, lancer une validation ciblée.
- Mettre à jour `docs/ARCHITECTURE.md` et la doc feature si le découpage devient structurel.

## Résultat attendu à terme

- écrans plus petits et plus lisibles
- orchestration métier testable hors UI
- réduction du risque de régression pendant les futures évolutions
- navigation plus rapide dans le dépôt pour humains comme pour l'agent