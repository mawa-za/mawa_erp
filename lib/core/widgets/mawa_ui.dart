import 'package:flutter/material.dart';

import '../theme/mawa_design.dart';

class MawaSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Border? border;
  final BorderRadius? borderRadius;
  final List<BoxShadow>? boxShadow;

  const MawaSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.border,
    this.borderRadius,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? MawaDesign.surface,
        borderRadius: borderRadius ?? BorderRadius.circular(MawaDesign.cardRadius),
        border: border ?? Border.all(color: MawaDesign.border),
        boxShadow: boxShadow ?? MawaDesign.cardShadow,
      ),
      child: child,
    );
  }
}

class MawaPageHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? eyebrow;
  final List<Widget> actions;

  const MawaPageHeader({
    super.key,
    required this.title,
    this.description,
    this.eyebrow,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 720;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (eyebrow != null) ...[
              eyebrow!,
              const SizedBox(height: 10),
            ],
            Text(title, style: theme.textTheme.headlineMedium),
            if (description != null && description!.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Text(
                  description!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: MawaDesign.textMuted,
                  ),
                ),
              ),
            ],
          ],
        );
        if (actions.isEmpty) return content;
        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              content,
              const SizedBox(height: 18),
              Wrap(spacing: 10, runSpacing: 10, children: actions),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: content),
            const SizedBox(width: 24),
            Wrap(spacing: 10, runSpacing: 10, children: actions),
          ],
        );
      },
    );
  }
}

class MawaSectionHeader extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? trailing;

  const MawaSectionHeader({
    super.key,
    required this.title,
    this.description,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (description != null && description!.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  description!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: MawaDesign.textMuted,
                  ),
                ),
              ],
            ],
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 16),
          trailing!,
        ],
      ],
    );
  }
}

class MawaIconBadge extends StatelessWidget {
  final IconData icon;
  final Color color;
  final double size;

  const MawaIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: MawaDesign.iconBackground(color),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: color, size: size * 0.5),
    );
  }
}

class MawaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Widget? action;
  final EdgeInsetsGeometry padding;

  const MawaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: MawaDesign.surfaceMuted,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: MawaDesign.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: const BoxDecoration(
              color: MawaDesign.surface,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: MawaDesign.textMuted, size: 25),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          const SizedBox(height: 5),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: MawaDesign.textMuted),
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 18),
            action!,
          ],
        ],
      ),
    );
  }
}

class MawaMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String? supportingText;
  final IconData icon;
  final Color color;

  const MawaMetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.supportingText,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return MawaSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: MawaDesign.textMuted,
                  ),
                ),
                const SizedBox(height: 10),
                Text(value, style: theme.textTheme.headlineSmall),
                if (supportingText != null) ...[
                  const SizedBox(height: 5),
                  Text(
                    supportingText!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: MawaDesign.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 14),
          MawaIconBadge(icon: icon, color: color, size: 42),
        ],
      ),
    );
  }
}

class MawaDialogHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onClose;

  const MawaDialogHeader({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MawaIconBadge(icon: icon, color: MawaDesign.red, size: 48),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                description,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: MawaDesign.textMuted,
                ),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: 'Close',
            onPressed: onClose,
            icon: const Icon(Icons.close_rounded),
          ),
      ],
    );
  }
}
