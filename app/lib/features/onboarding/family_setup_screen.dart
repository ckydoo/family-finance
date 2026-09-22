import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/avatar_service.dart';
import '../../core/theme/app_theme.dart';

/// First-run setup: identity/family → invitations → access review.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

enum _Step { create, invite, permissions, join }

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  _Step _step = _Step.create;
  final _personName = TextEditingController();
  final _familyName = TextEditingController();
  final _joinCode = TextEditingController();
  final _inviteEmail = TextEditingController();
  Currency _currency = Currency.usd;
  String _inviteRole = 'Parent';
  Uint8List? _photo;
  String _photoExt = 'jpg';
  bool _busy = false;
  String? _error;

  final Map<String, bool> _access = {
    'child_wallet': true,
    'child_transactions': false,
    'child_budget': true,
    'teen_wallet': true,
    'teen_transactions': true,
    'teen_budget': true,
  };

  @override
  void dispose() {
    _personName.dispose();
    _familyName.dispose();
    _joinCode.dispose();
    _inviteEmail.dispose();
    super.dispose();
  }

  int get _stepNumber => switch (_step) {
        _Step.create || _Step.join => 1,
        _Step.invite => 2,
        _Step.permissions => 3,
      };

  Future<void> _pickPhoto() async {
    final image = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 720,
      imageQuality: 76,
    );
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    setState(() {
      _photo = bytes;
      _photoExt = image.name.toLowerCase().endsWith('.png') ? 'png' : 'jpg';
    });
  }

  Future<void> _create() async {
    final person = _personName.text.trim();
    final family = _familyName.text.trim();
    if (person.length < 2 || family.length < 2) {
      setState(() => _error = 'Enter your preferred name and family name.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final engine = widget.state.sync;
    if (engine == null) {
      setState(() {
        _busy = false;
        _error = 'A connection is required to create your family.';
      });
      return;
    }
    if (await engine.familyNameTaken(family)) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'That family name is already taken. Try another.';
      });
      return;
    }
    final ok = await engine.createSpace(
      family,
      baseCurrency: _currency.short,
      preferredName: person,
    );
    if (!mounted) return;
    if (!ok) {
      setState(() {
        _busy = false;
        _error = engine.lastError ?? 'Could not create the family.';
      });
      return;
    }
    widget.state
      ..setMyName(person)
      ..setDisplayCurrency(_currency);
    await _uploadPhotoIfNeeded();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.invite;
    });
  }

  Future<void> _uploadPhotoIfNeeded() async {
    final photo = _photo;
    final auth = widget.state.auth;
    if (photo == null || auth?.session == null) return;
    try {
      final uploader = AvatarUploader(
        baseUrl: widget.state.env.supabaseUrl!,
        anonKey: widget.state.env.supabaseAnonKey!,
        tokenGet: auth!.refreshAccessToken,
      );
      final url = await uploader.upload(
        bytes: photo,
        userId: auth.session!.userId,
        ext: _photoExt,
      );
      widget.state.setMyAvatar(url);
    } on AvatarException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  Future<void> _join() async {
    final name = _personName.text.trim();
    if (name.length < 2 || _joinCode.text.trim().isEmpty) {
      setState(() => _error = 'Enter your preferred name and invite code.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ok = await widget.state.sync?.joinSpace(_joinCode.text) ?? false;
    if (!mounted) return;
    if (ok) {
      widget.state.setMyName(name);
      await widget.state.completeOnboarding();
    } else {
      setState(() {
        _busy = false;
        _error = widget.state.sync?.lastError ?? 'Could not join the family.';
      });
    }
  }

  String get _code => widget.state.inviteCode ?? '';
  String get _inviteText =>
      'Join ${_familyName.text.trim()} on Mhuri Hub with invite code $_code. '
      'Suggested role: $_inviteRole.';

  Future<void> _copyInvite() async {
    await Clipboard.setData(ClipboardData(text: _inviteText));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Invite copied.')));
  }

  Future<void> _emailInvite() async {
    final email = _inviteEmail.text.trim();
    if (!RegExp(r'^\S+@\S+\.\S+').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address.');
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': 'Join ${_familyName.text.trim()} on Mhuri Hub',
        'body': _inviteText,
      },
    );
    if (!await launchUrl(uri)) await _copyInvite();
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    widget.state.saveLocalNote('role_permissions', jsonEncode(_access));
    await widget.state.sync?.saveRolePermissions(_access);
    if (!mounted) return;
    setState(() => _busy = false);
    await widget.state.completeOnboarding();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          child: Column(children: [
            _progress(),
            Expanded(
              child: switch (_step) {
                _Step.create => _createStep(),
                _Step.invite => _inviteStep(),
                _Step.permissions => _permissionsStep(),
                _Step.join => _joinStep(),
              },
            ),
          ]),
        ),
      );

  Widget _progress() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
        child: Row(children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 4,
                decoration: BoxDecoration(
                  color: i <= _stepNumber ? context.primary : context.hairline,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
          const SizedBox(width: 14),
          Text('Step $_stepNumber of 3',
              style: TextStyle(
                  color: context.inkSoft,
                  fontWeight: FontWeight.w700,
                  fontSize: 12)),
        ]),
      );

  Widget _page(List<Widget> children, Widget bottom) => Column(children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            children: children,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: bottom,
        ),
      ]);

  Widget _title(String text, [String? subtitle]) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(text,
              style: TextStyle(
                  color: context.ink,
                  fontSize: 27,
                  fontWeight: FontWeight.w800)),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle,
                style: TextStyle(
                    color: context.inkSoft, fontSize: 14, height: 1.4)),
          ],
        ],
      );

  Widget _primary(String text, VoidCallback? onPressed) => ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.primary,
          foregroundColor: context.onSolid,
          minimumSize: const Size.fromHeight(54),
          shape: const StadiumBorder(),
        ),
        child: _busy
            ? const SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2.5))
            : Text(text,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
      );

  Widget _field(TextEditingController controller, String label,
          {TextInputType? keyboardType}) =>
      TextField(
        controller: controller,
        keyboardType: keyboardType,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: context.card,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        ),
      );

  Widget _createStep() => _page([
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(clipBehavior: Clip.none, children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: context.primarySoft,
                backgroundImage: _photo == null ? null : MemoryImage(_photo!),
                child: _photo == null
                    ? Icon(Icons.family_restroom,
                        size: 36, color: context.primary)
                    : null,
              ),
              Positioned(
                right: -4,
                bottom: -4,
                child: CircleAvatar(
                  radius: 15,
                  backgroundColor: context.primary,
                  child: const Icon(Icons.camera_alt,
                      color: Colors.white, size: 16),
                ),
              ),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: Text('Mhuri Hub',
              style: TextStyle(
                  color: context.ink,
                  fontSize: 28,
                  fontWeight: FontWeight.w800)),
        ),
        Center(
            child: Text('One family. One plan.',
                style: TextStyle(color: context.inkSoft, fontSize: 14))),
        Center(
          child: TextButton(
            onPressed: _pickPhoto,
            child: const Text('Add profile photo (optional)'),
          ),
        ),
        const SizedBox(height: 22),
        _title('Create your family', 'Tell us what your family calls you.'),
        const SizedBox(height: 16),
        _field(_personName, 'Preferred name'),
        const SizedBox(height: 12),
        _field(_familyName, 'Family name (for example, The Moyos)'),
        const SizedBox(height: 12),
        DropdownButtonFormField<Currency>(
          initialValue: _currency,
          decoration: const InputDecoration(labelText: 'Primary currency'),
          items: [
            for (final currency in Currency.values)
              DropdownMenuItem(value: currency, child: Text(currency.long)),
          ],
          onChanged: (value) =>
              setState(() => _currency = value ?? Currency.usd),
        ),
        if (_error != null) _errorBox(),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = _Step.join;
              _error = null;
            }),
            child: const Text('I have an invite code'),
          ),
        ),
      ], _primary('Create family  →', _busy ? null : _create));

  Widget _joinStep() => _page([
        _title('Join your family', 'Use the code shared by a family member.'),
        const SizedBox(height: 20),
        _field(_personName, 'Preferred name'),
        const SizedBox(height: 12),
        _field(_joinCode, 'Invite code'),
        if (_error != null) _errorBox(),
        TextButton.icon(
          onPressed: () => setState(() => _step = _Step.create),
          icon: const Icon(Icons.arrow_back),
          label: const Text('Create a family instead'),
        ),
      ], _primary('Join family  →', _busy ? null : _join));

  Widget _inviteStep() => _page(
          [
            _title(
                'Invite members', 'Bring everyone into the same family space.'),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: context.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: context.hairline)),
              child: Row(children: [
                Expanded(
                    child: Text(_code,
                        style: TextStyle(
                            color: context.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2))),
                TextButton.icon(
                    onPressed: _copyInvite,
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copy')),
              ]),
            ),
            const SizedBox(height: 16),
            CustomPaint(
              painter: _DashedPainter(color: context.inkSoft),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.qr_code_2, size: 72, color: context.inkSoft),
                      Text('Scan to join',
                          style: TextStyle(color: context.inkSoft)),
                    ]),
              ),
            ),
            const SizedBox(height: 18),
            _field(_inviteEmail, 'Email address',
                keyboardType: TextInputType.emailAddress),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              for (final role in const [
                'Parent',
                'Adult',
                'Teen',
                'Child',
                'Viewer'
              ])
                ChoiceChip(
                  label: Text(role),
                  selected: _inviteRole == role,
                  onSelected: (_) => setState(() => _inviteRole = role),
                ),
            ]),
            const SizedBox(height: 6),
            Text(
              'The role is included as a suggestion. Confirm it in Family settings after they join.',
              style: TextStyle(color: context.inkSoft, fontSize: 11.5),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _emailInvite,
              icon: const Icon(Icons.mail_outline),
              label: const Text('Send invite'),
            ),
            if (_error != null) _errorBox(),
          ],
          Column(children: [
            _primary(
                'Continue  →', () => setState(() => _step = _Step.permissions)),
            TextButton(
                onPressed: () => setState(() => _step = _Step.permissions),
                child: const Text('Invite later')),
          ]));

  Widget _permissionsStep() => _page([
        _title('Set permissions',
            'Recommended access is ready. You can change it later in Family settings.'),
        const SizedBox(height: 18),
        _rolePermissions('Child', 'child'),
        const SizedBox(height: 12),
        _rolePermissions('Teen', 'teen'),
      ], _primary('Finish setup', _busy ? null : _finish));

  Widget _rolePermissions(String title, String prefix) => Container(
        decoration: BoxDecoration(
            color: context.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.hairline)),
        child: Column(children: [
          ListTile(
              title: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w800))),
          _toggle(prefix, 'wallet', 'View own wallet'),
          _toggle(prefix, 'transactions', 'Log transactions'),
          _toggle(prefix, 'budget', 'View family budget'),
        ]),
      );

  Widget _toggle(String prefix, String key, String label) => SwitchListTile(
        title: Text(label, style: const TextStyle(fontSize: 13.5)),
        value: _access['${prefix}_$key']!,
        onChanged: (value) => setState(() => _access['${prefix}_$key'] = value),
      );

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: context.dangerSoft,
              borderRadius: BorderRadius.circular(12)),
          child: Text(_error!, style: TextStyle(color: context.expenseRed)),
        ),
      );
}

class _DashedPainter extends CustomPainter {
  const _DashedPainter({required this.color});
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(
          Offset.zero & size, const Radius.circular(16)));
    for (final metric in path.computeMetrics()) {
      for (double p = 0; p < metric.length; p += 14) {
        canvas.drawPath(metric.extractPath(p, p + 8), paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedPainter oldDelegate) =>
      oldDelegate.color != color;
}
