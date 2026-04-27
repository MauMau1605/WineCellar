# Documentation — Wine Cellar

Index central de la documentation technique du projet.

## Commencer

- [QUICK_START.md](QUICK_START.md) : parcours de lecture rapide pour comprendre le dépôt en quelques minutes.
- [ARCHITECTURE.md](ARCHITECTURE.md) : vue d'ensemble fiable et orientée navigation.

## Documentation par feature

- [features/wine_cellar.md](features/wine_cellar.md) : feature métier principale, vins et caves virtuelles.
- [features/ai_assistant.md](features/ai_assistant.md) : assistant IA, OCR, fournisseurs externes.
- [features/statistics.md](features/statistics.md) : calcul et rendu des statistiques.
- [features/settings.md](features/settings.md) : réglages généraux, affichage et IA.
- [features/user_manual.md](features/user_manual.md) : manuel utilisateur intégré à l'application.
- [features/developer.md](features/developer.md) : outils internes de réévaluation et de purge.

## Documentation transverse

- [technical/providers.md](technical/providers.md) : providers globaux, DI et préférences persistées.
- [technical/routing.md](technical/routing.md) : arbre GoRouter et conventions de navigation.
- [technical/database.md](technical/database.md) : Drift, tables, DAOs et migrations.

## Diagrammes

- [diagrams/architecture-globale.md](diagrams/architecture-globale.md) : vue système Mermaid.
- [diagrams/dependency-flow-clean-architecture.md](diagrams/dependency-flow-clean-architecture.md) : flux des dépendances.
- [diagrams/class-diagram-wine-cellar.md](diagrams/class-diagram-wine-cellar.md) : diagramme de classes métier principal.
- [diagrams/class-diagram-ai-assistant.md](diagrams/class-diagram-ai-assistant.md) : diagramme de classes IA.

## Sources de vérité à consulter avant toute mise à jour documentaire

- `lib/core/router.dart`
- `lib/core/providers.dart`
- `lib/database/app_database.dart`
- `lib/features/statistics/presentation/providers/statistics_providers.dart`
- `lib/features/developer/presentation/screens/developer_screen.dart`

## Quand mettre à jour cette documentation

Mettre à jour la doc quand un changement touche :

- les routes ou la structure du shell
- les providers globaux ou un use case transverse
- le schéma Drift ou les migrations
- le périmètre ou les points d'entrée d'une feature