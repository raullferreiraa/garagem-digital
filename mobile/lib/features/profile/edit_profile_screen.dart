import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/config/app_config.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/auth/session_controller.dart';
import 'package:garagem_mobile/features/cars/photo_crop_screen.dart';
import 'package:image_picker/image_picker.dart';

final class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({required this.session, super.key});

  final SessionController session;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

final class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _bioController;
  late final TextEditingController _cityController;
  late final TextEditingController _stateController;
  bool _saving = false;
  bool _updatingAvatar = false;

  @override
  void initState() {
    super.initState();
    final user = widget.session.user!;
    _nameController = TextEditingController(text: user.name);
    _bioController = TextEditingController(text: user.bio);
    _cityController = TextEditingController(text: user.city);
    _stateController = TextEditingController(text: user.state);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    super.dispose();
  }

  Future<void> _chooseAvatar() async {
    if (_updatingAvatar) return;
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text(
                'Foto de perfil',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Escolher da galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Usar a câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            if (widget.session.user!.avatarUrl != null)
              ListTile(
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  'Remover foto',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _removeAvatar();
                },
              ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;

    final selected = await ImagePicker().pickImage(
      source: source,
      imageQuality: 95,
      maxWidth: 4096,
      maxHeight: 4096,
    );
    if (selected == null || !mounted) return;
    final selectedBytes = await selected.readAsBytes();
    if (!mounted) return;

    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => PhotoCropScreen(
          image: selectedBytes,
          aspectRatio: 1,
          title: 'Enquadrar perfil',
          instructions: 'Centralize seu rosto e ajuste o enquadramento.',
        ),
      ),
    );
    if (cropped == null || !mounted) return;

    setState(() => _updatingAvatar = true);
    try {
      await widget.session.uploadAvatar(
        bytes: cropped,
        fileName: 'avatar.jpg',
      );
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil atualizada.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Future<void> _removeAvatar() async {
    setState(() => _updatingAvatar = true);
    try {
      await widget.session.removeAvatar();
      if (!mounted) return;
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil removida.')),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(apiErrorMessage(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _updatingAvatar = false);
    }
  }

  Widget _avatarEditor() {
    final user = widget.session.user!;
    final avatarUrl = AppConfig.resolveApiUrl(user.avatarUrl);
    return Center(
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 54,
                backgroundImage:
                    avatarUrl == null ? null : NetworkImage(avatarUrl),
                child: avatarUrl == null
                    ? Text(
                        user.name.substring(0, 1).toUpperCase(),
                        style: Theme.of(context).textTheme.headlineLarge,
                      )
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: IconButton.filled(
                  onPressed: _updatingAvatar ? null : _chooseAvatar,
                  tooltip: 'Alterar foto',
                  icon: _updatingAvatar
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.camera_alt_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _updatingAvatar ? null : _chooseAvatar,
            child: const Text('Alterar foto de perfil'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await widget.session.updateProfile(
        name: _nameController.text,
        bio: _bioController.text,
        city: _cityController.text,
        state: _stateController.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(apiErrorMessage(error))),
      );
      setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            children: [
              Text(
                'Sua identidade na garagem',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Essas informações aparecem no seu perfil e ajudam outros entusiastas a conhecer você.',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 22),
              _avatarEditor(),
              const SizedBox(height: 22),
              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                maxLength: 100,
                decoration: const InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) {
                  if ((value ?? '').trim().length < 2) {
                    return 'Informe um nome com pelo menos 2 caracteres.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 280,
                minLines: 3,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Sobre você',
                  hintText: 'Conte sua relação com carros e projetos.',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _cityController,
                      textCapitalization: TextCapitalization.words,
                      maxLength: 120,
                      decoration: const InputDecoration(
                        labelText: 'Cidade',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _stateController,
                      textCapitalization: TextCapitalization.characters,
                      maxLength: 120,
                      decoration: const InputDecoration(labelText: 'Estado'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_saving ? 'Salvando...' : 'Salvar alterações'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
