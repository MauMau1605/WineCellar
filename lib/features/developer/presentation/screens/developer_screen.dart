import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:wine_cellar/core/providers.dart';
import 'package:wine_cellar/core/usecases/usecase.dart';
import 'package:wine_cellar/features/developer/presentation/helpers/developer_screen_helper.dart';

/// Landing screen for developer tools.
/// Shows all available developer-only features.
class DeveloperScreen extends ConsumerWidget {
  const DeveloperScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
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
