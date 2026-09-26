import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:my_test_app/main.dart';

/// Guards the force-update gate against build-number drift: the hardcoded
/// comparison value must always equal the pubspec `+N` suffix, otherwise
/// the new build would force-update itself (or old builds would slip by).
int _pubspecBuildNumber() {
  final lines = File('pubspec.yaml').readAsLinesSync();
  final versionLine = lines.firstWhere(
    (line) => line.trim().startsWith('version:'),
    orElse: () => throw StateError('version: line missing in pubspec.yaml'),
  );
  final match = RegExp(r'version:\s*\S+\+(\d+)').firstMatch(versionLine);
  if (match == null) {
    throw StateError('cannot parse build number from "$versionLine"');
  }
  return int.parse(match.group(1)!);
}

void main() {
  test('force-update build constant matches pubspec build number', () {
    expect(MyApp.currentBuildNumber, _pubspecBuildNumber());
  });

  test('current release is build 28', () {
    expect(MyApp.currentBuildNumber, 28);
    expect(_pubspecBuildNumber(), 28);
  });
}
