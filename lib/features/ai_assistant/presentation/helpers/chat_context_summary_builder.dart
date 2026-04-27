import 'package:wine_cellar/features/ai_assistant/domain/entities/wine_ai_response.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/wine_entity.dart';

class ChatContextSummaryBuilder {
  ChatContextSummaryBuilder._();

  static String buildCellarSummary(List<WineEntity> wines) {
    final available = wines.where((wine) => wine.quantity > 0).toList();
    if (available.isEmpty) {
      return '(Cave vide — aucune bouteille disponible)';
    }

    available.sort((a, b) {
      final aYear = a.drinkUntilYear ?? 9999;
      final bYear = b.drinkUntilYear ?? 9999;
      return aYear.compareTo(bYear);
    });

    final currentYear = DateTime.now().year;
    final buffer = StringBuffer();
    buffer.writeln(
      '${available.length} vin(s) disponible(s) (année actuelle : $currentYear) :',
    );
    buffer.writeln();

    for (final wine in available) {
      buffer.write('• ${wine.displayName}');
      buffer.write(' | ${wine.color.emoji} ${wine.color.label}');
      if (wine.appellation != null) buffer.write(' | ${wine.appellation}');
      if (wine.region != null) buffer.write(', ${wine.region}');
      buffer.writeln();
      if (wine.grapeVarieties.isNotEmpty) {
        buffer.writeln('  Cépages : ${wine.grapeVarieties.join(", ")}');
      }
      buffer.write('  Quantité : ${wine.quantity}');
      if (wine.drinkFromYear != null || wine.drinkUntilYear != null) {
        buffer.write(
          ' | À boire : ${wine.drinkFromYear ?? "?"} → ${wine.drinkUntilYear ?? "?"}',
        );
      }
      buffer.writeln();
      if (wine.tastingNotes != null && wine.tastingNotes!.isNotEmpty) {
        buffer.writeln('  Notes : ${wine.tastingNotes}');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  static String buildCurrentWineSummaryForRefinement(
    List<WineAiResponse> currentWineDataList,
  ) {
    if (currentWineDataList.isEmpty) {
      return 'Aucune fiche active.';
    }

    final first = currentWineDataList.first;
    final parts = <String>[];
    if ((first.name ?? '').trim().isNotEmpty) {
      parts.add('Nom: ${first.name}');
    }
    if (first.vintage != null) {
      parts.add('Millésime: ${first.vintage}');
    }
    if ((first.appellation ?? '').trim().isNotEmpty) {
      parts.add('Appellation: ${first.appellation}');
    }
    if ((first.producer ?? '').trim().isNotEmpty) {
      parts.add('Producteur: ${first.producer}');
    }

    if (parts.isEmpty) {
      return 'Une fiche vin est en cours mais encore incomplète.';
    }

    return parts.join(' | ');
  }
}