import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/messages/message_draft_storage.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
