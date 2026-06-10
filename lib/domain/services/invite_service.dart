import 'dart:math';

import '../../core/config/app_config.dart';

/// Everything one caregiver invite needs to be shared: the human-readable
/// code, the join link, and ready-to-send share text.
class InvitePayload {
  const InvitePayload({
    required this.code,
    required this.url,
    required this.shareText,
  });

  final String code;
  final Uri url;
  final String shareText;

  /// Link without the scheme, for compact display ("babyrelay.app/join/ABC").
  String get displayLink => '${url.host}${url.path}';
}

/// Builds deterministic invite payloads. Pure Dart, no Flutter imports.
///
/// This is the AppRefer / deep-link seam: when attribution lands, only
/// [decorateLink] changes (wrapping the join URL in a tracked AppRefer link
/// built from `AppConfig.appReferLinkId`); every caller keeps working.
class InviteService {
  const InviteService();

  static const _codeLength = 6;

  /// No ambiguous characters (0/O, 1/I/L) — caregivers read these out loud.
  static const codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

  static String generateCode([Random? random]) {
    final rng = random ?? Random();
    return List.generate(
      _codeLength,
      (_) => codeAlphabet[rng.nextInt(codeAlphabet.length)],
    ).join();
  }

  /// Hook for attribution: today the join link is shared as-is.
  Uri decorateLink(Uri joinUrl) => joinUrl;

  InvitePayload buildInvite(String code) {
    final url = decorateLink(
      Uri.https(AppConfig.inviteLinkHost, '/join/$code'),
    );
    return InvitePayload(
      code: code,
      url: url,
      shareText:
          "Join me on BabyRelay so we both see the baby's day: $url\n"
          'Your invite code: $code',
    );
  }
}
