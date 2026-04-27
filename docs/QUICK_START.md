# Quick Start Documentation

Parcours court pour comprendre rapidement où agir dans le dépôt sans repartir dans une exploration large.

## Objectif

En moins de 10 minutes, identifier :

- où entre l'application
- où sont déclarées les routes
- où sont déclarés les providers et use cases globaux
- où est définie la base locale
- quelle feature porte le comportement à modifier

## Parcours recommandé

### 1. Comprendre le shell de l'application

Lire dans cet ordre :

1. `lib/main.dart`
2. `lib/app.dart`
3. `lib/core/router.dart`

Ce que vous cherchez :

- la route initiale `/cellar`
- les routes shell : `/chat`, `/cellars`, `/statistics`, `/settings`, `/developer`
- les routes hors shell : `/manual`
- les sous-routes de réglages et de réévaluation développeur

### 2. Comprendre l'injection et l'état transverse

Lire `lib/core/providers.dart`.

Repères utiles :

- `databaseProvider` pour l'instance Drift
- repositories globaux et use cases globaux
- préférences d'affichage : layout de liste, ratios de split, thème visuel
- configuration IA : fournisseur, modèles, overrides vision, OCR
- `developerModeProvider`
- `deleteAllWinesUseCaseProvider`

### 3. Comprendre la persistance

Lire `lib/database/app_database.dart`.

Repères utiles :

- tables Drift enregistrées
- DAOs enregistrés
- stratégie de migration
- seed des catégories alimentaires

### 4. Aller directement à la bonne feature

| Si vous changez... | Lire d'abord |
| --- | --- |
| Liste, détail, ajout, édition de vin | [features/wine_cellar.md](features/wine_cellar.md) |
| Analyse IA, OCR, chat | [features/ai_assistant.md](features/ai_assistant.md) |
| Graphiques et agrégations | [features/statistics.md](features/statistics.md) |
| Préférences, affichage, paramètres IA | [features/settings.md](features/settings.md) |
| Outils réservés aux devs | [features/developer.md](features/developer.md) |
| Manuel utilisateur embarqué | [features/user_manual.md](features/user_manual.md) |

## Raccourcis utiles

| Sujet | Point d'entrée |
| --- | --- |
| Navigation | [technical/routing.md](technical/routing.md) |
| Providers globaux | [technical/providers.md](technical/providers.md) |
| Base de données | [technical/database.md](technical/database.md) |
| Vue d'ensemble | [ARCHITECTURE.md](ARCHITECTURE.md) |

## Avant de modifier le code

Vérifier systématiquement si le changement impacte aussi :

- une route dans `lib/core/router.dart`
- un provider ou use case global dans `lib/core/providers.dart`
- une table ou migration dans `lib/database/app_database.dart`
- la documentation de feature correspondante dans `docs/features/`

## Principe de maintenance

Le but de cette documentation est d'éviter les grandes phases de re-cartographie du dépôt.
Si un changement vous oblige à refaire une exploration large, il manque probablement soit un index, soit une doc feature, soit un diagramme à compléter.