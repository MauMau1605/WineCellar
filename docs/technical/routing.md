# Routing

La navigation applicative est centralisée dans `lib/core/router.dart` et repose sur GoRouter.

## Structure générale

Le router déclare :

- un `ShellRoute` principal rendu par `ShellScaffold`
- des routes métier intégrées au shell
- une route `/manual` hors shell

## Arbre réel des routes

```mermaid
flowchart TD
    Root[/appRouter/] --> Shell[ShellRoute -> ShellScaffold]
    Root --> Manual[/manual]

    Shell --> Cellar[/cellar]
    Cellar --> CellarAdd[/cellar/add]
    Cellar --> WineDetail[/cellar/wine/:id]
    WineDetail --> WineEdit[/cellar/wine/:id/edit]

    Shell --> Chat[/chat]
    Shell --> Cellars[/cellars]
    Cellars --> CellarDetail[/cellars/:id]

    Shell --> Statistics[/statistics]

    Shell --> Settings[/settings]
    Settings --> SettingsAi[/settings/ai]
    Settings --> SettingsDisplay[/settings/display]

    Shell --> Developer[/developer]
    Developer --> Reevaluate[/developer/reevaluate]
    Reevaluate --> Preview[/developer/reevaluate/preview]
```

## Table de référence

| Route | Type | Écran |
| --- | --- | --- |
| `/cellar` | shell | `WineListScreen` |
| `/cellar/add` | shell | `WineAddScreen` |
| `/cellar/wine/:id` | shell | `WineDetailScreen` |
| `/cellar/wine/:id/edit` | shell | `WineEditScreen` |
| `/chat` | shell | `ChatScreen` |
| `/cellars` | shell | `VirtualCellarListScreen` |
| `/cellars/:id` | shell | `VirtualCellarDetailScreen` |
| `/statistics` | shell | `StatisticsScreen` |
| `/settings` | shell | `SettingsScreen` |
| `/settings/ai` | shell | `AiSettingsScreen` |
| `/settings/display` | shell | `DisplaySettingsScreen` |
| `/developer` | shell | `DeveloperScreen` |
| `/developer/reevaluate` | shell | `WineReevaluationScreen` |
| `/developer/reevaluate/preview` | shell | `ReevaluationPreviewScreen` |
| `/manual` | hors shell | `UserManualScreen` |

## Paramètres et conventions

| Route | Paramètres |
| --- | --- |
| `/cellar/wine/:id` | `id` en path parameter |
| `/cellar/wine/:id/edit` | `id` en path parameter |
| `/cellars/:id` | `id` en path parameter ; `wineId` et `highlightWineId` en query string |
| `/manual` | `section` en query string |

## Points d'attention

- la route initiale est `/cellar`
- les écrans shell utilisent `NoTransitionPage`
- `/manual` est explicitement séparée du shell applicatif
- la feature développeur est routée explicitement dans le router actuel

## Règles de maintenance

- toute nouvelle route doit être ajoutée ici et dans [../ARCHITECTURE.md](../ARCHITECTURE.md) si elle change la vue d'ensemble
- si une route reflète une nouvelle feature, documenter aussi `docs/features/<feature>.md`