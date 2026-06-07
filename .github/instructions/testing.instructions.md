---
description: "Use when writing unit or widget tests — mocktail patterns, behavior-focused test structure, file mirroring convention, test priority order for Wine Cellar"
applyTo: "test/**/*.dart"
---

# Tests unitaires — Wine Cellar

## Principe directeur

Tester **ce que le composant garantit**, pas la façon exacte dont il est écrit.

## Ordre de priorité

1. **Use cases** — `call()`, vérifier `Right<T>` et `Left<Failure>`
2. **Repositories** — transformation DTO ↔ entité, gestion d'erreurs
3. **Providers / Notifiers** — transitions d'état (`AsyncData`, `AsyncError`, `AsyncLoading`)
4. **Helpers purs** — fonctions de mapping, calcul, parsing sans dépendances Flutter

Widget tests uniquement si le contrat dépend réellement du rendu Flutter.

## Conventions

- Framework : `flutter_test` + `mocktail` (pas `mockito`).
- Fichiers miroirs : `lib/features/x/y.dart` → `test/features/x/y_test.dart`.
- Noms de tests : décrire le comportement attendu.
  - ✓ `'returns Right(wine) when repository succeeds'`
  - ✗ `'calls repository.addWine once'`
- `setUp()` pour initialiser les mocks communs à un groupe.

## Structure type — use case

```dart
group('XxxUseCase', () {
  late MockXxxRepository mockRepository;
  late XxxUseCase useCase;

  setUp(() {
    mockRepository = MockXxxRepository();
    useCase = XxxUseCase(mockRepository);
  });

  test('returns Right(result) when repository succeeds', () async {
    when(() => mockRepository.doSomething())
        .thenAnswer((_) async => right(expected));
    final result = await useCase(params);
    expect(result, right(expected));
  });

  test('returns Left(CacheFailure) when repository fails', () async {
    when(() => mockRepository.doSomething())
        .thenAnswer((_) async => left(const CacheFailure()));
    final result = await useCase(params);
    expect(result, left(isA<CacheFailure>()));
  });
});
```

## Ce qu'il ne faut PAS tester

- Noms de variables locales ou ordre interne des instructions
- Wording UI non essentiel au comportement
- Vérification exclusive d'appels de mocks sans vérifier le résultat
- Comportements accidentels ou bugués (expliciter d'abord le comportement attendu)

## Si le code est difficile à tester

Signaler plutôt qu'écrire un test fragile :
- Logique enfouie dans un gros screen → extraire un use case ou helper
- Trop de mocks → vérifier si le couplage peut être réduit
- Mélange logique + rendu → isoler la partie décisionnelle
