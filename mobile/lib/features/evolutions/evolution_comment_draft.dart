import 'dart:convert';

import 'package:garagem_mobile/features/messages/message_draft_storage.dart';

final class EvolutionCommentDraft {
  const EvolutionCommentDraft(this.text, this.replyToId);

  final String text;
  final String? replyToId;

  static EvolutionCommentDraft? decode(String? value) {
    if (value == null) return null;
    try {
      final data = jsonDecode(value) as Map<String, Object?>;
      return EvolutionCommentDraft(
        data['text'] as String? ?? '',
        data['replyToId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  String encode() => jsonEncode({'text': text, 'replyToId': replyToId});
}

final class EvolutionCommentDraftStorage {
  const EvolutionCommentDraftStorage();

  static const _storage = MessageDraftStorage();

  Future<EvolutionCommentDraft?> read(
          String userId, String evolutionId) async =>
      EvolutionCommentDraft.decode(
        await _storage.read(userId, 'evolution-comment', evolutionId),
      );

  Future<void> save(
          String userId, String evolutionId, EvolutionCommentDraft draft) =>
      _storage.save(userId, 'evolution-comment', evolutionId,
          draft.text.trim().isEmpty ? '' : draft.encode());
}
