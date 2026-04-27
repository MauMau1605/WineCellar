---
description: "Plan and write behavior-focused unit tests for Wine Cellar"
name: "Unit Test"
argument-hint: "Zone a tester + comportement a securiser (ex: 'wine_repository_impl import JSON avec donnees invalides')"
agent: "agent"
---

# Creation ou extension de tests unitaires Wine Cellar

## 1. Objectif

Le but est d'ajouter des tests unitaires utiles, rapides et stables qui :

- protegent les comportements metier critiques
- detectent les regressions de fonctionnement
- donnent de la confiance avant un refactor incremental
- evitent les tests trop couples aux details d'implementation

Les tests doivent servir a trouver des problemes de fonctionnement reel.
Ils ne doivent pas valider un comportement uniquement parce qu'il existe deja aujourd'hui.
Si un comportement observe semble incorrect, ambigu ou accidentel, il faut d'abord expliciter le comportement attendu au lieu de figer le bug potentiel dans un test.

## 2. Questions a clarifier avant d'ecrire les tests

Avant de proposer ou d'implementer les tests, clarifier :

- quelle zone exacte doit etre securisee
- quel contrat observable doit etre garanti
- quels chemins succes, erreur et cas limites sont importants
- si le besoin vient d'un bug, d'un refactor ou d'une nouvelle logique
- s'il existe deja des tests voisins a etendre plutot que repartir de zero

## 3. Principe directeur

Tester ce que le composant garantit, pas la facon exacte dont il est ecrit.

Exemples de bons contrats a tester :

- un use case retourne le bon Right ou le bon Left
- un repository transforme correctement les donnees
- un notifier passe par les bons etats observables
- un helper pur produit le bon mapping ou la bonne decision

Exemples de mauvais ancrages :

- noms de variables locales
- ordre interne d'instructions sans impact observable
- wording UI non essentiel
- verification exclusive d'appels de mocks sans verifier le resultat fonctionnel

## 4. Si le code est difficile a tester

Si une zone est difficile a tester proprement, il faut se demander si le code doit d'abord etre refactorise.

En pratique :

- si la logique est enfouie dans un gros ecran, extraire un helper, un use case local ou une logique pure
- si un composant melange trop d'orchestration et de rendu, isoler d'abord la partie decisionnelle
- si un test necessite trop de mocks, verifier si une extraction reduirait le couplage

Ne pas compenser un design difficile par des tests fragiles.
Un petit refactor cible pour rendre le comportement testable est souvent preferable a un mauvais test.

## 5. Priorite recommandee dans ce depot

Ordre par defaut :

1. use cases et logique metier pure
2. repositories avec logique de transformation
3. notifiers et providers a etat
4. helpers purs extraits des gros ecrans
5. widget tests minimaux seulement si le contrat depend vraiment de Flutter

Pour Wine Cellar, commencer de preference par :

- logique IA deterministe et builders purs
- parsing, import/export et mappings de repository
- transitions d'etat des notifiers locaux
- logique extractible depuis les gros ecrans avant tout test de bout en bout

## 6. Regles pratiques de redaction

- un test doit repondre a une seule question metier claire
- couvrir les chemins d'erreur autant que les chemins succes
- preferer de petits jeux de donnees lisibles
- verifier les invariants metier importants
- reutiliser les patterns existants du depot avant d'inventer une nouvelle approche
- utiliser mocktail surtout pour les dependances externes ou abstraites
- eviter les mocks si une logique pure peut etre testee directement

Dans ce depot, faire particulierement attention a :

- Either Failure ou succes pour les use cases
- mapping des exceptions vers Failure
- comportements sur donnees partielles, invalides ou manquantes
- cas historiques qui ont deja casse pendant un refactor ou une migration

## 7. Anti-patterns a eviter

- viser la couverture pour la couverture
- tester un ecran geant en entier avant d'avoir isole sa logique
- figer des details internes qui vont bouger pendant le refactor
- ecrire un test qui enterine un comportement possiblement faux juste parce qu'il est present aujourd'hui
- transformer un bug courant en specification sans verifier le comportement attendu

Si le comportement actuel semble incoherent, il faut le signaler explicitement et ecrire le test autour du comportement attendu, pas autour de l'anomalie actuelle.

## 8. Workflow attendu

1. Identifier le composant exact a securiser.
2. Lire les tests voisins et l'implementation locale.
3. Formuler les contrats observables a figer.
4. Choisir le niveau de test le plus simple qui protege le comportement.
5. Si necessaire, proposer ou effectuer une extraction minimale pour rendre la logique testable.
6. Ecrire les tests de facon ciblee.
7. Lancer une validation et corriger localement si besoin.

## 9. Format de sortie attendu

Quand tu utilises ce prompt, produire :

- la zone cible et le contrat retenu
- les cas de test proposes, titres de tests compris
- la decision sur le niveau de test choisi
- un signal clair si un refactor minimal est recommande avant de tester
- les fichiers a creer ou modifier
- la commande de validation ciblee a executer

## 10. Definition de fini

Une tranche de tests est suffisante quand :

- les regles metier critiques de la zone sont couvertes
- les erreurs attendues sont testees
- les principaux chemins de transformation sont proteges
- le contrat observable est securise sans figer des details internes
- les tests aident a detecter un dysfonctionnement, pas a normaliser un bug existant

Tu peux maintenant me donner une zone precise a tester et le comportement a securiser.