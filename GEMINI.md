# Gemini CLI — Configuration Wine Cellar

Ce projet utilise une structure d'agents et d'instructions partagée.

## Source de Vérité Principale
Toutes les directives architecturales, de nommage et de workflow se trouvent dans :
👉 **[AGENTS.md](./AGENTS.md)**

## Instructions Modulaires
Pour des tâches spécifiques, se référer aux instructions dans `.github/instructions/` :
- [Clean Architecture](./.github/instructions/clean-architecture.instructions.md)
- [Drift Database](./.github/instructions/drift-database.instructions.md)
- [Localisation (l10n)](./.github/instructions/l10n.instructions.md)
- [Testing](./.github/instructions/testing.instructions.md)

## Agents Spécialisés (Invocation via `invoke_agent`)
Pour déléguer des tâches complexes, utiliser les agents définis dans `.github/agents/`. Lors de l'invocation d'un sous-agent (ex: `generalist`), lui passer le contenu du fichier `.agent.md` correspondant comme instruction de départ.

| Rôle | Fichier Agent |
|------|---------------|
| Tests Dart/Flutter | [.github/agents/dart-tester.agent.md](./.github/agents/dart-tester.agent.md) |
| Documentation | [.github/agents/doc-writer.agent.md](./.github/agents/doc-writer.agent.md) |
| Planning de Feature | [.github/agents/feature-planner.agent.md](./.github/agents/feature-planner.agent.md) |
| Développement Flutter | [.github/agents/flutter-coder.agent.md](./.github/agents/flutter-coder.agent.md) |
| Audit de Sécurité | [.github/agents/security-auditor.agent.md](./.github/agents/security-auditor.agent.md) |

## Workflows Gemini CLI
1. **Initialisation** : Lire `AGENTS.md` au début de chaque session complexe.
2. **Développement** : Suivre le workflow "Nouvelle fonctionnalité" décrit dans `AGENTS.md`.
3. **Validation** : Toujours exécuter `flutter analyze` et `flutter test` avant de considérer une tâche comme terminée.
