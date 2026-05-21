import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:logger/logger.dart';

import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/features/ai_assistant/domain/entities/cellar_tracker_result.dart';

/// Datasource pour accéder aux données communautaires de CellarTracker.
///
/// Utilise l'API officielle (non-documentée publiquement mais stable) via
/// des requêtes HTTP simples avec authentification par paramètres.
///
/// Si les identifiants ne sont pas configurés, toutes les méthodes retournent
/// silencieusement [CellarTrackerResult.unconfigured].
///
/// Documentation de référence : https://www.cellartracker.com/faq.asp#API
class CellarTrackerDatasource {
  static const String _baseUrl = 'https://www.cellartracker.com';
  static const int _maxNotes = 5;

  final FlutterSecureStorage _storage;
  final Logger _logger = Logger();
  late final Dio _dio;

  CellarTrackerDatasource(this._storage) {
    _dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        responseType: ResponseType.plain,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Recherche principale
  // ---------------------------------------------------------------------------

  /// Recherche un vin sur CellarTracker et retourne les données communautaires.
  ///
  /// [wineName] : nom du vin.
  /// [vintage]  : millésime optionnel.
  ///
  /// Retourne [CellarTrackerResult.unconfigured] si les identifiants sont absents,
  /// [CellarTrackerResult.unavailable] en cas d'erreur réseau/parsing,
  /// [CellarTrackerResult.notFound] si aucun vin ne correspond.
  Future<CellarTrackerResult> searchWine({
    required String wineName,
    int? vintage,
  }) async {
    final user =
        await _storage.read(key: AppConstants.keyCellarTrackerUser);
    final password =
        await _storage.read(key: AppConstants.keyCellarTrackerPassword);

    if (user == null || user.isEmpty || password == null || password.isEmpty) {
      _logger.d('CellarTracker: identifiants non configurés — ignoré');
      return CellarTrackerResult.unconfigured();
    }

    try {
      // Appel 1 : données structurées du vin (fenêtre, score CT global)
      final wineData = await _fetchWineData(
        wineName: wineName,
        vintage: vintage,
        user: user,
        password: password,
      );

      if (wineData == null) {
        _logger.i('CellarTracker: aucun résultat pour "$wineName"');
        return CellarTrackerResult.notFound();
      }

      // Appel 2 : notes individuelles de la communauté
      final notes = await _fetchNotes(
        wineName: wineName,
        vintage: vintage,
        user: user,
        password: password,
      );

      _logger.i(
        'CellarTracker: "${wineData['Wine']}" trouvé '
        '(CT=${wineData['CT']}, notes=${notes.length})',
      );

      return CellarTrackerResult(
        status: CellarTrackerSourceStatus.found,
        wineName: wineData['Wine'],
        vintage: _parseInt(wineData['Vintage']),
        communityScore: _parseDouble(wineData['CT']),
        communityCount: _parseInt(wineData['CTnotes']),
        beginConsume: _parseInt(wineData['BeginConsume']),
        endConsume: _parseInt(wineData['EndConsume']),
        notes: notes,
      );
    } on DioException catch (e) {
      _logger.e('CellarTracker: erreur réseau', error: e);
      return CellarTrackerResult.unavailable();
    } catch (e, st) {
      _logger.e('CellarTracker: erreur parsing', error: e, stackTrace: st);
      return CellarTrackerResult.unavailable();
    }
  }

  // ---------------------------------------------------------------------------
  // Requêtes HTTP privées
  // ---------------------------------------------------------------------------

  Future<Map<String, String>?> _fetchWineData({
    required String wineName,
    required int? vintage,
    required String user,
    required String password,
  }) async {
    final params = _buildBaseParams(user, password, 'Wine', wineName, vintage);
    final rows = await _fetchTsv(params);
    if (rows.isEmpty) return null;

    // Si vintage précisé, tenter de trouver le millésime exact.
    if (vintage != null) {
      final match = rows.firstWhere(
        (r) => _parseInt(r['Vintage']) == vintage,
        orElse: () => rows.first,
      );
      return match;
    }
    return rows.first;
  }

  Future<List<CellarTrackerNote>> _fetchNotes({
    required String wineName,
    required int? vintage,
    required String user,
    required String password,
  }) async {
    final params = _buildBaseParams(user, password, 'Notes', wineName, vintage);
    final rows = await _fetchTsv(params);
    return rows
        .take(_maxNotes)
        .map(
          (r) => CellarTrackerNote(
            rating: _parseDouble(r['Score']),
            note: r['Note']?.trim().isNotEmpty == true ? r['Note']!.trim() : null,
            author: r['Author'] ?? r['User'],
          ),
        )
        .where((n) => n.note != null || n.rating != null)
        .toList();
  }

  Map<String, String> _buildBaseParams(
    String user,
    String password,
    String table,
    String wineName,
    int? vintage,
  ) {
    final params = <String, String>{
      'User': user,
      'Password': password,
      'Type': 'List',
      'Table': table,
      'Wine': wineName,
      'format': 'tab',
    };
    if (vintage != null) params['Vintage'] = vintage.toString();
    return params;
  }

  /// Effectue la requête HTTP et parse le TSV retourné.
  Future<List<Map<String, String>>> _fetchTsv(
    Map<String, String> params,
  ) async {
    final response = await _dio.get<String>(
      '/list.php',
      queryParameters: params,
    );

    if (response.statusCode != 200 || response.data == null) {
      _logger.w('CellarTracker: HTTP ${response.statusCode}');
      return [];
    }

    return _parseTsv(response.data!);
  }

  // ---------------------------------------------------------------------------
  // Parsing TSV
  // ---------------------------------------------------------------------------

  static List<Map<String, String>> _parseTsv(String body) {
    final lines = body
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .toList();
    if (lines.length < 2) return [];

    final headers = lines.first.split('\t');
    final result = <Map<String, String>>[];

    for (final line in lines.skip(1)) {
      final values = line.split('\t');
      final row = <String, String>{};
      for (var i = 0; i < headers.length; i++) {
        row[headers[i].trim()] = i < values.length ? values[i].trim() : '';
      }
      result.add(row);
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Helpers de formatage
  // ---------------------------------------------------------------------------

  /// Convertit un [CellarTrackerResult] en Markdown pour le chat.
  static String formatAsMarkdown(CellarTrackerResult result) {
    if (result.status != CellarTrackerSourceStatus.found) return '';

    final buf = StringBuffer();

    if (result.wineName != null) {
      buf.write('**${result.wineName}**');
      if (result.vintage != null) buf.write(' (${result.vintage})');
      buf.writeln();
    }

    if (result.communityScore != null) {
      final score = result.communityScore!.toStringAsFixed(0);
      final countPart = result.communityCount != null
          ? ' (${result.communityCount} avis)'
          : '';
      buf.writeln('🏆 **Note CellarTracker : $score / 100**$countPart');
    }

    if (result.beginConsume != null && result.endConsume != null) {
      buf.writeln(
        '🗓️ Fenêtre de dégustation : ${result.beginConsume}–${result.endConsume}',
      );
    }

    if (result.notes.isNotEmpty) {
      buf.writeln();
      buf.writeln('**Avis CellarTracker :**');
      for (final note in result.notes) {
        final score =
            note.rating != null ? '[${note.rating!.toStringAsFixed(0)}/100] ' : '';
        if (note.note != null) {
          buf.writeln('- $score${note.note}');
        }
      }
    }

    return buf.toString().trim();
  }

  // ---------------------------------------------------------------------------
  // Utilitaires de conversion
  // ---------------------------------------------------------------------------

  static int? _parseInt(String? value) {
    if (value == null || value.isEmpty) return null;
    return int.tryParse(value);
  }

  static double? _parseDouble(String? value) {
    if (value == null || value.isEmpty) return null;
    return double.tryParse(value);
  }
}
