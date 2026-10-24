import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../core/query.dart';
import '../../models/canvas.dart';
import '../../models/classroom.dart';
import '../../models/product.dart';
import '../../models/user.dart';
import '../../theme/tokens.dart';
import '../../ui/asset_icon.dart';
import '../../ui/auto_grid.dart';
import '../../ui/card_box.dart';
import '../../ui/layout.dart';
import '../../ui/link_box.dart';
import '../../ui/page_bits.dart';
import '../../ui/states.dart';
import '../../ui/user_image.dart';
import '../shared/report_button.dart';
import '../shared/social.dart';

const _tabs = ['Overview', 'Products', 'Canvases', 'Classrooms'];

class BusinessProfilePage extends ConsumerStatefulWidget {
  const BusinessProfilePage({super.key, required this.id});

  final String id;

  @override
  ConsumerState<BusinessProfilePage> createState() => _BusinessProfilePageState();
}

class _BusinessProfilePageState extends ConsumerState<BusinessProfilePage> {
  String _tab = 'Overview';

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(query('/users/${widget.id}'));
    if (result.hasError) return ErrorState(error: result.error!);
    final json = result.value as Map<String, dynamic>?;
    if (json == null) return const SizedBox.shrink();
    final p = PublicProfile.fromJson(json);

    final all = _tab != 'Overview';
    final products = pagedOf(ref, withQuery('/products', {'businessId': p.id, 'limit': all ? 24 : 3}), Product.fromJson);
    final canvases = pagedOf(ref, withQuery('/canvases/public', {'authorId': p.id, 'limit': all ? 24 : 3}), CanvasCard.fromJson);
    final classrooms = pagedOf(
      ref,
      withQuery('/classrooms', {'scope': 'explore', 'instructorId': p.id, 'limit': all ? 24 : 2}),
      ClassroomCard.fromJson,
    );

    final dark = context.isDark;
    final b = p.business;
    final name = b?.legalName ?? p.name;
    final line = dark ? Dak.border : Dak.line;

    Widget stat(int value, String label, {bool big = false}) => Container(
      padding: EdgeInsets.symmetric(horizontal: big ? 32 : 16, vertical: 12),
      decoration: BoxDecoration(
        color: big ? null : (dark ? Dak.surface : Colors.white),
        gradient: big
            ? LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: dark ? const [Dak.surface, Dak.surface] : const [Colors.white, Color(0xFFF3E8FF)],
              )
            : null,
        borderRadius: BorderRadius.circular(big ? 8 : 4),
        border: Border.all(color: big ? Dak.cta : line),
      ),
      child: Column(
        children: [
          Text(
            compactNumber(value),
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink),
          ),
          const SizedBox(height: 8),
          Text(
            label.toUpperCase(),
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: context.mutedText),
          ),
        ],
      ),
    );

    final crumb = TextStyle(fontSize: 14, color: context.body);
    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          height: context.isSm ? 64 : 80,
          child: OverflowBox(
            alignment: Alignment.bottomCenter,
            maxHeight: 120,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: dark ? Dak.bg : Colors.white, width: 4),
              ),
              child: Avatar(src: p.avatarUrl, name: name, size: 112),
            ),
          ),
        ),
        const SizedBox(width: 24),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: context.isSm ? 48 : 30,
                        height: context.isSm ? 56 / 48 : null,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -.6,
                        color: context.ink,
                      ),
                    ),
                  ),
                  if (p.verified) ...[const SizedBox(width: 8), const AssetIcon('icons/verified-badge.svg', width: 22, height: 21)],
                ],
              ),
              const SizedBox(height: 12),
              Text(b?.industry ?? p.specialty ?? 'Business', style: TextStyle(fontSize: 18, color: context.body)),
              const SizedBox(height: 12),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  stat(p.stats['followers'] ?? 0, 'Followers', big: true),
                  const SizedBox(width: 16),
                  stat(p.stats['following'] ?? 0, 'Followings', big: true),
                ],
              ),
            ],
          ),
        ),
      ],
    );
    final counts = Row(
      mainAxisSize: context.isLg ? MainAxisSize.min : MainAxisSize.max,
      children: [
        for (final (i, (v, l)) in [
          (p.stats['products'] ?? 0, 'Products'),
          (p.stats['canvases'] ?? 0, 'Canvases'),
          (p.stats['classrooms'] ?? 0, 'Classrooms'),
        ].indexed) ...[if (i > 0) const SizedBox(width: 16), context.isLg ? stat(v, l) : Expanded(child: stat(v, l))],
      ],
    );

    final main = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_tab == 'Overview') ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration(context, blur: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('About $name', style: _h2(context)),
                const SizedBox(height: 8),
                Text(b?.description ?? p.bio ?? 'No description yet.', style: TextStyle(fontSize: 16, color: context.body)),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
        if (_tab == 'Overview' || _tab == 'Products') ...[
          _SignatureProducts(items: products?.items ?? const []),
          const SizedBox(height: 32),
        ],
        if (_tab == 'Overview' || _tab == 'Canvases') ...[
          _TechnicalCanvases(items: canvases?.items ?? const []),
          const SizedBox(height: 32),
        ],
        if (_tab == 'Overview' || _tab == 'Classrooms') _TrainingClassrooms(items: classrooms?.items ?? const []),
      ],
    );

    final side = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!p.isSelf) ...[
          Container(
            padding: const EdgeInsets.all(24),
            decoration: cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Connect with $name',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink),
                ),
                const SizedBox(height: 12),
                Text(
                  'Follow to see their posts in your feed and new products on your home page.',
                  style: TextStyle(fontSize: 14, color: context.body),
                ),
                const SizedBox(height: 20),
                FollowButton(
                  userId: p.id,
                  initial: p.isFollowing,
                  look: (context, following) => Container(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: following ? (dark ? Dak.cta : Hex.black) : null,
                      borderRadius: BorderRadius.circular(4),
                      border: following ? null : Border.all(color: dark ? Dak.border : Hex.text),
                    ),
                    child: Text(
                      following ? 'Following' : '+ Follow',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: following ? Colors.white : context.ink),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ReportButton(
                    targetType: 'USER',
                    targetId: p.id,
                    label: 'Report this business',
                    style: const TextStyle(fontSize: 12, color: Color(0xFF929292)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
        Container(
          padding: const EdgeInsets.all(24),
          decoration: cardDecoration(context, blur: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: dark ? Dak.border : Light.border)),
                ),
                child: Text(
                  'PROFILE DETAILS',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: .7, color: context.ink),
                ),
              ),
              const SizedBox(height: 20),
              _Detail(
                icon: AssetIcon('icons/email.svg', width: 15, height: 12, color: dark ? Colors.white : null),
                label: 'Email',
                child: b?.contactEmail != null ? _Url(text: b!.contactEmail!, href: 'mailto:${b.contactEmail}') : const _DetailText('—'),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AssetIcon('icons/phone-badge.svg', width: 40, height: 40),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Phone Number',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.mutedText),
                      ),
                      const SizedBox(height: 4),
                      _DetailText(b?.phone ?? '—'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _Detail(
                icon: AssetIcon('icons/expertise.svg', width: 16, height: 20, color: dark ? Colors.white : null),
                label: 'Professional Expertise',
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final tag in (b?.categoryTags.isNotEmpty ?? false) ? b!.categoryTags : const ['—'])
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Dak.cta.withValues(alpha: .1),
                          borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: Dak.cta.withValues(alpha: .2)),
                        ),
                        child: Text(
                          tag,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Dak.cta),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _Detail(
                icon: AssetIcon('icons/website.svg', width: 20, height: 20, color: dark ? Colors.white : null),
                label: 'Website',
                child: b?.website != null
                    ? _Url(text: b!.website!.replaceFirst(RegExp(r'^https?://'), ''), href: b.website!)
                    : const _DetailText('—'),
              ),
            ],
          ),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            TextLink('Explore', href: '/explore', style: crumb),
            Text('›', style: crumb),
            TextLink('Business Profile', href: '/explore?tab=peoples', style: crumb),
            Text('›', style: crumb),
            Text(
              name,
              style: crumb.copyWith(fontWeight: FontWeight.w500, color: context.ink),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const BackLink(href: '/explore?tab=peoples'),
        const SizedBox(height: 24),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: context.isLg ? 320 : (context.isSm ? 260 : 180),
            child: UserImage(src: b?.coverUrl ?? p.coverUrl, fallback: 'illustrations/business-profile-hero.png'),
          ),
        ),
        const SizedBox(height: 24),
        if (context.isLg)
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: identity),
              counts,
            ],
          )
        else ...[
          identity,
          const SizedBox(height: 24),
          counts,
        ],
        const SizedBox(height: 24),
        Container(
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: line)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final (i, tab) in _tabs.indexed) ...[
                  if (i > 0) const SizedBox(width: 32),
                  _Tab(label: tab, active: _tab == tab, onTap: () => setState(() => _tab = tab)),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        if (context.screenWidth >= 1280)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 32),
              SizedBox(width: 380, child: side),
            ],
          )
        else ...[
          main,
          const SizedBox(height: 32),
          side,
        ],
      ],
    );
  }
}

TextStyle _h2(BuildContext context) => TextStyle(fontSize: 24, fontWeight: FontWeight.w600, letterSpacing: -.32, color: context.ink);

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(top: 8, bottom: 18),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: active ? (dark ? Dak.cta : Hex.black) : Colors.transparent, width: 2)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
            letterSpacing: .28,
            color: active ? context.ink : context.mutedText,
          ),
        ),
      ),
    );
  }
}

class _SignatureProducts extends StatelessWidget {
  const _SignatureProducts({required this.items});

  final List<Product> items;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final line = dark ? Dak.border : Dak.line;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Signature Products', style: _h2(context)),
        const SizedBox(height: 24),
        if (items.isEmpty) Text('No published products yet.', style: TextStyle(fontSize: 14, color: context.body)),
        AutoGrid(
          minItemWidth: 260,
          gap: 24,
          fill: true,
          children: [
            for (final p in items)
              Container(
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: dark ? Dak.surface : Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: dark ? Dak.border : Light.border.withValues(alpha: .6)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 130,
                      child: ColoredBox(
                        color: dark ? Dak.bg : Auth.navy,
                        child: UserImage(src: p.images.firstOrNull, fallback: 'illustrations/classroom-thumb-engineers.jpg'),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            (p.brand ?? p.business.name).toUpperCase(),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, letterSpacing: .6, color: context.mutedText),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            p.name,
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.ink),
                          ),
                          const SizedBox(height: 12),
                          for (final (i, (label, value)) in productSpecs(p).indexed) ...[
                            if (i > 0) const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.only(bottom: 4),
                              decoration: i < productSpecs(p).length - 1
                                  ? BoxDecoration(
                                      border: Border(bottom: BorderSide(color: line)),
                                    )
                                  : null,
                              child: Row(
                                children: [
                                  Text(label, style: TextStyle(fontSize: 14, color: context.body)),
                                  const Spacer(),
                                  Text(
                                    value,
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: context.ink),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          LinkBox(
                            href: '/products/${p.id}',
                            child: Container(
                              height: 33,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Dak.cta,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [BoxShadow(color: Dak.cta.withValues(alpha: .4), offset: const Offset(0, 8), blurRadius: 6)],
                              ),
                              child: const Text(
                                'View Details',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.white),
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
      ],
    );
  }
}

class _TechnicalCanvases extends StatelessWidget {
  const _TechnicalCanvases({required this.items});

  final List<CanvasCard> items;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text('Technical Canvases', style: _h2(context)),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Dak.cta.withValues(alpha: .1), borderRadius: BorderRadius.circular(2)),
              child: const Text(
                'Public',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Dak.cta),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        if (items.isEmpty) Text('No public canvases yet.', style: TextStyle(fontSize: 14, color: context.body)),
        AutoGrid(
          minItemWidth: 260,
          gap: 24,
          fill: true,
          children: [
            for (final c in items)
              LinkBox(
                href: '/canvas/${c.id}',
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: dark ? Dak.surface : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [BoxShadow(color: Hex.text.withValues(alpha: .2), offset: const Offset(0, 4), blurRadius: 8)],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      SizedBox(
                        height: 130,
                        child: ColoredBox(
                          color: dark ? Dak.bg : Auth.navy,
                          child: Stack(
                            fit: StackFit.expand,
                            children: [
                              UserImage(src: c.thumbnailUrl, fallback: 'illustrations/canvas-thumb-mortar-pattern.jpg'),
                              Positioned(
                                right: 16,
                                top: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: const Color(0xFF45464D), borderRadius: BorderRadius.circular(2)),
                                  child: Text(
                                    '+${c.collaboratorCount} Collabs',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: Colors.white),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              c.title,
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, letterSpacing: .28, color: context.ink),
                            ),
                            const SizedBox(height: 8),
                            Text(c.workspaceName, style: TextStyle(fontSize: 14, letterSpacing: .28, color: context.mutedText)),
                            const SizedBox(height: 8),
                            Text(
                              'Edited ${timeAgo(c.updatedAt)} · ${plural(c.productCount, 'Product')}',
                              style: TextStyle(fontSize: 14, color: dark ? Dak.muted : const Color(0xFF929292)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrainingClassrooms extends StatelessWidget {
  const _TrainingClassrooms({required this.items});

  final List<ClassroomCard> items;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Training & Classrooms', style: _h2(context)),
        const SizedBox(height: 24),
        if (items.isEmpty) Text('No public classrooms yet.', style: TextStyle(fontSize: 14, color: context.body)),
        for (final (i, c) in items.indexed) ...[
          if (i > 0) const SizedBox(height: 24),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: cardDecoration(context),
            child: Flex(
              direction: context.isSm ? Axis.horizontal : Axis.vertical,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: context.isSm ? 220 : null,
                  height: context.isSm ? 200 : 180,
                  child: UserImage(src: c.imageUrl, fallback: 'illustrations/canvas-thumb-moodboard.png'),
                ),
                Flexible(
                  fit: context.isSm ? FlexFit.tight : FlexFit.loose,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AssetIcon('icons/beginner-star.svg', width: 9, height: 12, color: dark ? Colors.white : null),
                            const SizedBox(width: 8),
                            Text(
                              (c.skillLevel != null ? titleCase(c.skillLevel!) : 'All levels').toUpperCase(),
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: .6, color: context.mutedText),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          c.title,
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: context.ink),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${c.category ?? 'Classroom'} · ${plural(c.moduleCount, 'module')} · ${plural(c.lessonCount, 'lesson')}',
                          style: TextStyle(fontSize: 16, color: context.body),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            LinkBox(
                              href: '/classrooms/${c.id}',
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(2),
                                  border: Border.all(color: dark ? Dak.border : Hex.text),
                                ),
                                child: Text(
                                  'View Syllabus',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: dark ? Dak.heading : Hex.text),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            AssetIcon('icons/graduates.svg', width: 15, height: 11, color: dark ? Colors.white : null),
                            const SizedBox(width: 4),
                            Text(
                              '${c.enrolledCount} Enrolled',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: context.mutedText),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.label, required this.child});

  final Widget icon;
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: Hex.black.withValues(alpha: .1), borderRadius: BorderRadius.circular(2)),
          child: icon,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: context.mutedText),
              ),
              const SizedBox(height: 4),
              child,
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailText extends StatelessWidget {
  const _DetailText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: context.ink),
  );
}

class _Url extends StatelessWidget {
  const _Url({required this.text, required this.href});

  final String text;
  final String href;

  @override
  Widget build(BuildContext context) => MouseRegion(
    cursor: SystemMouseCursors.click,
    child: GestureDetector(
      onTap: () => launchUrl(Uri.parse(href), webOnlyWindowName: href.startsWith('mailto:') ? '_self' : '_blank'),
      child: _DetailText(text),
    ),
  );
}
