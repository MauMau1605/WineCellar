---
description: "Use when modifying Drift tables, DAOs, or migrations — schema versioning, code generation commands, naming conventions, migration patterns, query safety"
applyTo: "lib/database/**"
---

# Drift Database — Wine Cellar

## Schéma actuel

Version : **v6**. Tables existantes :
- `Wines` — bouteilles dans la cave
- `VirtualCellars` — caves virtuelles
- `BottlePlacements` — positions des bouteilles dans les caves
- `FoodCategories` — catégories d'accords mets-vins
- `WineFoodPairings` — relations vin ↔ catégorie alimentaire

Documentation complète : [docs/technical/database.md](../../docs/technical/database.md)

## Règles obligatoires

- **Jamais modifier** les fichiers `*.g.dart` manuellement.
- Après toute modification de table ou DAO, régénérer :
  ```bash
  dart run build_runner build --delete-conflicting-outputs
  ```
- Toute nouvelle table ou colonne **incrémente la version** du schéma.
- Les migrations sont **non-destructives** (pas de `DROP COLUMN` sans migration de données).

## Conventions de nommage

| Élément | Convention | Exemple |
|---------|-----------|---------|
| Table | Pluriel PascalCase | `Wines`, `FoodCategories` |
| DAO | `XxxDao` | `WineDao` |
| Colonne | camelCase en Dart | `bottleCount` |

## Sécurité des requêtes

- Utiliser les paramètres typés Drift (expressions et variables bindées).
- **Jamais** de concaténation de chaînes pour construire du SQL dynamique.
- Les `WHERE` complexes passent par des expressions Drift typées, pas par `customStatement`.

## Migration — patron

```dart
MigrationStrategy get migration => MigrationStrategy(
  onUpgrade: (m, from, to) async {
    if (from < 7) {
      await m.addColumn(wines, wines.newColumn);
    }
    // ...
  },
);
```

Mettre à jour `docs/technical/database.md` après toute migration.
