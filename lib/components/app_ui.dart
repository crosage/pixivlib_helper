import 'package:flutter/material.dart';
import 'package:tagselector/model/image_model.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/image_state_merger.dart';

class AppSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final bool border;
  final double? radius;
  final Clip clipBehavior;

  const AppSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.color = Colors.white,
    this.border = true,
    this.radius,
    this.clipBehavior = Clip.none,
  });

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 640;
    final effectiveRadius = radius ?? (compact ? 8.0 : 12.0);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(effectiveRadius),
      clipBehavior: clipBehavior,
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(effectiveRadius),
          border: border ? Border.all(color: const Color(0xFFE5E7EB)) : null,
        ),
        child: child,
      ),
    );
  }
}

class AppSection extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final double gap;

  const AppSection({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.gap = 10,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSectionHeader(title: title, trailing: trailing),
        SizedBox(height: gap),
        child,
      ],
    );
  }
}

class AppSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const AppSectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111827),
            ),
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class AppInfoPill extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color foregroundColor;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;

  const AppInfoPill({
    super.key,
    this.icon,
    required this.label,
    this.foregroundColor = const Color(0xFF475569),
    this.backgroundColor = const Color(0xFFF8FAFC),
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: padding,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foregroundColor),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: foregroundColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AppEmptyState extends StatelessWidget {
  final String title;
  final String? description;
  final IconData icon;

  const AppEmptyState({
    super.key,
    required this.title,
    this.description,
    this.icon = Icons.inbox_outlined,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: const Color(0xFF64748B)),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppErrorState extends StatelessWidget {
  final String title;
  final String? description;
  final VoidCallback? onRetry;

  const AppErrorState({
    super.key,
    required this.title,
    this.description,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 40,
              color: Color(0xFF64748B),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
            ),
            if (description != null && description!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Color(0xFF64748B)),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppToolbar extends StatelessWidget {
  final Widget? title;
  final List<Widget> children;

  const AppToolbar({
    super.key,
    this.title,
    this.children = const [],
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (title != null)
            DefaultTextStyle.merge(
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF111827),
              ),
              child: title!,
            ),
          ...children,
        ],
      ),
    );
  }
}

class AppSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const AppSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

class AppSegmentedControl<T> extends StatelessWidget {
  final List<AppSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const AppSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 34,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final segment in segments)
            _AppSegmentButton<T>(
              segment: segment,
              selected: segment.value == selected,
              onTap: () => onChanged(segment.value),
            ),
        ],
      ),
    );
  }
}

class _AppSegmentButton<T> extends StatelessWidget {
  final AppSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  const _AppSegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF2563EB) : const Color(0xFF64748B);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          height: 28,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFFEFF6FF) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? const Color(0xFFBFDBFE) : Colors.transparent,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2563EB).withValues(alpha: 0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (segment.icon != null) ...[
                Icon(segment.icon, size: 15, color: color),
                const SizedBox(width: 4),
              ],
              Text(
                segment.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppBookmarkButton extends StatefulWidget {
  final ImageModel image;
  final ValueChanged<ImageModel>? onChanged;
  final VoidCallback? onBookmarked;
  final bool showCount;
  final bool iconOnly;
  final bool elevated;
  final double iconSize;
  final EdgeInsetsGeometry padding;

  const AppBookmarkButton({
    super.key,
    required this.image,
    this.onChanged,
    this.onBookmarked,
    this.showCount = true,
    this.iconOnly = false,
    this.elevated = false,
    this.iconSize = 15,
    this.padding = const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  });

  @override
  State<AppBookmarkButton> createState() => _AppBookmarkButtonState();
}

class _AppBookmarkButtonState extends State<AppBookmarkButton> {
  ImageModel get _image => _localImage ?? widget.image;

  ImageModel? _localImage;
  bool _busy = false;

  @override
  void didUpdateWidget(covariant AppBookmarkButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.pid != widget.image.pid ||
        oldWidget.image.isBookmarked != widget.image.isBookmarked ||
        oldWidget.image.bookmarkCount != widget.image.bookmarkCount) {
      _localImage = null;
    }
  }

  Future<void> _toggle() async {
    if (_busy || _image.pid <= 0) {
      return;
    }

    final wasBookmarked = _image.isBookmarked;
    setState(() => _busy = true);
    try {
      final updated = wasBookmarked
          ? await ApiService.instance.unbookmarkImage(_image.pid)
          : await ApiService.instance.bookmarkImage(_image.pid);
      if (!mounted) {
        return;
      }
      final merged = mergeImageState(_image, updated);
      setState(() => _localImage = merged);
      widget.onChanged?.call(merged);
      if (!wasBookmarked && updated.isBookmarked) {
        widget.onBookmarked?.call();
      }
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('收藏操作失败: $error')),
      );
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color =
        _image.isBookmarked ? const Color(0xFFE11D48) : const Color(0xFF64748B);
    final background = Colors.white.withValues(alpha: 0.94);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      elevation: widget.elevated ? 1 : 0,
      shadowColor: Colors.black.withValues(alpha: 0.14),
      child: InkWell(
        onTap: _busy ? null : _toggle,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: widget.iconOnly ? const EdgeInsets.all(8) : widget.padding,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_busy)
                SizedBox(
                  width: widget.iconSize,
                  height: widget.iconSize,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  _image.isBookmarked
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                  size: widget.iconSize,
                  color: color,
                ),
              if (widget.showCount && !widget.iconOnly) ...[
                const SizedBox(width: 4),
                Text(
                  _image.bookmarkCount <= 0 ? '获取中' : '${_image.bookmarkCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

typedef ImageGridTileBuilder = Widget Function(
  BuildContext context,
  ImageModel image,
);

class ImageGridTile extends StatelessWidget {
  final ImageModel image;
  final Widget imageChild;
  final VoidCallback? onTap;
  final Widget? topLeft;
  final Widget? topRight;
  final Widget? bottom;
  final double radius;

  const ImageGridTile({
    super.key,
    required this.image,
    required this.imageChild,
    this.onTap,
    this.topLeft,
    this.topRight,
    this.bottom,
    this.radius = 8,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Material(
      color: Colors.white,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Stack(
          fit: StackFit.expand,
          children: [
            imageChild,
            if (topLeft != null) Positioned(top: 7, left: 7, child: topLeft!),
            if (topRight != null)
              Positioned(top: 7, right: 7, child: topRight!),
            if (bottom != null)
              Positioned(left: 8, right: 8, bottom: 8, child: bottom!),
          ],
        ),
      ),
    );
  }
}
