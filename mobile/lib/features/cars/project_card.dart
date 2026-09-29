import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/widgets/gd_premium.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/cars/car.dart';

/// The same project identity in discovery and in personal/public garages.
class GdProjectCard extends StatelessWidget {
  const GdProjectCard(
      {required this.car,
      required this.onTap,
      this.highlighted = false,
      this.compact = false,
      super.key});
  final Car car;
  final VoidCallback onTap;
  final bool highlighted, compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final specs = <(IconData, String)>[
      if (car.engine?.trim().isNotEmpty ?? false)
        (Icons.settings_outlined, car.engine!),
      if (car.estimatedPower?.trim().isNotEmpty ?? false)
        (Icons.speed_rounded, car.estimatedPower!),
      if (car.color?.trim().isNotEmpty ?? false)
        (Icons.palette_outlined, car.color!),
    ];
    return Card(
      child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AspectRatio(
                  aspectRatio: car.photoUrl?.trim().isNotEmpty == true
                      ? (compact ? 16 / 9 : 16 / 10)
                      : (compact ? 2.2 : 2),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      GdImage(url: car.photoUrl, semanticLabel: car.model),
                      const DecoratedBox(
                          decoration: BoxDecoration(
                              gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x22000000),
                          Color(0x00000000),
                          Color(0x880B0E12)
                        ],
                        stops: [0, .6, 1],
                      ))),
                      Positioned(
                          left: 14,
                          right: 14,
                          bottom: 14,
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              if (highlighted)
                                const GdBadge(
                                    label: 'Seu projeto',
                                    icon: Icons.garage_outlined,
                                    accent: true,
                                    onImage: true),
                              if (car.projectStatus?.trim().isNotEmpty ?? false)
                                GdBadge(
                                    label: car.projectStatus!, onImage: true),
                            ],
                          )),
                    ],
                  )),
              Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                                child: Text(car.model,
                                    style: theme.textTheme.headlineMedium,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis)),
                            if (car.year != null) ...[
                              const SizedBox(width: 10),
                              GdBadge(label: '${car.year}')
                            ],
                          ]),
                      if (!compact) ...[
                        const SizedBox(height: 14),
                        Row(children: [
                          GdAvatar(
                              url: car.ownerAvatarUrl,
                              name: car.ownerName,
                              size: 30),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text('@${car.ownerUsername}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: theme.textTheme.labelLarge)),
                          if (car.likesCount > 0) ...[
                            Icon(Icons.favorite_border_rounded,
                                size: 15, color: colors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('${car.likesCount}',
                                style: theme.textTheme.labelSmall),
                          ],
                          if (car.commentsCount > 0) ...[
                            const SizedBox(width: 12),
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 15, color: colors.onSurfaceVariant),
                            const SizedBox(width: 4),
                            Text('${car.commentsCount}',
                                style: theme.textTheme.labelSmall),
                          ],
                        ]),
                        if (car.history?.trim().isNotEmpty ?? false) ...[
                          const SizedBox(height: 12),
                          Text(car.history!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: colors.onSurfaceVariant)),
                        ],
                      ],
                      if (specs.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Wrap(spacing: 6, runSpacing: 6, children: [
                          for (final spec in specs.take(compact ? 2 : 3))
                            GdBadge(icon: spec.$1, label: spec.$2),
                        ]),
                      ],
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(
                            child: Text('Abrir projeto',
                                style: theme.textTheme.labelLarge
                                    ?.copyWith(color: colors.primary))),
                        Icon(Icons.arrow_forward_rounded,
                            size: 18, color: colors.primary),
                      ]),
                    ],
                  )),
            ],
          )),
    );
  }
}
