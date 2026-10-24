import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../core/query.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/pale_input.dart';
import '../../ui/tag_input.dart';
import '../../ui/text_field.dart';
import '../../ui/toast.dart';
import '../../ui/user_image.dart';

BoxDecoration _card(BuildContext context) => BoxDecoration(
  color: context.pick(Colors.white, Dak.surface),
  borderRadius: BorderRadius.circular(8),
  border: Border.all(color: context.pick(Light.border, Dak.border)),
);

TextStyle _label(BuildContext context) => TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: context.pick(Auth.navy, Dak.heading));

/// Cover + avatar pickers shared by both forms.
class _ImagesEditor extends ConsumerStatefulWidget {
  const _ImagesEditor({
    required this.cover,
    required this.avatar,
    required this.name,
    required this.onCover,
    required this.onAvatar,
    required this.onError,
  });

  final String? cover;
  final String? avatar;
  final String name;
  final ValueChanged<String> onCover;
  final ValueChanged<String> onAvatar;
  final ValueChanged<String> onError;

  @override
  ConsumerState<_ImagesEditor> createState() => _ImagesEditorState();
}

class _ImagesEditorState extends ConsumerState<_ImagesEditor> {
  bool _uploading = false;

  Future<void> _pick(ValueChanged<String> done) async {
    final file = await pickFile(UploadKind.image);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      done(await uploadFile(ref.read(apiProvider), file));
    } catch (e) {
      widget.onError(errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 160,
            child: Stack(
              fit: StackFit.expand,
              children: [
                UserImage(src: widget.cover, fallback: 'illustrations/profile-cover.png'),
                Positioned(
                  right: 16,
                  top: 16,
                  child: Material(
                    color: Colors.black.withValues(alpha: .6),
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: _uploading ? null : () => _pick(widget.onCover),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Text(_uploading ? 'Uploading…' : 'Change cover', style: const TextStyle(fontSize: 14, color: Colors.white)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                SizedBox(
                  width: 104,
                  height: 48,
                  child: OverflowBox(
                    alignment: Alignment.bottomCenter,
                    maxHeight: 104,
                    child: Container(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: dark ? Dak.surface : Colors.white, width: 4),
                      ),
                      child: Avatar(src: widget.avatar, name: widget.name.isEmpty ? '?' : widget.name, size: 96),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _uploading ? null : () => _pick(widget.onAvatar),
                  icon: AssetIcon('icons/camera.svg', width: 18, height: 16, color: dark ? null : Colors.black),
                  label: const Text('Change photo', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dark ? Dak.heading : Auth.navy,
                    side: BorderSide(color: dark ? Dak.border : Light.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back link, title, form body, error and Cancel / Save buttons.
class _Shell extends StatelessWidget {
  const _Shell({required this.title, required this.error, required this.saving, required this.onSubmit, required this.children});

  final String title;
  final String? error;
  final bool saving;
  final VoidCallback onSubmit;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(href: '/profile'),
            const SizedBox(height: 24),
            Text(
              title,
              style: TextStyle(
                fontSize: context.isSm ? 32 : 24,
                fontWeight: FontWeight.w700,
                letterSpacing: -.32,
                color: dark ? Dak.heading : Auth.navy,
              ),
            ),
            for (final c in children) ...[const SizedBox(height: 24), c],
            if (error != null) ...[const SizedBox(height: 24), ErrorText(error!)],
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => context.go('/profile'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: dark ? Dak.heading : Auth.navy,
                    side: BorderSide(color: dark ? Dak.border : Light.border),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                ),
                const SizedBox(width: 12),
                Opacity(
                  opacity: saving ? .6 : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 16)],
                    ),
                    child: FilledButton(
                      onPressed: saving ? null : onSubmit,
                      style: FilledButton.styleFrom(
                        backgroundColor: Dak.cta,
                        disabledBackgroundColor: Dak.cta,
                        disabledForegroundColor: Colors.white,
                        minimumSize: Size.zero,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      ),
                      child: Text(saving ? 'Saving…' : 'Save Profile', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Two columns from sm up; [wide] fields span both.
class _FieldGrid extends StatelessWidget {
  const _FieldGrid({required this.fields});

  final List<(String label, Widget input, bool wide)> fields;

  @override
  Widget build(BuildContext context) {
    Widget field((String, Widget, bool) f) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(f.$1, style: _label(context)),
        const SizedBox(height: 8),
        f.$2,
      ],
    );

    final rows = <Widget>[];
    if (!context.isSm) {
      rows.addAll(fields.map(field));
    } else {
      for (var i = 0; i < fields.length;) {
        if (fields[i].$3) {
          rows.add(field(fields[i]));
          i++;
        } else {
          final pair = [fields[i], if (i + 1 < fields.length && !fields[i + 1].$3) fields[i + 1]];
          rows.add(
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: field(pair[0])),
                const SizedBox(width: 16),
                Expanded(child: pair.length > 1 ? field(pair[1]) : const SizedBox.shrink()),
              ],
            ),
          );
          i += pair.length;
        }
      }
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _card(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, r) in rows.indexed) ...[if (i > 0) const SizedBox(height: 16), r],
        ],
      ),
    );
  }
}

class EditPersonalProfilePage extends ConsumerStatefulWidget {
  const EditPersonalProfilePage({super.key});

  @override
  ConsumerState<EditPersonalProfilePage> createState() => _EditPersonalProfilePageState();
}

class _EditPersonalProfilePageState extends ConsumerState<EditPersonalProfilePage> {
  late final Me? _user = ref.read(authProvider);
  late final MyProfile? _p = _user?.profile;
  late final _fullName = TextEditingController(text: _p?.fullName ?? '');
  late final _username = TextEditingController(text: _user?.username ?? '');
  late final _bio = TextEditingController(text: _p?.bio ?? '');
  late final _specialty = TextEditingController(text: _p?.specialty ?? '');
  late final _portfolio = TextEditingController(text: _p?.portfolioUrl ?? '');
  late final _phone = TextEditingController(text: _p?.phone ?? '');
  late final _city = TextEditingController(text: _p?.city ?? '');
  late final _country = TextEditingController(text: _p?.country ?? '');
  late List<String> _interests = _p?.interests ?? [];
  late List<String> _tags = _p?.tags ?? [];
  late String? _avatarUrl = _p?.avatarUrl;
  late String? _coverUrl = _p?.coverUrl;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_fullName, _username, _bio, _specialty, _portfolio, _phone, _city, _country]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_fullName.text.trim().isEmpty) return setState(() => _error = "Your name can't be empty.");
    setState(() {
      _error = null;
      _saving = true;
    });
    final api = ref.read(apiProvider);
    try {
      if (_username.text.trim() != (_user?.username ?? '')) {
        await api.patch<dynamic>('/users/me', {if (_username.text.trim().isNotEmpty) 'username': _username.text.trim()});
      }
      final json = await api.put<Map<String, dynamic>>('/users/me/profile', {
        'fullName': _fullName.text,
        'bio': _bio.text,
        'specialty': _specialty.text,
        'portfolioUrl': _portfolio.text,
        'phone': _phone.text,
        'city': _city.text,
        'country': _country.text,
        'interests': _interests,
        'tags': _tags,
        'avatarUrl': _avatarUrl,
        'coverUrl': _coverUrl,
      });
      api.updateUser(Me.fromJson(json));
      invalidateQueries(ref);
      ref.read(toastProvider.notifier).show('Profile saved');
      if (mounted) context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _Shell(
      title: 'Edit Personal Profile',
      error: _error,
      saving: _saving,
      onSubmit: _submit,
      children: [
        _ImagesEditor(
          cover: _coverUrl,
          avatar: _avatarUrl,
          name: _fullName.text,
          onCover: (u) => setState(() => _coverUrl = u),
          onAvatar: (u) => setState(() => _avatarUrl = u),
          onError: (m) => setState(() => _error = m),
        ),
        _FieldGrid(
          fields: [
            ('Full Name', PaleInput(controller: _fullName, height: 48, onChanged: (_) => setState(() {})), false),
            ('Username', PaleInput(controller: _username, height: 48, hint: 'e.g. jane.builds'), false),
            (
              'Profile Type / Specialty',
              PaleInput(controller: _specialty, height: 48, hint: 'e.g. Contractor, Student, Instructor'),
              false,
            ),
            ('Portfolio URL', PaleInput(controller: _portfolio, height: 48, hint: 'https://'), false),
            ('Bio', PaleInput(controller: _bio, lines: 4), true),
            ('City', PaleInput(controller: _city, height: 48), false),
            ('Country', PaleInput(controller: _country, height: 48), false),
            ('Phone', PaleInput(controller: _phone, height: 48), false),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Trade Interests', style: _label(context)),
              const SizedBox(height: 16),
              TagInput(tags: _interests, onChanged: (t) => setState(() => _interests = t)),
              const SizedBox(height: 16),
              Text('Category Tags', style: _label(context)),
              const SizedBox(height: 16),
              TagInput(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
            ],
          ),
        ),
      ],
    );
  }
}

class EditBusinessProfilePage extends ConsumerStatefulWidget {
  const EditBusinessProfilePage({super.key});

  @override
  ConsumerState<EditBusinessProfilePage> createState() => _EditBusinessProfilePageState();
}

class _EditBusinessProfilePageState extends ConsumerState<EditBusinessProfilePage> {
  late final MyBusiness? _b = ref.read(authProvider)?.business;
  late final _legalName = TextEditingController(text: _b?.legalName ?? '');
  late final _description = TextEditingController(text: _b?.description ?? '');
  late final _industry = TextEditingController(text: _b?.industry ?? '');
  late final _specialty = TextEditingController(text: _b?.specialty ?? '');
  late final _contactEmail = TextEditingController(text: _b?.contactEmail ?? '');
  late final _phone = TextEditingController(text: _b?.phone ?? '');
  late final _website = TextEditingController(text: _b?.website ?? '');
  late List<String> _tags = _b?.categoryTags ?? [];
  late String? _logoUrl = _b?.logoUrl;
  late String? _coverUrl = _b?.coverUrl;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_legalName, _description, _industry, _specialty, _contactEmail, _phone, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_legalName.text.trim().isEmpty) return setState(() => _error = "Your business name can't be empty.");
    setState(() {
      _error = null;
      _saving = true;
    });
    final api = ref.read(apiProvider);
    try {
      final json = await api.put<Map<String, dynamic>>('/users/me/business', {
        'legalName': _legalName.text,
        'description': _description.text,
        'industry': _industry.text,
        'specialty': _specialty.text,
        'contactEmail': _contactEmail.text,
        'phone': _phone.text,
        'website': _website.text,
        'categoryTags': _tags,
        'logoUrl': _logoUrl,
        'coverUrl': _coverUrl,
      });
      api.updateUser(Me.fromJson(json));
      invalidateQueries(ref);
      ref.read(toastProvider.notifier).show('Business profile saved');
      if (mounted) context.go('/profile');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final dark = context.isDark;
    return _Shell(
      title: 'Edit Business Profile',
      error: _error,
      saving: _saving,
      onSubmit: _submit,
      children: [
        _ImagesEditor(
          cover: _coverUrl,
          avatar: _logoUrl,
          name: _legalName.text,
          onCover: (u) => setState(() => _coverUrl = u),
          onAvatar: (u) => setState(() => _logoUrl = u),
          onError: (m) => setState(() => _error = m),
        ),
        if (b != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: dark ? Dak.cta.withValues(alpha: .1) : const Color(0xFFF3E8FF),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text.rich(
              TextSpan(
                style: const TextStyle(fontSize: 14, color: Dak.cta),
                children: [
                  const TextSpan(text: 'Verification: '),
                  TextSpan(
                    text: b.verification.toLowerCase(),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  if (b.verification == 'PENDING') const TextSpan(text: ' — our team is reviewing your documents.'),
                ],
              ),
            ),
          ),
        _FieldGrid(
          fields: [
            ('Legal Business Name', PaleInput(controller: _legalName, height: 48, onChanged: (_) => setState(() {})), false),
            ('Industry Segment', PaleInput(controller: _industry, height: 48, hint: 'e.g. Distributor, Manufacturer'), false),
            ('Primary Specialty', PaleInput(controller: _specialty, height: 48), false),
            ('Website', PaleInput(controller: _website, height: 48, hint: 'https://'), false),
            ('Professional Bio', PaleInput(controller: _description, lines: 4), true),
            ('Contact Email', PaleInput(controller: _contactEmail, height: 48), false),
            ('Phone Number', PaleInput(controller: _phone, height: 48), false),
          ],
        ),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: _card(context),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Professional Expertise', style: _label(context)),
              const SizedBox(height: 16),
              TagInput(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
            ],
          ),
        ),
      ],
    );
  }
}
