# Diagramme de classes — Wine Cellar

Diagramme focalisé sur les abstractions métier principales de la feature `wine_cellar`.

```mermaid
classDiagram
    class WineEntity {
        +int? id
        +String name
        +String country
        +WineColor color
        +int quantity
        +int? cellarId
        +double? cellarPositionX
        +double? cellarPositionY
        +List~int~ foodCategoryIds
        +WineMaturity maturity
        +String displayName
        +copyWith()
        +toJson()
    }

    class VirtualCellarEntity {
        +int? id
        +String name
        +int rows
        +int columns
        +Set~CellarCellPosition~ emptyCells
        +VirtualCellarTheme theme
        +int totalCells
        +int totalSlots
        +isCellEmpty()
        +copyWith()
    }

    class BottlePlacementEntity {
        +int id
        +int wineId
        +int cellarId
        +int positionX
        +int positionY
        +DateTime createdAt
        +WineEntity wine
    }

    class WineRepository {
        <<interface>>
        +watchAllWines()
        +watchFilteredWines(filter)
        +getWineById(id)
        +addWine(wine)
        +updateWine(wine)
        +deleteWine(id)
        +deleteAllWines()
        +importFromCsv(...)
        +exportToJson()
    }

    class VirtualCellarRepository {
        <<interface>>
        +watchAll()
        +getAll()
        +create(cellar)
        +update(cellar)
        +delete(id)
        +watchPlacementsByCellarId(id)
        +placeWine(...)
        +moveBottleInCellar(...)
    }

    class WineRepositoryImpl
    class VirtualCellarRepositoryImpl
    class AddWineUseCase
    class DeleteAllWinesUseCase
    class GetAllVirtualCellarsUseCase
    class PlaceWineInCellarUseCase

    WineRepositoryImpl ..|> WineRepository
    VirtualCellarRepositoryImpl ..|> VirtualCellarRepository

    AddWineUseCase --> WineRepository
    DeleteAllWinesUseCase --> WineRepository
    GetAllVirtualCellarsUseCase --> VirtualCellarRepository
    PlaceWineInCellarUseCase --> VirtualCellarRepository

    VirtualCellarRepository --> VirtualCellarEntity
    VirtualCellarRepository --> BottlePlacementEntity
    VirtualCellarRepository --> WineEntity
    BottlePlacementEntity --> WineEntity
    WineEntity ..> VirtualCellarEntity : cellarId reference
```

Note : le domaine contient encore des champs de placement hérités dans `WineEntity` en parallèle de `BottlePlacementEntity`, car la base gère une migration historique vers le modèle par placement physique.