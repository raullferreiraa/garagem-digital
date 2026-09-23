import 'dart:typed_data';
import 'package:garagem_mobile/core/widgets/form_photo.dart';
import 'package:garagem_mobile/core/widgets/form_validation.dart';
import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';

final class RegisterScreen extends StatefulWidget {
  const RegisterScreen({required this.session, super.key});

  final SessionController session;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  Uint8List? _photo;
  bool _showPassword = false;

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    FocusScope.of(context).unfocus();
    if (!validateAndReveal(_formKey)) return;
    setState(() => _submitting = true);
    try {
      await widget.session.register(
        name: _name.text.trim(),
        username: _username.text.trim().toLowerCase(),
        email: _email.text.trim().toLowerCase(),
        password: _password.text,
      );
      if (_photo != null && mounted) {
        await uploadFormPhoto<bool>(context, false, () async {
          await widget.session
              .uploadAvatar(bytes: _photo!, fileName: 'perfil.jpg');
          return true;
        });
      }
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSaveGuard(
        saving: _submitting,
        child: Scaffold(
          appBar: AppBar(title: const Text('Criar conta')),
          body: SafeArea(
            child: Center(
                child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: AutofillGroup(
                    child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const GdReveal(
                          child: AuthRacingHeader(
                        title: 'Toda paixão',
                        accent: 'tem um começo.',
                        description:
                            'Crie seu perfil e dê um lugar para a história '
                            'do seu projeto.',
                        compact: true,
                      )),
                      const SizedBox(height: 28),
                      FormPhoto(
                          label: 'Foto do perfil',
                          bytes: _photo,
                          aspectRatio: 1,
                          enabled: !_submitting,
                          onChanged: (value) => setState(() => _photo = value)),
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.next,
                        textCapitalization: TextCapitalization.words,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                            labelText: 'Nome',
                            prefixIcon: Icon(Icons.person_outline_rounded)),
                        validator: (value) =>
                            value == null || value.trim().length < 2
                                ? 'Informe seu nome.'
                                : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _username,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.newUsername],
                        decoration: const InputDecoration(
                          labelText: 'Nome de usuário',
                          prefixText: '@',
                          prefixIcon: Icon(Icons.alternate_email_rounded),
                        ),
                        validator: (value) {
                          final username = value?.trim() ?? '';
                          return RegExp(r'^[a-z0-9._]{3,30}$')
                                  .hasMatch(username)
                              ? null
                              : 'Use 3 a 30 letras minúsculas, números, ponto ou _.';
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded)),
                        validator: (value) =>
                            value != null && value.contains('@')
                                ? null
                                : 'Informe um email válido.',
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: !_showPassword,
                        autofillHints: const [AutofillHints.newPassword],
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Senha',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          helperText: 'Pelo menos 8 caracteres.',
                          suffixIcon: IconButton(
                            tooltip: _showPassword
                                ? 'Ocultar senha'
                                : 'Mostrar senha',
                            onPressed: () =>
                                setState(() => _showPassword = !_showPassword),
                            icon: Icon(_showPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined),
                          ),
                        ),
                        validator: (value) => value == null || value.length < 8
                            ? 'Use pelo menos 8 caracteres.'
                            : null,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _submitting ? null : _submit,
                          child: _submitting
                              ? const SizedBox.square(
                                  dimension: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Flexible(
                                        child: Text('Criar conta',
                                            textAlign: TextAlign.center)),
                                    SizedBox(width: 12),
                                    Icon(Icons.arrow_forward_rounded, size: 20)
                                  ],
                                ),
                        ),
                      ),
                    ],
                  ),
                )),
              ),
            )),
          ),
        ));
  }
}

/// Marca e traçado de pista compartilhados pelas telas de acesso.
final class AuthRacingHeader extends StatelessWidget {
  const AuthRacingHeader({
    required this.title,
    required this.accent,
    required this.description,
    this.compact = false,
    super.key,
  });

  final String title;
  final String accent;
  final String description;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final typography = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const GdWordmark(),
        const SizedBox(height: 24),
        if (!compact) ...[
          ExcludeSemantics(
            child: SizedBox(
              height: 88,
              width: double.infinity,
              child: CustomPaint(
                  painter: _TrackPainter(
                      accent: colors.primary, line: colors.outlineVariant)),
            ),
          ),
          const SizedBox(height: 24),
        ],
        Text(title,
            style: typography.displaySmall
                ?.copyWith(height: 1, fontWeight: FontWeight.w700)),
        Text(accent,
            style: typography.displaySmall?.copyWith(
                height: 1.08,
                color: colors.primary,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 16),
        Text(description,
            style: typography.bodyMedium
                ?.copyWith(color: colors.onSurfaceVariant, height: 1.6)),
      ],
    );
  }
}

final class _TrackPainter extends CustomPainter {
  const _TrackPainter({required this.accent, required this.line});

  final Color accent;
  final Color line;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    final guide = Paint()
      ..color = line
      ..strokeWidth = 1;
    for (var x = 0.0; x < size.width; x += 24) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), guide);
    }
    for (var y = 0.0; y < size.height; y += 22) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), guide);
    }
    final track = Path()
      ..moveTo(-12, size.height * .8)
      ..lineTo(size.width * .30, size.height * .8)
      ..cubicTo(size.width * .47, size.height * .8, size.width * .45,
          size.height * .23, size.width * .61, size.height * .23)
      ..lineTo(size.width + 12, size.height * .23);
    canvas.drawPath(
        track,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 14);
    canvas.drawPath(
        track.shift(const Offset(0, 18)),
        Paint()
          ..color = accent.withValues(alpha: .35)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _TrackPainter oldDelegate) =>
      accent != oldDelegate.accent || line != oldDelegate.line;
}
