import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/analytics/analytics_service.dart';
import '../../core/design/relay_theme.dart';
import '../../core/purchases/purchase_service.dart';
import '../../data/family_repository.dart';

class JoinFamilyScreen extends StatefulWidget {
  const JoinFamilyScreen({super.key, this.initialCode});

  final String? initialCode;

  @override
  State<JoinFamilyScreen> createState() => _JoinFamilyScreenState();
}

class _JoinFamilyScreenState extends State<JoinFamilyScreen> {
  late final TextEditingController _codeController = TextEditingController(
    text: widget.initialCode ?? '',
  );
  final _nameController = TextEditingController();
  bool _joining = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final repo = context.read<FamilyRepository>();
    final purchases = context.read<PurchaseService>();
    final analytics = context.read<AnalyticsService>();
    final code = _codeController.text.trim();
    final name = _nameController.text.trim();
    if (code.isEmpty || name.isEmpty) {
      setState(() => _error = 'Enter the invite code and your name.');
      return;
    }
    if (!repo.syncConfigured) {
      setState(
        () => _error =
            'Joining a care team needs the production sync build. This preview is local-only.',
      );
      return;
    }
    setState(() {
      _joining = true;
      _error = null;
    });
    try {
      await repo.joinFamilyByInviteCode(
        code: code,
        caregiverName: name,
        allowOverFreeCaregiverLimit: purchases.isPro,
      );
      analytics.logEvent('caregiver_joined');
      if (!mounted) return;
      context.go('/today');
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'That invite code did not work. Check it and try again.';
        _joining = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.relay;
    final text = Theme.of(context).textTheme;
    final syncConfigured = context.watch<FamilyRepository>().syncConfigured;

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => context.go('/onboarding'),
          icon: const Icon(Icons.arrow_back),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
          children: [
            Icon(Icons.group_add_rounded, color: c.clay, size: 44),
            const SizedBox(height: 18),
            Text('Join a care team', style: text.headlineMedium),
            const SizedBox(height: 8),
            Text(
              'Enter the code from your partner, nanny, grandparent, or whoever invited you.',
              style: text.bodyLarge?.copyWith(color: c.inkSoft),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _codeController,
              enabled: !_joining,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Invite code'),
              style: text.titleLarge,
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _nameController,
              enabled: !_joining,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Your name'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 14),
              Text(_error!, style: text.bodyMedium?.copyWith(color: c.danger)),
            ],
            if (!syncConfigured) ...[
              const SizedBox(height: 14),
              Text(
                'This local preview can show the join screen, but real joining switches on with Firebase.',
                style: text.bodyMedium?.copyWith(color: c.inkFaint),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _joining ? null : _join,
              icon: _joining
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_rounded),
              label: Text(_joining ? 'Joining...' : 'Join care team'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _joining ? null : () => context.go('/onboarding'),
              child: const Text('Set up a new family instead'),
            ),
          ],
        ),
      ),
    );
  }
}
