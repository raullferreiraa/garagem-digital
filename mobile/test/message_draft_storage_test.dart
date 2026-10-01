import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/features/messages/message_draft_storage.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('limpar tokens preserva rascunhos das contas no dispositivo', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const tokens = SecureTokenStorage();
    const drafts = MessageDraftStorage();
    await tokens.write(accessToken: 'access', refreshToken: 'refresh');
    await drafts.save('ana', 'direct', 'chat', 'Mensagem pendente');
    await drafts.save(
        'bia', 'evolution-comment', 'evolution', 'Comentário pendente');
    await tokens.clear();
    expect(await tokens.readAccessToken(), isNull);
    expect(await tokens.readRefreshToken(), isNull);
    expect(await drafts.read('ana', 'direct', 'chat'), 'Mensagem pendente');
    expect(await drafts.read('bia', 'evolution-comment', 'evolution'),
        'Comentário pendente');
  });

  test('rascunhos ficam separados por conta e conversa e somem após envio',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    const drafts = MessageDraftStorage();

    await drafts.save('ana', 'direct', 'chat-1', '  Olá, pessoal  ');
    await drafts.save('ana', 'team', 'chat-1', 'Equipe');
    expect(await drafts.read('ana', 'direct', 'chat-1'), '  Olá, pessoal  ');
    expect(await drafts.read('ana', 'team', 'chat-1'), 'Equipe');
    expect(await drafts.read('bia', 'direct', 'chat-1'), isNull);
    expect(await drafts.read('ana', 'direct', 'chat-2'), isNull);

    final olderWrite = drafts.save('ana', 'direct', 'chat-1', 'Antigo');
    final latestWrite = drafts.save('ana', 'direct', 'chat-1', 'Novo');
    expect(await drafts.read('ana', 'direct', 'chat-1'), 'Novo');
    await Future.wait([olderWrite, latestWrite]);

    await drafts.save('ana', 'direct', 'chat-1', '');
    expect(await drafts.read('ana', 'direct', 'chat-1'), isNull);
    expect(await drafts.read('ana', 'team', 'chat-1'), 'Equipe');
  });
}
