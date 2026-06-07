# Wine Cellar — Instructions pour agents IA

> **Source de vérité portable** — Ce fichier est lu par OpenAI Codex, Claude CLI et tout outil compatible AGENTS.md.
> Pour GitHub Copilot, voir aussi `.github/copilot-instructions.md` (adaptateur Copilot avec directives spécifiques).

Application Flutter de gestion de cave à vin avec assistant IA intégré.
Cible principale : Android. Linux utilisé pour les tests locaux.

---

## Architecture — Clean Architecture (feature-first)

Structure par feature, 3 couches :

```
lib/features/<feature>/
  domain/       → entities, repositories (abstracts), usecases
  data/         → repository impls, datasources
  presentation/ → screens, widgets, providers (Riverpod)
```

**Règle de dépendance stricte :** `Presentation → Domain ← Data`
Le domain ne dépend jamais de `data` ni de `presentation`.

Couches transversales :
- `lib/core/` — providers Riverpod, router, thème, enums, constantes, erreurs
- `lib/database/` — Drift ORM (tables, DAOs, migrations)

Documentation de référence :
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- [docs/technical/routing.md](docs/technical/routing.md)
- [docs/technical/providers.md](docs/technical/providers.md)
- [docs/technical/database.md](docs/technical/database.md)
- `docs/features/*.md` — documentation par feature

---

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

---

## Patterns obligatoires

- **State management :** Riverpod (`Provider`, `StateNotifierProvider`). Ne pas introduire `get_it` ou `injectable`.
- **Use cases :** méthode `call()`, retournent `Either<Failure, T>` (fpdart). Pas d'exceptions non gérées.
- **Erreurs :** classe sealed `Failure` avec sous-types : `ServerFailure`, `CacheFailure`, `AiFailure`, `ValidationFailure`, `ConfigurationFailure`.
- **Navigation :** GoRouter dans `lib/core/router.dart`.
- **Stockage sécurisé :** `flutter_secure_storage` pour clés API et configs sensibles. Jamais `SharedPreferences` pour des secrets.
- **Entités :** immutables avec `copyWith`. Éviter `dynamic`.
- **Pas de logique métier** dans les widgets ou les providers ; uniquement dans les use cases.

---

## Base de données (Drift)

- Schéma versionné — actuellement **v6**, migrations non-destructives uniquement.
- Tables : `Wines`, `VirtualCellars`, `BottlePlacements`, `FoodCategories`, `WineFoodPairings`.
- Fichiers `*.g.dart` : **ne jamais modifier manuellement**.
- Après toute modification de table ou DAO :
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```

---

## Localisation

- French-first (`template-arb-file: app_fr.arb`), anglais supporté.
- Fichiers ARB dans `lib/l10n/`.
- Tout texte visible par l'utilisateur doit avoir une clé dans `app_fr.arb` **et** `app_en.arb`.
- Usage dans les widgets : `AppLocalizations.of(context)?.labelKey`

---

## Sécurité (OWASP Mobile Top 10)

- Clés API et tokens : uniquement via `flutter_secure_storage`, jamais en clair dans le code ou les assets.
- Requêtes Drift : paramètres typés, pas de concaténation SQL.
- Appels vers APIs IA (OpenAI, Gemini, Mistral, Ollama) : HTTPS uniquement.
- Pas de `print()` / `debugPrint()` exposant des données sensibles en production.
- Inputs utilisateur envoyés aux LLMs : sanitizés contre l'injection de prompt.
- ProGuard/R8 activé en release Android (`android/app/build.gradle.kts`).
- Clés de signature non committées — voir `android/key.properties.example`.

---

## Règles de taille de fichier

| Type de fichier | Seuil recommandé |
|-----------------|------------------|
| Screen (`*_screen.dart`) | < 400 lignes |
| Provider | < 250 lignes |
| Widget | < 200 lignes |
| Use case | < 120 lignes (1 responsabilité) |
| Repository impl | < 300 lignes |
| DAO | < 300 lignes |

Au-delà de ces seuils : signaler et proposer un découpage ciblé avant d'ajouter de nouvelles responsabilités.

---

## Règles de développement

- Séparer strictement les responsabilités : pas de logique métier dans les widgets ou providers.
- Éviter `dynamic` sauf justification explicite.
- Lors d'un changement de route : mettre à jour `docs/technical/routing.md`.
- Lors d'un changement de provider global : mettre à jour `docs/technical/providers.md`.
- Lors d'un changement de schéma Drift : mettre à jour `docs/technical/database.md`.
- Lors d'une modification de feature : mettre à jour `docs/features/<feature>.md`.
- Lors d'une fonctionnalité visible par l'utilisateur : mettre à jour `lib/features/user_manual/`.
- Lors d'un ajout de fonctionnalité : ajouter ou mettre à jour les tests dans `test/`.

---

## Workflow — Nouvelle fonctionnalité

1. **Clarifier** scope, données, UI/navigation, IA, besoins transversaux.
2. **Sketch** : liste exacte des fichiers à créer par couche (domain → data → presentation).
3. **Implémenter** dans cet ordre : entities → repository interface → use cases → data layer → presentation.
4. **Régénérer** les `*.g.dart` si tables/DAOs modifiés.
5. **Tester** : use cases en priorité, puis repositories, puis providers.
6. **Vérifier** : `flutter analyze` sans erreur.
7. **Documenter** : mettre à jour les `docs/` concernés.

### Checklist avant commit

- [ ] Règle de dépendance `Presentation → Domain ← Data` respectée
- [ ] Use cases retournent `Either<Failure, T>`
- [ ] Entités immutables avec `copyWith`
- [ ] Pas de `dynamic`, pas d'exceptions non gérées
- [ ] Nouvelles routes GoRouter ajoutées si nécessaire
- [ ] Clés ARB ajoutées (FR + EN) si textes visibles
- [ ] Migration Drift versionnée si schéma modifié
- [ ] Tests unitaires écrits (use cases en priorité)
- [ ] `flutter analyze` sans erreur
- [ ] Docs mises à jour

---

## Commandes de build & test

```bash
# Installer les dépendances
flutter pub get

# Générer le code Drift (obligatoire après modification de tables/DAOs)
dart run build_runner build --delete-conflicting-outputs

# Lancer en debug Linux
flutter run -d linux

# Build Linux release
flutter build linux

# Lancer les tests
flutter test

# Analyser le code
flutter analyze
```

---

## Fournisseurs IA supportés

| Fournisseur | Type | Interface |
|-------------|------|-----------|
| OpenAI | Cloud | `AiService` |
| Google Gemini | Cloud | `AiService` |
| Mistral | Cloud (API OpenAI-compatible) | `AiService` |
| Ollama | Local | `AiService` |

OCR on-device via Google ML Kit.

---

## Tests — conventions

- Framework : `flutter_test` + `mocktail` (pas `mockito`).
- Fichiers miroirs : `lib/features/x/y.dart` → `test/features/x/y_test.dart`.
- Noms de tests : décrire le comportement attendu, pas l'implémentation.
  - ✓ `'returns Right(wine) when repository succeeds'`
  - ✗ `'calls repository.addWine once'`
- Priorité : use cases → repositories → providers/notifiers → helpers purs.
- Widget tests uniquement si le contrat dépend réellement du rendu Flutter.

---

## Pièges courants

- **Drift :** toujours régénérer les `*.g.dart` après modification de tables/DAOs.
- **Either :** les use cases retournent `Either` — utiliser `fold` ou pattern matching, jamais de `try/catch` direct en dehors des datasources.
- **Android signing :** voir `android/key.properties.example` pour la configuration de signature.
- **GPU ancien :** `LIBGL_ALWAYS_SOFTWARE=1` si crash OpenGL (ex: ThinkPad T410s).

---

## Compatibilité outils IA

| Fichier | Lu par | Rôle |
|---------|--------|------|
| `AGENTS.md` (ce fichier) | OpenAI Codex, Claude CLI, Gemini CLI, tout outil compatible | Source de vérité portable |
| `.github/copilot-instructions.md` | GitHub Copilot | Instructions spécifiques Copilot + directives agents/prompts |
| `.github/agents/*.agent.md` | GitHub Copilot | Agents spécialisés avec rôles, tools, handoffs |
| `.github/prompts/*.prompt.md` | GitHub Copilot | Prompts réutilisables (slash commands) |
| `.github/instructions/*.instructions.md` | GitHub Copilot | Instructions modulaires par contexte fichier |
| `CLAUDE.md` | Claude CLI (si présent) | Alias vers AGENTS.md pour Claude Projects |

> Pour utiliser avec un nouvel outil : pointer cet outil sur `AGENTS.md` comme fichier d'instructions principal.
