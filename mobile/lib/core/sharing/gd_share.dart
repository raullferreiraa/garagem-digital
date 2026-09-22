import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class GdSharePayload {
  const GdSharePayload({required this.title, required this.text});

  final String title;
  final String text;
}

abstract final class GdShare {
  static const _channel = MethodChannel(
    'br.com.garagem.garagem_mobile/share',
  );

  static Future<void> open(GdSharePayload payload) =>
      _channel.invokeMethod<void>('shareText', {
        'title': payload.title,
        'text': payload.text,
      });
}

final class GdShareAction extends StatefulWidget {
  const GdShareAction({
    required this.payload,
    required this.tooltip,
    super.key,
  });

  final GdSharePayload payload;
  final String tooltip;

  @override
  State<GdShareAction> createState() => _GdShareActionState();
}

final class _GdShareActionState extends State<GdShareAction> {
  bool _opening = false;

  Future<void> _share() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await GdShare.open(widget.payload);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível abrir o compartilhamento.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
        onPressed: _opening ? null : _share,
        tooltip: widget.tooltip,
        icon: _opening
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.ios_share_rounded),
      );
}
