# Wine Cellar — Copilot Instructions

Application Flutter de gestion de cave à vin avec assistant IA intégré.
Cible principale finale : Android. Linux est utilisé pour les tests locaux.

## Architecture

**Clean Architecture feature-first** avec 3 couches par feature :

```
lib/features/<feature>/
  domain/     → entities, repositories (abstracts), usecases
  data/       → repository impls, datasources
  presentation/ → screens, widgets, providers (Riverpod)
```

**Règle de dépendance :** `Presentation → Domain ← Data`. Le domain ne dépend jamais de data ni de presentation.

Couches transversales :
- `lib/core/` — providers Riverpod, router, thème, enums, constantes, erreurs
- `lib/database/` — Drift ORM (tables, DAOs, migrations)

Voir [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) pour le détail complet.

## Conventions de nommage

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Interface repository | `XxxRepository` | `WineRepository` |
| Implémentation | `XxxRepositoryImpl` | `WineRepositoryImpl` |
| Entité | `XxxEntity` | `WineEntity` |
| Use case | `XxxUseCase` | `AddWineUseCase` |
| Provider Riverpod | suffixe `Provider` | `wineRepositoryProvider` |
| Screen | `XxxScreen` | `WineListScreen` |
| Table Drift | Pluriel PascalCase | `Wines`, `FoodCategories` |
| DAO Drift | `XxxDao` | `WineDao` |

## Patterns clés

- **State management :** Riverpod (providers manuels dans `lib/core/providers.dart`)
- **Injection de dépendances :** via providers Riverpod (`Provider`, `StateNotifierProvider`). Ne pas introduire `get_it`/`injectable`.
- **Retour des use cases :** `Either<Failure, T>` (fpdart). Pas d'exceptions non gérées.
- **Erreurs :** classe sealed `Failure` avec sous-types (`ServerFailure`, `CacheFailure`, `AiFailure`, `ValidationFailure`, `ConfigurationFailure`)
- **Navigation :** GoRouter (`lib/core/router.dart`)
- **Stockage sécurisé :** `flutter_secure_storage` pour clés API et configs sensibles

## Règles de développement

- Séparer strictement les responsabilités : pas de logique métier dans les widgets ou providers.
- Les use cases exposent une méthode `call` et restent centrés sur une seule responsabilité.
- Éviter `dynamic` sauf justification explicite.
- Privilégier les entités immutables et `copyWith`.
- Lors d'un changement de responsabilité ou d'architecture, mettre à jour `docs/ARCHITECTURE.md`.
- Lors d'un ajout ou modification de fonctionnalité visible par l'utilisateur, mettre à jour le manuel utilisateur (`lib/features/user_manual/`).
- Lors d'un ajout de fonctionnalité, ajouter ou mettre à jour les tests unitaires correspondants dans `test/`.
- Lors d'une correction de bug, créer ou mettre à jour des tests associés qui reproduisent le bug corrigé afin de limiter les régressions futures.
- En cas de demande ambiguë, demander une clarification avant d'implémenter.

## Base de données (Drift)

- Schéma versionné (actuellement **v5**), migrations non-destructives
- Fichiers générés : `*.g.dart` — ne jamais modifier manuellement
- Régénérer après modification des tables : `dart run build_runner build --delete-conflicting-outputs`
- Tables : `Wines`, `VirtualCellars`, `BottlePlacements`, `FoodCategories`, `WineFoodPairings`

## Localisation

- French-first (`template-arb-file: app_fr.arb`), anglais supporté
- Fichiers ARB dans `lib/l10n/`
- Usage : `AppLocalizations.of(context)?.labelKey`

## Build & Test

```bash
# Installer les dépendances
flutter pub get

# Générer le code Drift (obligatoire après clone ou modification de tables/DAOs)
dart run build_runner build --delete-conflicting-outputs

# Build Linux release
flutter build linux

# Exécuter en debug
flutter run -d linux

# Lancer les tests
flutter test

# Analyser le code
flutter analyze
```

## Fournisseurs IA supportés

OpenAI, Google Gemini, Mistral (API compatible OpenAI), Ollama (local).
Chaque service implémente l'interface abstraite `AiService`.
OCR on-device via Google ML Kit.

## Pièges courants

- Toujours regénérer les `*.g.dart` après modification de tables/DAOs (`dart run build_runner build --delete-conflicting-outputs`)
- Les use cases retournent `Either` — utiliser `fold` ou pattern matching, jamais de try/catch direct
- Le repo mémoire note un workflow spécifique pour la signature Android — voir `android/key.properties.example`
- GPU ancien (ex: ThinkPad T410s) : `LIBGL_ALWAYS_SOFTWARE=1` si crash OpenGL
