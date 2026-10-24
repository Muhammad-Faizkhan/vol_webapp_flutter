import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_error.dart';
import '../../core/api/upload.dart';
import '../../core/auth/auth.dart';
import '../../core/query.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/button.dart';
import '../../ui/drop_zone.dart';
import '../../ui/layout.dart';
import '../../ui/page_bits.dart';
import '../../ui/states.dart';
import '../../ui/text_field.dart';

const _industries = ['Architecture', 'Engineering', 'Construction'];

class CreateWorkspacePage extends ConsumerStatefulWidget {
  const CreateWorkspacePage({super.key});

  @override
  ConsumerState<CreateWorkspacePage> createState() => _CreateWorkspacePageState();
}

class _CreateWorkspacePageState extends ConsumerState<CreateWorkspacePage> {
  final _name = TextEditingController();
  final _description = TextEditingController();
  String? _industry;
  PickedFile? _photo;
  String? _error;
  bool _submitting = false;

  @override
  void dispose() {
    _name.dispose();
    _description.dispose();
    super.dispose();
  }

  void _setPhoto(PickedFile? file) {
    if (file == null || !file.type.startsWith('image/')) return;
    setState(() => _photo = file);
  }

  Future<void> _submit() async {
    final name = _name.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Give your workspace a name.');
    setState(() {
      _error = null;
      _submitting = true;
    });
    final api = ref.read(apiProvider);
    try {
      final imageUrl = _photo == null ? null : await uploadFile(api, _photo!);
      final workspace = await api.post<Map<String, dynamic>>('/workspaces', {
        'name': name,
        if (_description.text.trim().isNotEmpty) 'description': _description.text.trim(),
        'industry': ?_industry,
        'imageUrl': imageUrl,
      });
      invalidateQueries(ref);
      if (mounted) context.go('/workspaces/${workspace['id']}/canvases');
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
    final navy = dark ? Dak.heading : Auth.navy;
    final slate = dark ? Dak.body : Auth.slate;
    final border = dark ? Dak.border : Hex.text;
    final placeholder = dark ? Dak.muted : Hex.text.withValues(alpha: .6);
    final label = TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: navy);
    BoxDecoration box() => BoxDecoration(
      color: dark ? Colors.transparent : const Color(0xFFF8F9FF),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: border),
    );

    final photo = _photo;
    final drop = DropZone(
      onTap: () async => _setPhoto(await pickFile(UploadKind.image)),
      onFile: _setPhoto,
      decoration: BoxDecoration(color: dark ? Dak.surface : const Color(0xFFFEFEFE), borderRadius: BorderRadius.circular(16)),
      child: CustomPaint(
        foregroundPainter: DashedBorder(color: border, radius: 16, strokeWidth: 2),
        child: SizedBox(
          height: 149,
          width: double.infinity,
          child: photo != null
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(photo.bytes, fit: BoxFit.cover),
                    ColoredBox(
                      color: Colors.black.withValues(alpha: .4),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: .4),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white),
                          ),
                          child: const Text(
                            'Change photo',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Tooltip(
                        message: 'Remove photo',
                        child: InkWell(
                          onTap: () => setState(() => _photo = null),
                          child: Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.black.withValues(alpha: .6), shape: BoxShape.circle),
                            child: const Text('✕', style: TextStyle(fontSize: 14, color: Colors.white)),
                          ),
                        ),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AssetIcon('icons/camera.svg', width: 27, height: 25, color: dark ? null : Colors.black),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 9),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: border),
                      ),
                      child: Text(
                        'Drag /Upload photo',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.text),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );

    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BackLink(href: '/workspaces'),
            const SizedBox(height: 24),
            Text(
              'Create Workspace',
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -.32, color: navy),
            ),
            const SizedBox(height: 8),
            Text(
              'Configure a new environment for your team’s projects, resources, and collaboration.',
              style: TextStyle(fontSize: 16, color: slate),
            ),
            const SizedBox(height: 24),
            drop,
            const SizedBox(height: 24),
            Text(
              'Workspace Details',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: navy),
            ),
            const SizedBox(height: 4),
            Text('Define the foundational details of your new workspace.', style: TextStyle(fontSize: 16, color: slate)),
            const SizedBox(height: 24),
            Text('Workspace Name', style: label),
            const SizedBox(height: 8),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: box(),
              child: TextField(
                controller: _name,
                style: TextStyle(fontSize: 16, color: navy),
                decoration: InputDecoration.collapsed(
                  hintText: 'e.g. Structural Engineering Dept',
                  hintStyle: TextStyle(fontSize: 16, color: placeholder),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Description (Optional)', style: label),
            const SizedBox(height: 8),
            Container(
              height: 100,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: box(),
              child: TextField(
                controller: _description,
                maxLines: null,
                expands: true,
                style: TextStyle(fontSize: 16, color: navy),
                decoration: InputDecoration.collapsed(
                  hintText: 'Briefly describe the purpose of this workspace...',
                  hintStyle: TextStyle(fontSize: 16, color: placeholder),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text('Industry / Trade Focus', style: label),
            const SizedBox(height: 8),
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: box(),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _industry,
                  isExpanded: true,
                  hint: Text('Select an industry focus...', style: TextStyle(fontSize: 16, color: placeholder)),
                  icon: AssetIcon('icons/dropdown-arrow.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                  dropdownColor: dark ? Dak.surface : Colors.white,
                  style: TextStyle(fontSize: 16, color: placeholder),
                  items: [for (final i in _industries) DropdownMenuItem(value: i, child: Text(i))],
                  onChanged: (v) => setState(() => _industry = v),
                ),
              ),
            ),
            if (_error != null) ...[const SizedBox(height: 24), ErrorText(_error!)],
            const SizedBox(height: 24),
            VolButton(
              label: _submitting ? 'Creating…' : 'Continue',
              variant: ButtonVariant.dark,
              radius: 16,
              onPressed: _submitting ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
