import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/core/theme/app_theme.dart';
import 'package:garagem_mobile/core/widgets/chat_message_bubble.dart';

void main() {
  testWidgets('mensagem enviada usa laranja queimado e destaque contrastante',
      (tester) async {
    Future<BoxDecoration> render({required bool highlighted}) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: ChatMessageBubble(
            messageId: 'message',
            content: 'Mensagem',
            createdAt: DateTime(2026, 9, 26, 19, 21),
            mine: true,
            deleted: false,
            edited: false,
            highlighted: highlighted,
          ),
        ),
      ));
      await tester.pumpAndSettle();
      return tester
          .widget<AnimatedContainer>(find.byType(AnimatedContainer))
          .decoration! as BoxDecoration;
    }

    final normal = await render(highlighted: false);
    expect(normal.color, isNot(AppColors.primary));
    expect(normal.color, isNot(AppColors.surfaceStrong));
    expect((normal.border! as Border).top.width, 1);

    final highlighted = await render(highlighted: true);
    final border = highlighted.border! as Border;
    expect(border.top.color, AppColors.secondary);
    expect(border.top.width, 3);
    expect(highlighted.color, isNot(normal.color));
    expect(highlighted.boxShadow, isNotEmpty);
  });

  testWidgets('texto enviado usa contraste claro', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Scaffold(
        body: ChatMessageBubble(
          messageId: 'message',
          content: 'Mensagem enviada',
          createdAt: DateTime(2026, 9, 26, 19, 21),
          mine: true,
          deleted: false,
          edited: false,
        ),
      ),
    ));
    final text = tester.widget<Text>(find.text('Mensagem enviada'));
    expect(text.style?.color, AppColors.text);
  });
}
