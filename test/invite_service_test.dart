import 'dart:math';

import 'package:babyrelay/core/config/app_config.dart';
import 'package:babyrelay/domain/services/invite_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('generated codes are 6 chars from the unambiguous alphabet', () {
    for (var i = 0; i < 50; i++) {
      final code = InviteService.generateCode();
      expect(code, hasLength(6));
      for (final ch in code.split('')) {
        expect(InviteService.codeAlphabet.contains(ch), isTrue);
      }
      // Never the look-alike characters caregivers misread.
      expect(code.contains(RegExp('[01OIL]')), isFalse);
    }
  });

  test('code generation is deterministic for a seeded random', () {
    expect(
      InviteService.generateCode(Random(7)),
      InviteService.generateCode(Random(7)),
    );
  });

  test('invite payload carries code, https join link, and share text', () {
    final invite = const InviteService().buildInvite('ABC234');

    expect(invite.code, 'ABC234');
    expect(invite.url.scheme, 'https');
    expect(invite.url.host, AppConfig.inviteLinkHost);
    expect(invite.url.path, '/join/ABC234');
    expect(invite.displayLink, '${AppConfig.inviteLinkHost}/join/ABC234');
    expect(invite.shareText, contains(invite.url.toString()));
    expect(invite.shareText, contains('ABC234'));
  });
}
