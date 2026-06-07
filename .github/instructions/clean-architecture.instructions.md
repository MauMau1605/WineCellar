---
description: "Use when writing Dart/Flutter code in lib/ — Clean Architecture layer rules, dependency direction, use case patterns, Riverpod providers, entity design, file size thresholds"
applyTo: "lib/**/*.dart"
---

# Clean Architecture — Wine Cellar

## Règle de dépendance

`Presentation → Domain ← Data`

- **Domain** (`entities/`, `repositories/` abstraits, `usecases/`) : zéro import de `data/` ou `presentation/`.
- **Data** (`datasources/`, `repositories/` impls) : dépend uniquement du domain.
- **Presentation** (`screens/`, `widgets/`, `providers/`) : dépend uniquement du domain.

## Use cases

- Une méthode `call()`, une seule responsabilité.
- Retournent `Either<Failure, T>` (fpdart). Pas de `throw`, pas de `try/catch` non géré.
- Injectés via providers Riverpod.

## Entités

- Immutables avec `copyWith`.
- Pas de `dynamic`.
- Aucun import `flutter/material.dart` dans le domain.

## Erreurs

Utiliser la hiérarchie `Failure` existante dans `lib/core/` :
- `ServerFailure` — erreurs réseau/API
- `CacheFailure` — erreurs base de données locale
- `AiFailure` — erreurs spécifiques aux LLMs
- `ValidationFailure` — erreurs de validation métier
- `ConfigurationFailure` — configuration manquante/invalide

## Providers Riverpod

- Déclarés dans `lib/core/providers.dart` pour les providers globaux.
- Providers locaux à une feature dans `lib/features/<feature>/presentation/providers/`.
- Ne pas introduire `get_it` ou `injectable`.

## Seuils de taille (hors `*.g.dart`)

| Fichier | Seuil |
|---------|-------|
| Screen | < 400 lignes — extraire widgets si dépassé |
| Provider / Notifier | < 250 lignes |
| Widget | < 200 lignes |
| Use case | < 120 lignes |
| Repository impl | < 300 lignes |

> Au-delà : signaler, proposer un découpage ciblé, ne pas ajouter de responsabilité sans refactor.
