import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GdNavigation extends StatelessWidget {
  const GdNavigation(
      {super.key,
      required this.selectedIndex,
      required this.onSelected,
      this.unreadCount = 0});
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final int unreadCount;

  static const _items = [
    ('Explorar', Icons.explore_outlined, Icons.explore_rounded),
    ('Garagem', Icons.garage_outlined, Icons.garage_rounded),
    ('Equipes', Icons.groups_outlined, Icons.groups_rounded),
    ('Perfil', Icons.person_outline_rounded, Icons.person_rounded),
    ('Avisos', Icons.notifications_outlined, Icons.notifications_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return DecoratedBox(
      decoration: BoxDecoration(
          color: colors.surface,
          border: Border(top: BorderSide(color: colors.outlineVariant))),
      child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: Row(
                children: List.generate(_items.length, (index) {
              final item = _items[index];
              final selected = selectedIndex == index;
              return Expanded(
                  child: Semantics(
                button: true,
                selected: selected,
                label: item.$1,
                value: index == 4 && unreadCount > 0
                    ? '$unreadCount não lidos'
                    : null,
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
                        constraints: const BoxConstraints(minHeight: 64),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: ExcludeSemantics(
                              child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                AnimatedContainer(
                                  duration: duration,
                                  curve: Curves.easeOutCubic,
                                  width: selected ? 24 : 4,
                                  height: 3,
                                  decoration: BoxDecoration(
                                      color: selected
                                          ? colors.primary
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(2)),
                                ),
                                const SizedBox(height: 6),
                                Badge(
                                  isLabelVisible: index == 4 && unreadCount > 0,
                                  label: Text(unreadCount > 99
                                      ? '99+'
                                      : '$unreadCount'),
                                  backgroundColor: colors.primary,
                                  textColor: colors.onPrimary,
                                  child: AnimatedScale(
                                      scale: selected ? 1.08 : 1,
                                      duration: duration,
                                      child: Icon(selected ? item.$3 : item.$2,
                                          size: 23,
                                          color: selected
                                              ? colors.primary
                                              : colors.onSurfaceVariant)),
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
          )),
    );
  }
}
