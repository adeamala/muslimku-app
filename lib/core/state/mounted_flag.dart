import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether one build of a provider is still current.
///
/// A Riverpod `Notifier` instance is reused when its provider rebuilds, so
/// async work started in `build` takes the flag of that build and checks it
/// before writing state:
///
/// ```dart
/// @override
/// int build() {
///   _load(MountedFlag(ref));
///   return 0;
/// }
///
/// Future<void> _load(MountedFlag alive) async {
///   final saved = await read();
///   if (!alive.mounted) return; // rebuilt or disposed meanwhile
///   state = saved;
/// }
/// ```
class MountedFlag {
  MountedFlag(Ref<Object?> ref) {
    ref.onDispose(() => _mounted = false);
  }

  bool _mounted = true;

  bool get mounted => _mounted;
}
