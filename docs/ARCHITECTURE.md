# Architecture — Wine Cellar

> Document de design détaillant la responsabilité de chaque fichier et les liens entre eux.
> Dernière mise à jour : 8 mars 2026.

---

## Table des matières

1. [Vue d'ensemble](#vue-densemble)
2. [Arborescence complète](#arborescence-complète)
3. [Principes d'architecture](#principes-darchitecture)
4. [Point d'entrée](#point-dentrée)
5. [Couche `core/`](#couche-core)
6. [Couche `database/`](#couche-database)
7. [Feature `wine_cellar/`](#feature-wine_cellar)
8. [Feature `ai_assistant/`](#feature-ai_assistant)
9. [Feature `settings/`](#feature-settings)
10. [Injection de dépendances](#injection-de-dépendances)
11. [Flux de données — Exemples concrets](#flux-de-données--exemples-concrets)
12. [Conventions de nommage](#conventions-de-nommage)
13. [Points d'évolution identifiés](#points-dévolution-identifiés)

---

## Vue d'ensemble

Wine Cellar est une application Flutter de gestion de cave à vin avec un assistant IA conversationnel. L'architecture suit le pattern **Clean Architecture** organisée en **feature-first** :

```
Presentation → UseCases → Repositories (interface) ← Repository Impls → Datasources
```

**Flux de dépendances :** les couches internes (domain) ne dépendent jamais des couches externes (data, presentation). L'inversion de dépendance est assurée par des interfaces abstraites dans `domain/` et l'injection via Riverpod dans `core/providers.dart`.

**Stack technique :**

| Responsabilité          | Technologie              |
| ----------------------- | ------------------------ |
| Framework UI            | Flutter / Material 3     |
| State management / DI   | Riverpod                 |
| Navigation              | GoRouter                 |
| Base de données         | Drift (SQLite)           |
| Gestion d'erreurs       | fpdart (`Either<F,T>`)   |
| Clients IA              | Dio, google_generative_ai, dart_openai |
| Stockage sécurisé       | flutter_secure_storage   |

---

## Arborescence complète

```
lib/
├── main.dart                          # Bootstrap
├── app.dart                           # Widget racine MaterialApp.router
│
├── core/                              # Utilitaires partagés (cross-feature)
│   ├── constants.dart
│   ├── enums.dart
│   ├── errors/
│   │   └── failures.dart
│   ├── usecases/
│   │   └── usecase.dart
│   ├── providers.dart
│   ├── router.dart
│   ├── theme.dart
│   ├── chat_logger.dart
│   └── widgets/
│       └── shell_scaffold.dart
│
├── database/                          # Infrastructure Drift (partagée)
│   ├── app_database.dart (+.g.dart)
│   ├── tables/
│   │   ├── wines.dart
│   │   ├── food_categories.dart
│   │   └── wine_food_pairings.dart
│   └── daos/
│       ├── wine_dao.dart (+.g.dart)
│       └── food_category_dao.dart (+.g.dart)
│
├── features/
│   ├── wine_cellar/                   # Feature principale
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── wine_entity.dart
│   │   │   │   ├── food_category_entity.dart
│   │   │   │   ├── wine_filter.dart
│   │   │   │   ├── csv_column_mapping.dart
│   │   │   │   └── csv_import_row.dart
│   │   │   ├── repositories/
│   │   │   │   ├── wine_repository.dart
│   │   │   │   └── food_category_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_wine.dart
│   │   │       ├── delete_wine.dart
│   │   │       ├── get_wine_by_id.dart
│   │   │       ├── update_wine.dart
│   │   │       ├── update_wine_quantity.dart
│   │   │       ├── export_wines.dart
│   │   │       ├── import_wines_from_json.dart
│   │   │       ├── parse_csv_import.dart
│   │   │       └── import_wines_from_csv.dart
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       ├── wine_repository_impl.dart
│   │   │       └── food_category_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── wine_list_provider.dart
│   │       ├── screens/
│   │       │   ├── wine_list_screen.dart
│   │       │   ├── wine_add_screen.dart
│   │       │   ├── wine_detail_screen.dart
│   │       │   └── wine_edit_screen.dart
│   │       └── widgets/
│   │           ├── wine_card.dart
│   │           └── csv_column_mapping_dialog.dart
│   │
│   ├── ai_assistant/                  # Feature IA
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── chat_message.dart
│   │   │   │   └── wine_ai_response.dart
│   │   │   ├── repositories/
│   │   │   │   └── ai_service.dart
│   │   │   └── usecases/
│   │   │       ├── analyze_wine.dart
│   │   │       └── test_ai_connection.dart
│   │   ├── data/
│   │   │   ├── ai_prompts.dart
│   │   │   └── datasources/
│   │   │       ├── openai_service.dart
│   │   │       ├── gemini_service.dart
│   │   │       ├── mistral_service.dart
│   │   │       └── ollama_service.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── chat_screen.dart
│   │       └── widgets/
│   │           ├── chat_bubble.dart
│   │           └── wine_preview_card.dart
│   │
│   └── settings/                      # Feature paramètres
│       └── presentation/
│           └── screens/
│               └── settings_screen.dart
│
└── l10n/                              # Localisation FR / EN
    ├── app_localizations.dart
    ├── app_localizations_en.dart
    └── app_localizations_fr.dart
```

---

## Principes d'architecture

### Clean Architecture — 3 couches par feature

| Couche | Rôle | Dépend de |
|--------|------|-----------|
| **domain/** | Entités, interfaces repositories, use cases. Zéro dépendance Flutter. | Rien (sauf `core/errors`, `core/usecases`) |
| **data/** | Implémentations concrètes des repositories, datasources, DTOs. | `domain/` + packages externes |
| **presentation/** | Widgets, écrans, providers Riverpod. | `domain/` via use cases |

### Sens des dépendances (règle d'or)

```
presentation → domain ← data
```

La couche `domain` ne sait rien de `data` ni de `presentation`. Les implémentations concrètes sont injectées via Riverpod.

### Gestion d'erreurs

Tous les use cases retournent `Either<Failure, T>` (fpdart). Les types de `Failure` sont dans `core/errors/failures.dart` :

| Failure | Quand |
|---------|-------|
| `ServerFailure` | Erreur API distante |
| `CacheFailure` | Erreur base de données locale |
| `AiFailure` | Erreur spécifique au service IA |
| `ValidationFailure` | Donnée invalide (nom vide, id null…) |
| `ConfigurationFailure` | Configuration manquante |

---

## Point d'entrée

### `main.dart`
- Appelle `WidgetsFlutterBinding.ensureInitialized()`
- Encapsule l'app dans un `ProviderScope` (Riverpod)
- Lance `WineCellarApp`

### `app.dart` — `WineCellarApp`
- Widget racine `MaterialApp.router`
- Configure le thème (clair/sombre), la locale (`fr`), et le routeur GoRouter
- **Dépend de :** `core/theme.dart`, `core/router.dart`

---

## Couche `core/`

Utilitaires **cross-feature** partagés par toute l'application.

### `constants.dart` — `AppConstants`
- Noms de clés secure storage, modèles par défaut, versions
- Classe avec constructeur privé (ne s'instancie pas)

### `enums.dart`
Trois enums avec extensions :
- **`WineColor`** (`red`, `white`, `rose`, `sparkling`, `sweet`) — avec `label` fr et `emoji`
- **`WineMaturity`** (`tooYoung`, `ready`, `peak`, `pastPeak`, `unknown`) — idem
- **`AiProvider`** (`openai`, `gemini`, `mistral`, `ollama`) — avec `label`

### `errors/failures.dart`
- `sealed class Failure` — classe de base avec `message` et `cause`
- 5 sous-classes typées : `ServerFailure`, `CacheFailure`, `AiFailure`, `ValidationFailure`, `ConfigurationFailure`

### `usecases/usecase.dart`
- `abstract class UseCase<Type, Params>` — contrat unique : `Future<Either<Failure, Type>> call(Params)`
- `NoParams` — marqueur pour les use cases sans paramètres

### `providers.dart`
Centre nerveux de l'injection de dépendances (détaillé dans [Injection de dépendances](#injection-de-dépendances)).

### `router.dart`
- Configuration GoRouter avec `ShellRoute` pour la navigation bottom bar/rail
- 3 routes principales : `/cellar`, `/chat`, `/settings`
- Sous-routes : `/cellar/add`, `/cellar/wine/:id`, `/cellar/wine/:id/edit`

### `theme.dart` — `AppTheme`
- Color scheme Material 3 inspiré du vin (rouge `#722F37`, or `#D4A843`)
- Thèmes clair et sombre
- Helper `colorForWine(String)` pour mapper une couleur de vin à une `Color`

### `chat_logger.dart` — `ChatLogger`
- Singleton loggant les conversations IA dans des fichiers `.log` horodatés
- Méthodes : `startSession()`, `logUserMessage()`, `logAiResponse()`, `logError()`, `logWineAdded()`, `endSession()`
- Stockage desktop : priorité au répertoire d'installation (`wine_cellar_logs/`), fallback sur `<documents>/wine_cellar_logs/` si non écrivable

### `widgets/shell_scaffold.dart` — `ShellScaffold`
- Shell layout adaptatif : `NavigationBar` (mobile) / `NavigationRail` (desktop)
- 3 destinations : Cave, Assistant IA, Paramètres
- **Utilisé par :** `core/router.dart` (ShellRoute builder)

---

## Couche `database/`

Infrastructure SQLite partagée (Drift ORM). Vit au niveau `lib/` car utilisée par plusieurs features.

### `tables/wines.dart` — `Wines`
Table Drift incluant :
- colonnes métier vin (nom, appellation, producteur, garde, notes, etc.)
- source IA persistée par champ critique : `aiSuggestedFoodPairings`, `aiSuggestedDrinkFromYear`, `aiSuggestedDrinkUntilYear`
- localisation cave virtuelle : `cellarPositionX`, `cellarPositionY`

### `tables/food_categories.dart` — `FoodCategories`
Table : `id`, `name`, `icon` (emoji), `sortOrder`.

### `tables/wine_food_pairings.dart` — `WineFoodPairings`
Table de jointure many-to-many : `wineId` → `Wines.id`, `foodCategoryId` → `FoodCategories.id`. Clé primaire composite. Cascade on delete.

### `app_database.dart` — `AppDatabase`
- Classe Drift `@DriftDatabase` regroupant les 3 tables et 2 DAOs
- `schemaVersion = 3`
- Stratégie actuelle d'upgrade : migration non destructive (création conditionnelle des tables/colonnes manquantes)
- `_seedFoodCategories()` — pré-peuple 18 catégories alimentaires à la création
- Seeding idempotent des catégories : insertion uniquement des catégories absentes
- Stockage DB desktop : priorité au répertoire d'installation (si écriture autorisée), fallback sur `<documents>`
- Migration automatique au démarrage : copie de l'ancienne DB depuis `<documents>` vers le répertoire d'installation si nécessaire

### `daos/wine_dao.dart` — `WineDao`
DAO pour les opérations sur les vins :
| Méthode | Description |
|---------|-------------|
| `watchAllWines()` | Stream réactif trié par nom |
| `getAllWines()` | Liste one-shot |
| `getWineById(int)` | Vin par ID |
| `getWineWithPairings(int)` | Vin + ses food pairings |
| `watchWinesByColor(String)` | Stream filtré par couleur |
| `watchWinesByFoodCategory(int)` | Stream filtré par catégorie (JOIN) |
| `searchWines(String)` | Stream LIKE sur nom/appellation/région/producteur |
| `insertWineWithPairings(…)` | Insert transactionnel vin + pairings |
| `updateWineWithPairings(…)` | Update transactionnel vin + pairings |
| `deleteWineById(int)` | Suppression (cascade pairings) |
| `updateQuantity(int, int)` | Mise à jour quantité uniquement |
| `getWineCount()` / `getTotalBottles()` | Statistiques |

### `daos/food_category_dao.dart` — `FoodCategoryDao`
| Méthode | Description |
|---------|-------------|
| `getAllCategories()` | Liste triée par `sortOrder` |
| `watchAllCategories()` | Stream réactif |
| `findCategoriesByName(String)` | Recherche LIKE (pour auto-matching IA) |

---

## Feature `wine_cellar/`

Gestion CRUD de la cave à vin.

### domain/entities/

#### `wine_entity.dart` — `WineEntity`
- Entité métier principale, **immutable** (champs `final`)
- Propriétés calculées : `maturity` (basée sur l'année courante vs fenêtre de dégustation), `displayName`
- `copyWith()` pour les modifications
- `toJson()` / `fromJson()` pour l'import/export
- `grapeVarietiesJson` / `parseGrapeVarieties()` pour la sérialisation DB

#### `food_category_entity.dart` — `FoodCategoryEntity`
- Entité légère : `id`, `name`, `icon`, `sortOrder`

#### `wine_filter.dart` — `WineFilter`
- Critères de filtrage : `searchQuery`, `color`, `foodCategoryId`, `maturity`
- `isEmpty` pour vérifier si aucun filtre n'est actif
- `copyWith()` avec options `clearX` pour réinitialiser un critère

### domain/repositories/

#### `wine_repository.dart` — `WineRepository` (abstract)
Contrat pour les opérations vin :
- CRUD : `addWine`, `updateWine`, `deleteWine`, `getWineById`
- Streams réactifs : `watchAllWines`, `watchFilteredWines`
- Quantité : `updateQuantity`
- Stats : `getWineCount`, `getTotalBottles`
- Export/Import : `exportToJson`, `exportToCsv`, `importFromJson`, `parseCsvRows`, `importFromCsv`

#### `food_category_repository.dart` — `FoodCategoryRepository` (abstract)
- `getAllCategories()`, `watchAllCategories()`, `findByName(String)`

### domain/usecases/

Chaque use case a **une seule** méthode `call()` retournant `Either<Failure, T>`.

| Use Case | Params | Retour | Logique métier |
|----------|--------|--------|----------------|
| `AddWineUseCase` | `WineEntity` | `int` (id) | Valide que le nom n'est pas vide |
| `DeleteWineUseCase` | `int` (id) | `void` | Suppression simple |
| `GetWineByIdUseCase` | `int` (id) | `WineEntity?` | Lecture simple |
| `UpdateWineUseCase` | `WineEntity` | `void` | Valide id non-null + nom non-vide |
| `UpdateWineQuantityUseCase` | `UpdateQuantityParams` | `void` | Clamp à 0 min. Méthode étendue `callWithAction()` pour gérer le cas « quantité à zéro : garder ou supprimer » |
| `ExportWinesUseCase` | `ExportFormat` | `String` | Délègue au repo selon format (JSON/CSV) |
| `ImportWinesFromJsonUseCase` | `String` (JSON) | `int` | Valide contenu + délègue import JSON |
| `ParseCsvImportUseCase` | `ParseCsvImportParams` | `List<CsvImportRow>` | Parse CSV avec mapping de colonnes utilisateur |
| `ImportWinesFromCsvUseCase` | `ImportWinesFromCsvParams` | `int` | Import direct CSV après validation de mapping |

### data/repositories/

#### `wine_repository_impl.dart` — `WineRepositoryImpl`
- Implémente `WineRepository`
- Injecté avec `WineDao` et `FoodCategoryDao`
- Responsabilités de mapping : `_mapToEntity(Wine)` (DB → domain) et `_mapToCompanion(WineEntity)` (domain → DB)
- Import JSON : parse et boucle `addWine`
- Import CSV : parsing avec mapping utilisateur + normalisation des champs (quantité, prix, couleur)

#### `food_category_repository_impl.dart` — `FoodCategoryRepositoryImpl`
- Implémente `FoodCategoryRepository`
- Mapping `FoodCategory` (DB) → `FoodCategoryEntity` (domain)

### presentation/providers/

#### `wine_list_provider.dart`
Providers Riverpod déclaratifs :
- `filteredWinesProvider(WineFilter)` — `StreamProvider.family` réactif
- `allWinesProvider` — `StreamProvider` sans filtre
- `wineCountProvider` / `totalBottlesProvider` — `FutureProvider` stats

### presentation/screens/

#### `wine_list_screen.dart` — `WineListScreen`
- Écran principal de la cave
- Barre de recherche, chips de filtre (couleur + maturité)
- Layout adaptatif : `ListView` (mobile) / `GridView` (desktop)
- Actions menu : export JSON/CSV + import JSON/CSV
- Import CSV guidé : mapping colonnes → prévisualisation extraction → mode direct ou enrichissement IA
- Enrichissement IA par lots de 20 vins max avec validation utilisateur à chaque lot
- Gestion quantité via `UpdateWineQuantityUseCase` avec dialogue confirmation
- FAB → navigue vers `/cellar/add` pour choisir IA ou saisie manuelle

#### `wine_add_screen.dart` — `WineAddScreen`
- Fiche d'ajout complète avec saisie manuelle de tous les champs métier (infos principales, cave, garde, notes)
- Trois actions : redirection vers `/chat`, complétion IA d'une fiche partiellement remplie, ajout manuel direct
- Les boutons « complétion IA » et « ajout manuel » restent grisés tant que nom + millésime ne sont pas valides
- Validation UX : tooltip au survol + popup explicative au clic si prérequis manquants

#### `wine_detail_screen.dart` — `WineDetailScreen`
- Détail complet d'un vin (chargé via `GetWineByIdUseCase`)
- Actions : modifier, supprimer (`DeleteWineUseCase`), ajuster quantité (`UpdateWineQuantityUseCase`)
- Affichage maturité, cépages, accords mets-vin, notes de dégustation

#### `wine_edit_screen.dart` — `WineEditScreen`
- Formulaire d'édition complet (15+ champs)
- Chargement via `GetWineByIdUseCase`, sauvegarde via `UpdateWineUseCase`
- Sélecteur de couleur, champs numériques validés

### presentation/widgets/

#### `wine_card.dart` — `WineCard`
- Carte résumé d'un vin (nom, millésime, couleur, appellation, maturité)
- Boutons +/- pour la quantité
- Callback `onTap` pour la navigation, `onQuantityChanged` pour la mise à jour

---

## Feature `ai_assistant/`

Assistant IA conversationnel pour l'ajout de vins par langage naturel et les accords mets-vin.

### domain/entities/

#### `chat_message.dart` — `ChatMessage`, `ChatRole`, `WinePreviewData`
- Message de chat avec `id` (UUID), `content`, `role` (user/assistant/system), `timestamp`
- `WinePreviewData` optionnel pour les données vin associées au message

#### `wine_ai_response.dart` — `WineAiResponse`
- Réponse structurée de l'IA : tous les champs d'un vin + `needsMoreInfo`, `followUpQuestion`
- `fromJson()` / `toJson()` pour parser la réponse JSON de l'IA
- `isComplete` : vrai si `name` et `color` sont renseignés

### domain/repositories/

#### `ai_service.dart` — `AiService` (abstract), `AiChatResult`
Interface commune aux 4 providers IA :
- `analyzeWine(userMessage, conversationHistory)` → `AiChatResult`
- `testConnection()` → `bool`

`AiChatResult` encapsule :
- `textResponse` — texte à afficher dans le chat
- `wineDataList` — liste de `WineAiResponse` extraits
- `isError` / `errorMessage`

### domain/usecases/

| Use Case | Params | Retour | Logique |
|----------|--------|--------|---------|
| `AnalyzeWineUseCase` | `AnalyzeWineParams` | `AiChatResult` | Appelle `AiService.analyzeWine()`, convertit erreurs en `AiFailure` |
| `TestAiConnectionUseCase` | `NoParams` | `bool` | Appelle `AiService.testConnection()`, convertit échec en `AiFailure` |

### data/

#### `ai_prompts.dart` — `AiPrompts`
- `systemPrompt` — prompt système complet pour le sommelier IA (extraction JSON, règles de complétion)
- `buildCellarSearchMessage()` — construit le prompt pour le mode « accord mets-vin » avec le contenu réel de la cave

#### `datasources/` — 4 implémentations de `AiService`

| Fichier | Classe | API | Particularités |
|---------|--------|-----|----------------|
| `openai_service.dart` | `OpenAiService` | OpenAI Chat Completions (via `dart_openai`) | Supporte GPT-4o-mini |
| `gemini_service.dart` | `GeminiService` | Google Generative AI (SDK natif) | Rate limiting 4s, session chat réutilisée, auto-discovery modèle |
| `mistral_service.dart` | `MistralService` | Mistral API (compatible OpenAI, via Dio) | Session historique, tracking RPM |
| `ollama_service.dart` | `OllamaService` | API REST locale Ollama (via Dio) | Fonctionne hors-ligne |

**Pattern commun à toutes les implémentations :**
1. Construction des messages (system prompt + historique + message courant)
2. Appel API
3. Extraction du bloc JSON de la réponse (`_extractWineData`)
4. Nettoyage du texte de réponse (`_cleanTextResponse`)
5. Logging via `ChatLogger`

### presentation/screens/

#### `chat_screen.dart` — `ChatScreen`
- Écran de chat principal
- Deux modes : « Ajouter un vin » / « Accord mets-vin » (SegmentedButton)
- Gère l'historique des messages en session (static pour persistance inter-navigation)
- Envoi de messages via `AnalyzeWineUseCase`
- Ajout de vins à la cave via `AddWineUseCase` + auto-matching des catégories alimentaires
- Reset de session (réinitialise le chat du service IA sous-jacent)
- Bouton « Ajouter tous les vins » pour les réponses multi-vins

### presentation/widgets/

#### `chat_bubble.dart` — `ChatBubble`
- Bulle de chat avec alignement et couleur selon le rôle (user/assistant)
- Rendu Markdown pour les réponses de l'IA

#### `wine_preview_card.dart` — `WinePreviewCard`
- Carte de prévisualisation d'un `WineAiResponse` dans le chat
- Affiche les champs extraits (nom, appellation, couleur, millésime, cépages…)
- Bouton « Ajouter à la cave » / « Déjà ajouté »

---

## Feature `settings/`

### `settings_screen.dart` — `SettingsScreen`
- Sélection du fournisseur IA (RadioListTile pour chaque `AiProvider`)
- Configuration contextuelle : clé API (OpenAI/Gemini/Mistral) ou URL (Ollama) + modèle
- Bouton « Enregistrer » → persiste dans flutter_secure_storage
- Bouton « Tester la connexion » → via `TestAiConnectionUseCase`
- Section « À propos »

---

## Injection de dépendances

Tout passe par `core/providers.dart`. Voici la hiérarchie complète des providers :

### Infrastructure

| Provider | Type | Fournit |
|----------|------|---------|
| `databaseProvider` | `Provider<AppDatabase>` | Singleton DB, fermeture au dispose |
| `secureStorageProvider` | `Provider<FlutterSecureStorage>` | Instance unique |

### Repositories

| Provider | Type | Fournit |
|----------|------|---------|
| `wineRepositoryProvider` | `Provider<WineRepository>` | `WineRepositoryImpl(wineDao, foodCategoryDao)` |
| `foodCategoryRepositoryProvider` | `Provider<FoodCategoryRepository>` | `FoodCategoryRepositoryImpl(foodCategoryDao)` |

### Settings (state persisté)

| Provider | Type | Fournit |
|----------|------|---------|
| `aiProviderSettingProvider` | `StateNotifierProvider<…, AiProvider>` | Enum du provider IA actuel |
| `openAiApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API OpenAI |
| `geminiApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API Gemini |
| `mistralApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API Mistral |
| `ollamaUrlProvider` | `StateNotifierProvider<…, String?>` | URL Ollama |
| `selectedModelProvider` | `StateNotifierProvider<…, String?>` | Modèle sélectionné |

### AI Service

| Provider | Type | Fournit |
|----------|------|---------|
| `aiServiceProvider` | `Provider<AiService?>` | L'implémentation IA active (ou `null` si non configuré). Switch sur `aiProviderSettingProvider`. |

### Use Cases — Wine

| Provider | Type |
|----------|------|
| `addWineUseCaseProvider` | `Provider<AddWineUseCase>` |
| `getWineByIdUseCaseProvider` | `Provider<GetWineByIdUseCase>` |
| `deleteWineUseCaseProvider` | `Provider<DeleteWineUseCase>` |
| `updateWineUseCaseProvider` | `Provider<UpdateWineUseCase>` |
| `updateWineQuantityUseCaseProvider` | `Provider<UpdateWineQuantityUseCase>` |
| `exportWinesUseCaseProvider` | `Provider<ExportWinesUseCase>` |
| `importWinesFromJsonUseCaseProvider` | `Provider<ImportWinesFromJsonUseCase>` |
| `parseCsvImportUseCaseProvider` | `Provider<ParseCsvImportUseCase>` |
| `importWinesFromCsvUseCaseProvider` | `Provider<ImportWinesFromCsvUseCase>` |

### Use Cases — AI

| Provider | Type |
|----------|------|
| `analyzeWineUseCaseProvider` | `Provider<AnalyzeWineUseCase?>` |
| `testAiConnectionUseCaseProvider` | `Provider<TestAiConnectionUseCase?>` |

---

## Flux de données — Exemples concrets

### Ajouter un vin via l'IA

```
1. ChatScreen : l'utilisateur tape "un Margaux 2018"
2. ChatScreen._sendMessage()
   → ref.read(analyzeWineUseCaseProvider)
   → AnalyzeWineUseCase.call(AnalyzeWineParams(...))
     → AiService.analyzeWine(...)                    [ex: GeminiService]
       → API Gemini → réponse texte + JSON
       → _extractWineData() → List<WineAiResponse>
     ← AiChatResult(textResponse, wineDataList)
   ← Either<Failure, AiChatResult>
3. ChatScreen affiche le texte + WinePreviewCard(s)
4. L'utilisateur clique "Ajouter à la cave"
5. ChatScreen._addWineToCellar()
   → Matching des food pairings par nom
   → Construction WineEntity
   → ref.read(addWineUseCaseProvider)
   → AddWineUseCase.call(WineEntity)
     → Validation nom non-vide
     → WineRepository.addWine(wine)                  [via WineRepositoryImpl]
       → WineDao.insertWineWithPairings(...)          [transaction SQLite]
     ← Either<Failure, int>
6. SnackBar confirmation + option "Voir la cave"
```

### Modifier la quantité d'un vin (scénario dernière bouteille)

```
1. WineListScreen : l'utilisateur clique "-" sur un vin avec quantité = 1
2. WineListScreen._updateQuantity(wine, 0)
   → showDialog → l'utilisateur choisit "Supprimer"
   → ref.read(updateWineQuantityUseCaseProvider)
   → UpdateWineQuantityUseCase.callWithAction(params, ZeroQuantityAction.delete)
     → WineRepository.deleteWine(wineId)
     ← Either<Failure, void>
3. SnackBar "vin supprimé"
```

### Export CSV

```
1. WineListScreen : menu → "Exporter CSV"
2. ref.read(exportWinesUseCaseProvider)
3. ExportWinesUseCase.call(ExportFormat.csv)
   → WineRepository.exportToCsv()
     → WineDao.getAllWines() → mapping → ListToCsvConverter
   ← Either<Failure, String>
4. _saveExport(csvString, "cave_export.csv")

### Import CSV avec mapping + IA (optionnel)

```
1. WineListScreen : menu → "Importer CSV"
2. FilePicker : sélection du fichier CSV
3. CsvColumnMappingDialog : l'utilisateur associe les colonnes aux champs vin
4. ParseCsvImportUseCase.call(ParseCsvImportParams)
  → WineRepository.parseCsvRows(...)
  → preview extraction (échantillon)
5. Choix utilisateur :
  A) Import direct
    → ImportWinesFromCsvUseCase.call(...)
    → WineRepository.importFromCsv(...)
  B) Compléter avec IA
    → découpage en lots de 20
    → AnalyzeWineUseCase.call(...) pour chaque lot
    → tableau de validation utilisateur
    → AddWineUseCase pour chaque vin validé
```
```

---

## Conventions de nommage

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Interface repository | `XxxRepository` (dans `domain/`) | `WineRepository` |
| Implémentation | `XxxRepositoryImpl` (dans `data/`) | `WineRepositoryImpl` |
| Interface service | `XxxService` (dans `domain/`) | `AiService` |
| Implémentation service | `XxxService` nommé par provider (dans `data/`) | `GeminiService` |
| Entité domain | `XxxEntity` | `WineEntity` |
| Use case | `XxxUseCase` | `AddWineUseCase` |
| Provider Riverpod | suffixe `Provider` | `wineRepositoryProvider` |
| Écran | `XxxScreen` | `WineListScreen` |
| Widget réutilisable | Nom descriptif | `WineCard`, `ChatBubble` |
| Enum | PascalCase | `WineColor`, `AiProvider` |
| Table Drift | Pluriel | `Wines`, `FoodCategories` |
| DAO Drift | `XxxDao` | `WineDao` |

---

## Points d'évolution identifiés

| # | Point | Priorité | Impact |
|---|-------|----------|--------|
| 1 | **Pas de `@freezed`** sur les entités — `copyWith`, `==`, `hashCode` manuels | Moyenne | Robustesse, réduction du boilerplate |
| 2 | **`fromJson`/`toJson` dans les entités domain** — devrait être dans des DTOs `data/models/` | Faible | Pureté architecturale |
| 3 | **Pas de barrel files** (`index.dart`) | Faible | Simplification des imports |
| 4 | **`ChatLogger` singleton** — non injecté via Riverpod | Faible | Testabilité |
| 5 | **Tests unitaires/widget absents** — à implémenter (mocktail) | Haute | Fiabilité |
| 6 | **Import CSV piloté par prompts IA** (qualité dépendante du provider/modèle) | Moyenne | Peut nécessiter ajustement de prompt selon modèle |
