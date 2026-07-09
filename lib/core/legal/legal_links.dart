import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/app_config.dart';

enum LegalDocument { privacy, terms }

extension LegalDocumentLabel on LegalDocument {
  String get label => switch (this) {
    LegalDocument.privacy => 'Privacy Policy',
    LegalDocument.terms => 'Terms of Service',
  };

  Uri get uri => switch (this) {
    LegalDocument.privacy => Uri.parse(AppConfig.privacyPolicyUrl),
    LegalDocument.terms => Uri.parse(AppConfig.termsOfServiceUrl),
  };
}

Future<void> openLegalDocument(
  BuildContext context,
  LegalDocument document,
) async {
  final messenger = ScaffoldMessenger.of(context);
  final launched = await _tryLaunch(document.uri);
  if (!launched) {
    messenger.showSnackBar(
      SnackBar(content: Text('Could not open ${document.label}.')),
    );
  }
}

Future<bool> _tryLaunch(Uri uri) async {
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on Exception {
    return false;
  }
}
