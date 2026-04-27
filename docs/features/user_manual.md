# Feature — User Manual

Feature de présentation qui embarque le manuel utilisateur directement dans l'application.

## Entrée principale

| Sujet | Point d'entrée |
| --- | --- |
| Manuel utilisateur | `/manual` |

## Responsabilités

- afficher un guide utilisateur multi-sections dans l'application
- ouvrir une section précise via un paramètre de requête
- documenter les usages visibles des fonctionnalités majeures

## Structure réelle

La feature est aujourd'hui centrée sur un seul écran :

- `lib/features/user_manual/presentation/screens/user_manual_screen.dart`

## Sections disponibles

Les sections sont définies par l'enum `UserManualSection` :

| Query string `section` | Onglet |
| --- | --- |
| `overview` | Vue generale |
| `imports-exports` | Imports / Exports |
| `csv-import` | Import CSV detaille |
| `ai-import` | Import par IA |
| `food-pairing` | Accords mets-vins |
| `virtual-cellar` | Cave virtuelle |
| `ai-tokens` | Tokens et connexion IA |
| `troubleshooting` | Bonnes pratiques |

## Comportement

- la route `/manual` est hors du `ShellRoute`
- la section initiale est dérivée de `state.uri.queryParameters['section']`
- l'écran repose sur un `DefaultTabController` avec onglets scrollables

## Quand mettre à jour cette feature

Mettre à jour le manuel intégré quand un changement modifie le comportement visible par l'utilisateur, par exemple :

- import/export
- analyse IA
- cave virtuelle
- parcours de réglages utiles à l'utilisateur final

Une documentation purement interne dans `docs/` n'impose pas, à elle seule, une mise à jour de ce manuel embarqué.

## À lire ensuite

- [../ARCHITECTURE.md](../ARCHITECTURE.md)
- [wine_cellar.md](wine_cellar.md)
- [ai_assistant.md](ai_assistant.md)