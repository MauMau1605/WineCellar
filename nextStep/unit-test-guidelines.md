# Règles pour des tests unitaires efficaces

Ce guide est orienté dépôt Wine Cellar.
Le but n'est pas de couvrir toutes les lignes, mais de sécuriser les comportements qui risquent de casser pendant les refactors incrémentaux.

## Objectif

Écrire des tests unitaires fonctionnels qui :

- protègent les règles métier
- détectent rapidement les régressions de comportement
- restent stables pendant les refactors de structure
- évitent les tests trop couplés aux détails d'implémentation

## Principe directeur

Tester ce que le composant garantit, pas la façon exacte dont il est écrit.

Exemples :

- un use case retourne `Right` ou `Left` avec le bon `Failure`
- un repository calcule ou transforme correctement les données attendues
- un notifier change d'état dans le bon ordre
- un helper produit le bon message, mapping ou résultat métier

Ne pas centrer les tests sur :

- le nom exact de variables locales
- des détails de rendu non essentiels
- la structure interne d'une méthode si le contrat externe ne change pas

## Ce qui marche déjà dans le dépôt

Patterns déjà présents et à réutiliser :

- `mocktail` pour mocker les repositories ou services
- tests simples de use cases, par exemple `delete_all_wines_test.dart`
- tests de repository avec données contrôlées, par exemple `statistics_repository_impl_test.dart`
- tests de migration Drift avec vraie base de test, par exemple `app_database_migration_test.dart`
- tests de logique pure sur providers/notifiers, par exemple `bottle_move_state_provider_test.dart`
- tests ciblés sur builders de prompts et transformations textuelles

## Priorité de test avant refactor

### 1. Use cases et logique métier pure

À privilégier en premier, car :

- ils sont rapides
- ils sont peu fragiles
- ils donnent un bon signal de régression

Tester notamment :

- chemins succès
- chemins erreur
- validations d'entrée
- mapping des exceptions vers `Failure`
- cas limites significatifs

### 2. Repositories avec logique de transformation

À viser quand un repository ne fait pas qu'un simple forwarding.

Tester notamment :

- transformation des données lues
- agrégations et regroupements
- sérialisation / désérialisation
- comportement sur valeurs nulles ou partielles

### 3. Notifiers et providers locaux avec état

Très utiles avant refactor de gros écrans.

Tester notamment :

- état initial
- séquences d'actions
- transitions intermédiaires importantes
- remise à zéro et cas d'erreur

### 4. Helpers purs extraits des gros écrans

Quand une logique de gros écran est isolée dans un helper ou une classe dédiée, lui donner un test unitaire immédiatement.

## Ce qu'il faut tester dans ce dépôt en priorité

### `chat_screen.dart`

Ne pas commencer par un gros widget test de bout en bout.
Extraire et tester d'abord :

- composition des messages IA selon le mode
- décisions de stratégie web search
- mapping réponse IA → ajout / correction / preview
- logique de récupération JSON manquant

### `wine_list_screen.dart`

Tester d'abord :

- logique de mapping et enrichissement CSV
- choix d'import direct vs IA
- réévaluation unitaire d'un vin CSV
- règles de sélection ou de filtrage si extraites

### `virtual_cellar_detail_screen.dart`

Tester d'abord les morceaux extractibles :

- logique de filtre par maturité
- règles de placement / déplacement / undo si extraites
- comportements de sélection et mode mouvement hors UI brute

### `wine_repository_impl.dart`

Tester prioritairement :

- import/export JSON
- parsing CSV
- cas limites sur données partielles ou invalides
- mapping entité / persistance sur scénarios critiques

### `ai_settings_screen.dart`

Avant tout widget test lourd, isoler si possible et tester :

- lecture / écriture des valeurs de configuration
- normalisation des champs
- conditions d'activation de certaines actions

## Format recommandé d'un bon test unitaire

Structure simple :

1. préparer les données et mocks
2. exécuter une seule action claire
3. vérifier le résultat observable
4. vérifier les interactions uniquement si elles font partie du contrat

Un bon test doit répondre à une seule question métier explicite.

Exemple de formulation :

- retourne `CacheFailure` si la suppression échoue
- calcule les pourcentages correctement
- active le drag mode seulement si une sélection existe

## Règles pratiques

### Tester les chemins d'erreur autant que les chemins succès

Dans ce projet, beaucoup de logique passe par `Either<Failure, T>`.
Un test n'est pas complet s'il ne couvre que le `Right` quand un `Left` métier est plausible.

### Préférer les jeux de données petits mais parlants

Éviter les fixtures énormes.
Deux ou trois objets bien choisis valent mieux qu'un gros jeu opaque.

### Vérifier les invariants métier

Exemples :

- un champ obligatoire ne doit pas être vide
- un batch vide ne doit pas produire de travail inutile
- une quantité ou un état impossible doit être rejeté ou normalisé

### Geler les cas limites historiques

Quand un bug a déjà existé ou quand une migration historique existe, écrire un test qui reproduit explicitement ce cas.

### Éviter les asserts trop nombreux sans lien

Si un test vérifie cinq comportements distincts, il faut probablement le découper.
Exception : un même résultat agrégé cohérent, par exemple un objet de statistiques complet.

### Éviter les mocks inutiles

Si une logique pure peut être testée sans mock, faire sans mock.
Utiliser `mocktail` surtout pour les dépendances externes ou les contrats abstraits.

### Tester les builders purs

Dans ce dépôt, les builders de prompts et les stratégies textuelles sont des bons candidats :

- rapides
- déterministes
- utiles pour protéger l'orchestration IA

## Quand utiliser autre chose qu'un test unitaire

Utiliser un widget test seulement si :

- le comportement dépend vraiment du cycle Flutter
- l'interaction UI elle-même est le contrat à protéger

Utiliser un test base réelle seulement si :

- la migration ou le comportement SQL doit être prouvé
- un mock masquerait le comportement qu'on veut vraiment verrouiller

## Anti-patterns à éviter

- tester un écran géant en entier avant d'avoir isolé sa logique
- tester uniquement que des mocks ont été appelés sans vérifier le résultat fonctionnel
- écrire des tests dépendants d'un wording UI non essentiel
- figer des détails internes qui vont bouger pendant le refactor
- viser la couverture pour la couverture

## Définition de fini pour une tranche de tests

Une tranche de sécurisation est suffisante quand :

- les règles métier critiques de la zone sont couvertes
- les erreurs attendues sont testées
- les principaux chemins de transformation sont protégés
- les futurs refactors pourront déplacer le code sans casser le contrat observable

## Boucle de travail recommandée

1. choisir une zone de refactor future
2. lister les comportements à figer
3. écrire ou compléter les tests unitaires ciblés
4. vérifier qu'ils échoueraient si le comportement changeait vraiment
5. refactorer par petites tranches
6. relancer les tests après chaque tranche

## Commandes utiles

```bash
flutter test
flutter test test/features/wine_cellar/domain/usecases/delete_all_wines_test.dart
flutter test test/features/statistics/data/repositories/statistics_repository_impl_test.dart
flutter analyze
```

## Résultat recherché

Utiliser les tests comme garde-fous de comportement, pas comme mesure cosmétique.
Si un refactor important devient stressant à lancer, c'est que la tranche de tests préalable n'est probablement pas encore suffisante.