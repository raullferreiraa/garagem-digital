import 'package:flutter/material.dart';

/// Forms must keep offscreen fields registered with FormState for validation.
class FormScrollView extends StatelessWidget {
  const FormScrollView(
      {required this.children,
      this.padding,
      this.keyboardDismissBehavior = ScrollViewKeyboardDismissBehavior.onDrag,
      super.key});
  final List<Widget> children;
  final EdgeInsetsGeometry? padding;
  final ScrollViewKeyboardDismissBehavior keyboardDismissBehavior;

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: padding,
        keyboardDismissBehavior: keyboardDismissBehavior,
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch, children: children),
      );
}

/// Bring the first invalid field into view, including in long forms.
bool validateAndReveal(GlobalKey<FormState> key) {
  final fields = key.currentState!.validateGranularly();
  if (fields.isEmpty) return true;
  final first = fields.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!first.mounted) return;
    Scrollable.ensureVisible(first.context,
        alignment: .15,
        duration: MediaQuery.disableAnimationsOf(first.context)
            ? Duration.zero
            : const Duration(milliseconds: 250));
  });
  return false;
}
