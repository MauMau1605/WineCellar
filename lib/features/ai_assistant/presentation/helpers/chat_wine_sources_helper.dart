import 'package:wine_cellar/features/ai_assistant/data/datasources/cellar_tracker_datasource.dart';
import 'package:wine_cellar/features/ai_assistant/data/datasources/vivino_datasource.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';

/// Helpers pour combiner les données Vivino + CellarTracker dans le chat.
class ChatWineSourcesHelper {
  ChatWineSourcesHelper._();

  static const int _divergenceThresholdYears = 3;
  static const int _minCommonWindowYears = 2;

  // ---------------------------------------------------------------------------
  // Formatage combiné
  // ---------------------------------------------------------------------------

  /// Construit le texte Markdown combiné Vivino + CellarTracker.
  ///
  /// Structure :
  /// 1. En-tête des notes moyennes (Vivino + CT si disponibles).
  /// 2. Bloc fenêtre de dégustation avec comparaison / avertissement.
  /// 3. Corps des avis Vivino.
  /// 4. Notes CellarTracker (dédupliquées).
  static String buildCombinedReviewMarkdown(
    VivinoSearchResult vivino,
    CellarTrackerResult ct,
  ) {
    final buf = StringBuffer();

    final vivinoFound = vivino.status == VivinoSourceStatus.found ||
        vivino.status == VivinoSourceStatus.foundNoReviews;
    final ctFound = ct.status == CellarTrackerSourceStatus.found;

    // --- En-tête des notes ---
    if (vivinoFound || ctFound) {
      buf.writeln('### 🍷 Notes moyennes');
      if (vivinoFound && vivino.ratingsAverage != null) {
        final avg = vivino.ratingsAverage!.toStringAsFixed(1);
        final countPart = vivino.ratingsCount != null
            ? ' (${VivinoDatasource.formatCount(vivino.ratingsCount!)} avis)'
            : '';
        buf.writeln('- **Vivino :** $avg / 5$countPart');
      }
      if (ctFound && ct.communityScore != null) {
        final score = ct.communityScore!.toStringAsFixed(0);
        final countPart = ct.communityCount != null
            ? ' (${ct.communityCount} avis)'
            : '';
        buf.writeln('- **CellarTracker :** $score / 100$countPart');
      }
      buf.writeln();
    }

    // --- Comparaison fenêtres de dégustation ---
    final windowBlock = buildDrinkingWindowBlock(vivino, ct);
    if (windowBlock.isNotEmpty) {
      buf.writeln(windowBlock);
    }

    // --- Corps Vivino ---
    if (vivinoFound) {
      final vivinoText = VivinoDatasource.formatAsMarkdown(vivino);
      buf.writeln(vivinoText);
    }

    // --- Notes CellarTracker ---
    if (ctFound) {
      final ctText = CellarTrackerDatasource.formatAsMarkdown(ct);
      // Évite de répéter l'en-tête de note déjà affiché.
      final ctBody =
          ctText.replaceAll(RegExp(r'^🏆.*$\n?', multiLine: true), '').trim();
      if (ctBody.isNotEmpty) {
        buf.writeln();
        buf.writeln(ctBody);
      }
    }

    return buf.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Comparaison fenêtres de dégustation
  // ---------------------------------------------------------------------------

  /// Construit le bloc Markdown décrivant la fenêtre de dégustation.
  ///
  /// - Si les deux sources ont une fenêtre et qu'elles divergent (> [_divergenceThresholdYears] ans) :
  ///   affiche un avertissement, et la fenêtre commune si elle est suffisante.
  /// - Si les deux sont cohérentes : affiche l'intersection.
  /// - Si une seule source a une fenêtre : l'affiche avec son label.
  static String buildDrinkingWindowBlock(
    VivinoSearchResult vivino,
    CellarTrackerResult ct,
  ) {
    final vBegin = vivino.beginConsume;
    final vEnd = vivino.endConsume;
    final cBegin = ct.beginConsume;
    final cEnd = ct.endConsume;

    // Les deux sources ont une fenêtre → comparaison
    if (vBegin != null && vEnd != null && cBegin != null && cEnd != null) {
      final diffBegin = (vBegin - cBegin).abs();
      final diffEnd = (vEnd - cEnd).abs();

      if (diffBegin > _divergenceThresholdYears ||
          diffEnd > _divergenceThresholdYears) {
        // Divergence significative
        final commonBegin = vBegin > cBegin ? vBegin : cBegin;
        final commonEnd = vEnd < cEnd ? vEnd : cEnd;
        final hasCommonWindow =
            commonEnd - commonBegin >= _minCommonWindowYears;

        final buf = StringBuffer();
        buf.writeln('> ⚠️ **Les fenêtres de dégustation divergent :**');
        buf.writeln('> - Vivino : $vBegin–$vEnd');
        buf.writeln('> - CellarTracker : $cBegin–$cEnd');
        if (hasCommonWindow) {
          buf.writeln(
            '> - Fenêtre commune retenue : **$commonBegin–$commonEnd**',
          );
        } else {
          buf.writeln(
            '> Les fenêtres ne se chevauchent pas suffisamment — '
            'consultez les deux sources pour décider.',
          );
        }
        return buf.toString();
      }

      // Pas de divergence notable → afficher l'intersection
      final commonBegin = vBegin > cBegin ? vBegin : cBegin;
      final commonEnd = vEnd < cEnd ? vEnd : cEnd;
      return '🗓️ **Fenêtre de dégustation :** $commonBegin–$commonEnd\n';
    }

    // Une seule source a une fenêtre
    if (vBegin != null && vEnd != null) {
      return '🗓️ **Fenêtre de dégustation (Vivino) :** $vBegin–$vEnd\n';
    }
    if (cBegin != null && cEnd != null) {
      return '🗓️ **Fenêtre de dégustation (CellarTracker) :** $cBegin–$cEnd\n';
    }

    return '';
  }
}
