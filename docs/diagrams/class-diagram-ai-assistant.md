# Diagramme de classes — AI Assistant

Diagramme focalisé sur les abstractions et objets d'échange de la feature `ai_assistant`.

```mermaid
classDiagram
    class AiService {
        <<interface>>
        +analyzeWine(...)
        +analyzeWineFromImage(...)
        +testConnection()
        +discoverVisionModel()
        +supportsWebSearch
        +resetChat()
        +analyzeWineWithWebSearch(...)
    }

    class ImageTextExtractor {
        <<interface>>
        +extractTextFromImage(imagePath)
    }

    class AiChatResult {
        +String textResponse
        +List~WineAiResponse~ wineDataList
        +bool isError
        +String? errorMessage
        +List~WebSource~ webSources
    }

    class WebSource {
        +String uri
        +String title
    }

    class WineAiResponse {
        +String? name
        +String? color
        +int? vintage
        +List~String~ grapeVarieties
        +List~String~ suggestedFoodPairings
        +List~String~ estimatedFields
        +bool needsMoreInfo
        +bool isComplete
        +List~String~ missingRequiredFields
        +mergeWith(other)
        +toJson()
    }

    class ChatMessage {
        +String id
        +String content
        +ChatRole role
        +DateTime timestamp
        +WinePreviewData? winePreview
        +List~ChatSource~ webSources
    }

    class WinePreviewData {
        +Map~String,dynamic~ fields
        +bool isComplete
    }

    class AnalyzeWineUseCase
    class AnalyzeWineFromImageUseCase
    class ExtractTextFromWineImageUseCase
    class TestAiConnectionUseCase
    class OpenAiService
    class GeminiService
    class MistralService
    class OllamaService
    class MlKitImageTextExtractor

    OpenAiService ..|> AiService
    GeminiService ..|> AiService
    MistralService ..|> AiService
    OllamaService ..|> AiService
    MlKitImageTextExtractor ..|> ImageTextExtractor

    AnalyzeWineUseCase --> AiService
    AnalyzeWineFromImageUseCase --> AiService
    ExtractTextFromWineImageUseCase --> ImageTextExtractor
    TestAiConnectionUseCase --> AiService

    AiService --> AiChatResult
    AiChatResult --> WineAiResponse
    AiChatResult --> WebSource
    ChatMessage --> WinePreviewData
```

Ce diagramme reflète les abstractions centrales. L'orchestration concrète par fournisseur et overrides vision est documentée dans [../features/ai_assistant.md](../features/ai_assistant.md) et [../technical/providers.md](../technical/providers.md).