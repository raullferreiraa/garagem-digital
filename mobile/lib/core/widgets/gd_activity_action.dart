import 'package:flutter/material.dart';

/// Provides the activity entry point only to the main tab headers.
class GdActivityScope extends InheritedWidget {
  const GdActivityScope(
      {super.key,
      required this.unreadCount,
      required this.onOpen,
      required super.child});

  final int unreadCount;
  final VoidCallback onOpen;

  @override
  bool updateShouldNotify(GdActivityScope oldWidget) =>
      unreadCount != oldWidget.unreadCount || onOpen != oldWidget.onOpen;
}

class GdActivityAction extends StatelessWidget {
  const GdActivityAction({super.key});

  @override
  Widget build(BuildContext context) {
    final activity =
        context.dependOnInheritedWidgetOfExactType<GdActivityScope>();
    if (activity == null) return const SizedBox.shrink();
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'Notificações',
      value: '${activity.unreadCount} não lidas',
      button: true,
      onTap: activity.onOpen,
      excludeSemantics: true,
      child: IconButton(
        key: const ValueKey('activity-bell'),
        tooltip: 'Notificações',
        onPressed: activity.onOpen,
        icon: Badge(
          isLabelVisible: activity.unreadCount > 0,
          backgroundColor: colors.primary,
          textColor: colors.onPrimary,
          label: Text(
              activity.unreadCount > 99 ? '99+' : '${activity.unreadCount}'),
          child: const Icon(Icons.notifications_outlined),
        ),
      ),
    );
  }
}
