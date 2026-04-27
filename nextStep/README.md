# Next Step

Ce dossier sert de point d'entrée pour reprendre le travail plus tard sans devoir re-cartographier le dépôt.

## Fichiers

- [refactor-backlog.md](refactor-backlog.md) : chantiers à mener après la phase de sécurisation par tests.
- [unit-test-guidelines.md](unit-test-guidelines.md) : règles pratiques pour écrire des tests unitaires efficaces dans ce dépôt.

## Ordre recommandé

1. Augmenter la couverture de tests unitaires fonctionnels sur les zones qui vont être refactorées.
2. Stabiliser les scénarios métier critiques avec ces tests.
3. Refactorer ensuite par petites tranches, avec validation après chaque tranche.

## Prompt de reprise suggéré

Tu peux me redonner plus tard un prompt de ce type :

```text
Utilise nextStep/refactor-backlog.md et nextStep/unit-test-guidelines.md comme source de vérité.
Commence par la prochaine tranche prioritaire, sans refactor large d'un coup.
Ajoute ou mets à jour les tests unitaires nécessaires avant les extractions de code.
Valide après chaque tranche.
```

## Intention

Le but n'est pas de viser une couverture maximale abstraite, mais de sécuriser les comportements métier et l'orchestration critique avant les refactors lourds.