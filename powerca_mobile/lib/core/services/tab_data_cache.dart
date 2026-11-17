/// In-memory cache of the last data each main page loaded.
///
/// The bottom-nav tabs are separate routes that get replaced on every
/// switch, so their state is rebuilt from scratch. Pages read their last
/// result from here to render instantly, then refresh quietly in the
/// background (no spinner). Keys include the staff id, and the cache is
/// cleared on sign-out.
class TabDataCache {
  TabDataCache._();

  static final Map<String, Object> _store = {};

  static T? read<T>(String key) {
    final value = _store[key];
    return value is T ? value : null;
  }

  static void write(String key, Object value) => _store[key] = value;

  static void clear() => _store.clear();
}
