---
description: "Plan a new Flutter feature following Clean Architecture patterns for Wine Cellar"
name: "Create Feature"
argument-hint: "Feature name and brief description (e.g., 'Wine inventory search with filters')"
agent: "agent"
---

# Création d'une nouvelle fonctionnalité Wine Cellar

## 1. Questions essentielles

Avant de proposer une implémentation, je dois clarifier:

### Scope & Domaine
- Quelle est exactement la fonctionnalité? (description détaillée)
- Fait-elle partie d'une feature existante ou est-ce nouvelle?
- Quels **use cases** (actions utilisateur) doivent être supportées?

### Stockage & Données
- Nécessite-t-elle des données persistantes (base de données)?
- Interagit-elle avec des données existantes (`Wines`, `VirtualCellars`, etc.)?
- Y a-t-il validation ou contraintes métier?
- Comment les données fluent-elles: locale ↔ API ↔ cache?

### UI & Navigation
- Quel écran/widget est nécessaire?
- S'intègre-t-elle dans une navigation existante ou crée-t-elle une nouvelle route?
- Quelles interactions utilisateur (forms, listes, modales, etc.)?
- Y a-t-il des états d'erreur ou chargement à gérer?

### IA Assistant
- Interagit-elle avec l'assistant IA intégré?
- Faut-il envoyer du contexte à l'API IA?
- Comment structurer la requête/réponse?

### Intégrations transversales
- Besoin de localisation (FR/EN)?
- Gestion des erreurs spécifiques?
- Configuration (clés API, paramètres)?
- Tests: unitaires, widgets, intégration?

---

## 2. Pattern Clean Architecture suggéré

Pour chaque fonctionnalité, proposer systématiquement :

```
lib/features/<feature>/
  domain/
    entities/          # Modèles métier immutables
    repositories/      # Interfaces abstraites
    usecases/          # Use cases (call pattern)
  data/
    datasources/       # Sources locales/distantes
    models/            # DTOs & serialisation
    repositories/      # Implémentations
  presentation/
    screens/           # Pages
    widgets/           # Composants réutilisables
    providers/         # Riverpod StateNotifierProvider
```

- **Dépendances**: `Presentation → Domain ← Data`
- **Use cases**: méthode `call()`, retorn `Either<Failure, T>`
- **Erreurs**: utiliser la hiérarchie `Failure` existante
- **Injection**: providers Riverpod, pas de `get_it`

---

## 3. Sous-fonctionnalités & cas d'usage courants à checker

Suggérer automatiquement (applicable?):

- **Validation métier**: les données entrantes sont-elles validées?
- **Cache**: faut-il mémoriser les résultats?
- **Pagination/Filtrage**: si liste, pagination ou chargement infini?
- **Gestion d'erreur**: timeouts, réessais, fallback?
- **Tests unitaires**: au moins les use cases
- **Documentation**: mise à jour de `docs/ARCHITECTURE.md` si pattern nouveau

---

## 4. Checklist de conformité

Au terme de l'implémentation, vérifier:

- [ ] Dossier créé: `lib/features/<feature>/`
- [ ] Séparation stricte: Domain ≠ Data ≠ Presentation
- [ ] Use cases retournent `Either<Failure, T>`
- [ ] Pas d'exceptions non gérées, pas de `dynamic`
- [ ] Entités immutables avec `copyWith`
- [ ] Providers Riverpod dans `lib/core/providers.dart` ou locaux?
- [ ] Tests unitaires pour logique métier
- [ ] Localisation ajoutée (FR/EN) si textes utilisateur
- [ ] Routes GoRouter mises à jour
- [ ] Base de données: migrations versionnées si tables Drift

---

## 5. Workflow proposé

1. **Clarification** : je pose les questions section 2
2. **Sketch**: je propose étapes + fichiers à créer
3. **Implémentation**: je crée entities → repositories → use cases → data → présentation
4. **Validation**: générér `*.g.dart` si Drift, tester, mettre à jour docs

Prêt? Décris-moi ta fonctionnalité! 🍷
