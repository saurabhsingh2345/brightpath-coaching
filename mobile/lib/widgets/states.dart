import 'package:flutter/material.dart';
import '../core/api_exception.dart';
import '../core/theme.dart';

/// Centred spinner used while a screen loads for the first time.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label});
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (label != null) ...[
            const SizedBox(height: Gap.lg),
            Text(
              label!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Skeleton rows - shown instead of a spinner for list-shaped screens.
class SkeletonList extends StatefulWidget {
  const SkeletonList({super.key, this.count = 5, this.height = 82});
  final int count;
  final double height;

  @override
  State<SkeletonList> createState() => _SkeletonListState();
}

class _SkeletonListState extends State<SkeletonList>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).colorScheme.surfaceContainerHighest;
    return ListView.separated(
      padding: const EdgeInsets.all(Gap.lg),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.count,
      separatorBuilder: (_, __) => const SizedBox(height: Gap.md),
      itemBuilder: (_, __) => AnimatedBuilder(
        animation: _c,
        builder: (context, _) => Container(
          height: widget.height,
          decoration: BoxDecoration(
            color: base.withValues(alpha: 0.35 + _c.value * 0.35),
            borderRadius: BorderRadius.circular(kRadius),
          ),
        ),
      ),
    );
  }
}

/// Friendly empty state with an optional call to action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: scheme.primary),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: Gap.sm),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: Gap.xl),
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Error state that distinguishes "no network" from a real server error.
class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final ApiException error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isNetwork = error.isNetwork;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Gap.xxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                color: scheme.errorContainer.withValues(alpha: 0.5),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isNetwork ? Icons.wifi_off_rounded : Icons.error_outline_rounded,
                size: 34,
                color: scheme.error,
              ),
            ),
            const SizedBox(height: Gap.xl),
            Text(
              isNetwork ? 'No connection' : 'Something went wrong',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: Gap.sm),
            Text(
              error.message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: Gap.xl),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(160, 48),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small helper that shows a themed snackbar without repeating boilerplate.
void showSnack(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final scheme = Theme.of(context).colorScheme;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
              size: 20,
              color: isError ? scheme.onErrorContainer : Colors.white,
            ),
            const SizedBox(width: Gap.md),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: isError ? scheme.onErrorContainer : Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor:
            isError ? scheme.errorContainer : const Color(0xFF1F2430),
        duration: Duration(seconds: isError ? 5 : 3),
      ),
    );
}

/// Yes/no confirmation used before destructive actions.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message, style: const TextStyle(height: 1.45)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error,
                  minimumSize: const Size(100, 44),
                )
              : FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
