import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wine_cellar/core/constants.dart';
import 'package:wine_cellar/core/enums.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/features/developer/domain/entities/backup_data.dart';
import 'package:wine_cellar/features/developer/domain/usecases/export_backup_usecase.dart';
import 'package:wine_cellar/features/developer/domain/usecases/import_backup_usecase.dart';
import 'package:wine_cellar/features/wine_cellar/domain/entities/virtual_cellar_theme.dart';

// ── State ──────────────────────────────────────────────────────────────────

sealed class BackupState {
  const BackupState();
}

class BackupIdle extends BackupState {
  const BackupIdle();
}

class BackupLoading extends BackupState {
  const BackupLoading();
}

class BackupSuccess extends BackupState {
  final String message;
  const BackupSuccess(this.message);
}

class BackupError extends BackupState {
  final String message;
  const BackupError(this.message);
}

// ── Notifier ───────────────────────────────────────────────────────────────

/// Orchestrates backup export and import operations.
///
/// On export it collects the current state from all Riverpod providers,
/// builds a [BackupData] snapshot and delegates encryption + file I/O to
/// [ExportBackupUseCase].
///
/// On import it delegates decryption + file picking to [ImportBackupUseCase]
/// and then restores each provider notifier with the recovered values.
class BackupNotifier extends StateNotifier<BackupState> {
  final ExportBackupUseCase _exportUseCase;
  final ImportBackupUseCase _importUseCase;
  final Ref _ref;

  BackupNotifier(this._exportUseCase, this._importUseCase, this._ref)
      : super(const BackupIdle());

  // ── Export ─────────────────────────────────────────────────────────────────

  Future<void> exportBackup(String password) async {
    state = const BackupLoading();

    final devMode = _ref.read(developerModeProvider);
    final data = await _buildBackupData(includeSecrets: devMode);

    final result = await _exportUseCase(
      ExportBackupParams(password: password, data: data),
    );

    state = result.fold(
      (failure) => BackupError(failure.message),
      (_) => BackupSuccess(
        devMode
            ? 'Sauvegarde exportée avec succès (inclut les secrets).'
            : 'Sauvegarde exportée avec succès.',
      ),
    );
  }

  // ── Import ─────────────────────────────────────────────────────────────────

  Future<void> importBackup(String password) async {
    state = const BackupLoading();

    final result = await _importUseCase(
      ImportBackupParams(password: password),
    );

    await result.fold(
      (failure) async => state = BackupError(failure.message),
      (data) async {
        await _applyConfig(data.config);
        if (data.secrets != null) {
          await _applySecrets(data.secrets!);
        }
        await _applyWines(data.winesJson);

        final secretsMsg =
            data.secrets != null ? ' (secrets inclus)' : '';
        state = BackupSuccess(
          'Sauvegarde restaurée avec succès$secretsMsg.',
        );
      },
    );
  }

  // ── Reset ──────────────────────────────────────────────────────────────────

  void reset() => state = const BackupIdle();

  // ── Private helpers ────────────────────────────────────────────────────────

  Future<BackupData> _buildBackupData({required bool includeSecrets}) async {
    final config = <String, String?>{
      AppConstants.keyAiProvider:
          _ref.read(aiProviderSettingProvider).name,
      AppConstants.keyAppVisualTheme:
          _ref.read(appVisualThemeProvider)?.name,
      AppConstants.keyWineListLayout:
          _ref.read(wineListLayoutProvider).name,
      AppConstants.keySplitRatioHorizontal:
          _ref.read(splitRatioHorizontalProvider).toString(),
      AppConstants.keySplitRatioVertical:
          _ref.read(splitRatioVerticalProvider).toString(),
      AppConstants.keyHighlightLastConsumptionYear:
          _ref.read(highlightLastConsumptionYearProvider).toString(),
      AppConstants.keyHighlightPastOptimalConsumption:
          _ref.read(highlightPastOptimalConsumptionProvider).toString(),
    };

    Map<String, String?>? secrets;
    if (includeSecrets) {
      secrets = {
        AppConstants.keyOpenAiApiKey: _ref.read(openAiApiKeyProvider),
        AppConstants.keyGeminiApiKey: _ref.read(geminiApiKeyProvider),
        AppConstants.keyGeminiFallbackApiKey:
            _ref.read(geminiFallbackApiKeyProvider),
        AppConstants.keyMistralApiKey: _ref.read(mistralApiKeyProvider),
        AppConstants.keyOllamaUrl: _ref.read(ollamaUrlProvider),
        AppConstants.keySelectedModel: _ref.read(selectedModelProvider),
        AppConstants.keyVisionProviderOverride:
            _ref.read(visionProviderOverrideProvider),
        AppConstants.keyVisionModel: _ref.read(visionModelOverrideProvider),
        AppConstants.keyVisionApiKeyOverride:
            _ref.read(visionApiKeyOverrideProvider),
        AppConstants.keyUseOcrForImages:
            _ref.read(useOcrForImagesProvider).toString(),
        AppConstants.keyCellarTrackerUser:
            _ref.read(cellarTrackerUserProvider),
        AppConstants.keyCellarTrackerPassword:
            _ref.read(cellarTrackerPasswordProvider),
      };
    }

    final winesJson =
        await _ref.read(wineRepositoryProvider).exportToJson();

    return BackupData(
      config: config,
      secrets: secrets,
      winesJson: winesJson,
      createdAt: DateTime.now(),
      version: 1,
    );
  }

  Future<void> _applyConfig(Map<String, String?> config) async {
    final aiName = config[AppConstants.keyAiProvider];
    if (aiName != null) {
      final match = AiProvider.values.cast<AiProvider?>().firstWhere(
            (e) => e?.name == aiName,
            orElse: () => null,
          );
      if (match != null) {
        await _ref.read(aiProviderSettingProvider.notifier).setProvider(match);
      }
    }

    final themeName = config[AppConstants.keyAppVisualTheme];
    final theme = (themeName != null && themeName.isNotEmpty)
        ? VirtualCellarTheme.values.cast<VirtualCellarTheme?>().firstWhere(
              (t) => t?.name == themeName,
              orElse: () => null,
            )
        : null;
    await _ref.read(appVisualThemeProvider.notifier).setTheme(theme);

    final layoutName = config[AppConstants.keyWineListLayout];
    if (layoutName != null) {
      final match = WineListLayout.values.cast<WineListLayout?>().firstWhere(
            (l) => l?.name == layoutName,
            orElse: () => null,
          );
      if (match != null) {
        await _ref.read(wineListLayoutProvider.notifier).setLayout(match);
      }
    }

    final hRatio = double.tryParse(
      config[AppConstants.keySplitRatioHorizontal] ?? '',
    );
    if (hRatio != null) {
      await _ref.read(splitRatioHorizontalProvider.notifier).setRatio(hRatio);
    }

    final vRatio = double.tryParse(
      config[AppConstants.keySplitRatioVertical] ?? '',
    );
    if (vRatio != null) {
      await _ref.read(splitRatioVerticalProvider.notifier).setRatio(vRatio);
    }

    final hlLast = config[AppConstants.keyHighlightLastConsumptionYear];
    if (hlLast != null) {
      await _ref
          .read(highlightLastConsumptionYearProvider.notifier)
          .setValue(hlLast == 'true');
    }

    final hlPast = config[AppConstants.keyHighlightPastOptimalConsumption];
    if (hlPast != null) {
      await _ref
          .read(highlightPastOptimalConsumptionProvider.notifier)
          .setValue(hlPast == 'true');
    }
  }

  Future<void> _applySecrets(Map<String, String?> secrets) async {
    await _ref
        .read(openAiApiKeyProvider.notifier)
        .setValue(secrets[AppConstants.keyOpenAiApiKey]);
    await _ref
        .read(geminiApiKeyProvider.notifier)
        .setValue(secrets[AppConstants.keyGeminiApiKey]);
    await _ref
        .read(geminiFallbackApiKeyProvider.notifier)
        .setValue(secrets[AppConstants.keyGeminiFallbackApiKey]);
    await _ref
        .read(mistralApiKeyProvider.notifier)
        .setValue(secrets[AppConstants.keyMistralApiKey]);
    await _ref
        .read(ollamaUrlProvider.notifier)
        .setValue(secrets[AppConstants.keyOllamaUrl]);
    await _ref
        .read(selectedModelProvider.notifier)
        .setValue(secrets[AppConstants.keySelectedModel]);
    await _ref
        .read(visionProviderOverrideProvider.notifier)
        .setValue(secrets[AppConstants.keyVisionProviderOverride]);
    await _ref
        .read(visionModelOverrideProvider.notifier)
        .setValue(secrets[AppConstants.keyVisionModel]);
    await _ref
        .read(visionApiKeyOverrideProvider.notifier)
        .setValue(secrets[AppConstants.keyVisionApiKeyOverride]);

    final useOcr = secrets[AppConstants.keyUseOcrForImages];
    if (useOcr != null) {
      await _ref
          .read(useOcrForImagesProvider.notifier)
          .setValue(useOcr == 'true');
    }

    await _ref
        .read(cellarTrackerUserProvider.notifier)
        .setValue(secrets[AppConstants.keyCellarTrackerUser]);
    await _ref
        .read(cellarTrackerPasswordProvider.notifier)
        .setValue(secrets[AppConstants.keyCellarTrackerPassword]);
  }

  Future<void> _applyWines(String winesJson) async {
    if (winesJson == '[]' || winesJson.isEmpty) return;
    final importUseCase = _ref.read(importWinesFromJsonUseCaseProvider);
    // Errors are silently ignored so the restore doesn't fail if wines are
    // already present — the screen shows a dedicated message if needed.
    await importUseCase(winesJson);
  }
}
