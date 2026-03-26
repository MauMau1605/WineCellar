---
description: "Créer un nouveau thème visuel immersif pour les caves virtuelles (fond plein écran + wrapper alcôve + ThemeData Material)"
name: "Create Cellar Theme"
argument-hint: "Nom du thème et description visuelle libre (ex: 'Bibliothèque victorienne : boiseries sombres, étagères sculptées, lustre à bougies')"
agent: "agent"
---

# Créer un nouveau thème de cave virtuelle

## Architecture des thèmes — Rappel

Chaque thème est composé de **5 éléments** obligatoires à créer ou modifier :

| Élément | Fichier | Rôle |
|---|---|---|
| 1. Enum value | `lib/features/wine_cellar/domain/entities/virtual_cellar_theme.dart` | Identifiant stable du thème |
| 2. ThemeData Material | `lib/core/cellar_theme_data.dart` | Palette couleurs app-wide |
| 3. Fond plein écran | `lib/features/wine_cellar/presentation/widgets/<name>_screen_background.dart` | Mur/décor CustomPainter full-screen |
| 4. Wrapper alcôve | `lib/features/wine_cellar/presentation/widgets/<name>_wrapper.dart` | Cadre sculptural + étagères |
| 5. Câblage écran | `lib/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart` | Switchs conditionnels |

Les fichiers de référence pour comprendre les patterns exacts sont :
- [virtual_cellar_theme.dart](../../lib/features/wine_cellar/domain/entities/virtual_cellar_theme.dart)
- [cellar_theme_data.dart](../../lib/core/cellar_theme_data.dart)
- [stone_cave_screen_background.dart](../../lib/features/wine_cellar/presentation/widgets/stone_cave_screen_background.dart)
- [stone_cave_wrapper.dart](../../lib/features/wine_cellar/presentation/widgets/stone_cave_wrapper.dart)
- [virtual_cellar_detail_screen.dart](../../lib/features/wine_cellar/presentation/screens/virtual_cellar_detail_screen.dart)
- [virtual_cellar_theme_selector.dart](../../lib/features/wine_cellar/presentation/widgets/virtual_cellar_theme_selector.dart)

---

## Étapes d'implémentation

### Étape 1 — Lire les fichiers de référence existants

Avant d'écrire une ligne, lire intégralement :
- `virtual_cellar_theme.dart` → comprendre la structure de l'enum, `label`, `storageValue`, `fromStorage()`
- `cellar_theme_data.dart` → comprendre la structure d'un ThemeData complet (`_buildStoneCave()` comme modèle)
- `stone_cave_screen_background.dart` → patron du fond plein écran (`shouldRepaint: false`, structure des méthodes)
- `stone_cave_wrapper.dart` → patron du wrapper (constantes de layout, painters `_AlcovePainter` + `_ShelfPainter`)
- la section `_CellarGridViewState.build` et `_buildGridContent` du detail screen → voir comment `isPremiumCave`/`isStoneCave` sont câblés
- `virtual_cellar_theme_selector.dart` → voir comment ajouter l'icône et la description

### Étape 2 — Extraire la palette visuelle

À partir de la description visuelle fournie, définir :
- **Couleur de base** (fond le plus sombre) → `const Color(0xFF______)`
- **Couleur de surface** (blocs/panneaux) → variation légèrement plus claire
- **Accent chaud/froid** (lumière, métal, bois) → pour gradients et lueurs
- **Parchment/cream** (texte clair sur fond sombre)
- **Accent secondaire** (reflets, LEDs, bougies, etc.)

### Étape 3 — Implémenter dans l'ordre

Toujours dans cet ordre pour éviter les références cassées :

#### 3a. Enum value
Dans `virtual_cellar_theme.dart`, ajouter la nouvelle valeur **avant le dernier membre** :
```dart
newTheme(
  label: 'Nom affiché',
  storageValue: 'camelCaseName',  // doit correspondre au nom Dart
),
```

#### 3b. Sélecteur UI
Dans `virtual_cellar_theme_selector.dart`, ajouter **dans chaque switch** :
```dart
case VirtualCellarTheme.newTheme:
  return Icons.some_icon_outlined;  // icône Material thématique

case VirtualCellarTheme.newTheme:
  return 'Description courte en français (max ~50 caractères)';
```

#### 3c. ThemeData Material
Dans `cellar_theme_data.dart` :
1. Ajouter 4–6 `static const Color _xxx = Color(0xFF______)` pour la palette
2. Ajouter `static final ThemeData _newTheme = _buildNewTheme();`
3. Implémenter `_buildNewTheme()` en suivant le modèle `_buildStoneCave()` :
   - `ColorScheme.dark(...)` avec tous les champs `surfaceContainerXxx`
   - `GoogleFonts.nunitoTextTheme(...)` ou autre police thématique
   - Tous les composants Material : AppBar, Card, FAB, Input, Chip, NavigationBar, Dialog, etc.
4. Dans `forTheme()`, ajouter `case VirtualCellarTheme.newTheme: return _newTheme;`
5. Dans `overridesAppTheme()`, ajouter `case VirtualCellarTheme.newTheme: return true;`

#### 3d. Fond plein écran
Créer `lib/features/wine_cellar/presentation/widgets/<snake_name>_screen_background.dart` :

```dart
class NewThemeScreenBackground extends StatelessWidget {
  const NewThemeScreenBackground({super.key});
  @override
  Widget build(BuildContext context) => const Positioned.fill(
    child: CustomPaint(painter: _FullScreenBgPainter()),
  );
}

class _FullScreenBgPainter extends CustomPainter {
  const _FullScreenBgPainter();

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);   // texture de surface (pierre, bois, tissu…)
    _drawArchOrStructure(canvas, size); // élément structurel iconique
    _drawLighting(canvas, size);     // éclairage directionnel + ambiance
    _drawVignette(canvas, size);     // assombris les bords
  }

  @override
  bool shouldRepaint(covariant _FullScreenBgPainter old) => false;
}
```

Règles pour le peintre de fond :
- `shouldRepaint` retourne toujours `false` (fond statique)
- Toujours commencer par un fond uniforme via `LinearGradient` sur `Rect.fromLTWH(0, 0, w, h)`
- Utiliser `math.Random(seed_fixe)` pour la texture répétable
- Terminer par une vignette radiale + assombrissement des 4 bords

#### 3e. Wrapper alcôve
Créer `lib/features/wine_cellar/presentation/widgets/<snake_name>_wrapper.dart` :

```dart
class NewThemeWrapper extends StatelessWidget {
  // Mêmes paramètres que StoneCaveWrapper / PremiumCaveWrapper
  final Widget gridChild;
  final int columns, rows;
  final double cellWidth, cellHeight, rowNumWidth, rowGap;
  // ...
}
```

Règles pour le wrapper :
- Reprendre exactement les constantes de layout `alcoveInsetX/Y`, `alcovePadX/V`, `ambientBleed`
- Stack à 3 couches : `_AlcovePainter` → `_ShelfPainter` → `gridChild` (Positioned)
- `_AlcovePainter` dessine le cadre sculptural autour de la grille
- `_ShelfPainter` dessine les étagères entre chaque rangée (boucle `for r in rows`)
- `shouldRepaint` compare tous les paramètres de layout

#### 3f. Câblage dans le detail screen
Dans `virtual_cellar_detail_screen.dart` :

1. **Import** : ajouter les 2 imports en haut du fichier
2. **Background** (dans `body: Stack`) :
   ```dart
   if (cellar.theme == VirtualCellarTheme.newTheme)
     const NewThemeScreenBackground(),
   ```
3. **Variable** `isNewTheme` dans `_CellarGridViewState.build` (à côté de `isPremiumCave`)
4. **Wrapper** : ajouter un `else if (isNewTheme) ? NewThemeWrapper(...) :` dans la chaîne conditionnelle du `child:`
5. **Label color** dans `_buildGridContent` : ajouter une condition `isStoneCave ? ... : isNewTheme ? const Color(0xCC______) :`
6. **_SlotCell** : vérifier si `isImmersive` doit inclure le nouveau thème (transparent bg, bottle-face painter, etc.)

---

## Checklist de validation

Après implémentation, vérifier :

- [ ] `dart analyze lib/` → zéro issue (ni error, ni warning)
- [ ] Aucun `*.g.dart` modifié (pas de changement de schéma DB)
- [ ] `storageValue` unique dans l'enum (pas de collision avec valeurs existantes)
- [ ] `fromStorage()` : le fallback `classic` fonctionne pour les valeurs inconnues
- [ ] Le thème apparaît dans le sélecteur avec icône + description
- [ ] Le fond est bien plein écran sur Linux (test avec `LIBGL_ALWAYS_SOFTWARE=1`)
- [ ] Les étagères sont alignées avec la grille de bouteilles
- [ ] Les bouteilles s'affichent correctement (bottle-face painter ou visuel adapté)
- [ ] Sélection/drag-drop des bouteilles fonctionne dans le nouveau thème

---

## Pièges fréquents

- **Ne jamais modifier** `*.g.dart` — régénérer avec `dart run build_runner build --delete-conflicting-outputs` si une table change
- **`shouldRepaint: false`** sur les fonds plein écran (statiques) — sinon performance catastrophique au scroll
- **Seed fixe** dans `math.Random(seed)` pour que la texture soit identique à chaque rebuild
- **`overridesAppTheme: true`** obligatoire pour le mode immersif (AppBar transparente, etc.)
- **`Colors.transparent`** pour `slotBackgroundColor` dans `_SlotCell` quand `isImmersive`
- Les **constantes de layout** du wrapper doivent correspondre à celles utilisées dans `_AlcovePainter` pour que la grille soit bien centrée dans le cadre
- Ajouter le thème dans **toutes** les clauses `switch/case` de `cellar_theme_data.dart` et du sélecteur (erreur de compilation sinon)
