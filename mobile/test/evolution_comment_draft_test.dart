import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garagem_mobile/features/evolutions/evolution_comment_draft.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('rascunho preserva texto e comentário respondido por conta e evolução',
      () async {
    FlutterSecureStorage.setMockInitialValues({});
    const storage = EvolutionCommentDraftStorage();
    await storage.save('autor', 'evolucao-1',
        const EvolutionCommentDraft('Resposta', 'pai-1'));
    final restored = await storage.read('autor', 'evolucao-1');
    expect(restored?.text, 'Resposta');
    expect(restored?.replyToId, 'pai-1');
    expect(await storage.read('outro', 'evolucao-1'), isNull);
    expect(await storage.read('autor', 'evolucao-2'), isNull);

    await storage.save(
        'autor', 'evolucao-1', const EvolutionCommentDraft('', null));
    expect(await storage.read('autor', 'evolucao-1'), isNull);
  });
}
