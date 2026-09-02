import 'package:flutter/material.dart';
import '../core/formatters.dart';
import '../core/theme.dart';

/// Section label above a group of cards.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.padding =
        const EdgeInsets.only(left: Gap.lg, right: Gap.sm, top: Gap.xl, bottom: Gap.md),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}

/// Compact metric tile for dashboards.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.tint,
    this.sublabel,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? tint;
  final String? sublabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = tint ?? scheme.primary;
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(kRadius),
        child: Padding(
          padding: const EdgeInsets.all(Gap.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(icon, size: 20, color: color),
              ),
              const SizedBox(height: Gap.lg),
              Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.8,
                    ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
              ),
              if (sublabel != null) ...[
                const SizedBox(height: Gap.xs),
                Text(
                  sublabel!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: color,
                        fontWeight: FontWeight.w600,
                        fontSize: 11.5,
                      ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Pill badge. Used for attendance status, fee status, audience, grade.
class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    required this.color,
    this.icon,
    this.dense = false,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? Gap.sm : Gap.md,
        vertical: dense ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: dense ? 11 : 13, color: color),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: dense ? 10.5 : 11.5,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular initials avatar - no image assets needed.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({
    super.key,
    required this.name,
    this.size = 44,
    this.color,
  });

  final String name;
  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Stable per-name hue so the same student always looks the same.
    final palette = [
      scheme.primary,
      const Color(0xFF12B76A),
      const Color(0xFFF79009),
      const Color(0xFF6172F3),
      const Color(0xFFEE46BC),
      const Color(0xFF06AED4),
    ];
    final c = color ??
        palette[name.isEmpty ? 0 : name.codeUnits.fold<int>(0, (a, b) => a + b) % palette.length];

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        Fmt.initials(name),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w700,
          fontSize: size * 0.36,
        ),
      ),
    );
  }
}

/// Thin animated progress meter - attendance %, collection rate, etc.
class MeterBar extends StatelessWidget {
  const MeterBar({
    super.key,
    required this.value,
    this.color,
    this.height = 8,
  });

  /// 0..100
  final double value;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: (value.clamp(0, 100)) / 100),
        duration: const Duration(milliseconds: 550),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => LinearProgressIndicator(
          value: v,
          minHeight: height,
          backgroundColor: scheme.surfaceContainerHighest,
          valueColor: AlwaysStoppedAnimation(color ?? scheme.primary),
        ),
      ),
    );
  }
}

/// Key/value row used on detail screens.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Gap.md),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 17, color: scheme.onSurfaceVariant),
              const SizedBox(width: Gap.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value.isEmpty ? '—' : value,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing!,
            if (onTap != null && trailing == null)
              Icon(Icons.chevron_right_rounded,
                  size: 20, color: scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Card wrapper with a title, used to group detail rows.
class InfoCard extends StatelessWidget {
  const InfoCard({
    super.key,
    required this.children,
    this.title,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.sm),
  });

  final List<Widget> children;
  final String? title;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.only(top: Gap.sm, bottom: Gap.xs),
                child: Text(
                  title!,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        letterSpacing: 0.3,
                      ),
                ),
              ),
            ...children,
          ],
        ),
      ),
    );
  }
}

/// Search field with a debounce, shared by every list screen.
class SearchBarField extends StatefulWidget {
  const SearchBarField({
    super.key,
    required this.hint,
    required this.onChanged,
    this.initial,
  });

  final String hint;
  final ValueChanged<String> onChanged;
  final String? initial;

  @override
  State<SearchBarField> createState() => _SearchBarFieldState();
}

class _SearchBarFieldState extends State<SearchBarField> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);
  Object? _token;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    final token = Object();
    _token = token;
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_token == token && mounted) widget.onChanged(v.trim());
    });
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _c,
      onChanged: _onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: widget.hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 21),
        isDense: true,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: Gap.lg, vertical: Gap.md),
        suffixIcon: _c.text.isEmpty
            ? null
            : IconButton(
                icon: const Icon(Icons.close_rounded, size: 19),
                onPressed: () {
                  _c.clear();
                  widget.onChanged('');
                  setState(() {});
                },
              ),
      ),
    );
  }
}

/// Horizontal scroller of filter chips.
class FilterChips<T> extends StatelessWidget {
  const FilterChips({
    super.key,
    required this.options,
    required this.selected,
    required this.onSelected,
    required this.labelOf,
    this.padding = const EdgeInsets.symmetric(horizontal: Gap.lg),
  });

  final List<T> options;
  final T selected;
  final ValueChanged<T> onSelected;
  final String Function(T) labelOf;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: options.length,
        separatorBuilder: (_, __) => const SizedBox(width: Gap.sm),
        itemBuilder: (context, i) {
          final option = options[i];
          final isSelected = option == selected;
          return ChoiceChip(
            label: Text(labelOf(option)),
            selected: isSelected,
            onSelected: (_) => onSelected(option),
            showCheckmark: false,
            backgroundColor: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
            selectedColor: scheme.primary,
            labelStyle: TextStyle(
              color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          );
        },
      ),
    );
  }
}
