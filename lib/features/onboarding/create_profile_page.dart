import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/auth/me.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/drop_zone.dart';
import '../../ui/form_fields.dart';
import '../../ui/layout.dart';
import '../../ui/tag_input.dart';
import '../../ui/text_field.dart';
import '../../ui/user_image.dart';
import '../auth/widgets/auth_shell.dart';

class CreateProfilePage extends ConsumerWidget {
  const CreateProfilePage({super.key, this.persona});

  final String? persona;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider);
    // The account type is the source of truth; ?persona= only matters before it's loaded.
    final business = user != null ? user.isBusiness : persona == 'business';
    return business ? const _BusinessForm() : const _IndividualForm();
  }
}

TextStyle _sectionLabel(BuildContext context, {double size = 16}) =>
    TextStyle(fontSize: size, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.pick(Auth.navy, Dak.heading));

Widget _divider(BuildContext context) => Divider(height: 1, thickness: 1, color: context.pick(Dak.cta.withValues(alpha: .6), Dak.border));

/// The 44-80px dashed square that shows the uploaded photo or a placeholder person icon.
class _PhotoSquare extends StatelessWidget {
  const _PhotoSquare({required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : Hex.black,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: dark ? Dak.border : Dak.cta),
      ),
      child: url != null ? UserImage(src: url) : const Center(child: AssetIcon('icons/user-rounded-small.svg', width: 36, height: 36)),
    );
  }
}

class _IndividualForm extends ConsumerStatefulWidget {
  const _IndividualForm();

  @override
  ConsumerState<_IndividualForm> createState() => _IndividualFormState();
}

class _IndividualFormState extends ConsumerState<_IndividualForm> {
  late final MyProfile? _profile = ref.read(authProvider)?.profile;
  late final _fullName = TextEditingController(text: _profile?.fullName ?? '');
  late final _bio = TextEditingController(text: _profile?.bio ?? '');
  late final _portfolio = TextEditingController(text: _profile?.portfolioUrl ?? '');
  late String? _interest = _profile?.interests.firstOrNull;
  late List<String> _tags = _profile?.tags ?? [];
  late String? _avatarUrl = _profile?.avatarUrl;
  bool _uploading = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _fullName.dispose();
    _bio.dispose();
    _portfolio.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final file = await pickFile(UploadKind.image);
    if (file == null) return;
    setState(() => _uploading = true);
    try {
      final url = await uploadFile(ref.read(apiProvider), file);
      setState(() => _avatarUrl = url);
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _submit() async {
    final fullName = _fullName.text.trim();
    if (fullName.isEmpty) return setState(() => _error = 'Enter your name to continue.');

    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    try {
      final json = await api.put<Map<String, dynamic>>('/users/me/profile', {
        'fullName': fullName,
        'bio': _bio.text.trim(),
        'interests': [?_interest],
        'tags': _tags,
        'avatarUrl': _avatarUrl,
        'portfolioUrl': _portfolio.text.trim(),
      });
      api.updateUser(Me.fromJson(json));
      if (mounted) context.go('/network-visibility');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final gap = context.dvh(6, 1.2, 16);
    final inputHeight = context.dvh(44, 7, 56);

    return AuthShell(
      contentWidth: 652,
      backHref: '/join-network',
      child: Column(
        children: [
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 396),
            child: Column(
              children: [
                SizedBox(height: context.dvh(72, 9, 120), child: const AssetIcon('illustrations/vol-logo.png')),
                SizedBox(height: context.dvh(6, 1, 24)),
                Text(
                  'Create Personal Profile',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: context.isSm ? context.dvh(20, 4, 32) : 24,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -.32,
                    color: dark ? Dak.heading : Hex.black,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tell us a bit about yourself to tailor your experience.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: dark ? Dak.body : Hex.text),
                ),
              ],
            ),
          ),
          SizedBox(height: context.dvh(4, 1.2, 40)),
          GlowCard(
            padding: EdgeInsets.symmetric(horizontal: context.isSm ? 41 : 24, vertical: context.dvh(10, 1.5, 28)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(bottom: context.dvh(8, 1.2, 16)),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _PhotoSquare(url: _avatarUrl, size: context.dvh(44, 5.5, 80)),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Profile Photo', style: _sectionLabel(context).copyWith(color: dark ? Dak.heading : Hex.black)),
                          const SizedBox(height: 6),
                          CameraButton(
                            label: _uploading ? 'Uploading…' : (_avatarUrl != null ? 'Change Image' : 'Upload Image'),
                            onPressed: _uploading ? null : _pickPhoto,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _divider(context),
                SizedBox(height: gap),
                const FieldLabel('Full Name'),
                const SizedBox(height: 6),
                FormInput(controller: _fullName, hint: 'Enter your name', height: inputHeight),
                SizedBox(height: gap),
                const FieldLabel('Bio'),
                const SizedBox(height: 6),
                FormInput(
                  controller: _bio,
                  hint: 'Briefly describe your expertise and goals...',
                  height: context.dvh(40, 5.5, 80),
                  maxLines: null,
                ),
                SizedBox(height: gap),
                const FieldLabel('Interest'),
                const SizedBox(height: 6),
                FormSelect(
                  value: _interest,
                  options: const ['Architecture', 'Engineering', 'Construction'],
                  placeholder: 'Select your main area of focus',
                  height: inputHeight,
                  onChanged: (v) => setState(() => _interest = v),
                ),
                SizedBox(height: gap),
                Text('Category Tags', style: TextStyle(fontSize: 16, color: dark ? Dak.heading : Auth.navy)),
                const SizedBox(height: 6),
                TagInput(tags: _tags, onChanged: (t) => setState(() => _tags = t)),
                SizedBox(height: gap),
                _divider(context),
                SizedBox(height: context.dvh(8, 1.2, 16)),
                Text('Portfolio Links', style: _sectionLabel(context)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const LinkBadge(),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FormInput(
                        controller: _portfolio,
                        hint: 'Portfolio URL (e.g., https://johndoe.com)',
                        horizontalPadding: 13,
                        keyboardType: TextInputType.url,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[SizedBox(height: gap), ErrorText(_error!)],
                SizedBox(height: gap + 8),
                VolButton(
                  label: _submitting ? 'Saving…' : 'Continue',
                  variant: ButtonVariant.cta,
                  radius: dark ? 999 : 16,
                  onPressed: _submitting ? null : _submit,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

const _industrySegments = ['Architecture', 'Engineering', 'Construction', 'Manufacturing'];
const _specialties = ['Structural', 'Mechanical', 'Electrical', 'Civil', 'Industrial Design'];

enum _Slot { cover, logo, doc }

class _BusinessForm extends ConsumerStatefulWidget {
  const _BusinessForm();

  @override
  ConsumerState<_BusinessForm> createState() => _BusinessFormState();
}

class _BusinessFormState extends ConsumerState<_BusinessForm> {
  late final Me? _user = ref.read(authProvider);
  late final MyBusiness? _business = _user?.business;
  late final _name = TextEditingController(text: _business?.legalName ?? '');
  late final _email = TextEditingController(text: _business?.contactEmail ?? _user?.email ?? '');
  late final _website = TextEditingController(text: _business?.website ?? '');
  late String? _specialty = _business?.specialty;
  late String? _industry = _business?.industry;
  late String? _coverUrl = _business?.coverUrl;
  late String? _logoUrl = _business?.logoUrl;
  late String? _docUrl = _business?.verificationDocUrl;
  String? _docName;
  _Slot? _busy;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _website.dispose();
    super.dispose();
  }

  Future<void> _upload(_Slot slot, [PickedFile? dropped]) async {
    final kind = slot == _Slot.doc ? UploadKind.document : UploadKind.image;
    final file = dropped ?? await pickFile(kind);
    if (file == null) return;
    setState(() => _busy = slot);
    try {
      final url = await uploadFile(ref.read(apiProvider), file, kind);
      setState(() {
        switch (slot) {
          case _Slot.cover:
            _coverUrl = url;
          case _Slot.logo:
            _logoUrl = url;
          case _Slot.doc:
            _docUrl = url;
            _docName = file.name;
        }
      });
    } catch (e) {
      setState(() => _error = errorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _submit() async {
    final legalName = _name.text.trim();
    final email = _email.text.trim();
    if (legalName.isEmpty || email.isEmpty) {
      return setState(() => _error = 'Enter your legal business name and a contact email to continue.');
    }

    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    try {
      final json = await api.put<Map<String, dynamic>>('/users/me/business', {
        'legalName': legalName,
        'contactEmail': email,
        'specialty': _specialty ?? '',
        'industry': _industry ?? '',
        'website': _website.text.trim(),
        'coverUrl': _coverUrl,
        'logoUrl': _logoUrl,
        'verificationDocUrl': _docUrl,
      });
      api.updateUser(Me.fromJson(json));
      if (mounted) context.go('/network-visibility?persona=business');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(e);
        _submitting = false;
      });
    }
  }

  BoxDecoration _dropDecoration(bool dark) => BoxDecoration(
    color: dark ? Dak.border : const Color(0xFFF5F5F5),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: dark ? Dak.border : Light.border),
  );

  Widget _pill(String text, bool dark, {double height = 29, double padding = 16}) => Container(
    height: height,
    padding: EdgeInsets.symmetric(horizontal: padding),
    decoration: BoxDecoration(color: dark ? const Color(0xFF45464D) : const Color(0xFFE4E4E7), borderRadius: BorderRadius.circular(6)),
    child: Center(
      widthFactor: 1,
      child: Text(
        text,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: dark ? Dak.heading : Hex.black),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final body = dark ? Dak.body : Hex.text;
    final gap = context.dvh(6, .7, 10);
    final inputHeight = context.dvh(44, 7, 56);
    final heading = TextStyle(fontSize: context.isSm ? 24 : 20, fontWeight: FontWeight.w700, color: dark ? Dak.heading : Hex.black);

    Widget section(List<Widget> children, {bool last = false}) => Container(
      width: double.infinity,
      padding: EdgeInsets.only(bottom: last ? 0 : gap),
      decoration: last
          ? null
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: dark ? Dak.border : Dak.cta.withValues(alpha: .6))),
            ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
    );

    final upload = AssetIcon('icons/upload-cloud.svg', width: 24, height: 30, color: dark ? null : Colors.black);

    final specialty = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RequiredLabel('Primary Specialty', required: false),
        const SizedBox(height: 6),
        FormSelect(
          value: _specialty,
          options: _specialties,
          placeholder: 'Select your trade',
          height: inputHeight,
          onChanged: (v) => setState(() => _specialty = v),
        ),
      ],
    );
    final industry = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const RequiredLabel('Industry Segment'),
        const SizedBox(height: 6),
        FormSelect(
          value: _industry,
          options: _industrySegments,
          placeholder: 'Select Industry',
          height: inputHeight,
          onChanged: (v) => setState(() => _industry = v),
        ),
      ],
    );

    return AuthShell(
      contentWidth: 820,
      backHref: '/join-network',
      child: Column(
        children: [
          SizedBox(height: context.dvh(56, 6, 80), child: const AssetIcon('illustrations/vol-logo.png')),
          const SizedBox(height: 8),
          Text(
            'Business Registration',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: context.isSm ? context.dvh(20, 4, 32) : 24,
              fontWeight: FontWeight.w700,
              color: dark ? Dak.heading : Hex.black,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 575),
            child: Text(
              'Join the leading network of precision engineering firms and manufacturers.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, height: 23 / 16, fontWeight: FontWeight.w500, color: body),
            ),
          ),
          SizedBox(height: context.dvh(4, .6, 10)),
          GlowCard(
            padding: EdgeInsets.symmetric(horizontal: context.isSm ? 41 : 24, vertical: context.dvh(8, .8, 16)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropZone(
                  onTap: () => _upload(_Slot.cover),
                  onFile: (f) => _upload(_Slot.cover, f),
                  minHeight: context.dvh(56, 5.5, 80),
                  decoration: _dropDecoration(dark),
                  child: Stack(
                    children: [
                      if (_coverUrl != null) Positioned.fill(child: UserImage(src: _coverUrl, opacity: .4)),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              upload,
                              const SizedBox(height: 6),
                              Text('or drag and drop', style: TextStyle(fontSize: 14, color: body)),
                              const SizedBox(height: 6),
                              Text(
                                'PDF, PNG, JPG up to 10MB',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: body),
                              ),
                              const SizedBox(height: 6),
                              _pill(
                                _busy == _Slot.cover ? 'Uploading…' : (_coverUrl != null ? 'Change cover image' : 'Upload cover image'),
                                dark,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: gap),
                section([
                  Center(
                    child: Column(
                      children: [
                        _PhotoSquare(url: _logoUrl, size: context.dvh(48, 4.5, 72)),
                        const SizedBox(height: 12),
                        CameraButton(
                          label: _busy == _Slot.logo ? 'Uploading…' : (_logoUrl != null ? 'Change Image' : 'Upload Image'),
                          onPressed: _busy == _Slot.logo ? null : () => _upload(_Slot.logo),
                        ),
                      ],
                    ),
                  ),
                ]),
                SizedBox(height: gap),
                section([
                  Text('Business Information', style: heading),
                  SizedBox(height: gap),
                  const RequiredLabel('Legal Business Name'),
                  const SizedBox(height: 6),
                  FormInput(controller: _name, hint: "Enter your company's legal name", height: inputHeight, fill: false),
                  SizedBox(height: gap),
                  if (context.isSm)
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: specialty),
                        SizedBox(width: gap),
                        Expanded(child: industry),
                      ],
                    )
                  else ...[
                    specialty,
                    SizedBox(height: gap),
                    industry,
                  ],
                ]),
                SizedBox(height: gap),
                section([
                  Text('Primary Contact', style: heading),
                  SizedBox(height: gap),
                  const RequiredLabel('Professional Email Address'),
                  const SizedBox(height: 6),
                  FormInput(
                    controller: _email,
                    hint: 'you@company.com',
                    height: inputHeight,
                    keyboardType: TextInputType.emailAddress,
                    fill: false,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'We recommend using a role-based email (e.g., procurement@company.com) if applicable.',
                    style: TextStyle(fontSize: 14, color: body),
                  ),
                ]),
                SizedBox(height: gap),
                section([
                  Text('Portfolio Links', style: _sectionLabel(context, size: 18)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const LinkBadge(),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FormInput(
                          controller: _website,
                          hint: 'Portfolio URL (e.g., https://johndoe.com)',
                          horizontalPadding: 13,
                          keyboardType: TextInputType.url,
                        ),
                      ),
                    ],
                  ),
                ]),
                SizedBox(height: gap),
                section(last: true, [
                  Text('Business Verification', style: heading),
                  const SizedBox(height: 12),
                  Text(
                    'To maintain network integrity, please provide a valid business license or relevant industry '
                    'certification (ISO, AS9100, etc.).',
                    style: TextStyle(fontSize: 16, color: body),
                  ),
                  const SizedBox(height: 12),
                  DropZone(
                    onTap: () => _upload(_Slot.doc),
                    onFile: (f) => _upload(_Slot.doc, f),
                    minHeight: context.dvh(48, 4.5, 64),
                    decoration: _dropDecoration(dark),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          upload,
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _pill(
                                _busy == _Slot.doc ? 'Uploading…' : (_docUrl != null ? 'Replace file' : 'Upload a file'),
                                dark,
                                height: 28,
                                padding: 12,
                              ),
                              const SizedBox(width: 4),
                              Text('or drag and drop', style: TextStyle(fontSize: 14, color: body)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _docUrl != null ? '✓ ${_docName ?? 'Document uploaded'}' : 'PDF, PNG, JPG up to 10MB',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: body),
                          ),
                        ],
                      ),
                    ),
                  ),
                ]),
                if (_error != null) ...[SizedBox(height: gap), ErrorText(_error!)],
                SizedBox(height: gap),
                Container(
                  padding: EdgeInsets.only(top: context.dvh(12, 2, 25)),
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: dark ? Dak.border : Dak.cta.withValues(alpha: .6))),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      TextButton(
                        onPressed: () async {
                          await ref.read(apiProvider).logout();
                          if (context.mounted) context.go('/login');
                        },
                        child: Text(
                          'Return to Login',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            letterSpacing: .28,
                            color: dark ? Dak.heading : Hex.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Flexible(
                        child: SizedBox(
                          width: 212,
                          child: VolButton(
                            label: _submitting ? 'Submitting…' : 'Submit Application',
                            fontSize: 14,
                            variant: ButtonVariant.cta,
                            trailing: const AssetIcon('icons/arrow-right-small.svg', width: 16, height: 16),
                            onPressed: _submitting ? null : _submit,
                          ),
                        ),
                      ),
                    ],
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
