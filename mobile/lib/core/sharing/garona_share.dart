import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

final class GaronaSharePayload {
  const GaronaSharePayload({required this.title, required this.text});

  final String title;
  final String text;
}

abstract final class GaronaShare {
  static const _channel = MethodChannel(
    'br.com.garagem.garagem_mobile/share',
  );

  static Future<void> open(GaronaSharePayload payload) =>
      _channel.invokeMethod<void>('shareText', {
        'title': payload.title,
        'text': payload.text,
      });
}

final class GaronaShareAction extends StatefulWidget {
  const GaronaShareAction({
    required this.payload,
    required this.tooltip,
    super.key,
  });

  final GaronaSharePayload payload;
  final String tooltip;

  @override
  State<GaronaShareAction> createState() => _GaronaShareActionState();
}

final class _GaronaShareActionState extends State<GaronaShareAction> {
  bool _opening = false;

  Future<void> _share() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await GaronaShare.open(widget.payload);
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
