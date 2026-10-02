import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:garona_mobile/core/network/api_client.dart';
import 'package:garona_mobile/core/storage/token_storage.dart';
import 'package:garona_mobile/features/messages/conversation.dart';
import 'package:garona_mobile/features/messages/conversation_screen.dart';
import 'package:garona_mobile/features/messages/messages_repository.dart';
import 'package:garona_mobile/features/teams/team.dart';
import 'package:garona_mobile/features/teams/team_chat_screen.dart';
import 'package:garona_mobile/features/teams/teams_repository.dart';
import 'package:garona_mobile/features/evolutions/evolution.dart';
import 'package:garona_mobile/features/evolutions/evolution_detail_screen.dart';
import 'package:garona_mobile/features/evolutions/evolutions_repository.dart';

class _Tokens implements TokenStorage {
  @override
  Future<String?> readAccessToken() async => null;
  @override
  Future<String?> readRefreshToken() async => null;
  @override
  Future<void> clear() async {}
  @override
  Future<void> write(
      {required String accessToken, required String refreshToken}) async {}
}

void main() {
  for (final kind in ['direct', 'team', 'comment']) {
    for (final failedRead in [false, true]) {
      testWidgets(
          'preserva rascunho $kind ao sair com leitura ${failedRead ? 'falha' : 'pendente'}',
          (tester) async {
        const channel =
            MethodChannel('plugins.it_nomads.com/flutter_secure_storage');
        final read = Completer<String?>();
        var stored = 'Rascunho existente';
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel,
            (call) async {
          if (call.method == 'read') return read.future;
          if (call.method == 'delete') stored = '';
          if (call.method == 'write')
            stored = (call.arguments as Map)['value'] as String;
          return null;
        });
        addTearDown(() => tester.binding.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null));
        final api =
            ApiClient(baseUrl: 'http://localhost', tokenStorage: _Tokens());
        api.dio.interceptors
            .add(InterceptorsWrapper(onRequest: (options, handler) {
          handler.resolve(Response(requestOptions: options, data: {
            'itens': <Object?>[],
            'proximo_cursor': null,
            'total_curtidas': 0,
            'curtido_por_mim': false,
            'comentarios': <Object?>[]
          }));
        }));
        final screen = kind == 'comment'
            ? EvolutionDetailScreen(
                evolution: Evolution(
                    id: 'evo',
                    carId: 'car',
                    title: 'Reforma',
                    description: 'Projeto',
                    authorName: 'Raul',
                    authorUsername: 'raul',
                    createdAt: DateTime(2026)),
                repository: EvolutionsRepository(api),
                currentUserId: 'user')
            : kind == 'team'
                ? TeamChatScreen(
                    team: const Team(
                        id: 'chat',
                        name: 'Equipe',
                        slug: 'equipe',
                        visibility: 'publica',
                        memberCount: 1),
                    repository: TeamsRepository(api),
                    currentUserId: 'user')
                : ConversationScreen(
                    conversation: DirectConversation(
                        id: 'chat',
                        otherUser: const ConversationUser(
                            id: 'other', name: 'Outro', username: 'outro'),
                        unreadCount: 0,
                        createdAt: DateTime(2026),
                        updatedAt: DateTime(2026)),
                    repository: MessagesRepository(api),
                    currentUserId: 'user',
                    onProfileTap: (_) {},
                    onChanged: () {});
        await tester.pumpWidget(MaterialApp(home: screen));
        await tester.pump();
        if (failedRead) {
          read.completeError(
              PlatformException(code: 'temporarily-unavailable'));
          await tester.pumpAndSettle();
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        if (!failedRead) read.complete('Rascunho existente');
        await tester.pumpAndSettle();
        expect(stored, 'Rascunho existente');
        expect(tester.takeException(), isNull);
      });
    }
  }
}
