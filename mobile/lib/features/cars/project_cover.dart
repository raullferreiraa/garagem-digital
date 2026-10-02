import 'package:flutter/material.dart';
import 'package:garona_mobile/core/widgets/garona_ui.dart';
import 'package:garona_mobile/core/widgets/garona_premium.dart';
import 'car.dart';

final class ProjectCover extends StatelessWidget {
  const ProjectCover({
    required this.car,
    this.canManage = false,
    this.updatingPhoto = false,
    this.onPhotoTap,
    this.onViewPhoto,
    this.previewImage,
    super.key,
  });

  final Car car;
  final bool canManage;
  final bool updatingPhoto;
  final VoidCallback? onPhotoTap;
  final VoidCallback? onViewPhoto;
  final Widget? previewImage;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceContainer,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colors.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 8, 4),
            child: Row(
              children: [
                const GaronaLightSignature(width: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('GARONA / PROJETO',
                      style: theme.textTheme.labelSmall?.copyWith(
                        letterSpacing: 1.6,
                        color: colors.onSurfaceVariant,
                      )),
                ),
                if (car.photoUrl != null && onViewPhoto != null)
                  IconButton(
                    onPressed: onViewPhoto,
                    tooltip: 'Ver foto inteira',
                    icon: const Icon(Icons.zoom_out_map_rounded, size: 20),
                  ),
              ],
            ),
          ),
          AspectRatio(
            aspectRatio: 16 / 10,
            child: Stack(
              fit: StackFit.expand,
              children: [
                ColoredBox(
                  color: colors.surfaceContainerLowest,
                  child: previewImage ??
                      GaronaImage(
                        url: car.photoUrl,
                        semanticLabel: car.model,
                        fit: BoxFit.contain,
                      ),
                ),
                if (car.photoUrl != null && onViewPhoto != null)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: onViewPhoto,
                      child: const SizedBox.expand(),
                    ),
                  ),
                if (updatingPhoto)
                  ColoredBox(
                    color: colors.scrim.withValues(alpha: .4),
                    child: const Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 14, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text(car.displayName,
                            style: theme.textTheme.headlineLarge?.copyWith(
                                fontFamily: 'BarlowCondensed',
                                fontWeight: FontWeight.w700,
                                fontSize: 34,
                                height: 1.05)),
                        if (car.projectName != null || car.year != null)
                          Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                  [
                                    if (car.projectName != null) car.model,
                                    if (car.year != null) '${car.year}'
                                  ].join(' · '),
                                  style: theme.textTheme.labelLarge
                                      ?.copyWith(color: colors.secondary))),
                      ])),
                  if (canManage && !updatingPhoto) ...[
                    const SizedBox(width: 12),
                    IconButton.filledTonal(
                        onPressed: onPhotoTap,
                        tooltip: 'Alterar foto principal',
                        icon: const Icon(Icons.add_a_photo_outlined)),
                  ],
                ]),
                if (car.proposal != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(car.proposal!)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
