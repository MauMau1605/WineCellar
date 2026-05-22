import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/developer/presentation/helpers/developer_screen_helper.dart';
import 'package:wine_cellar/features/developer/presentation/providers/backup_provider.dart';

/// Landing screen for developer tools.
/// Shows all available developer-only features.
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final devMode = ref.watch(developerModeProvider);

    // Listen to backup state changes and show feedback.
    ref.listen<BackupState>(backupNotifierProvider, (_, next) {
      if (next is BackupSuccess) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(next.message)));
        ref.read(backupNotifierProvider.notifier).reset();
      } else if (next is BackupError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.message),
            backgroundColor: theme.colorScheme.error,
          ),
        );
        ref.read(backupNotifierProvider.notifier).reset();
      }
    });

    final backupState = ref.watch(backupNotifierProvider);
    final isBackupLoading = backupState is BackupLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Outils développeur')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          MaterialBanner(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            content: const Text(DeveloperScreenHelper.bannerText),
            leading: const Icon(Icons.warning_amber, color: Colors.orange),
            actions: const [SizedBox.shrink()],
          ),
          const SizedBox(height: 20),
          Text(
            DeveloperScreenHelper.toolsTitle,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),

          // ── Réévaluation IA ────────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(DeveloperScreenHelper.reevaluationTool.icon),
              title: Text(DeveloperScreenHelper.reevaluationTool.title),
              subtitle: Text(DeveloperScreenHelper.reevaluationTool.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  context.push(DeveloperScreenHelper.reevaluationTool.route!),
            ),
          ),
          const SizedBox(height: 8),

          // ── Export sauvegarde ──────────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(
                DeveloperScreenHelper.exportBackupTool.icon,
                color: theme.colorScheme.primary,
              ),
              title: Text(DeveloperScreenHelper.exportBackupTool.title),
              subtitle: Text(DeveloperScreenHelper.exportBackupTool.subtitle),
              trailing: isBackupLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: isBackupLoading
                  ? null
                  : () => _showExportDialog(context, ref, devMode),
            ),
          ),
          const SizedBox(height: 8),

          // ── Import / restauration ──────────────────────────────────────────
          Card(
            child: ListTile(
              leading: Icon(
                DeveloperScreenHelper.importBackupTool.icon,
                color: theme.colorScheme.secondary,
              ),
              title: Text(DeveloperScreenHelper.importBackupTool.title),
              subtitle: Text(DeveloperScreenHelper.importBackupTool.subtitle),
              trailing: isBackupLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chevron_right),
              onTap: isBackupLoading
                  ? null
                  : () => _showImportDialog(context, ref),
            ),
          ),
          const SizedBox(height: 8),

          // ── Suppression totale ─────────────────────────────────────────────
          Card(
            color: theme.colorScheme.errorContainer,
            child: ListTile(
              leading: Icon(
                DeveloperScreenHelper.deleteAllWinesTool.icon,
                color: theme.colorScheme.onErrorContainer,
              ),
              title: Text(
                DeveloperScreenHelper.deleteAllWinesTool.title,
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
              subtitle: Text(
                DeveloperScreenHelper.deleteAllWinesTool.subtitle,
                style: TextStyle(
                  color: theme.colorScheme.onErrorContainer.withAlpha(180),
                ),
              ),
              trailing: Icon(
                Icons.chevron_right,
                color: theme.colorScheme.onErrorContainer,
              ),
              onTap: () => _confirmDeleteAllWines(context, ref),
            ),
          ),
        ],
      ),
    );
  }

  // ── Backup dialogs ─────────────────────────────────────────────────────────

  Future<void> _showExportDialog(
    BuildContext context,
    WidgetRef ref,
    bool devMode,
  ) async {
    final passwordCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.backup_outlined, size: 40),
        title: const Text(DeveloperScreenHelper.backupExportTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (devMode) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.orange.withAlpha(25),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withAlpha(80)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.key, color: Colors.orange, size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DeveloperScreenHelper.backupExportWithSecretsNotice,
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: DeveloperScreenHelper.backupPasswordLabel,
                  helperText: DeveloperScreenHelper.backupPasswordHint,
                  helperMaxLines: 2,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ obligatoire.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: confirmCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: DeveloperScreenHelper.backupPasswordConfirmLabel,
                ),
                validator: (v) => v != passwordCtrl.text
                    ? DeveloperScreenHelper.backupPasswordMismatch
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(DeveloperScreenHelper.cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: Text(
              DeveloperScreenHelper.backupExportConfirmLabel(devMode),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref
        .read(backupNotifierProvider.notifier)
        .exportBackup(passwordCtrl.text);
  }

  Future<void> _showImportDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final passwordCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_outlined, size: 40),
        title: const Text(DeveloperScreenHelper.backupImportTitle),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withAlpha(20),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withAlpha(60)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Un sélecteur de fichiers s\'ouvrira après '
                        'validation pour choisir le fichier .wce.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: passwordCtrl,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: DeveloperScreenHelper.backupPasswordLabel,
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Champ obligatoire.' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(DeveloperScreenHelper.cancelLabel),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.of(dialogContext).pop(true);
              }
            },
            child: const Text('Choisir un fichier'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;
    await ref
        .read(backupNotifierProvider.notifier)
        .importBackup(passwordCtrl.text);
  }

  // ── Delete all wines ───────────────────────────────────────────────────────

  Future<void> _confirmDeleteAllWines(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final wineCount = await ref.read(wineRepositoryProvider).getWineCount();

    if (!context.mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning, color: Colors.red, size: 48),
        title: const Text(DeveloperScreenHelper.deleteDialogTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              DeveloperScreenHelper.deleteDialogContent(wineCount),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.red),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      DeveloperScreenHelper.deleteDialogWarning,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(DeveloperScreenHelper.cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text(DeveloperScreenHelper.confirmDeleteLabel),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    final deleteUseCase = ref.read(deleteAllWinesUseCaseProvider);
    final result = await deleteUseCase(const NoParams());

    if (!context.mounted) return;

    result.fold(
      (failure) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              DeveloperScreenHelper.deleteErrorMessage(failure.message),
            ),
          ),
        );
      },
      (_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(DeveloperScreenHelper.deleteSuccessMessage(wineCount)),
          ),
        );
      },
    );
  }
}
