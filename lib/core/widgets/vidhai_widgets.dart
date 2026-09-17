import 'package:flutter/material.dart';
import 'package:vidhai/core/theme/vidhai_theme.dart';

bool isRtl(BuildContext context) =>
    Directionality.maybeOf(context) == TextDirection.rtl;

IconData directionalIcon(BuildContext context, IconData icon) {
  if (!isRtl(context)) return icon;
  switch (icon) {
    case Icons.chevron_right:
      return Icons.chevron_left;
    case Icons.chevron_right_rounded:
      return Icons.chevron_left_rounded;
    case Icons.arrow_forward_ios:
      return Icons.arrow_back_ios;
    case Icons.arrow_forward_ios_rounded:
      return Icons.arrow_back_ios_rounded;
    case Icons.arrow_back_ios:
      return Icons.arrow_forward_ios;
    case Icons.arrow_back_ios_rounded:
      return Icons.arrow_forward_ios_rounded;
    case Icons.arrow_back_ios_new:
      return Icons.arrow_forward_ios;
    case Icons.arrow_back_ios_new_rounded:
      return Icons.arrow_forward_ios_rounded;
    default:
      return icon;
  }
}

/// Mapping helpers for directional back/forward arrows.
IconData directionalBack(BuildContext context) =>
    isRtl(context) ? Icons.arrow_forward_ios : Icons.arrow_back_ios;
IconData directionalBackRounded(BuildContext context) => isRtl(context)
    ? Icons.arrow_forward_ios_rounded
    : Icons.arrow_back_ios_rounded;
IconData directionalBackNew(BuildContext context) =>
    isRtl(context) ? Icons.arrow_forward_ios : Icons.arrow_back_ios_new;
IconData directionalBackNewRounded(BuildContext context) => isRtl(context)
    ? Icons.arrow_forward_ios_rounded
    : Icons.arrow_back_ios_new_rounded;
IconData directionalChevron(BuildContext context) =>
    isRtl(context) ? Icons.chevron_left : Icons.chevron_right;
IconData directionalChevronRounded(BuildContext context) =>
    isRtl(context) ? Icons.chevron_left_rounded : Icons.chevron_right_rounded;

/// ===================== VidhAI Reusable Component Library =====================

/* ------------------------------- Buttons ------------------------------- */

class VidhAIButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expanded;
  final VidhAIButtonVariant variant;
  final double height;

  const VidhAIButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
    this.loading = false,
    this.expanded = true,
    this.variant = VidhAIButtonVariant.primary,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final disabled = onPressed == null || loading;

    Color bg;
    Color fg;
    BorderSide? side;
    switch (variant) {
      case VidhAIButtonVariant.primary:
        bg = colors.brandDeep;
        fg = Colors.white;
        break;
      case VidhAIButtonVariant.secondary:
        bg = colors.surfaceMuted;
        fg = colors.onBackground;
        break;
      case VidhAIButtonVariant.outline:
        bg = Colors.transparent;
        fg = colors.onBackground;
        side = BorderSide(color: colors.borderColor);
        break;
      case VidhAIButtonVariant.soft:
        bg = colors.brand.withValues(alpha: 0.35);
        fg = colors.brandDeep;
        break;
    }

    final button = SizedBox(
      height: height,
      child: OutlinedButton.icon(
        onPressed: disabled ? null : onPressed,
        icon: loading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              )
            : (icon != null
                ? Icon(icon, size: 20, color: fg)
                : const SizedBox.shrink()),
        label: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg,
          disabledForegroundColor: colors.onSurfaceMuted,
          side: side,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(FreshLeafTheme.radiusMd),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );

    return expanded ? SizedBox(width: double.infinity, child: button) : button;
  }
}

enum VidhAIButtonVariant { primary, secondary, outline, soft }

class VidhAIIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final double size;
  final double radius;

  const VidhAIIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.color,
    this.size = 20,
    this.radius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Material(
      color: colors.surfaceMuted,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          child: Icon(icon, size: size, color: color ?? colors.onBackground),
        ),
      ),
    );
  }
}

/* -------------------------------- Cards -------------------------------- */

class VidhAICard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadius? borderRadius;
  final VoidCallback? onTap;
  final Color? color;
  final bool hasShadow;
  final BoxBorder? border;
  final Clip clipBehavior;

  const VidhAICard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius,
    this.onTap,
    this.color,
    this.hasShadow = false,
    this.border,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final shape = RoundedRectangleBorder(
      borderRadius:
          borderRadius ?? BorderRadius.circular(FreshLeafTheme.radiusMd),
    );
    final container = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? colors.surface,
        borderRadius: shape.borderRadius,
        border: border ?? Border.all(color: colors.borderColor, width: 1),
        boxShadow: hasShadow ? FreshLeafTheme.softShadow : null,
      ),
      clipBehavior: clipBehavior,
      child: child,
    );
    if (onTap == null) return container;
    return GestureDetector(onTap: onTap, child: container);
  }
}

class VidhAISectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;
  final VoidCallback? onTrailing;
  final IconData? trailingIcon;

  const VidhAISectionHeader({
    super.key,
    required this.title,
    this.trailing,
    this.onTrailing,
    this.trailingIcon = Icons.chevron_right,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colors.onBackground,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onTap: onTrailing,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      trailing!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: colors.brandDeep,
                          fontSize: 13,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    directionalIcon(
                        context, trailingIcon ?? Icons.chevron_right),
                    size: 16,
                    color: colors.brandDeep,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/* -------------------------------- Chips -------------------------------- */

class VidhAIChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;

  const VidhAIChip({
    super.key,
    required this.label,
    this.selected = false,
    this.onTap,
    this.icon,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final fg = color != null
        ? Colors.white
        : (selected ? Colors.white : colors.onBackground);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color ?? (selected ? colors.brandDeep : colors.surfaceMuted),
          borderRadius: BorderRadius.circular(20),
          border: selected && color == null
              ? null
              : Border.all(color: colors.borderColor, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: fg),
              const SizedBox(width: 6),
            ],
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/* --------------------------- Avatar + Tiles ---------------------------- */

class VidhAICircleAvatar extends StatelessWidget {
  final String text;
  final double radius;
  final Color? backgroundColor;
  final Color? textColor;

  const VidhAICircleAvatar({
    super.key,
    required this.text,
    this.radius = 24,
    this.backgroundColor,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? colors.brand.withValues(alpha: 0.5),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: TextStyle(
            fontSize: radius * 0.8,
            fontWeight: FontWeight.w700,
            color: textColor ?? colors.brandDeep,
          ),
        ),
      ),
    );
  }
}

class VidhAIProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Color? iconColor;

  const VidhAIProfileTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.trailing,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final tile = ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? colors.brandDeep).withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? colors.brandDeep, size: 20),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
            color: colors.onBackground,
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null
          ? Text(
              subtitle!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceMuted, fontSize: 13),
            )
          : null,
      trailing: trailing ??
          Icon(directionalChevron(context),
              color: colors.onSurfaceMuted, size: 22),
    );
    return tile;
  }
}

/* --------------------------- Bottom Navigation -------------------------- */

class VidhAIBottomNavigation extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<VidhAIBottomItem> items;

  const VidhAIBottomNavigation({
    super.key,
    required this.currentIndex,
    required this.onTap,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderColor, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final selected = i == currentIndex;

              if (item.isFloating) {
                return Expanded(
                  child: GestureDetector(
                    onTap: () => onTap(i),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                colors.brand.withValues(alpha: 0.9),
                                colors.brandDeep
                              ],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colors.brandDeep.withValues(alpha: 0.35),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child:
                              Icon(item.icon, color: colors.surface, size: 26),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Expanded(
                child: InkWell(
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              selected
                                  ? (item.activeIcon ?? item.icon)
                                  : item.icon,
                              color: selected
                                  ? colors.brandDeep
                                  : colors.onSurfaceMuted,
                              size: 22,
                            ),
                            if (item.badge > 0)
                              Positioned(
                                right: -7,
                                top: -5,
                                child: Container(
                                  constraints: const BoxConstraints(
                                      minWidth: 16, minHeight: 16),
                                  alignment: Alignment.center,
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: FreshLeafColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Text(
                                    item.badge > 99 ? '99+' : '${item.badge}',
                                    maxLines: 1,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 8,
                                      fontWeight: FontWeight.bold,
                                      height: 1,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            item.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selected
                                  ? colors.brandDeep
                                  : colors.onSurfaceMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class VidhAIBottomItem {
  final IconData icon;
  final IconData? activeIcon;
  final String label;
  final bool isFloating;
  final int badge;

  const VidhAIBottomItem({
    required this.icon,
    this.activeIcon,
    required this.label,
    this.isFloating = false,
    this.badge = 0,
  });
}

/* ------------------------------ App Bar -------------------------------- */

class VidhAIAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;

  const VidhAIAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.centerTitle = true,
  });

  @override
  Size get preferredSize => const Size.fromHeight(56);

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return AppBar(
      backgroundColor: colors.bg,
      foregroundColor: colors.onBackground,
      elevation: 0,
      centerTitle: centerTitle,
      leading: leading,
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: colors.onBackground,
          fontSize: 18,
          fontWeight: FontWeight.w700,
        ),
      ),
      actions: actions,
    );
  }
}

/* --------------------------- Price / Product --------------------------- */

class VidhAIPriceCard extends StatelessWidget {
  final String commodity;
  final String market;
  final double price;
  final String? unit;
  final double? change;
  final VoidCallback? onTap;

  const VidhAIPriceCard({
    super.key,
    required this.commodity,
    required this.market,
    required this.price,
    this.unit = 'quintal',
    this.change,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return VidhAICard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      margin: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.grass_rounded, color: colors.brandDeep, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  commodity,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  market,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '₹${price > 0 ? price.toStringAsFixed(0) : '--'}',
                  maxLines: 1,
                  style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
                if (change != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        change! >= 0
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        size: 12,
                        color: change! >= 0 ? colors.success : colors.danger,
                      ),
                      Text(
                        '${change!.abs().toStringAsFixed(1)}%',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 11,
                          color: change! >= 0 ? colors.success : colors.danger,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class VidhAIProductCard extends StatelessWidget {
  final String name;
  final String farmerName;
  final double price;
  final String unit;
  final String? imagePath;
  final VoidCallback? onTap;
  final Widget? badge;

  const VidhAIProductCard({
    super.key,
    required this.name,
    required this.farmerName,
    required this.price,
    required this.unit,
    this.imagePath,
    this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    return VidhAICard(
      onTap: onTap,
      padding: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 110,
                width: double.infinity,
                color: colors.surfaceMuted,
                child: imagePath != null
                    ? Image.asset(imagePath!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(colors))
                    : _placeholder(colors),
              ),
              if (badge != null)
                PositionedDirectional(top: 8, start: 8, child: badge!),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onBackground,
                      fontSize: 14,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  farmerName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                ),
                const SizedBox(height: 8),
                Text(
                  '₹$price / $unit',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 15,
                      fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholder(VidhAIColorsX colors) {
    return Center(
      child: Icon(Icons.eco_rounded,
          color: colors.brandDeep.withValues(alpha: 0.4), size: 40),
    );
  }
}

class VidhAIFarmCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final String acreage;
  final String status;
  final Color? statusColor;
  final VoidCallback? onTap;

  const VidhAIFarmCard({
    super.key,
    required this.name,
    required this.subtitle,
    required this.acreage,
    required this.status,
    this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final sc = statusColor ?? colors.brandDeep;
    return VidhAICard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.agriculture_rounded,
                color: colors.brandDeep, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Text(
                  acreage,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: colors.onSurfaceMuted,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: sc.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                status,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: sc, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class VidhAIOrderCard extends StatelessWidget {
  final String id;
  final String title;
  final String subtitle;
  final double amount;
  final String status;
  final Color? statusColor;
  final VoidCallback? onTap;

  const VidhAIOrderCard({
    super.key,
    required this.id,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.status,
    this.statusColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = VidhAIColorsX(context);
    final sc = statusColor ?? colors.brandDeep;
    return VidhAICard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: colors.brand.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.receipt_long_rounded,
                color: colors.brandDeep, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onBackground,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 11),
                ),
                const SizedBox(height: 4),
                Text(
                  id,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: colors.onSurfaceMuted, fontSize: 10),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '₹$amount',
                    maxLines: 1,
                    style: TextStyle(
                      color: colors.brandDeep,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sc.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: sc, fontSize: 10, fontWeight: FontWeight.w700),
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
