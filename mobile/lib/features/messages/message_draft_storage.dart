import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Keeps a draft separate for each account and conversation on this device.
final class MessageDraftStorage {
  const MessageDraftStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;
  static final _pendingWrites = <String, Future<void>>{};

  String _key(String userId, String kind, String id) =>
      'message_draft:$userId:$kind:$id';

  Future<String?> read(String userId, String kind, String id) async {
    final key = _key(userId, kind, id);
    await _pendingWrites[key]?.catchError((Object _) {});
    return _storage.read(key: key);
  }

  Future<void> save(String userId, String kind, String id, String text) {
    final key = _key(userId, kind, id);
    final previous = _pendingWrites[key] ?? Future<void>.value();
    final next = previous.catchError((Object _) {}).then((_) =>
        text.trim().isEmpty
            ? _storage.delete(key: key)
            : _storage.write(key: key, value: text));
    _pendingWrites[key] = next;
    next.then((_) {
      if (identical(_pendingWrites[key], next)) _pendingWrites.remove(key);
    }, onError: (Object _) {
      if (identical(_pendingWrites[key], next)) _pendingWrites.remove(key);
    });
    return next;
  }
}
