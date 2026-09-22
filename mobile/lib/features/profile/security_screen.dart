import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/core/widgets/gd_ui.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';

final class SecurityScreen extends StatefulWidget {
  const SecurityScreen({required this.session, super.key});

  final SessionController session;

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

final class _SecurityScreenState extends State<SecurityScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.session.changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Senha atualizada. Os outros dispositivos precisarão entrar novamente.',
          ),
        ),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Segurança')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            GdReveal(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: colors.surfaceContainer,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: colors.outlineVariant),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.enhanced_encryption_outlined,
                      color: colors.primary,
                      size: 34,
                    ),
                    const SizedBox(height: 18),
                    Text(
                      'Acesso sob seu controle',
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ao trocar a senha, os outros dispositivos perderão o '
                      'acesso em até 15 minutos. Este aparelho continuará '
                      'conectado.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            const GdSectionTitle(
              title: 'Alterar senha',
              eyebrow: 'PROTEÇÃO DA CONTA',
            ),
            const SizedBox(height: 18),
            _PasswordField(
              controller: _currentPassword,
              label: 'Senha atual',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _newPassword,
              label: 'Nova senha',
              helperText: 'Use pelo menos 8 caracteres.',
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              validator: (value) {
                final baseError = _validatePassword(value);
                if (baseError != null) return baseError;
                if (value == _currentPassword.text) {
                  return 'Use uma senha diferente da atual.';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            _PasswordField(
              controller: _confirmation,
              label: 'Confirmar nova senha',
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) => _submit(),
              validator: (value) {
                final baseError = _validatePassword(value);
                if (baseError != null) return baseError;
                if (value != _newPassword.text) {
                  return 'As senhas não coincidem.';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.lock_reset_rounded),
              label: Text(_saving ? 'Atualizando...' : 'Atualizar senha'),
            ),
          ],
        ),
      ),
    );
  }
}

String? _validatePassword(String? value) {
  if (value == null || value.isEmpty) return 'Informe a senha.';
  if (value.length < 8) return 'Use pelo menos 8 caracteres.';
  return null;
}

final class _PasswordField extends StatefulWidget {
  const _PasswordField({
    required this.controller,
    required this.label,
    required this.textInputAction,
    required this.autofillHints,
    this.helperText,
    this.onFieldSubmitted,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final String? helperText;
  final TextInputAction textInputAction;
  final Iterable<String> autofillHints;
  final ValueChanged<String>? onFieldSubmitted;
  final FormFieldValidator<String>? validator;

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

final class _PasswordFieldState extends State<_PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.visiblePassword,
      textInputAction: widget.textInputAction,
      autofillHints: widget.autofillHints,
      onFieldSubmitted: widget.onFieldSubmitted,
      validator: widget.validator ?? _validatePassword,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.key_rounded),
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
          icon: Icon(
            _obscure
                ? Icons.visibility_outlined
                : Icons.visibility_off_outlined,
          ),
        ),
      ),
    );
  }
}
