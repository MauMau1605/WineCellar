# Wine Cellar 🍷

Application de gestion de cave à vin avec assistant IA intégré.

## Fonctionnalités

- **Saisie de vin via chat IA** — décrivez un vin en langage naturel, l'IA extrait les informations structurées
- **Liste & détail des bouteilles** — gestion des quantités, filtres par couleur/maturité/accord mets-vins
- **Export JSON / CSV** de la cave
- **Fournisseurs IA flexibles** — OpenAI (GPT) ou Ollama (local, gratuit)
- **Base SQLite locale** avec Drift (migrations versionnées)

## Prérequis

- **Flutter SDK 3.41+** (Dart 3.11+)
- **Linux** : `clang`, `cmake`, `ninja-build`, `pkg-config`, `libgtk-3-dev`, `libsecret-1-dev`

```bash
# Installation des dépendances système (Ubuntu/Debian)
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev libsecret-1-dev
```

## Build & exécution

### 1. Installer les dépendances Dart

```bash
flutter pub get
```

### 2. Générer le code (Drift ORM + serialization)

```bash
dart run build_runner build --delete-conflicting-outputs
```

> ⚠️ Cette étape est **obligatoire** après un clone ou un `flutter clean`. Elle génère les fichiers `*.g.dart` (tables, DAOs).

### 3. Builder l'application Linux

```bash
flutter build linux
```

Le binaire est produit dans `build/linux/x64/release/bundle/wine_cellar`.

### 4. Exécuter

```bash
# Lancement direct du binaire release
./build/linux/x64/release/bundle/wine_cellar

# OU en mode debug avec hot-reload
flutter run -d linux
```

> **Note GPU ancien** (ex: ThinkPad T410s) : si l'app crash avec une erreur OpenGL, forcer le rendu logiciel :
> ```bash
> LIBGL_ALWAYS_SOFTWARE=1 ./build/linux/x64/release/bundle/wine_cellar
> ```

### Commande tout-en-un (après un clone)

```bash
flutter pub get && dart run build_runner build --delete-conflicting-outputs && flutter build linux
```

## Build Android

```bash
flutter build apk
# ou
flutter build appbundle
```

## CI/CD GitHub (Android)

- `build-android.yml`
	- Déclenchement : `push`/`pull_request` sur `main` + manuel (`workflow_dispatch`)
	- Actions : `flutter pub get` + `build_runner` + test migration + `flutter build apk --debug`
	- Résultat : artifact `wine-cellar-android-debug-apk`

- `release-android.yml`
	- Déclenchement : push d'un tag `v*` (ex: `v0.2.0`)
	- Actions : build APK release puis publication dans une GitHub Release
	- Asset publié : `wine-cellar-android-<tag>.apk`

### Publier une release Android

```bash
git tag v0.2.0
git push origin v0.2.0
```

Ensuite, télécharge l'APK depuis la section **Releases** du repo et installe-le sur le téléphone.

## Structure du projet

```
lib/
├── main.dart                  # Point d'entrée
├── app.dart                   # MaterialApp.router
├── core/                      # Thème, enums, constantes, providers, routeur
├── database/                  # Drift : tables, DAOs, migrations
│   ├── tables/                # Définitions des tables (wines, food_categories, pairings)
│   └── daos/                  # Data Access Objects
├── features/
│   ├── wine_cellar/           # Liste, détail, filtres, export
│   ├── ai_assistant/          # Chat IA, prompts, services OpenAI/Ollama
│   └── settings/              # Configuration fournisseur IA, clé API
└── l10n/                      # Fichiers .arb (fr/en)
```

## Technologies

| Couche | Choix |
|--------|-------|
| Framework | Flutter 3.41 |
| State management | Riverpod |
| Navigation | GoRouter |
| Base de données | Drift (SQLite) |
| IA | OpenAI / Ollama |
| Sécurité | flutter_secure_storage |
