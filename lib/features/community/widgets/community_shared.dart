import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';
import 'package:vidhai/data/models/market_price_models.dart';
import 'package:vidhai/features/community/models/community_models.dart';
import 'package:vidhai/features/community/services/price_risk_service.dart';
import 'package:vidhai/locale/locale.dart';

/// Formats a post/comment timestamp in the current locale.
String communityDate(BuildContext context, DateTime? date) {
  if (date == null) return '';
  final locale = Localizations.localeOf(context).toLanguageTag();
  return DateFormat.yMMMd(locale).format(date);
}

/// Returns an image provider for both the new inline Firestore data URLs and
/// legacy HTTP/Firebase Storage URLs.
ImageProvider<Object>? communityImageProvider(String source) {
  final value = source.trim();
  if (value.isEmpty) return null;

  if (value.startsWith('data:image/')) {
    const marker = ';base64,';
    final markerIndex = value.indexOf(marker);
    if (markerIndex > 0) {
      try {
        final encoded = value.substring(markerIndex + marker.length);
        return MemoryImage(base64Decode(encoded));
      } catch (_) {
        return null;
      }
    }
  }

  return NetworkImage(value);
}

Color riskColor(BuildContext context, PriceRiskLevel level) {
  final colors = FreshLeafColorsX(context);
  switch (level) {
    case PriceRiskLevel.competitive:
      return colors.success;
    case PriceRiskLevel.slightlyHigh:
      return colors.warning;
    case PriceRiskLevel.high:
      return const Color(0xFFEF6C00);
    case PriceRiskLevel.veryHigh:
      return colors.error;
  }
}

Color postTypeColor(BuildContext context, CommunityPostType type) {
  final colors = FreshLeafColorsX(context);
  switch (type) {
    case CommunityPostType.experience:
      return colors.info;
    case CommunityPostType.harvest:
      return colors.success;
    case CommunityPostType.demand:
      return colors.warning;
  }
}

String postTypeLabel(AppLocalizations loc, CommunityPostType type) {
  switch (type) {
    case CommunityPostType.experience:
      return loc.communityTabExperience;
    case CommunityPostType.harvest:
      return loc.communityTabHarvestSoon;
    case CommunityPostType.demand:
      return loc.communityTabDemand;
  }
}

String riskLabel(AppLocalizations loc, PriceRiskLevel level) {
  switch (level) {
    case PriceRiskLevel.competitive:
      return loc.priceRiskCompetitive;
    case PriceRiskLevel.slightlyHigh:
      return loc.priceRiskSlightlyHigh;
    case PriceRiskLevel.high:
      return loc.priceRiskHigh;
    case PriceRiskLevel.veryHigh:
      return loc.priceRiskVeryHigh;
  }
}

String statusLabel(AppLocalizations loc, CommunityStatus status) {
  switch (status) {
    case CommunityStatus.active:
      return '';
    case CommunityStatus.reserved:
      return loc.communityReserved;
    case CommunityStatus.fulfilled:
      return loc.communityFulfilled;
    case CommunityStatus.closed:
      return loc.communityClosed;
  }
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    this.photo = '',
    this.name = '',
    this.radius = 20,
  });

  final String photo;
  final String name;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();
    final fallback = CircleAvatar(
      radius: radius,
      backgroundColor: colors.brand.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(
          color: colors.brandDeep,
          fontWeight: FontWeight.w700,
          fontSize: radius * 0.8,
        ),
      ),
    );

    final provider = communityImageProvider(photo);
    if (provider == null) return fallback;

    return CircleAvatar(
      radius: radius,
      backgroundColor: colors.surfaceMuted,
      child: ClipOval(
        child: Image(
          image: provider,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => fallback,
        ),
      ),
    );
  }
}

class CommunityChip extends StatelessWidget {
  const CommunityChip({
    super.key,
    required this.label,
    this.color,
    this.icon,
    this.filled = false,
  });

  final String label;
  final Color? color;
  final IconData? icon;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final c = color ?? colors.onSurfaceMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: filled ? c.withValues(alpha: 0.14) : colors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: filled ? null : Border.all(color: colors.borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              color: filled ? c : colors.onSurfaceMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class PriceRiskBar extends StatelessWidget {
  const PriceRiskBar({super.key, required this.risk});

  final PriceRiskResult risk;

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    if (risk.unknown) {
      return Text(
        loc.communityNoMarketData,
        style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12.5),
      );
    }

    final pct = risk.pctOfReference;
    final clamped = pct.clamp(80.0, 140.0);
    final position = (clamped - 80) / 60;
    final color = riskColor(context, risk.level);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                loc.communityBuyerAcceptanceRisk,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Text(
              '${pct.toStringAsFixed(0)}%',
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            const dot = 12.0;
            final x = (constraints.maxWidth - dot) * position;
            return SizedBox(
              height: 18,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      height: 8,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [
                            Color(0xFF2E7D32),
                            Color(0xFFF9A825),
                            Color(0xFFEF6C00),
                            Color(0xFFC62828),
                          ],
                          stops: [0.0, 0.42, 0.58, 1.0],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: x,
                    top: 0,
                    child: Container(
                      width: dot,
                      height: dot,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 3,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Text(
              riskLabel(loc, risk.level),
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            if (risk.belowMarketStart) ...[
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  loc.communityBelowMarketWarning,
                  style: TextStyle(
                    color: colors.warning,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

class CommunityPostCard extends StatelessWidget {
  const CommunityPostCard({
    super.key,
    required this.post,
    this.onTap,
  });

  final CommunityPost post;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final colors = FreshLeafColorsX(context);
    final loc = AppLocalizations.of(context);
    final typeColor = postTypeColor(context, post.type);
    final imageProvider = communityImageProvider(post.imageUrl);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(context, loc, colors, typeColor),
                const SizedBox(height: 10),
                _body(context, loc, colors, typeColor),
                if (imageProvider != null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image(
                      image: imageProvider,
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                _footer(context, loc, colors),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(
    BuildContext context,
    AppLocalizations loc,
    FreshLeafColorsX colors,
    Color typeColor,
  ) {
    final time = communityDate(context, post.createdAt);
    return Row(
      children: [
        CommunityAvatar(photo: post.authorPhoto, name: post.authorName),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.authorName.isEmpty ? loc.communityOwner : post.authorName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (post.district.isNotEmpty || time.isNotEmpty)
                Text(
                  [post.district, time].where((e) => e.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceMuted,
                    fontSize: 11.5,
                  ),
                ),
            ],
          ),
        ),
        CommunityChip(
          label: postTypeLabel(loc, post.type),
          color: typeColor,
          filled: true,
        ),
        if (post.status != CommunityStatus.active) ...[
          const SizedBox(width: 6),
          CommunityChip(label: statusLabel(loc, post.status)),
        ],
      ],
    );
  }

  Widget _body(
    BuildContext context,
    AppLocalizations loc,
    FreshLeafColorsX colors,
    Color typeColor,
  ) {
    if (post.isExperience) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (post.title.isNotEmpty)
            Text(
              post.title,
              style: TextStyle(
                color: colors.onBackground,
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          if (post.experienceText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              post.experienceText,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: colors.onSurfaceMuted,
                fontSize: 13.5,
                height: 1.35,
              ),
            ),
          ],
        ],
      );
    }

    final isHarvest = post.isHarvest;
    final price = isHarvest ? post.askingPricePerKg : post.targetPricePerKg;
    final date = isHarvest ? post.harvestDate : post.requiredDate;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                post.cropName,
                style: TextStyle(
                  color: colors.onBackground,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (price != null)
              Text(
                '${MarketFormat.inr(price)}${loc.communityPricePerKg}',
                style: TextStyle(
                  color: typeColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            if (post.quantityKg != null)
              CommunityChip(
                label: '${_qty(post.quantityKg!)} ${loc.communityKgUnit}',
                icon: Icons.scale_outlined,
              ),
            if (date != null)
              CommunityChip(
                label: isHarvest
                    ? _harvestLabel(loc, post)
                    : '${loc.communityRequiredBy}: ${communityDate(context, date)}',
                icon: isHarvest
                    ? Icons.agriculture_outlined
                    : Icons.event_outlined,
              ),
            if (isHarvest && post.marketReferencePerKg != null)
              CommunityChip(
                label:
                    '${loc.communityMarketPriceLabel}: ${MarketFormat.inr(post.marketReferencePerKg)}/${loc.communityKgUnit}',
                icon: Icons.trending_up,
              ),
          ],
        ),
        if (post.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            post.description,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onSurfaceMuted,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    AppLocalizations loc,
    FreshLeafColorsX colors,
  ) {
    final children = <Widget>[];
    if (post.isExperience) {
      children.add(
        _stat(
          colors,
          Icons.favorite_border,
          loc.communityLikes('${post.likeCount}'),
        ),
      );
      children.add(
        _stat(
          colors,
          Icons.mode_comment_outlined,
          loc.communityComments('${post.commentCount}'),
        ),
      );
    } else if (post.isHarvest) {
      children.add(
        _stat(
          colors,
          Icons.handshake_outlined,
          loc.communityInterestedCount('${post.interestedCount}'),
        ),
      );
    } else {
      children.add(
        _stat(
          colors,
          Icons.local_shipping_outlined,
          loc.communitySupplierCount('${post.supplierCount}'),
        ),
      );
    }

    children.add(const Spacer());
    children.add(
      Text(
        loc.communityViewDetails,
        style: TextStyle(
          color: colors.brand,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Row(children: children);
  }

  Widget _stat(FreshLeafColorsX colors, IconData icon, String label) => Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: colors.onSurfaceMuted),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
            ),
          ],
        ),
      );

  String _harvestLabel(AppLocalizations loc, CommunityPost post) {
    final days = post.daysUntilHarvest;
    if (days <= 0) return loc.communityHarvestToday;
    return loc.communityHarvestInDays('$days');
  }

  String _qty(double value) {
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toStringAsFixed(1);
  }
}
