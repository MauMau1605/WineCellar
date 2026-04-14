# Wine Cellar 🍷

Application de gestion de cave à vin avec assistant IA intégré.

## Fonctionnalités

- **Saisie de vin via chat IA** — décrivez un vin en langage naturel, l'IA extrait les informations structurées
- **Liste & détail des bouteilles** — gestion des quantités, filtres par couleur/maturité/accord mets-vins
- **Import CSV intelligent** — détection automatique du séparateur, prévisualisation interactive, mapping des colonnes par clic ou pré-analyse IA, sélection flexible de la ligne d'en-tête, enrichissement IA avec validation par lot éditable
- **Export JSON / CSV** de la cave
- **Accords mets-vins** — catégories éditables avec suggestions IA
- **Cave virtuelle** — celliers configurables avec grille de placement des bouteilles
- **Fournisseurs IA flexibles** — OpenAI (GPT), Google Gemini, Mistral, Ollama (local, gratuit)
- **Vision & OCR** — analyse d'étiquettes par caméra (OCR local ou vision IA)
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

### Signature Android release (important pour conserver les donnees)

Si l'APK est signe avec une cle differente de la version deja installee,
Android refuse la mise a jour et force une reinstallation complete
(`INSTALL_FAILED_UPDATE_INCOMPATIBLE`), ce qui supprime les donnees locales.

1. Generer un keystore unique (une seule fois) :

```bash
mkdir -p android/keystore
keytool -genkeypair -v \
	-keystore android/keystore/upload-keystore.jks \
	-alias upload \
	-keyalg RSA -keysize 2048 -validity 10000
```

2. Creer `android/key.properties` a partir du template :

```bash
cp android/key.properties.example android/key.properties
```

Puis renseigner les vrais mots de passe/alias.

3. Builder en release (signe avec cette cle) :

```bash
flutter build apk --release
```

4. Installer en mise a jour (donnees conservees) :

```bash
scripts/install_android_apk.sh --apk-file <chemin_vers_apk_release>
```

Regle d'or : garde toujours le meme keystore pour toutes les versions futures.

### Installer l'APK sur téléphone sans Android Studio

Prérequis Linux:

```bash
sudo apt install -y adb
```

Script fourni:

```bash
chmod +x scripts/install_android_apk.sh
```

Installer depuis la dernière GitHub Release:

```bash
scripts/install_android_apk.sh --repo <owner>/<repo>
```

> Par défaut, le script fait une **mise à jour** (`adb install -r`) et conserve les données locales.

Installer depuis un tag précis:

```bash
scripts/install_android_apk.sh --repo <owner>/<repo> --tag v0.2.0
```

Installer depuis un APK local déjà téléchargé:

```bash
scripts/install_android_apk.sh --apk-file ./wine-cellar-android-v0.2.0.apk
```

Forcer une réinstallation complète (suppression des données):

```bash
scripts/install_android_apk.sh --repo <owner>/<repo> --fresh-install
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
│   ├── wine_cellar/           # Liste, détail, filtres, import/export CSV & JSON
│   ├── ai_assistant/          # Chat IA, prompts, services OpenAI/Gemini/Mistral/Ollama
│   ├── settings/              # Configuration fournisseur IA, clé API
│   ├── user_manual/           # Manuel utilisateur intégré
│   └── developer/             # Outils développeur (logs IA)
└── l10n/                      # Fichiers .arb (fr/en)
```

## Technologies

| Couche | Choix |
|--------|-------|
| Framework | Flutter 3.41 |
| State management | Riverpod |
| Navigation | GoRouter |
| Base de données | Drift (SQLite) |
| IA | OpenAI / Gemini / Mistral / Ollama |
| Sécurité | flutter_secure_storage |
