import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GaronaNavigation extends StatelessWidget {
  const GaronaNavigation({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    this.unreadMessages = 0,
    this.unreadTeamMessages = 0,
    this.hasTeam = false,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadMessages;
  final int unreadTeamMessages;
  final bool hasTeam;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('Explorar', Icons.explore_outlined, Icons.explore_rounded),
      ('Encontros', Icons.flag_outlined, Icons.flag_rounded),
      (
        hasTeam ? 'Minha equipe' : 'Equipes',
        Icons.groups_outlined,
        Icons.groups_rounded,
      ),
      ('Conversas', Icons.forum_outlined, Icons.forum_rounded),
      ('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
    ];
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    // Android gesture/three-button insets sit outside the floating dock.
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 8),
      child: Container(
        key: const ValueKey('navigation-dock'),
        margin: const EdgeInsets.symmetric(horizontal: 12),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [colors.surfaceContainer, colors.surface]),
            border: Border.all(color: colors.outlineVariant)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: Row(
              children: List.generate(items.length, (index) {
            final item = items[index];
            final selected = selectedIndex == index;
            final badgeCount = index == 2
                ? unreadTeamMessages
                : index == 3
                    ? unreadMessages
                    : 0;
            return Expanded(
                child: Semantics(
              button: true,
              selected: selected,
              label: item.$1,
              value: badgeCount > 0 ? '$badgeCount não lidas' : null,
              child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: ValueKey('nav-$index'),
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (!selected) HapticFeedback.selectionClick();
                      onSelected(index);
                    },
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 62),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: ExcludeSemantics(
                            child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                              AnimatedContainer(
                                duration: duration,
                                curve: Curves.easeOutCubic,
                                width: selected ? 18 : 4,
                                height: 2,
                                decoration: BoxDecoration(
                                    color: selected
                                        ? colors.primary
                                        : Colors.transparent,
                                    borderRadius: BorderRadius.circular(2)),
                              ),
                              const SizedBox(height: 6),
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Icon(selected ? item.$3 : item.$2,
                                      size: 23,
                                      color: selected
                                          ? colors.primary
                                          : colors.onSurfaceVariant),
                                  if (badgeCount > 0)
                                    Positioned(
                                      right: -9,
                                      top: -7,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: colors.primary,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                            color: colors.surface,
                                            width: 1.5,
                                          ),
                                        ),
                                        child: Text(
                                          badgeCount > 99
                                              ? '99+'
                                              : '$badgeCount',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            fontSize: 8,
                                            height: 1.2,
                                            fontWeight: FontWeight.w900,
                                            color: colors.onPrimary,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              AnimatedDefaultTextStyle(
                                duration: duration,
                                style: Theme.of(context)
                                    .textTheme
                                    .labelSmall!
                                    .copyWith(
                                        fontSize: 10,
                                        letterSpacing: .1,
                                        fontWeight: selected
                                            ? FontWeight.w800
                                            : FontWeight.w500,
                                        color: selected
                                            ? colors.onSurface
                                            : colors.onSurfaceVariant),
                                child: Text(item.$1,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ])),
                      ),
                    ),
                  )),
            ));
          })),
        ),
      ),
    );
  }
}
