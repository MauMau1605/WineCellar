# Architecture — Wine Cellar

> Document de design détaillant la responsabilité de chaque fichier et les liens entre eux.
> Dernière mise à jour : 28 mars 2026.

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
10. [Feature `user_manual/`](#feature-user_manual)
11. [Injection de dépendances](#injection-de-dépendances)
12. [Flux de données — Exemples concrets](#flux-de-données--exemples-concrets)
13. [Conventions de nommage](#conventions-de-nommage)
14. [Points d'évolution identifiés](#points-dévolution-identifiés)

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
│   ├── cellar_theme_data.dart
│   ├── food_pairing_catalog.dart
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
│   │   ├── wine_food_pairings.dart
│   │   ├── virtual_cellars.dart
│   │   └── bottle_placements.dart
│   └── daos/
│       ├── wine_dao.dart (+.g.dart)
│       ├── food_category_dao.dart (+.g.dart)
│       ├── virtual_cellar_dao.dart (+.g.dart)
│       └── bottle_placement_dao.dart (+.g.dart)
│
├── features/
│   ├── wine_cellar/                   # Feature principale
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── wine_entity.dart
│   │   │   │   ├── food_category_entity.dart
│   │   │   │   ├── virtual_cellar_entity.dart
│   │   │   │   ├── virtual_cellar_theme.dart
│   │   │   │   ├── bottle_placement_entity.dart
│   │   │   │   ├── bottle_move_state_entity.dart
│   │   │   │   ├── cellar_cell_position.dart
│   │   │   │   ├── wine_filter.dart
│   │   │   │   ├── wine_sort.dart
│   │   │   │   ├── csv_column_mapping.dart
│   │   │   │   └── csv_import_row.dart
│   │   │   ├── repositories/
│   │   │   │   ├── wine_repository.dart
│   │   │   │   ├── food_category_repository.dart
│   │   │   │   └── virtual_cellar_repository.dart
│   │   │   └── usecases/
│   │   │       ├── add_wine.dart
│   │   │       ├── delete_wine.dart
│   │   │       ├── get_wine_by_id.dart
│   │   │       ├── update_wine.dart
│   │   │       ├── update_wine_quantity.dart
│   │   │       ├── export_wines.dart
│   │   │       ├── import_wines_from_json.dart
│   │   │       ├── parse_csv_import.dart
│   │   │       ├── import_wines_from_csv.dart
│   │   │       ├── get_all_virtual_cellars.dart
│   │   │       ├── create_virtual_cellar.dart
│   │   │       ├── update_virtual_cellar.dart
│   │   │       ├── delete_virtual_cellar.dart
│   │   │       ├── place_wine_in_cellar.dart
│   │   │       ├── get_wine_placements.dart
│   │   │       ├── move_bottles_in_cellar.dart
│   │   │       └── remove_bottle_placement.dart
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       ├── wine_repository_impl.dart
│   │   │       ├── food_category_repository_impl.dart
│   │   │       └── virtual_cellar_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── wine_list_provider.dart
│   │       ├── providers/
│   │       │   ├── wine_list_provider.dart
│   │       │   └── bottle_move_state_provider.dart
│   │       ├── screens/
│   │       │   ├── wine_list_screen.dart
│   │       │   ├── wine_add_screen.dart
│   │       │   ├── wine_detail_screen.dart
│   │       │   ├── wine_edit_screen.dart
│   │       │   ├── virtual_cellar_list_screen.dart
│   │       │   ├── virtual_cellar_detail_screen.dart
│   │       │   └── expert_cellar_editor_screen.dart
│   │       └── widgets/
│   │           ├── wine_card.dart
│   │           ├── csv_column_mapping_dialog.dart
│   │           ├── csv_batch_validation_dialog.dart
│   │           ├── virtual_cellar_theme_selector.dart
│   │           ├── premium_cave_wrapper.dart (+background)
│   │           ├── stone_cave_wrapper.dart (+background)
│   │           └── garage_industrial_wrapper.dart (+background)
│   │
│   ├── ai_assistant/                  # Feature IA
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   ├── chat_message.dart
│   │   │   │   └── wine_ai_response.dart
│   │   │   ├── repositories/
│   │   │   │   ├── ai_service.dart
│   │   │   │   └── image_text_extractor.dart
│   │   │   └── usecases/
│   │   │       ├── analyze_wine.dart
│   │   │       ├── analyze_wine_from_image.dart
│   │   │       ├── extract_text_from_wine_image.dart
│   │   │       └── test_ai_connection.dart
│   │   ├── data/
│   │   │   ├── ai_prompts.dart
│   │   │   └── datasources/
│   │   │       ├── openai_service.dart
│   │   │       ├── gemini_service.dart
│   │   │       ├── mistral_service.dart
│   │   │       ├── ollama_service.dart
│   │   │       └── mlkit_image_text_extractor.dart
│   │   └── presentation/
│   │       ├── screens/
│   │       │   └── chat_screen.dart
│   │       └── widgets/
│   │           ├── chat_bubble.dart
│   │           └── wine_preview_card.dart
│   │
│   ├── statistics/                    # Feature statistiques
│   │   ├── domain/
│   │   │   ├── entities/
│   │   │   │   └── cellar_statistics.dart
│   │   │   ├── repositories/
│   │   │   │   └── statistics_repository.dart
│   │   │   └── usecases/
│   │   │       └── get_cellar_statistics.dart
│   │   ├── data/
│   │   │   └── repositories/
│   │   │       └── statistics_repository_impl.dart
│   │   └── presentation/
│   │       ├── providers/
│   │       │   └── statistics_providers.dart
│   │       ├── screens/
│   │       │   └── statistics_screen.dart
│   │       └── widgets/
│   │           ├── stat_donut_chart.dart
│   │           ├── stat_bar_chart.dart
│   │           ├── overview_section.dart
│   │           ├── color_distribution_chart.dart
│   │           ├── maturity_distribution_chart.dart
│   │           ├── geography_section.dart
│   │           ├── vintage_distribution_chart.dart
│   │           ├── grape_distribution_chart.dart
│   │           ├── ratings_price_section.dart
│   │           └── producer_distribution_chart.dart
│   │
│   └── settings/                      # Feature paramètres
│       └── presentation/
│           └── screens/
│               ├── settings_screen.dart
│               └── display_settings_screen.dart
│
│   └── user_manual/                   # Feature manuel utilisateur
│       └── presentation/
│           └── screens/
│               └── user_manual_screen.dart
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
- 6 routes principales : `/cellar`, `/chat`, `/cellars`, `/statistics`, `/settings`, `/manual`
- Sous-routes : `/cellar/add`, `/cellar/wine/:id`, `/cellar/wine/:id/edit`, `/cellars/:id`

### `theme.dart` — `AppTheme`
- Color scheme Material 3 inspiré du vin (rouge `#722F37`, or `#D4A843`)
- Thèmes clair et sombre
- Helper `colorForWine(String)` pour mapper une couleur de vin à une `Color`

### `chat_logger.dart` — `ChatLogger`
- Singleton loggant les conversations IA dans des fichiers `.log` horodatés
- Méthodes : `startSession()`, `logUserMessage()`, `logAiResponse()`, `logError()`, `logWineAdded()`, `endSession()`
- Stockage desktop : priorité au répertoire d'installation (`wine_cellar_logs/`), fallback sur `<documents>/wine_cellar_logs/` si non écrivable

### `food_pairing_catalog.dart`
- `FoodPairingPreset` — classe immutable (`name`, `icon`, `sortOrder`)
- `defaultFoodPairingCatalog` — liste const de 18 catégories alimentaires prédéfinies (Viande rouge, Volaille, Poisson, Fromage…)
- Utilisé pour le seeding initial de la base de données

### `cellar_theme_data.dart` — `CellarThemeData`
- Mappe chaque variante de `VirtualCellarTheme` vers un `ThemeData` Flutter complet
- `forTheme()` — retourne le thème visuel d'un cellier (classic, premiumCave, stoneCave, garageIndustrial)
- `overridesAppTheme()` — indique si le thème remplace le thème global (seul classic ne le fait pas)

### `widgets/shell_scaffold.dart` — `ShellScaffold`
- Shell layout adaptatif : `NavigationBar` (mobile) / `NavigationRail` (desktop)
- Panneau latéral desktop repliable/dépliable via un bouton de bascule intégré au rail
- 5 destinations : Cave, Assistant IA, Celliers, Statistiques, Paramètres
- **Utilisé par :** `core/router.dart` (ShellRoute builder)

---

## Couche `database/`

Infrastructure SQLite partagée (Drift ORM). Vit au niveau `lib/` car utilisée par plusieurs features.

### `tables/wines.dart` — `Wines`
Table Drift incluant :
- colonnes métier vin (nom, appellation, producteur, garde, notes, etc.)
- source IA persistée par champ critique : `aiSuggestedFoodPairings`, `aiSuggestedDrinkFromYear`, `aiSuggestedDrinkUntilYear`
- rattachement à un cellier virtuel : `cellarId`
- localisation cave virtuelle : `cellarPositionX`, `cellarPositionY`

### `tables/virtual_cellars.dart` — `VirtualCellars`
Table Drift des celliers virtuels : `id`, `name`, `rows`, `columns`, `createdAt`, `updatedAt`.
Chaque bouteille placée dans un cellier référence cette table via `Wines.cellarId`.

### `tables/food_categories.dart` — `FoodCategories`
Table : `id`, `name`, `icon` (emoji), `sortOrder`.

### `tables/wine_food_pairings.dart` — `WineFoodPairings`
Table de jointure many-to-many : `wineId` → `Wines.id`, `foodCategoryId` → `FoodCategories.id`. Clé primaire composite. Cascade on delete.
### `tables/bottle_placements.dart` — `BottlePlacements`
Table des placements physiques individuels de bouteilles dans les celliers virtuels :
- `id` (auto-increment), `wineId`, `cellarId`, `positionX` (colonne 0-based), `positionY` (ligne 0-based), `createdAt`
- Contrainte d'unicité `(cellarId, positionX, positionY)` — empêche le double-booking d'un emplacement
### `app_database.dart` — `AppDatabase`
- Classe Drift `@DriftDatabase` regroupant 5 tables et 4 DAOs
- `schemaVersion = 5` (via `AppConstants.databaseVersion`)
- Stratégie actuelle d'upgrade : migration non destructive (création conditionnelle des tables/colonnes manquantes)
- Migration v4 : création de `virtual_cellars` et ajout de `wines.cellar_id`
- Migration v5 : création de `bottle_placements` (découplage des placements individuels des bouteilles)
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

### `daos/virtual_cellar_dao.dart` — `VirtualCellarDao`
DAO dédié aux celliers virtuels et à l'occupation de leurs emplacements :

| Méthode | Description |
|---------|-------------|
| `watchAll()` / `getAll()` | Liste des celliers triée par nom |
| `getById(int)` | Chargement d'un cellier |
| `insertCellar(...)` / `updateCellar(...)` / `deleteCellar(int)` | CRUD cellier |
| `watchWinesByCellarId(int)` / `getWinesByCellarId(int)` | Bouteilles placées dans un cellier |
| `clearCellarPlacementsForCellar(int)` | Déplace toutes les bouteilles hors du cellier avant suppression |
| `updateCellarPlacement(...)` | Place ou retire une bouteille d'un emplacement |

### `daos/bottle_placement_dao.dart` — `BottlePlacementDao`
DAO dédié aux placements individuels de bouteilles (table `BottlePlacements`) :

| Méthode | Description |
|---------|-----------|
| `watchPlacementsByCellarId(int)` | Stream réactif des placements d'un cellier (tri Y puis X) |
| `getPlacementsByWineId(int)` | Tous les placements d'un vin (cross-celliers) |
| `getPlacedBottleCountForWine(int)` | Nombre de bouteilles placées pour un vin |
| `isSlotOccupied(cellarId, x, y)` | Vérifie si un emplacement est occupé |
| `placeBottle(wineId, cellarId, x, y)` | Place une bouteille (échoue si occupé) |
| `removePlacement(id)` | Retire un placement |
| `clearPlacementsForWine(wineId)` | Retire tous les placements d'un vin |
| `clearPlacementsForCellar(cellarId)` | Vide un cellier |
| `trimPlacementsForWine(wineId, keep)` | Garde les N placements les plus récents |
| `moveBottlePlacement(id, newX, newY)` | Déplace une bouteille (échoue si destination occupée) |

---

## Feature `wine_cellar/`

Gestion CRUD de la cave à vin.

### domain/entities/

#### `wine_entity.dart` — `WineEntity`
- Entité métier principale, **immutable** (champs `final`)
- Inclut le placement virtuel via `cellarId`, `cellarPositionX`, `cellarPositionY`
- Propriétés calculées : `maturity` (basée sur l'année courante vs fenêtre de dégustation), `displayName`
- `copyWith()` pour les modifications
- `toJson()` / `fromJson()` pour l'import/export
- `grapeVarietiesJson` / `parseGrapeVarieties()` pour la sérialisation DB

#### `virtual_cellar_entity.dart` — `VirtualCellarEntity`
- Entité métier d'un cellier virtuel
- Champs : `id`, `name`, `rows`, `columns`, `createdAt`, `updatedAt`, `theme`
- Propriété calculée : `totalSlots`

#### `virtual_cellar_theme.dart` — `VirtualCellarTheme`
- Enum des thèmes visuels de cellier : `classic`, `premiumCave`, `stoneCave`, `garageIndustrial`
- `label` — libellé français localisé
- `storageValue` / `fromStorage()` — sérialisation pour persistance

#### `bottle_placement_entity.dart` — `BottlePlacementEntity`
- Placement physique d'une bouteille dans la grille d'un cellier
- Champs : `id`, `wineId`, `cellarId`, `positionX`, `positionY`, `createdAt`, `wine` (`WineEntity`)

#### `bottle_move_state_entity.dart` — `BottleMoveStateEntity`
- État UI pour le déplacement de bouteilles (mode mouvement, drag & drop, sélection)
- Champs : `isMovementMode`, `isDragModeEnabled`, `selectedPlacementIds` (Set), `cellarId`
- `initial(cellarId)` factory, `copyWith()`, `isSelected()`, `hasSelection`

#### `cellar_cell_position.dart` — `CellarCellPosition`
- Value object représentant une position (row, col) 1-based dans la grille
- Implémente `==` / `hashCode` pour utilisation dans Set/Map

#### `food_category_entity.dart` — `FoodCategoryEntity`
- Entité légère : `id`, `name`, `icon`, `sortOrder`

#### `wine_filter.dart` — `WineFilter`
- Critères de filtrage : `searchQuery`, `color`, `foodCategoryId`, `maturity`
- `isEmpty` pour vérifier si aucun filtre n'est actif
- `copyWith()` avec options `clearX` pour réinitialiser un critère
#### `wine_sort.dart` — `WineSort` / `WineSortField`
- Value object de tri des vins : `field` (`WineSortField` : name, vintage, drinkUntilYear, color, region, appellation…) + `ascending`
- `apply(List<WineEntity>)` — retourne la liste triée
- `copyWith()` pour modifier le critère ou la direction
### domain/repositories/

#### `wine_repository.dart` — `WineRepository` (abstract)
Contrat pour les opérations vin :
- CRUD : `addWine`, `updateWine`, `deleteWine`, `getWineById`
- Streams réactifs : `watchAllWines`, `watchFilteredWines`
- Quantité : `updateQuantity`
- Stats : `getWineCount`, `getTotalBottles`
- Export/Import : `exportToJson`, `exportToCsv`, `importFromJson`, `parseCsvRows`, `importFromCsv`
- Le JSON est un instantané complet de cave : vins, celliers virtuels et placements. Son import restaure cet état complet après confirmation explicite en UI.

#### `food_category_repository.dart` — `FoodCategoryRepository` (abstract)
- `getAllCategories()`, `watchAllCategories()`, `findByName(String)`

#### `virtual_cellar_repository.dart` — `VirtualCellarRepository` (abstract)
- Lecture : `watchAll`, `getAll`, `getById`
- Écriture : `create`, `update`, `delete`
- Occupation : `getWinesByCellarId`, `watchWinesByCellarId`, `placeWine`- Placements individuels : `getPlacementsByWineId`, `watchPlacementsByCellarId`, `removePlacement`, `moveBottlePlacement`
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
| `GetAllVirtualCellarsUseCase` | `NoParams` implicite / `watch()` | `List<VirtualCellarEntity>` | Liste et observe les celliers |
| `CreateVirtualCellarUseCase` | `VirtualCellarEntity` | `int` | Crée un cellier |
| `UpdateVirtualCellarUseCase` | `VirtualCellarEntity` | `void` | Met à jour nom et dimensions |
| `DeleteVirtualCellarUseCase` | `int` | `void` | Supprime un cellier après dépose des bouteilles |
| `PlaceWineInCellarUseCase` | `PlaceWineParams` | `void` | Place ou retire une bouteille d'un emplacement |
| `GetWinePlacementsUseCase` | `int` (wineId) | `List<BottlePlacementEntity>` | Récupère tous les placements d'un vin (cross-celliers) |
| `MoveBottlesInCellar` | `MoveBottlesParams` | `Unit` | Déplace un groupe de bouteilles sélectionnées : vérifie bornes, collisions, ordonne les mouvements |
| `RemoveBottlePlacementUseCase` | `int` (placementId) | `Unit` | Retire un placement de bouteille |

### data/repositories/

#### `wine_repository_impl.dart` — `WineRepositoryImpl`
- Implémente `WineRepository`
- Injecté avec `WineDao` et `FoodCategoryDao`
- Responsabilités de mapping : `_mapToEntity(Wine)` (DB → domain) et `_mapToCompanion(WineEntity)` (domain → DB)
- Import JSON : supporte deux modes
- Instantané complet moderne : remplace la cave actuelle et restaure vins, celliers et placements
- JSON historique sans `virtualCellars` : import additionnel rétrocompatible, sans réappliquer de placements virtuels
- Import CSV : parsing avec mapping utilisateur + normalisation des champs (quantité, prix, couleur)
- Détection automatique du séparateur CSV : `detectCsvSeparator()` (static) — analyse fréquence et cohérence de `,`, `;`, `\t`
- Support `headerLine` (1-based, nullable) au lieu de `hasHeader` booléen

#### `food_category_repository_impl.dart` — `FoodCategoryRepositoryImpl`
- Implémente `FoodCategoryRepository`
- Mapping `FoodCategory` (DB) → `FoodCategoryEntity` (domain)

#### `virtual_cellar_repository_impl.dart` — `VirtualCellarRepositoryImpl`
- Implémente `VirtualCellarRepository`
- Injecté avec `VirtualCellarDao` et `BottlePlacementDao`
- Mappe `VirtualCellar` et `Wine` (Drift) vers les entités métier
- Gère le placement, le déplacement et le retrait des bouteilles dans les celliers

### presentation/providers/

#### `wine_list_provider.dart`
Providers Riverpod déclaratifs :
- `filteredWinesProvider(WineFilter)` — `StreamProvider.family` réactif
- `allWinesProvider` — `StreamProvider` sans filtre
- `wineCountProvider` / `totalBottlesProvider` — `FutureProvider` stats

#### `bottle_move_state_provider.dart`
- `BottleMoveStateNotifier` — `StateNotifier<BottleMoveStateEntity>` gérant le mode déplacement de bouteilles
- `bottleMoveStateProvider` — `StateNotifierProvider.family` scopé par `cellarId`
- Méthodes : `toggleMovementMode()`, `togglePlacementSelection()`, `clearSelection()`, `startMoving()`, `enableDragMode()`, `exitMovementMode()`

### presentation/screens/

#### `wine_list_screen.dart` — `WineListScreen`
- Écran principal de la cave
- Barre de recherche, chips de filtre (couleur + maturité)
- Layout adaptatif : `ListView` (mobile) / `GridView` (desktop)
- Actions menu : export JSON/CSV + import JSON/CSV
- Import CSV guidé : mapping colonnes (avec pré-analyse IA optionnelle) → prévisualisation extraction → mode direct ou enrichissement IA
- Détection automatique du séparateur CSV (virgule, point-virgule, tabulation)
- Sélection flexible de la ligne d'en-tête (click dans l'aperçu ou champ numérique)
- Vérification avant import CSV et confirmation explicite de préservation de la cave virtuelle actuelle
- Pour le JSON snapshot, confirmation destructive dédiée avant restauration complète de la cave
- Enrichissement IA par lots de 20 vins max via prompts `AiPrompts.buildCsvEnrichmentPrompt` (évaluation complète : correction + normalisation + complétion)
- Validation utilisateur à chaque lot via `CsvBatchValidationDialog` (édition inline, suppression, réévaluation IA individuelle, retry du lot)
- Résumé final détaillé de l'import (lots traités, vins importés, supprimés)
- Gestion quantité via `UpdateWineQuantityUseCase` avec dialogue confirmation
- Surbrillance visuelle (option A) des vins en dernière année théorique de consommation et des vins au-delà de la fenêtre optimale (bordure + badge distincts)
- Surbrillance pilotée par 2 réglages séparés dans `display_settings_screen.dart`, activés par défaut
- FAB → navigue vers `/cellar/add` pour choisir IA ou saisie manuelle

#### `wine_add_screen.dart` — `WineAddScreen`
- Fiche d'ajout complète avec saisie manuelle de tous les champs métier (infos principales, cave, garde, notes)
- Trois actions : redirection vers `/chat`, complétion IA d'une fiche partiellement remplie, ajout manuel direct
- Les boutons « complétion IA » et « ajout manuel » restent grisés tant que nom + millésime ne sont pas valides
- Validation UX : tooltip au survol + popup explicative au clic si prérequis manquants
- Après création d'un vin, propose immédiatement un placement dans un cellier virtuel avec sélection du cellier cible

#### `wine_detail_screen.dart` — `WineDetailScreen`
- Détail complet d'un vin (chargé via `GetWineByIdUseCase`)
- Actions : modifier, supprimer (`DeleteWineUseCase`), ajuster quantité (`UpdateWineQuantityUseCase`)
- Affichage maturité, cépages, accords mets-vin, notes de dégustation
- Remplace les anciennes coordonnées brutes par un aperçu du placement dans le cellier avec navigation vers le cellier concerné
- Ajoute un CTA « Placer en cave » lorsque des bouteilles restent non placées, avec sélection du cellier avant navigation

#### `wine_edit_screen.dart` — `WineEditScreen`
- Formulaire d'édition complet (15+ champs)
- Chargement via `GetWineByIdUseCase`, sauvegarde via `UpdateWineUseCase`
- Sélecteur de couleur, champs numériques validés

#### `virtual_cellar_list_screen.dart` — `VirtualCellarListScreen`
- Liste l'ensemble des celliers virtuels sous forme de cartes
- Permet création, renommage, redimensionnement, choix du thème visuel et suppression
- Affiche la capacité et le nombre d'emplacements par cellier
- Accès à l'éditeur expert (`ExpertCellarEditorScreen`) pour personnalisation avancée

#### `virtual_cellar_detail_screen.dart` — `VirtualCellarDetailScreen`
- Vue grille d'un cellier avec placement interactif des bouteilles
- Tap sur emplacement vide : sélection d'un vin à placer
- Tap sur emplacement occupé : infos bouteille + retrait ou navigation vers la fiche
- Redimensionnement avec alerte avant dépose automatique des bouteilles hors bornes
- La grille garde une taille de cellule fixe et devient scrollable horizontalement et verticalement avec scrollbars visibles
- Supporte un vin pré-sélectionné via la navigation, puis accompagne le placement bouteille par bouteille jusqu'au retour optionnel vers la fiche vin
- Ajoute un filtrage multi-sélection par stade de fenetre de degustation (pret a boire, apogee, etc.) pour n'afficher que les bouteilles correspondantes dans la grille
- **Mode déplacement** : sélection multiple de bouteilles, drag & drop pour déplacer un groupe, avec détection de collisions et vérification des bornes
- Thème visuel appliqué dynamiquement selon le `VirtualCellarTheme` du cellier (classic, premium cave, stone cave, garage industrial)
- Surbrillance visuelle des bouteilles en fin de fenêtre (pastille ambre + liseré) et au-delà de la fenêtre optimale (pastille rouge + liseré), selon les réglages utilisateur

#### `expert_cellar_editor_screen.dart` — `ExpertCellarEditorScreen`
- Éditeur avancé de cellier : personnalisation des dimensions, thème, sélection de cellules
- Modes de sélection : cellule individuelle, ligne complète, colonne complète
- Paramètres initiaux : `initialName`, `initialRows`, `initialColumns`, `initialTheme`, `sourceCellar` optionnel

### presentation/widgets/

#### `wine_card.dart` — `WineCard`
- Carte résumé d'un vin (nom, millésime, couleur, appellation, maturité)
- Boutons +/- pour la quantité
- Callback `onTap` pour la navigation, `onQuantityChanged` pour la mise à jour

#### `csv_column_mapping_dialog.dart` — `CsvColumnMappingDialog`
- Dialogue d'import CSV avec mapping interactif colonnes → champs vin
- Aperçu interactif du CSV (20 lignes) : clic sur un en-tête de colonne → dropdown d'assignation de champ vin
- **Mapping bidirectionnel** : clic sur un champ (chip) → popup de sélection de colonne avec échantillons de données
- Sélection de la ligne d'en-tête : clic sur le numéro de ligne dans l'aperçu ou champ numérique synchronisé
- Auto-détection par mots-clés des en-têtes (nom, millésime, producteur…) en fallback
- Bouton « Pré-analyse IA du mapping » : analyse jusqu'à 100 lignes du CSV pour détecter l'en-tête et le mapping (y compris quand l'en-tête n'est pas la première ligne)
- **Panneau de champs repliable** : section « Champs assignés » avec compteur de progression (ex: « 4/12 »), repliable pour gagner de l'espace sur petits écrans
- Résumé des champs assignés sous forme de chips cliquables (icônes 🤖 IA / 🪄 auto / 👆 manuel)
- Bouton « Réinitialiser » le mapping
- Avertissements de validation des données (millésime suspect, quantité négative)
- Retourne `CsvMappingDialogResult` avec `CsvColumnMapping` + `headerLine` (1-based, null si pas d'en-tête)

#### `csv_batch_validation_dialog.dart` — `CsvBatchValidationDialog`
- Dialogue de validation des lots IA pour l'import CSV avec édition inline
- Cartes dépliables par vin avec tous les champs éditables (`TextFormField`)
- Badge « Modifié » affiché sur les vins touchés par l'utilisateur
- Bouton de suppression individuelle d'un vin du lot
- Bouton « Réévaluer ce vin par l'IA » (callback `onReevaluateSingleWine`)
- Barre résumé : nombre de vins actifs, supprimés, modifiés
- 3 actions : « Annuler l'import » / « Réessayer ce lot » / « Valider ce lot »
- Retourne `CsvBatchValidationResult` (`CsvBatchAction` + liste éditée + indices modifiés)

#### Widgets de thèmes visuels de cellier
- `virtual_cellar_theme_selector.dart` — helpers pour afficher icône et description par thème
- `premium_cave_wrapper.dart` / `premium_cave_screen_background.dart` / `premium_cave_background_painter.dart` — rendu visuel cave premium (boiseries, or)
- `stone_cave_wrapper.dart` / `stone_cave_screen_background.dart` — rendu visuel cave en pierre (grès, chêne)
- `garage_industrial_wrapper.dart` / `garage_industrial_screen_background.dart` — rendu visuel garage industriel (acier, néon)

---

## Feature `ai_assistant/`

Assistant IA conversationnel pour l'ajout de vins par langage naturel et les accords mets-vin.

### domain/entities/

#### `chat_message.dart` — `ChatMessage`, `ChatRole`, `WinePreviewData`
- Message de chat avec `id` (UUID), `content`, `role` (user/assistant/system), `timestamp`
- `WinePreviewData` optionnel pour les données vin associées au message

#### `wine_ai_response.dart` — `WineAiResponse`
- Réponse structurée de l'IA : tous les champs d'un vin + `needsMoreInfo`, `followUpQuestion`
- `estimatedFields` — liste des champs estimés/déduits par l'IA (non fournis par l'utilisateur)
- `confidenceNotes` — raisonnement de l'IA pour les estimations (surtout fenêtre de dégustation)
- `fromJson()` / `toJson()` pour parser la réponse JSON de l'IA
- `isComplete` : vrai si `name` et `color` sont renseignés
- `mergeWith(other)` — fusionne les champs complétés par la recherche web dans l'instance courante
- `fieldWasCompleted(fieldName, other)` — vérifie si un champ a été complété par `other`

### domain/repositories/

#### `ai_service.dart` — `AiService` (abstract), `AiChatResult`, `WebSource`
Interface commune aux 4 providers IA :
- `analyzeWine(userMessage, conversationHistory)` → `AiChatResult`
- `analyzeWineWithWebSearch(userMessage, conversationHistory, systemPromptOverride?)` → `AiChatResult` — recherche web grounding (défaut : fallback vers `analyzeWine`)
- `supportsWebSearch` → `bool` — seul `GeminiService` retourne `true`
- `testConnection()` → `bool`

`AiChatResult` encapsule :
- `textResponse` — texte à afficher dans le chat
- `wineDataList` — liste de `WineAiResponse` extraits
- `isError` / `errorMessage`
- `webSources` — liste de `WebSource` (URI + titre) pour les réponses vérifiées par internet

`WebSource` :
- `uri` — URL de la source
- `title` — titre de la page source

#### `image_text_extractor.dart` — `ImageTextExtractor` (abstract)
Interface d'extraction OCR pour les photos d'étiquette :
- `extractTextFromImage(imagePath)` → `String`

### domain/usecases/

| Use Case | Params | Retour | Logique |
|----------|--------|--------|---------|
| `AnalyzeWineUseCase` | `AnalyzeWineParams` | `AiChatResult` | Appelle `AiService.analyzeWine()` ou `analyzeWineWithWebSearch()` selon `useWebSearch`, convertit erreurs en `AiFailure` |
| `AnalyzeWineFromImageUseCase` | `AnalyzeWineFromImageParams` | `AiChatResult` | Valide imageBytes + MIME type, appelle `AiService.analyzeWineFromImage()`, convertit erreurs en `AiFailure`/`ValidationFailure` |
| `ExtractTextFromWineImageUseCase` | `ExtractTextFromWineImageParams` | `String` | Appelle `ImageTextExtractor.extractTextFromImage()`, valide texte non vide, mappe erreurs en `Failure` |
| `TestAiConnectionUseCase` | `NoParams` | `bool` | Appelle `AiService.testConnection()`, convertit échec en `AiFailure` |

### data/

#### `ai_prompts.dart` — `AiPrompts`
- `systemPrompt` — prompt système complet pour le sommelier IA (extraction JSON, règles anti-hallucination, `estimatedFields`, `confidenceNotes`)
- `buildCellarSearchMessage()` — construit le prompt pour le mode « accord mets-vin » avec le contenu réel de la cave
- `buildWineReviewMessage()` — prompt pour le mode « avis » (sans recherche web, avec règles anti-hallucination)
- `groundedReviewSystemPrompt` — prompt système pour le mode avis avec recherche web Gemini (cite les sources)
- `buildGroundedReviewMessage()` — message utilisateur pour la recherche web grounded
- `fieldCompletionSystemPrompt` — prompt système pour la complétion de champs estimés via recherche web
- `buildFieldCompletionMessage()` — construit le message pour compléter les champs manquants d'un vin
- `buildCsvMappingPrompt()` — prompt pour l'analyse IA du mapping de colonnes CSV. Accepte `allRows` (jusqu'à 100 lignes) pour analyser le fichier en profondeur et détecter l'en-tête même quand elle n'est pas en première ligne. Retourne JSON avec `headerLine` + `mapping`
- `buildCsvEnrichmentPrompt()` — prompt d'enrichissement complet des vins CSV (correction, normalisation, complétion)
- `buildCsvRowDescription()` — formate une ligne CSV pour le prompt d'enrichissement
- `buildSingleWineReevaluationPrompt()` — prompt de réévaluation individuelle d'un vin après modification manuelle

#### `datasources/` — 4 implémentations de `AiService` + 1 datasource OCR

| Fichier | Classe | API | Particularités |
|---------|--------|-----|----------------|
| `openai_service.dart` | `OpenAiService` | OpenAI Chat Completions (via `dart_openai`) | Supporte GPT-4o-mini |
| `gemini_service.dart` | `GeminiService` | Google Generative AI (SDK natif) + REST API (Dio) | Rate limiting 4s, session chat réutilisée, auto-discovery modèle, **seul provider supportant la recherche web** (Gemini Search Grounding via `/v1beta/` REST) |
| `mistral_service.dart` | `MistralService` | Mistral API (compatible OpenAI, via Dio) | Session historique, tracking RPM |
| `ollama_service.dart` | `OllamaService` | API REST locale Ollama (via Dio) | Fonctionne hors-ligne |
| `mlkit_image_text_extractor.dart` | `MlKitImageTextExtractor` | Google ML Kit Text Recognition | OCR on-device depuis photo d'étiquette |

**Pattern commun à toutes les implémentations :**
1. Construction des messages (system prompt + historique + message courant)
2. Appel API
3. Extraction du bloc JSON de la réponse (`_extractWineData`)
4. Nettoyage du texte de réponse (`_cleanTextResponse`)
5. Logging via `ChatLogger`

### presentation/screens/

#### `chat_screen.dart` — `ChatScreen`
- Écran de chat principal
- Trois modes : « Ajouter un vin » / « Accord mets-vin » / « Avis sur un vin » (SegmentedButton `_ChatMode`)
- Gère l'historique des messages en session (static pour persistance inter-navigation)
- Envoi de messages via `AnalyzeWineUseCase`
- Capture photo Android via `image_picker` + OCR via `ExtractTextFromWineImageUseCase`, puis envoi du texte extrait à l'IA
- Ajout de vins à la cave via `AddWineUseCase` + auto-matching des catégories alimentaires
- Après ajout IA, propose aussi un placement immédiat dans un cellier virtuel avec pré-sélection du vin
- En mode accord mets-vin, enrichit la réponse avec des liens rapides vers les fiches détail des vins proposés présents en cave
- En mode avis, utilise Gemini Search Grounding pour chercher des informations vérifiées sur internet (avec sources)
- **Complétion web search** : après analyse d'un vin, si des champs sont estimés (✨) et qu'une clé Gemini est disponible, un bouton « Compléter via Google » propose de vérifier/compléter ces champs via la recherche internet
- Reset de session (réinitialise le chat du service IA sous-jacent)
- Bouton « Ajouter tous les vins » pour les réponses multi-vins

### presentation/widgets/

#### `chat_bubble.dart` — `ChatBubble`
- Bulle de chat avec alignement et couleur selon le rôle (user/assistant)
- Rendu Markdown pour les réponses de l'IA

#### `wine_preview_card.dart` — `WinePreviewCard`
- Carte de prévisualisation d'un `WineAiResponse` dans le chat
- Affiche les champs extraits (nom, appellation, couleur, millésime, cépages…)
- Les champs estimés par l'IA sont signalés par l'icône ✨ (ambre, italique, tooltip « Estimé par l'IA »)
- Affiche une boîte `confidenceNotes` expliquant le raisonnement de l'IA pour les estimations
- Bouton « Ajouter à la cave » / « Déjà ajouté »

---

## Feature `statistics/`

Tableaux de bord et graphiques d'analyse de la cave.

### domain/entities/

#### `cellar_statistics.dart`
- `CellarStatistics` — agrégation de toutes les statistiques de la cave
- `OverviewStats` — KPI globaux (références, bouteilles, valeur, note moyenne, millésimes)
- `ColorStat`, `MaturityStat`, `RegionStat`, `AppellationStat`, `CountryStat`, `VintageStat`, `GrapeVarietyStat`, `RatingStat`, `ProducerStat` — entrées de distribution
- `PriceStats` — statistiques de prix (min, max, médiane, moyenne, tranches)

### domain/repositories/

#### `statistics_repository.dart` — `StatisticsRepository` (abstract)
- `getCellarStatistics()` → `CellarStatistics`

### domain/usecases/

#### `get_cellar_statistics.dart` — `GetCellarStatisticsUseCase`
- Retourne `Either<Failure, CellarStatistics>`, mappe les exceptions en `CacheFailure`

### data/repositories/

#### `statistics_repository_impl.dart` — `StatisticsRepositoryImpl`
- Calcule toutes les distributions à partir de `WineRepository.getAllWines()`
- Comptage en bouteilles (`wine.quantity`), pas en références
- Distributions triées par ordre décroissant de volume
- Tranches de prix prédéfinies (0-5€, 5-10€, … 100+€)

### presentation/providers/

#### `statistics_providers.dart`
- `statisticsRepositoryProvider` — injecte `StatisticsRepositoryImpl`
- `getCellarStatisticsUseCaseProvider` — use case
- `cellarStatisticsProvider` — `FutureProvider<CellarStatistics>` réactif (se rafraîchit quand la cave change)
- `selectedStatCategoryProvider` — catégorie sélectionnée (`StatCategory` enum)
- `StatCategory` — 8 catégories : overview, color, maturity, geography, vintages, grapes, ratingsPrice, producers

### presentation/screens/

#### `statistics_screen.dart` — `StatisticsScreen`
- Écran principal avec sélecteur de catégorie (chips horizontales scrollables, mobile-friendly)
- Chaque catégorie affiche des graphiques dédiés : donut charts (couleur, maturité), bar charts (géographie, cépages, producteurs), timeline (millésimes), KPI (vue d'ensemble), hybride (notes & prix)
- Gère l'état vide (aucun vin) et les erreurs de chargement
- Données réactives : les statistiques se recalculent automatiquement quand la cave change

### presentation/widgets/

| Widget | Rôle |
|--------|------|
| `stat_donut_chart.dart` | Donut chart réutilisable avec légende (fl_chart) |
| `stat_bar_chart.dart` | Bar chart horizontal + vertical réutilisable (fl_chart) |
| `overview_section.dart` | Grille de cartes KPI (références, bouteilles, valeur, note, millésimes) |
| `color_distribution_chart.dart` | Donut par couleur de vin |
| `maturity_distribution_chart.dart` | Donut par stade de maturité |
| `geography_section.dart` | Tabs pays/régions/appellations avec bar charts |
| `vintage_distribution_chart.dart` | Bar chart vertical des millésimes |
| `grape_distribution_chart.dart` | Bar chart horizontal des cépages |
| `ratings_price_section.dart` | Tabs notes/prix avec graphiques et KPI |
| `producer_distribution_chart.dart` | Bar chart horizontal des producteurs |

---

## Feature `settings/`

### `settings_screen.dart` — `SettingsScreen`
- Hub de réglages qui regroupe IA, affichage, mode développeur et informations de version

### `display_settings_screen.dart` — `DisplaySettingsScreen`
- Paramètres d'affichage de la cave : disposition liste/master-detail et thème visuel global
- Section **Alertes de consommation** :
  - Toggle « Dernière année de consommation » (activé par défaut)
  - Toggle « Fenêtre optimale dépassée » (activé par défaut)
- Ces réglages pilotent la surbrillance dans `WineListScreen` et `VirtualCellarDetailScreen`

---

## Feature `user_manual/`

### `presentation/screens/user_manual_screen.dart` — `UserManualScreen`
- Manuel utilisateur global en onglets (vue d'ensemble, imports/exports, CSV détaillé, IA, accords, cave virtuelle, tokens IA)
- Route dédiée `/manual` (hors shell de navigation)
- Paramètre de route optionnel `section` pour ouvrir directement une section (ex: `/manual?section=ai-tokens`)
- Point d'entrée global depuis l'écran cave (icône `?` dans l'AppBar)
- Point d'entrée ciblé depuis Paramètres vers la section tokens/appairage IA

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
| `virtualCellarRepositoryProvider` | `Provider<VirtualCellarRepository>` | `VirtualCellarRepositoryImpl(virtualCellarDao, bottlePlacementDao)` |

### Settings (state persisté)

| Provider | Type | Fournit |
|----------|------|---------|
| `aiProviderSettingProvider` | `StateNotifierProvider<…, AiProvider>` | Enum du provider IA actuel |
| `openAiApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API OpenAI |
| `geminiApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API Gemini |
| `mistralApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API Mistral |
| `ollamaUrlProvider` | `StateNotifierProvider<…, String?>` | URL Ollama |
| `selectedModelProvider` | `StateNotifierProvider<…, String?>` | Modèle sélectionné |
| `visionModelOverrideProvider` | `StateNotifierProvider<…, String?>` | Modèle dédié à l'analyse d'image (optionnel) |
| `visionApiKeyOverrideProvider` | `StateNotifierProvider<…, String?>` | Clé API dédiée à l'analyse d'image (optionnel) |
| `geminiFallbackApiKeyProvider` | `StateNotifierProvider<…, String?>` | Clé API Gemini dédiée à la recherche web (fallback) |
| `useOcrForImagesProvider` | `StateNotifierProvider<…, bool>` | Si `true`, analyse image via OCR local (MLKit) plutôt que vision IA |
| `appVisualThemeProvider` | `StateNotifierProvider<…, VirtualCellarTheme?>` | Thème visuel global persisté (cave premium, pierre, garage…). `null` = thème classique par défaut |
| `highlightLastConsumptionYearProvider` | `StateNotifierProvider<…, bool>` | Si `true`, met en évidence les vins dans leur dernière année théorique de consommation |
| `highlightPastOptimalConsumptionProvider` | `StateNotifierProvider<…, bool>` | Si `true`, met en évidence les vins dont la fenêtre optimale est dépassée |
| `immersiveCellarThemeProvider` | `StateProvider<VirtualCellarTheme?>` | Override temporaire de thème quand l'utilisateur navigue dans un cellier thémé (réinitialisé en sortie) |
| `visionProviderOverrideProvider` | `StateNotifierProvider<…, String?>` | Fournisseur IA dédié à l'analyse d'image (optionnel, override du fournisseur principal) |

### AI Service

| Provider | Type | Fournit |
|----------|------|---------|
| `aiServiceProvider` | `Provider<AiService?>` | L'implémentation IA active (ou `null` si non configuré). Switch sur `aiProviderSettingProvider`. |
| `visionAiServiceProvider` | `Provider<AiService?>` | Service IA dédié à l'analyse d'images. Applique les overrides de modèle/clé vision si configurés ; sinon délègue à `aiServiceProvider`. Retourne toujours `null` pour Ollama (non supporté). |
| `geminiWebSearchServiceProvider` | `Provider<GeminiService?>` | Service Gemini dédié à la recherche web. Si Gemini est le fournisseur principal, utilise sa clé ; sinon, utilise la clé fallback (`geminiFallbackApiKeyProvider`). Retourne `null` si aucune clé disponible. |
| `imageTextExtractorProvider` | `Provider<ImageTextExtractor>` | Implémentation OCR active : `MlKitImageTextExtractor` |
| `visionModelProvider` | `FutureProvider.autoDispose<String?>` | Découvre le modèle vision disponible via `visionAiServiceProvider.discoverVisionModel()` |

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
| `getAllVirtualCellarsUseCaseProvider` | `Provider<GetAllVirtualCellarsUseCase>` |
| `createVirtualCellarUseCaseProvider` | `Provider<CreateVirtualCellarUseCase>` |
| `updateVirtualCellarUseCaseProvider` | `Provider<UpdateVirtualCellarUseCase>` |
| `deleteVirtualCellarUseCaseProvider` | `Provider<DeleteVirtualCellarUseCase>` |
| `placeWineInCellarUseCaseProvider` | `Provider<PlaceWineInCellarUseCase>` |
| `getWinePlacementsUseCaseProvider` | `Provider<GetWinePlacementsUseCase>` |
| `moveBottlesInCellarUseCaseProvider` | `Provider<MoveBottlesInCellar>` |
| `removeBottlePlacementUseCaseProvider` | `Provider<RemoveBottlePlacementUseCase>` |

### Use Cases — AI

| Provider | Type |
|----------|------|
| `analyzeWineUseCaseProvider` | `Provider<AnalyzeWineUseCase?>` |
| `analyzeWineFromImageUseCaseProvider` | `Provider<AnalyzeWineFromImageUseCase?>` | Utilise `visionAiServiceProvider` |
| `extractTextFromWineImageUseCaseProvider` | `Provider<ExtractTextFromWineImageUseCase>` |
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
   → Les champs estimés par l'IA sont signalés par ✨ (via estimatedFields)
3b. [Optionnel] L'utilisateur clique "Compléter N champ(s) via Google"
   → ref.read(geminiWebSearchServiceProvider)
   → GeminiService.analyzeWineWithWebSearch(
       buildFieldCompletionMessage(wine, estimatedFields),
       systemPromptOverride: fieldCompletionSystemPrompt)
   → API Gemini REST /v1beta/ avec google_search tool
   → WineAiResponse.mergeWith(completedResponse)
   → Mise à jour des WinePreviewCard(s)
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

### Avis sur un vin (recherche web Gemini)

```
1. ChatScreen en mode « Avis sur un vin »
2. L'utilisateur tape "Que penses-tu du Château Margaux 2018 ?"
3. ChatScreen._sendMessage()
   → Si le provider supporte le web search (Gemini) :
     → AnalyzeWineUseCase.call(params, useWebSearch: true)
       → AiService.analyzeWineWithWebSearch(
           buildGroundedReviewMessage(msg),
           systemPromptOverride: groundedReviewSystemPrompt)
       → GeminiService : appel REST /v1beta/ avec google_search tool
       → Extraction grounding metadata → List<WebSource>
     ← AiChatResult(textResponse, webSources: [...])
   → Si le provider ne supporte pas mais clé Gemini fallback dispo :
     → geminiWebSearchServiceProvider.analyzeWineWithWebSearch(...)
   → Sinon : analyzeWine classique sans recherche web
4. ChatScreen affiche la réponse + WebSourcesWidget (liens cliquables)
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
3. Détection automatique du séparateur CSV (virgule, point-virgule, tabulation)
4. Extraction de 5 lignes d'aperçu
5. CsvColumnMappingDialog :
   - Aperçu interactif : clic sur en-tête de colonne → dropdown d'assignation
   - Auto-détection des en-têtes par mots-clés (fallback)
   - [Optionnel] Pré-analyse IA : AiPrompts.buildCsvMappingPrompt()
     → AnalyzeWineUseCase → parsing JSON <json>...</json>
     → assignation automatique des colonnes
   - Sélection de la ligne d'en-tête (clic ou champ numérique)
   - Retourne CsvMappingDialogResult (mapping + headerLine)
6. ParseCsvImportUseCase.call(ParseCsvImportParams)
  → WineRepository.parseCsvRows(csvContent, mapping, headerLine)
  → preview extraction (échantillon)
7. Choix utilisateur :
  A) Import direct
    → Récapitulatif détaillé → confirmation
    → ImportWinesFromCsvUseCase.call(...)
    → WineRepository.importFromCsv(...)
  B) Compléter avec IA
    → découpage en lots de 20
    → AiPrompts.buildCsvEnrichmentPrompt() (évaluation complète)
    → AnalyzeWineUseCase.call(...) pour chaque lot
    → CsvBatchValidationDialog : édition inline, suppression, réévaluation individuelle
    → CsvBatchAction.validate : AddWineUseCase pour chaque vin validé
    → CsvBatchAction.retry : renvoi du lot à l'IA
    → CsvBatchAction.cancel : arrêt de l'import
    → Résumé final détaillé (lots traités, vins importés, supprimés)
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
| 5 | **Tests unitaires/widget** — couverture partielle (mocktail), à enrichir | Moyenne | Fiabilité |
| 6 | **Import CSV piloté par prompts IA** (qualité dépendante du provider/modèle) | Moyenne | Peut nécessiter ajustement de prompt selon modèle |
| 7 | **Tesseract OCR** — alternatif plus puissant pour les textes très artistiques. Ajouter `tesseract_ocr` (~15 MB) si MLKit s'avère insuffisant sur certaines étiquettes | Faible | Amélioration OCR, coût en taille d'APK |
