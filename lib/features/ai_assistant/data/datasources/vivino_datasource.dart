import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/features/ai_assistant/domain/entities/vivino_result.dart';

/// Datasource pour accéder aux données non-officielles de Vivino.
///
/// Utilise les endpoints JSON internes que le site Vivino appelle lui-même.
/// Ces endpoints ne sont pas garantis dans le temps et leur utilisation est
/// soumise aux CGU de Vivino — à réserver à une phase d'évaluation POC.
///
/// Flux supportés :
/// - Recherche d'un vin par nom (+ millésime optionnel) → note + avis
/// - Récupération des avis d'un vin par son ID Vivino
class VivinoDatasource {
  static const String _baseUrl = 'https://www.vivino.com/api';

  // Headers mimant un navigateur mobile pour limiter le risque de blocage.
  static const Map<String, String> _headers = {
    'User-Agent':
        'Mozilla/5.0 (Linux; Android 14; Mobile) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
    'Accept': 'application/json, text/plain, */*',
    'Accept-Language': 'fr-FR,fr;q=0.9,en;q=0.8',
    'Referer': 'https://www.vivino.com/',
    'Origin': 'https://www.vivino.com',
  };

  final Logger _logger = Logger();
  late final Dio _dio;

  VivinoDatasource() {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: _headers,
      ),
    );
  }

  /// Recherche un vin sur Vivino et retourne sa note ainsi que ses avis.
  ///
  /// [wineName] : nom du vin (ex. "Château Margaux").
  /// [vintage]  : millésime optionnel — améliore la précision de la recherche.
  /// [maxReviews] : nombre maximum d'avis à récupérer (défaut : 5).
  Future<VivinoSearchResult> searchWineWithReviews({
    required String wineName,
    int? vintage,
    int maxReviews = 5,
  }) async {
    try {
      final query = vintage != null ? '$wineName $vintage' : wineName;

      final searchResponse = await _dio.get(
        '/explore/explore',
        queryParameters: {
          'q': query,
          'language': 'fr',
          'min_rating': 1,
          'order_by': 'ratings_average',
          'order': 'desc',
        },
      );

      final data = searchResponse.data as Map<String, dynamic>?;
      final records =
          (data?['explore_vintage']?['records'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList();

      if (records == null || records.isEmpty) {
        _logger.i('Vivino: aucun résultat pour "$query"');
        return VivinoSearchResult.notFound();
      }

      final firstRecord = records.first;
      final vintageData = firstRecord['vintage'] as Map<String, dynamic>?;
      final wineData = vintageData?['wine'] as Map<String, dynamic>?;
      final statistics = vintageData?['statistics'] as Map<String, dynamic>?;

      final wineId = wineData?['id'] as int?;
      if (wineId == null) {
        _logger.w('Vivino: wine_id manquant dans la réponse');
        return VivinoSearchResult.notFound();
      }

      final wineryData = wineData?['winery'] as Map<String, dynamic>?;
      final regionData = wineData?['region'] as Map<String, dynamic>?;
      final countryData = regionData?['country'] as Map<String, dynamic>?;

      final ratingsAverage =
          (statistics?['ratings_average'] as num?)?.toDouble();
      final ratingsCount = statistics?['ratings_count'] as int?;
      final vintageYear = vintageData?['year'] as int?;

      final reviews = await _fetchReviews(wineId, maxReviews: maxReviews);
      final window = await _fetchDrinkingWindow(wineId, vintageYear: vintageYear);

      _logger.i(
        'Vivino: "${wineData?['name']}" trouvé (id=$wineId, '
        'note=$ratingsAverage, avis=${reviews.length})',
      );

      return VivinoSearchResult(
        status: reviews.isEmpty
            ? VivinoSourceStatus.foundNoReviews
            : VivinoSourceStatus.found,
        wineId: wineId,
        wineName: wineData?['name'] as String?,
        winery: wineryData?['name'] as String?,
        region: regionData?['name'] as String?,
        country: countryData?['name'] as String?,
        vintage: vintageYear,
        ratingsAverage: ratingsAverage,
        ratingsCount: ratingsCount,
        reviews: reviews,
        wineUrl: 'https://www.vivino.com/wines/$wineId',
        beginConsume: window.begin,
        endConsume: window.end,
      );
    } on DioException catch (e) {
      _logger.e('Vivino API DioException', error: e);
      return VivinoSearchResult.unavailable();
    } catch (e, st) {
      _logger.e('Vivino parsing error', error: e, stackTrace: st);
      return VivinoSearchResult.unavailable();
    }
  }

  /// Récupère les avis en français (puis toutes langues si insuffisant) pour
  /// un vin identifié par son [wineId] Vivino.
  Future<List<VivinoReview>> _fetchReviews(
    int wineId, {
    int maxReviews = 5,
  }) async {
    try {
      final response = await _dio.get(
        '/wines/$wineId/reviews',
        queryParameters: {
          'language': 'fr',
          'per_page': maxReviews,
          'page': 1,
        },
      );

      final data = response.data as Map<String, dynamic>?;
      final reviewsData =
          (data?['reviews'] as List?)
              ?.whereType<Map<String, dynamic>>()
              .toList() ??
          [];

      return reviewsData
          .map(
            (r) => VivinoReview(
              rating: (r['rating'] as num?)?.toDouble() ?? 0.0,
              note: r['note'] as String?,
              language: r['language'] as String?,
              createdAt: r['created_at'] as String?,
            ),
          )
          .where((r) => r.note != null && r.note!.trim().isNotEmpty)
          .toList();
    } catch (e) {
      _logger.w('Vivino: impossible de récupérer les avis pour $wineId', error: e);
      return [];
    }
  }

  /// Tente de récupérer la fenêtre de dégustation pour un vin Vivino.
  ///
  /// Appelle `/api/wines/{wineId}/vintages` — données non garanties.
  /// Retourne `(begin: null, end: null)` si indisponible.
  Future<({int? begin, int? end})> _fetchDrinkingWindow(
    int wineId, {
    int? vintageYear,
  }) async {
    try {
      final params = <String, dynamic>{'language': 'fr'};
      if (vintageYear != null) params['vintage_year'] = vintageYear;

      final response = await _dio.get(
        '/wines/$wineId/vintages',
        queryParameters: params,
      );

      final data = response.data;
      final List<dynamic> vintages;
      if (data is List) {
        vintages = data;
      } else if (data is Map) {
        final inner = data['vintages'];
        vintages = inner is List ? inner : [data];
      } else {
        return (begin: null, end: null);
      }

      if (vintages.isEmpty) return (begin: null, end: null);

      // Cible le millésime demandé, sinon prend le premier.
      final target = vintageYear != null
          ? vintages.firstWhere(
              (v) =>
                  v is Map &&
                  ((v['year'] as int?) == vintageYear ||
                      (v['vintage']?['year'] as int?) == vintageYear),
              orElse: () => vintages.first,
            )
          : vintages.first;

      final int? begin = _extractYearFromMap(
        target,
        ['begin_year', 'begin_consume', 'drink_from'],
      );
      final int? end = _extractYearFromMap(
        target,
        ['end_year', 'end_consume', 'drink_to'],
      );
      return (begin: begin, end: end);
    } catch (e) {
      _logger.d(
        'Vivino: fenêtre de dégustation indisponible pour $wineId',
        error: e,
      );
      return (begin: null, end: null);
    }
  }

  static int? _extractYearFromMap(dynamic data, List<String> keys) {
    if (data is! Map) return null;
    for (final key in keys) {
      final value = data[key];
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Helpers de formatage (texte prêt à l'affichage dans le chat)
  // ---------------------------------------------------------------------------

  /// Convertit un [VivinoSearchResult] en texte Markdown pour le chat.
  static String formatAsMarkdown(VivinoSearchResult result) {
    final buf = StringBuffer();

    if (result.wineName != null) {
      buf.write('**${result.wineName}**');
      if (result.winery != null && result.winery != result.wineName) {
        buf.write(' — ${result.winery}');
      }
      if (result.vintage != null) buf.write(' (${result.vintage})');
      buf.writeln();
    }

    final location = [result.region, result.country]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');
    if (location.isNotEmpty) buf.writeln('📍 $location');

    if (result.ratingsAverage != null) {
      final avg = result.ratingsAverage!.toStringAsFixed(1);
      final countPart = result.ratingsCount != null
          ? ' (${_formatCount(result.ratingsCount!)} avis)'
          : '';
      buf.writeln('⭐ **Note Vivino : $avg / 5**$countPart');
    }

    if (result.reviews.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Avis récents sur Vivino :**');
      for (final review in result.reviews.take(5)) {
        final stars = List.filled(review.rating.round().clamp(0, 5), '⭐').join();
        if (review.note != null) {
          buf.writeln('- $stars ${review.note}');
        }
      }
    }

    return buf.toString().trim();
  }

  static String _formatCount(int count) {
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }

  /// Alias public de [_formatCount] utilisable hors de la classe.
  static String formatCount(int count) => _formatCount(count);
}
