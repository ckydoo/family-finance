import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/services.dart';

import '../../core/models/models.dart';
import '../../core/money/money.dart';
import '../../core/state/app_state.dart';
import '../../core/sync/avatar_service.dart';
import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_icons.dart';
import '../../core/widgets/ui.dart';
import '../../l10n/generated/app_localizations.dart';
import '../quickadd/quick_add_sheet.dart';

/// System starter template for family spending areas.
class StarterTemplate {
  final String key;
  final String name;
  final String iconKey;

  const StarterTemplate({
    required this.key,
    required this.name,
    required this.iconKey,
  });
}

const List<StarterTemplate> kStarterTemplates = [
  StarterTemplate(key: 'groceries', name: 'Groceries', iconKey: 'cart'),
  StarterTemplate(key: 'rent', name: 'Rent', iconKey: 'home'),
  StarterTemplate(key: 'transport', name: 'Transport', iconKey: 'car'),
  StarterTemplate(key: 'school', name: 'School', iconKey: 'school'),
  StarterTemplate(key: 'electricity', name: 'Electricity', iconKey: 'power'),
  StarterTemplate(key: 'water', name: 'Water', iconKey: 'water'),
  StarterTemplate(
      key: 'airtime_data', name: 'Airtime & Data', iconKey: 'airtime'),
  StarterTemplate(key: 'medical', name: 'Medical', iconKey: 'health'),
  StarterTemplate(key: 'household', name: 'Household', iconKey: 'receipt'),
  StarterTemplate(key: 'giving', name: 'Giving', iconKey: 'giving'),
  StarterTemplate(
      key: 'entertainment', name: 'Entertainment', iconKey: 'beach'),
  StarterTemplate(key: 'other', name: 'Other', iconKey: 'money'),
];

enum _Step { create, currencies, spending, ready, join }

/// First-run onboarding immediately after registration:
/// Short onboarding → family setup → selectable starter templates → real empty structures → guided Home.
class FamilySetupScreen extends StatefulWidget {
  const FamilySetupScreen({super.key, required this.state});
  final AppState state;

  @override
  State<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends State<FamilySetupScreen> {
  _Step _step = _Step.create;
  final _personName = TextEditingController();
  final _familyName = TextEditingController();
  final _joinCode = TextEditingController();
  final _customCategoryController = TextEditingController();

  Currency _currency = Currency.usd;
  Currency? _secondaryCurrency;
  int _monthStartDay = 1;

  final Set<String> _selectedTemplateKeys = {
    'groceries',
    'rent',
    'transport',
    'electricity'
  };
  final List<StarterTemplate> _customTemplates = [];

  Uint8List? _photo;
  String _photoExt = 'jpg';
  bool _busy = false;
  String? _error;
  bool _addingCustom = false;
  Map<String, String>? _pendingInvite;

  @override
  void initState() {
    super.initState();
    _currency = widget.state.primaryCurrency;
    _secondaryCurrency = widget.state.secondaryCurrency;
    _monthStartDay = widget.state.monthStartDay;

    // Resumable setup: if family already created, resume at the exact stage.
    final stage = widget.state.onboardingStage;
    if (stage == 'ready' || stage == 'complete') {
      _restoreTemplateSelection(widget.state.onboardingTemplates);
    }
    if (widget.state.hasSpace) {
      if (stage == 'currencies') {
        _step = _Step.currencies;
      } else if (stage == 'spending') {
        _step = _Step.spending;
      } else if (stage == 'ready') {
        _step = _Step.ready;
      }
    }

    // State A: Pending family invitation detection (via email or deep link code).
    final sync = widget.state.sync;
    if (sync != null && !widget.state.hasSpace) {
      unawaited(() async {
        final invite = await sync.pendingFamilyInvite();
        if (invite != null && mounted) {
          setState(() {
            _pendingInvite = invite;
            _joinCode.text = invite['code'] ?? '';
            _step = _Step.join;
          });
        }
      }());
    }

    final db = widget.state.db;
    if (db != null) {
      unawaited(() async {
        final c = await db.kvGet('pending_invite_code');
        if (c != null && c.isNotEmpty && mounted && _step != _Step.join) {
          setState(() {
            _joinCode.text = c;
            _step = _Step.join;
          });
        }
      }());
    }
  }

  void _restoreTemplateSelection(List<Map<String, String>> templates) {
    _selectedTemplateKeys.clear();
    _customTemplates.clear();
    for (final item in templates) {
      final key = item['key']?.trim() ?? '';
      final name = item['name']?.trim() ?? '';
      if (key.isEmpty || name.isEmpty) continue;
      _selectedTemplateKeys.add(key);
      if (!kStarterTemplates.any((template) => template.key == key)) {
        _customTemplates.add(StarterTemplate(
          key: key,
          name: name,
          iconKey: item['icon']?.trim().isNotEmpty == true
              ? item['icon']!.trim()
              : 'money',
        ));
      }
    }
  }

  @override
  void dispose() {
    _personName.dispose();
    _familyName.dispose();
    _joinCode.dispose();
    _customCategoryController.dispose();
    super.dispose();
  }

  int get _stepNumber => switch (_step) {
        _Step.create => 1,
        _Step.currencies => 2,
        _Step.spending => 3,
        _Step.ready => 3,
        _Step.join => 1,
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
    } catch (_) {
      // Photo upload failure is non-fatal to onboarding.
    }
  }

  // ── Step 1: Create Family ──────────────────────────────────────────────────
  Future<void> _handleCreateFamily() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final person = _personName.text.trim();
    final family = _familyName.text.trim();

    if (person.length < 2 || family.length < 2) {
      setState(() => _error = l.setupEnterBoth);
      return;
    }
    if (family.length > 80) {
      setState(() => _error = 'Family name must be under 80 characters.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final engine = widget.state.sync;
    if (engine != null) {
      if (await engine.familyNameTaken(family)) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = l.setupNameTaken;
        });
        return;
      }

      final ok = await engine.createSpace(
        family,
        baseCurrency: _currency.code,
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
    }

    widget.state
      ..setMyName(person)
      ..setPrimaryCurrency(_currency);
    await _uploadPhotoIfNeeded();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.currencies;
    });
  }

  // ── Step 2: Currencies & Month Start ───────────────────────────────────────
  List<Map<String, String>> get _selectedTemplatePayload => _allTemplates
      .where((template) => _selectedTemplateKeys.contains(template.key))
      .map((template) => {
            'key': template.key,
            'name': template.name,
            'icon': template.iconKey,
          })
      .toList(growable: false);

  Future<void> _handleSaveCurrencies() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final sync = widget.state.sync;
    if (sync != null) {
      final saved = await sync.saveFamilySetup(
        primary: _currency,
        secondary: _secondaryCurrency,
        monthStart: _monthStartDay,
        // Returning from Ready to edit currencies must not erase the starter
        // choices already saved. On the first pass there are no persisted
        // choices yet, so no budgets are created before explicit confirmation.
        templates: widget.state.onboardingStage == 'ready'
            ? _selectedTemplatePayload
            : const [],
        stage: 'spending',
      );
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _busy = false;
          _error = sync.lastError ??
              'We could not save your setup. Your previous steps are still safe.';
        });
        return;
      }
    } else {
      widget.state
        ..setPrimaryCurrency(_currency)
        ..setSecondaryCurrency(_secondaryCurrency)
        ..setMonthStartDay(_monthStartDay);
      await widget.state.applyFamilySetupSettings(
        stage: 'spending',
        primary: _currency.code,
        secondary: _secondaryCurrency?.code,
        monthStart: _monthStartDay,
      );
    }

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.spending;
    });
  }

  // ── Step 3: Spending Areas (Starter Templates) ─────────────────────────────
  List<StarterTemplate> get _allTemplates => [
        ...kStarterTemplates,
        ..._customTemplates,
      ];

  void _addCustomCategory() {
    final text = _customCategoryController.text.trim();
    if (text.length < 2) return;
    final key =
        'custom_${text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9_]'), '_')}';
    final custom = StarterTemplate(key: key, name: text, iconKey: 'money');
    setState(() {
      _customTemplates.add(custom);
      _selectedTemplateKeys.add(key);
      _customCategoryController.clear();
      _addingCustom = false;
    });
  }

  Future<void> _handleSaveSpendingAreas() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });

    final selected = _allTemplates
        .where((t) => _selectedTemplateKeys.contains(t.key))
        .toList();

    final sync = widget.state.sync;
    if (sync != null) {
      final payload = _selectedTemplatePayload;
      final saved = await sync.saveFamilySetup(
        primary: _currency,
        secondary: _secondaryCurrency,
        monthStart: _monthStartDay,
        templates: payload,
        stage: 'ready',
      );
      if (!mounted) return;
      if (!saved) {
        setState(() {
          _busy = false;
          _error = sync.lastError ??
              'We could not save your setup. Your previous steps are still safe.';
        });
        return;
      }
    } else {
      // Offline mode: create starter empty envelopes locally
      for (final template in selected) {
        final exists = widget.state.envelopes.any(
          (e) =>
              !e.isPersonal &&
              e.name.toLowerCase() == template.name.toLowerCase(),
        );
        if (!exists) {
          widget.state.addEnvelope(
            name: template.name,
            limit: Money(0, _currency),
            emoji: template.iconKey,
          );
        }
      }
      await widget.state.applyFamilySetupSettings(
        stage: 'ready',
        primary: _currency.code,
        secondary: _secondaryCurrency?.code,
        monthStart: _monthStartDay,
        templates: selected
            .map((t) => {'key': t.key, 'name': t.name, 'icon': t.iconKey})
            .toList(growable: false),
      );
    }
    widget.state.deduplicateEnvelopes();

    if (!mounted) return;
    setState(() {
      _busy = false;
      _step = _Step.ready;
    });
  }

  // ── Step 4: Family Ready ───────────────────────────────────────────────────
  Future<bool> _finishToHome() async {
    if (_busy) return false;
    setState(() => _busy = true);

    final sync = widget.state.sync;
    if (sync != null) {
      final saved = await sync.saveFamilySetup(
        primary: _currency,
        secondary: _secondaryCurrency,
        monthStart: _monthStartDay,
        templates: _selectedTemplatePayload,
        stage: 'complete',
      );
      if (!mounted) return false;
      if (!saved) {
        setState(() {
          _busy = false;
          _error = sync.lastError ??
              'We could not finish your setup. Your previous steps are still safe.';
        });
        return false;
      }
    }
    widget.state.deduplicateEnvelopes();
    await widget.state.completeOnboarding();
    return true;
  }

  Future<void> _finishWithIncome() async {
    if (_busy) return;
    final finished = await _finishToHome();
    if (!finished) return;
    if (!mounted) return;
    showQuickAdd(context, initialType: TxType.income);
  }

  // ── Join Flow (Invited or with Code) ────────────────────────────────────────
  Future<void> _handleJoinFamily() async {
    if (_busy) return;
    final l = AppLocalizations.of(context)!;
    final name = _personName.text.trim();
    final code = _joinCode.text.trim();

    if (name.length < 2 || code.isEmpty) {
      setState(() => _error = l.setupEnterJoin);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await widget.state.sync?.joinSpace(code) ?? false;
    if (!mounted) return;
    if (ok) {
      widget.state.setMyName(name);
      await widget.state.completeOnboarding();
    } else {
      setState(() {
        _busy = false;
        _error = widget.state.sync?.lastError ??
            'Could not join the family. Check the code and try again.';
      });
    }
  }

  Future<bool> _confirmLeave() async {
    if (_personName.text.trim().isEmpty && _familyName.text.trim().isEmpty) {
      return true;
    }
    final l = AppLocalizations.of(context)!;
    final leave = await confirmDialog(
      context,
      title: l.discardChangesTitle,
      body: l.discardChangesBody,
      confirmLabel: l.leave,
    );
    return leave;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (_step == _Step.currencies) {
          setState(() => _step = _Step.create);
          return;
        }
        if (_step == _Step.spending) {
          setState(() => _step = _Step.currencies);
          return;
        }
        if (_step == _Step.ready) {
          setState(() => _step = _Step.spending);
          return;
        }
        if (_step == _Step.join && _pendingInvite == null) {
          setState(() => _step = _Step.create);
          return;
        }
        final leave = await _confirmLeave();
        if (leave && mounted && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        backgroundColor: context.bg,
        body: SafeArea(
          child: Column(
            children: [
              if (_step != _Step.join) _progressHeader(),
              Expanded(
                child: switch (_step) {
                  _Step.create => _createStep(),
                  _Step.currencies => _currenciesStep(),
                  _Step.spending => _spendingStep(),
                  _Step.ready => _readyStep(),
                  _Step.join => _joinStep(),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _progressHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        children: [
          for (var i = 1; i <= 3; i++) ...[
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
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
          Text(
            'Step $_stepNumber of 3',
            style: TextStyle(
              color: context.inkSoft,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(List<Widget> children, Widget bottom) {
    return Column(
      children: [
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
      ],
    );
  }

  Widget _title(String text, [String? subtitle]) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          text,
          style: TextStyle(
            color: context.ink,
            fontSize: 24,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: TextStyle(
              color: context.inkSoft,
              fontSize: 14,
              height: 1.4,
            ),
          ),
        ],
      ],
    );
  }

  Widget _primaryButton(String text, VoidCallback? onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: context.primary,
        foregroundColor: context.onSolid,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
      ),
      child: _busy
          ? const SizedBox.square(
              dimension: 22,
              child: CircularProgressIndicator.adaptive(strokeWidth: 2.5),
            )
          : Text(
              text,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    String? hintText,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: context.card,
        border: OutlineInputBorder(
          borderRadius: kBRadiusM,
          borderSide: BorderSide.none,
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _errorBox() => Padding(
        padding: const EdgeInsets.only(top: 12),
        child: ErrorNotice(_error!),
      );

  // ── Step 1: Create your family ─────────────────────────────────────────────
  Widget _createStep() {
    final l = AppLocalizations.of(context)!;
    return _page(
      [
        Center(
          child: GestureDetector(
            onTap: _pickPhoto,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: context.primarySoft,
                  backgroundImage: _photo == null ? null : MemoryImage(_photo!),
                  child: _photo == null
                      ? Icon(Icons.family_restroom,
                          size: 34, color: context.primary)
                      : null,
                ),
                Positioned(
                  right: -4,
                  bottom: -4,
                  child: CircleAvatar(
                    radius: 14,
                    backgroundColor: context.primary,
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 15),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            'Mhuri',
            style: TextStyle(
              color: context.ink,
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Center(
          child: Text(
            l.setupTagline,
            style: TextStyle(color: context.inkSoft, fontSize: 13.5),
          ),
        ),
        const SizedBox(height: 24),
        _title(
          'Create your family',
          'Mhuri helps your household plan spending, save and manage money together.',
        ),
        const SizedBox(height: 16),
        _field(_personName, 'Preferred name', hintText: 'e.g. Mac'),
        const SizedBox(height: 12),
        _field(_familyName, 'Family name', hintText: 'e.g. Chikangaiso Family'),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        Center(
          child: TextButton(
            onPressed: () => setState(() {
              _step = _Step.join;
              _error = null;
            }),
            child: Text(l.setupHaveCode),
          ),
        ),
      ],
      _primaryButton('Continue  →', _busy ? null : _handleCreateFamily),
    );
  }

  // ── Step 2: Currencies ─────────────────────────────────────────────────────
  Widget _currenciesStep() {
    return _page(
      [
        _title(
          'Which currencies do you use?',
          'Choose the money your family normally uses. You can change this later.',
        ),
        const SizedBox(height: 20),
        Text(
          'Main currency',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          "We'll use this for your main totals.",
          style: TextStyle(fontSize: 12, color: context.inkSoft),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Currency>(
          initialValue: _currency,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: kBRadiusM,
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            for (final c in Currency.values)
              DropdownMenuItem(
                value: c,
                child: Text('${c.long} (${c.symbol})'),
              ),
          ],
          onChanged: (v) {
            if (v != null) {
              setState(() {
                _currency = v;
                if (_secondaryCurrency == v) _secondaryCurrency = null;
              });
            }
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Secondary currency (Optional dual-currency)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Track transactions in a second currency alongside your primary one.',
          style: TextStyle(fontSize: 12, color: context.inkSoft),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<Currency?>(
          initialValue: _secondaryCurrency,
          isExpanded: true,
          decoration: InputDecoration(
            filled: true,
            fillColor: context.card,
            border: OutlineInputBorder(
              borderRadius: kBRadiusM,
              borderSide: BorderSide.none,
            ),
          ),
          items: [
            const DropdownMenuItem(
              value: null,
              child: Text('None (Single currency)'),
            ),
            for (final c in Currency.values.where((c) => c != _currency))
              DropdownMenuItem(
                value: c,
                child: Text('${c.long} (${c.symbol})'),
              ),
          ],
          onChanged: (v) => setState(() => _secondaryCurrency = v),
        ),
        const SizedBox(height: 20),
        Text(
          'When does your money month normally start?',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.ink,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Align your budget cycles to paydays or calendar months. Change later anytime.',
          style: TextStyle(fontSize: 12, color: context.inkSoft),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          children: [1, 15, 25].map((day) {
            final isSelected = _monthStartDay == day;
            return ChoiceChip(
              label: Text(day == 1 ? '1st (Calendar)' : '${day}th'),
              selected: isSelected,
              onSelected: (_) => setState(() => _monthStartDay = day),
            );
          }).toList(),
        ),
        if (_error != null) _errorBox(),
      ],
      _primaryButton('Continue  →', _busy ? null : _handleSaveCurrencies),
    );
  }

  // ── Step 3: Choose spending areas ──────────────────────────────────────────
  Widget _spendingStep() {
    return _page(
      [
        _title(
          'What do you normally spend money on?',
          'Choose a few to get started. You can add or remove budgets anytime.',
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: context.primarySoft,
            borderRadius: kBRadiusM,
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: context.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'No budget limits required now. You can set amounts progressively once you reach Home.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: context.ink,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _allTemplates.map((template) {
            final isSelected = _selectedTemplateKeys.contains(template.key);
            final icon = iconForKey(template.iconKey) ?? Icons.category;
            return FilterChip(
              avatar: Icon(
                icon,
                size: 16,
                color: isSelected ? context.primary : context.inkSoft,
              ),
              label: Text(template.name),
              selected: isSelected,
              selectedColor: context.primarySoft,
              checkmarkColor: context.primary,
              labelStyle: TextStyle(
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected ? context.primary : context.ink,
              ),
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedTemplateKeys.add(template.key);
                  } else {
                    _selectedTemplateKeys.remove(template.key);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 14),
        if (!_addingCustom)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => setState(() => _addingCustom = true),
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('+ Add my own',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: kBRadiusL,
              border: Border.all(color: context.hairline),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _customCategoryController,
                    autofocus: true,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Church, Farm, Parents',
                      isDense: true,
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _addCustomCategory(),
                  ),
                ),
                TextButton(
                  onPressed: _addCustomCategory,
                  child: const Text('Add',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _addingCustom = false),
                ),
              ],
            ),
          ),
        if (_error != null) _errorBox(),
      ],
      _primaryButton('Continue  →', _busy ? null : _handleSaveSpendingAreas),
    );
  }

  // ── Step 4: Family Ready ───────────────────────────────────────────────────
  Widget _readyStep() {
    return _page(
      [
        const SizedBox(height: 16),
        Center(
          child: Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: context.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.check_circle_rounded,
                size: 48, color: context.primary),
          ),
        ),
        const SizedBox(height: 20),
        _title(
          'Your family space is ready',
          'Start by adding money coming in, then Mhuri can help you plan what to spend and save.',
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.card,
            borderRadius: kBRadiusL,
            border: Border.all(color: context.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'YOUR STARTER BUDGETS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: context.inkSoft,
                ),
              ),
              const SizedBox(height: 10),
              if (_selectedTemplateKeys.isEmpty)
                Text(
                  'No starter budgets selected. You can create budgets anytime.',
                  style: TextStyle(fontSize: 13, color: context.inkSoft),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: _allTemplates
                      .where((t) => _selectedTemplateKeys.contains(t.key))
                      .map((t) => Chip(
                            avatar: Icon(
                                iconForKey(t.iconKey) ?? Icons.category,
                                size: 14),
                            label: Text(t.name,
                                style: const TextStyle(fontSize: 12)),
                            backgroundColor: context.bg,
                            side: BorderSide(color: context.hairline),
                          ))
                      .toList(),
                ),
            ],
          ),
        ),
        if (_error != null) _errorBox(),
      ],
      Column(
        children: [
          _primaryButton(
              'Add money coming in', _busy ? null : _finishWithIncome),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: _busy ? null : _finishToHome,
            style: OutlinedButton.styleFrom(
              foregroundColor: context.primary,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(borderRadius: kBRadiusM),
            ),
            child: const Text('Go to Home',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  // ── Join Step (State A / Code Entry) ───────────────────────────────────────
  Widget _joinStep() {
    final invite = _pendingInvite;
    final hasInvite = invite != null;
    final familyTitle = hasInvite
        ? 'Join ${invite['family_name'] ?? 'Family'}'
        : 'Join your family';
    final subTitle = hasInvite
        ? '${invite['inviter_name'] ?? 'A family admin'} invited you to manage family money together. You\'ll join as an Adult Member.'
        : 'Use the code shared by a family member.';

    return _page(
      [
        _title(familyTitle, subTitle),
        const SizedBox(height: 24),
        _field(_personName, 'Preferred name',
            hintText: 'What should the family call you?'),
        const SizedBox(height: 12),
        if (!hasInvite)
          _field(_joinCode, 'Invite code', hintText: 'e.g. MHRI-ABCD')
        else
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: context.card,
              borderRadius: kBRadiusM,
              border: Border.all(color: context.hairline),
            ),
            child: Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 18, color: context.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Code: ${_joinCode.text}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: context.ink,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (_error != null) _errorBox(),
        const SizedBox(height: 16),
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() {
              _step = _Step.create;
              _pendingInvite = null;
              _error = null;
            }),
            icon: Icon(Icons.adaptive.arrow_back, size: 18),
            label: const Text('Create a family instead'),
          ),
        ),
      ],
      _primaryButton('Join family', _busy ? null : _handleJoinFamily),
    );
  }
}
