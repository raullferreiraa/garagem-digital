import 'dart:async';

import 'package:flutter/material.dart';
import 'package:garagem_mobile/core/network/api_client.dart';
import 'package:garagem_mobile/features/messages/message_reply.dart';

final class HistoryMessage {
  const HistoryMessage(this.message, this.createdAt, {this.edited = false});
  final MessageReply message;
  final DateTime createdAt;
  final bool edited;
}

final class HistoryPage {
  const HistoryPage(this.items, this.nextCursor);
  final List<HistoryMessage> items;
  final String? nextCursor;
}

String _date(DateTime value) {
  final date = value.toLocal();
  String pad(int n) => n.toString().padLeft(2, '0');
  return '${pad(date.day)}/${pad(date.month)}/${date.year} · ${pad(date.hour)}:${pad(date.minute)}';
}

class MessageHistoryScreen extends StatefulWidget {
  const MessageHistoryScreen(
      {required this.load, required this.author, super.key});
  final Future<HistoryPage> Function(String query, String? cursor) load;
  final String Function(MessageReply) author;

  @override
  State<MessageHistoryScreen> createState() => _MessageHistoryScreenState();
}

class _MessageHistoryScreenState extends State<MessageHistoryScreen> {
  final _query = TextEditingController();
  final _scroll = ScrollController();
  Timer? _debounce;
  List<HistoryMessage> _items = [];
  String? _cursor;
  Object? _error;
  bool _loading = false;
  bool _searched = false;
  int _request = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _changed(String value) {
    _debounce?.cancel();
    ++_request;
    setState(() {
      _items = [];
      _cursor = null;
      _error = null;
      _searched = false;
      _loading = value.trim().length >= 2;
    });
    if (_loading)
      _debounce = Timer(const Duration(milliseconds: 350), () => _search());
  }

  Future<void> _search({bool more = false}) async {
    _debounce?.cancel();
    final query = _query.text.trim();
    if (query.length < 2 || (more && (_loading || _cursor == null))) return;
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await widget.load(query, more ? _cursor : null);
      if (!mounted || request != _request) return;
      final known = more ? _items.map((e) => e.message.id).toSet() : <String>{};
      setState(() {
        _items = [
          if (more) ..._items,
          ...page.items.reversed.where((e) => known.add(e.message.id))
        ];
        _cursor = page.nextCursor;
        _searched = true;
      });
      if (!more && _scroll.hasClients) _scroll.jumpTo(0);
    } catch (error) {
      if (!mounted || request != _request) return;
      // Do not leave previously fetched content visible after access is revoked.
      setState(() {
        _items = [];
        _cursor = null;
        _error = error;
      });
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Buscar na conversa')),
        body: Column(children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _query,
              autofocus: true,
              maxLength: 100,
              textInputAction: TextInputAction.search,
              onChanged: _changed,
              onSubmitted: (_) => _search(),
              decoration: InputDecoration(
                hintText: 'Buscar mensagem',
                counterText: '',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpar busca',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () {
                          _query.clear();
                          _changed('');
                        },
                      ),
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
              child: _error != null
                  ? Center(
                      child: Padding(
                          padding: const EdgeInsets.all(24),
                          child:
                              Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(apiErrorMessage(_error!),
                                textAlign: TextAlign.center),
                            TextButton(
                                onPressed: () => _search(),
                                child: const Text('Tentar novamente')),
                          ])))
                  : _items.isEmpty
                      ? Center(
                          child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                _searched
                                    ? 'Nenhuma mensagem encontrada.'
                                    : 'Busque em todo o histórico. Digite pelo menos dois caracteres.',
                                textAlign: TextAlign.center,
                              )))
                      : ListView.separated(
                          controller: _scroll,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _items.length + (_cursor == null ? 0 : 1),
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == _items.length)
                              return TextButton(
                                onPressed:
                                    _loading ? null : () => _search(more: true),
                                child: const Text('Carregar mais resultados'),
                              );
                            final item = _items[index];
                            return ListTile(
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 8, horizontal: 4),
                              title: Text(widget.author(item.message)),
                              subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item.message.displayContent,
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis),
                                    const SizedBox(height: 4),
                                    Text(_date(item.createdAt),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall),
                                  ]),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () =>
                                  Navigator.of(context).pop(item.message.id),
                            );
                          },
                        )),
        ]),
      );
}
