import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_test_app/services/user_session.dart';

void main() {
  setUp(() {
    UserSession.clear();
    SharedPreferences.setMockInitialValues({});
  });

  /// Seeds the `loggedUser` key consumed by [UserSession.loadSession].
  /// Pass `null` to simulate "no session stored".
  void mockStoredSession(Map<String, dynamic>? data) {
    SharedPreferences.setMockInitialValues(
      data == null ? {} : {'loggedUser': jsonEncode(data)},
    );
  }

  group('isReadOnly', () {
    test('is true when role is read_only', () {
      UserSession.role = 'read_only';

      expect(UserSession.isReadOnly, isTrue);
    });

    test('is false when role is full', () {
      UserSession.role = 'full';

      expect(UserSession.isReadOnly, isFalse);
    });

    test('is false when role is null (no session)', () {
      UserSession.role = null;

      expect(UserSession.isReadOnly, isFalse);
    });

    test('is false for any other role value', () {
      UserSession.role = 'admin';

      expect(UserSession.isReadOnly, isFalse);
    });
  });

  group('canEdit', () {
    test('owner (not a sub-user) can edit regardless of role', () {
      UserSession.isSubUser = false;
      UserSession.role = null;

      expect(UserSession.canEdit, isTrue);
    });

    test('sub-user with full role can edit', () {
      UserSession.isSubUser = true;
      UserSession.role = 'full';

      expect(UserSession.canEdit, isTrue);
    });

    test('sub-user with read_only role cannot edit', () {
      UserSession.isSubUser = true;
      UserSession.role = 'read_only';

      expect(UserSession.canEdit, isFalse);
    });

    test('sub-user with missing role cannot edit', () {
      UserSession.isSubUser = true;
      UserSession.role = null;

      expect(UserSession.canEdit, isFalse);
    });

    test('sub-user with an unknown role cannot edit', () {
      UserSession.isSubUser = true;
      UserSession.role = 'limited';

      expect(UserSession.canEdit, isFalse);
    });

    test('non-sub-user with read_only role can still edit', () {
      // canEdit only checks `role == 'full' || !isSubUser`,
      // so a non-sub-user keeps edit rights even with read_only role.
      UserSession.isSubUser = false;
      UserSession.role = 'read_only';

      expect(UserSession.canEdit, isTrue);
    });
  });

  group('loadSession', () {
    test('loads every field of a full owner session', () async {
      mockStoredSession({
        'id': 'user-1',
        'ownerId': 'owner-1',
        'role': 'full',
        'phone': '01000000000',
        'merchantName': 'My Shop',
        'isSubUser': false,
      });

      await UserSession.loadSession();

      expect(UserSession.userId, 'user-1');
      expect(UserSession.ownerId, 'owner-1');
      expect(UserSession.role, 'full');
      expect(UserSession.phoneNumber, '01000000000');
      expect(UserSession.merchantName, 'My Shop');
      expect(UserSession.isSubUser, isFalse);
    });

    test('loads a read-only sub-user session with matching permissions',
        () async {
      mockStoredSession({
        'id': 'sub-1',
        'ownerId': 'owner-1',
        'role': 'read_only',
        'phone': '01111111111',
        'merchantName': 'My Shop',
        'isSubUser': true,
      });

      await UserSession.loadSession();

      expect(UserSession.userId, 'sub-1');
      expect(UserSession.ownerId, 'owner-1');
      expect(UserSession.isSubUser, isTrue);
      expect(UserSession.isReadOnly, isTrue);
      expect(UserSession.canEdit, isFalse);
    });

    test('missing isSubUser flag defaults to false', () async {
      mockStoredSession({
        'id': 'user-2',
        'ownerId': 'owner-2',
        'role': 'full',
        'phone': '01222222222',
        'merchantName': 'Shop 2',
      });

      await UserSession.loadSession();

      expect(UserSession.isSubUser, isFalse);
      expect(UserSession.canEdit, isTrue);
    });

    test('empty stored object leaves fields null with isSubUser false',
        () async {
      mockStoredSession({});

      await UserSession.loadSession();

      expect(UserSession.userId, isNull);
      expect(UserSession.ownerId, isNull);
      expect(UserSession.role, isNull);
      expect(UserSession.phoneNumber, isNull);
      expect(UserSession.merchantName, isNull);
      expect(UserSession.isSubUser, isFalse);
    });

    test('no stored session keeps the previous in-memory values', () async {
      mockStoredSession(null);
      UserSession.userId = 'old-user';
      UserSession.role = 'full';
      UserSession.isSubUser = false;

      await UserSession.loadSession();

      // loadSession is a no-op when the key is absent: it neither
      // populates nor clears the static fields.
      expect(UserSession.userId, 'old-user');
      expect(UserSession.role, 'full');
    });

    test('loading a new session overwrites previously loaded values',
        () async {
      mockStoredSession({
        'id': 'first',
        'ownerId': 'owner-a',
        'role': 'full',
        'phone': '01000000000',
        'merchantName': 'First Shop',
        'isSubUser': false,
      });
      await UserSession.loadSession();

      mockStoredSession({
        'id': 'second',
        'ownerId': 'owner-b',
        'role': 'read_only',
        'phone': '09999999999',
        'merchantName': 'Second Shop',
        'isSubUser': true,
      });
      await UserSession.loadSession();

      expect(UserSession.userId, 'second');
      expect(UserSession.ownerId, 'owner-b');
      expect(UserSession.role, 'read_only');
      expect(UserSession.phoneNumber, '09999999999');
      expect(UserSession.merchantName, 'Second Shop');
      expect(UserSession.isSubUser, isTrue);
    });
  });

  group('clear', () {
    test('resets every field after a full session was loaded', () async {
      mockStoredSession({
        'id': 'user-1',
        'ownerId': 'owner-1',
        'role': 'read_only',
        'phone': '01000000000',
        'merchantName': 'My Shop',
        'isSubUser': true,
      });
      await UserSession.loadSession();

      UserSession.clear();

      expect(UserSession.userId, isNull);
      expect(UserSession.ownerId, isNull);
      expect(UserSession.role, isNull);
      expect(UserSession.phoneNumber, isNull);
      expect(UserSession.merchantName, isNull);
      expect(UserSession.isSubUser, isFalse);
      expect(UserSession.isReadOnly, isFalse);
      expect(UserSession.canEdit, isTrue);
    });

    test('is safe to call when no session was ever loaded', () {
      expect(() => UserSession.clear(), returnsNormally);

      expect(UserSession.userId, isNull);
      expect(UserSession.isSubUser, isFalse);
    });
  });
}
