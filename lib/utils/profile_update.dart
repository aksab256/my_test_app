// lib/utils/profile_update.dart
//
// Profile update payload for the My Account screen ('/myDetails').
//
// The delivery address is locked: it stays exactly as registered and is
// never written from this screen (no 'address' key, ever) — changing it
// would require the registration-style map + coordinates flow. Only the
// display name is editable: `fullname` for consumers, `name` otherwise.

/// Builds the Firestore update map for a profile name edit.
///
/// Never includes an address key: the address stays fixed as registered.
Map<String, dynamic> buildProfileNameUpdate({
  required bool isConsumerCollection,
  required String name,
}) {
  final String key = isConsumerCollection ? 'fullname' : 'name';
  return <String, dynamic>{key: name.trim()};
}
