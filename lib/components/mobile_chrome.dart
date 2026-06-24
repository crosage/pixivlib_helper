import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tagselector/components/pixiv_mark.dart';

const Color mobileInk = Color(0xFF111827);
const Color mobileSubtleInk = Color(0xFF64748B);
const Color mobileLine = Color(0xFFE5E7EB);
const Color mobileBlue = Color(0xFF0A84FF);

class MobileToolbar extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? topCenter;
  final Widget? leading;
  final List<Widget> actions;
  final List<Widget> chips;
  final Widget? bottom;

  const MobileToolbar({
    super.key,
    this.title = '',
    this.eyebrow,
    this.subtitle,
    this.topCenter,
    this.leading,
    this.actions = const [],
    this.chips = const [],
    this.bottom,
  });

  @override
  Widget build(BuildContext context) {
    final hasTitle = title.trim().isNotEmpty;
    final hasEyebrow = eyebrow != null && eyebrow!.trim().isNotEmpty;
    final hasHeader = hasTitle || hasEyebrow;
    final headerContent = hasHeader
        ? _MobileTitleHeader(
            title: title,
            eyebrow: eyebrow,
            subtitle: subtitle,
            leading: leading,
            actions: actions,
          )
        : null;
    final hasTopLine = topCenter != null || headerContent != null;
    final controlRows = <Widget>[
      if (bottom != null)
        _MobileToolbarRail(
          height: 40,
          children: [
            if (!hasTopLine) ...actions,
            bottom!,
            ...chips,
          ],
        )
      else if (chips.isNotEmpty || actions.isNotEmpty || leading != null)
        _MobileToolbarRail(
          height: 40,
          children: [if (leading != null) leading!, ...chips, ...actions],
        ),
    ];

    return SizedBox(
      width: double.infinity,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          border: const Border(
            bottom: BorderSide(color: Color(0xFFE8EDF4)),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (topCenter != null)
                _MobileCenteredBrandBar(
                  center: topCenter!,
                  leading: leading,
                  actions: actions,
                )
              else if (headerContent != null)
                headerContent,
              for (final row in controlRows) ...[
                if (hasTopLine) const SizedBox(height: 7),
                row,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileTitleHeader extends StatelessWidget {
  final String title;
  final String? eyebrow;
  final String? subtitle;
  final Widget? leading;
  final List<Widget> actions;

  const _MobileTitleHeader({
    required this.title,
    required this.eyebrow,
    required this.subtitle,
    required this.leading,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    final hasEyebrow = eyebrow != null && eyebrow!.trim().isNotEmpty;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (leading != null) ...[
          leading!,
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasEyebrow)
                Text(
                  eyebrow!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: mobileBlue,
                    letterSpacing: 0.2,
                  ),
                ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.55,
                  color: mobileInk,
                ),
              ),
              if (subtitle != null && subtitle!.trim().isNotEmpty)
                Text(
                  subtitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mobileSubtleInk,
                  ),
                ),
            ],
          ),
        ),
        if (actions.isNotEmpty) ...[
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                if (index > 0) const SizedBox(width: 6),
                actions[index],
              ],
            ],
          ),
        ],
      ],
    );
  }
}

class _MobileCenteredBrandBar extends StatelessWidget {
  final Widget center;
  final Widget? leading;
  final List<Widget> actions;

  const _MobileCenteredBrandBar({
    required this.center,
    required this.leading,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 36,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.center,
            child: center,
          ),
          if (leading != null)
            Align(
              alignment: Alignment.centerLeft,
              child: leading!,
            ),
          if (actions.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var index = 0; index < actions.length; index++) ...[
                    if (index > 0) const SizedBox(width: 6),
                    actions[index],
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MobileBrandMark extends StatelessWidget {
  final String label;

  const MobileBrandMark({
    super.key,
    this.label = 'Pixiv',
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 30,
          height: 30,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F8FF),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: const Color(0xFFDCEEFF)),
          ),
          child: const PixivMark(size: 22, radius: 7),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            fontSize: 17,
            height: 1,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.6,
            color: mobileInk,
          ),
        ),
      ],
    );
  }
}

class _MobileToolbarRail extends StatelessWidget {
  final List<Widget> children;
  final double height;

  const _MobileToolbarRail({
    required this.children,
    this.height = 38,
  });

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      height: height,
      width: double.infinity,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: const Color(0xFFF5F7FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              for (var index = 0; index < children.length; index++) ...[
                if (index > 0) const SizedBox(width: 4),
                children[index],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class MobileCollapsibleToolbar extends StatelessWidget {
  final bool visible;
  final Widget child;

  const MobileCollapsibleToolbar({
    super.key,
    required this.visible,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        alignment: Alignment.topCenter,
        heightFactor: visible ? 1 : 0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: child,
        ),
      ),
    );
  }
}

class MobileScrollHideToolbar extends StatefulWidget {
  final bool enabled;
  final ScrollController scrollController;
  final Widget child;
  final double height;

  const MobileScrollHideToolbar({
    super.key,
    required this.enabled,
    required this.scrollController,
    required this.child,
    this.height = 50,
  });

  @override
  State<MobileScrollHideToolbar> createState() =>
      _MobileScrollHideToolbarState();
}

class _MobileScrollHideToolbarState extends State<MobileScrollHideToolbar>
    with SingleTickerProviderStateMixin {
  static const double _hideDelta = 8;
  static const double _showDelta = 5;

  bool _visible = true;
  double _lastOffset = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant MobileScrollHideToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController.removeListener(_handleScroll);
      widget.scrollController.addListener(_handleScroll);
      _lastOffset = 0;
      _visible = true;
    }
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_handleScroll);
    super.dispose();
  }

  void _handleScroll() {
    if (!widget.enabled || !widget.scrollController.hasClients) {
      return;
    }

    final offset = widget.scrollController.offset;
    final delta = offset - _lastOffset;
    _lastOffset = offset;

    if (offset <= 4) {
      _setVisible(true);
      return;
    }

    if (delta > _hideDelta && offset > widget.height * 0.6) {
      _setVisible(false);
      return;
    }

    if (delta < -_showDelta) {
      _setVisible(true);
    }
  }

  void _setVisible(bool value) {
    if (_visible == value || !mounted) {
      return;
    }
    setState(() {
      _visible = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) {
      return widget.child;
    }

    return ClipRect(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 210),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: _visible ? null : 0,
          child: AnimatedSlide(
            duration: const Duration(milliseconds: 210),
            curve: Curves.easeOutCubic,
            offset: _visible ? Offset.zero : const Offset(0, -0.15),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 150),
              curve: Curves.easeOutCubic,
              opacity: _visible ? 1 : 0,
              child: IgnorePointer(
                ignoring: !_visible,
                child: widget.child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MobileSheetFrame extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MobileSheetFrame({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(14, 8, 14, 16),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: Color(0xFFF5F7FA),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}

class MobileSheetSection extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MobileSheetSection({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF4)),
      ),
      child: child,
    );
  }
}

class DeferredSheetContent extends StatefulWidget {
  final WidgetBuilder builder;
  final Widget placeholder;
  final Duration delay;

  const DeferredSheetContent({
    super.key,
    required this.builder,
    required this.placeholder,
    this.delay = const Duration(milliseconds: 260),
  });

  @override
  State<DeferredSheetContent> createState() => _DeferredSheetContentState();
}

class _DeferredSheetContentState extends State<DeferredSheetContent> {
  Timer? _timer;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }
      _timer = Timer(widget.delay, () {
        if (mounted) {
          setState(() => _ready = true);
        }
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return widget.placeholder;
    }
    return widget.builder(context);
  }
}

class MobileToolbarRow extends StatelessWidget {
  final List<Widget> children;

  const MobileToolbarRow({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: 6),
          children[index],
        ],
      ],
    );
  }
}

class MobileGlassGroup extends StatelessWidget {
  final List<Widget> children;

  const MobileGlassGroup({
    super.key,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FA),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE9EEF5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 3),
            children[index],
          ],
        ],
      ),
    );
  }
}

class MobilePill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected;
  final Color accent;

  const MobilePill({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.accent = mobileBlue,
  });

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? accent : const Color(0xFF334155);
    final background =
        selected ? accent.withValues(alpha: 0.1) : const Color(0xFFF7F9FC);
    final borderColor =
        selected ? accent.withValues(alpha: 0.18) : const Color(0xFFE9EEF5);

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 4),
              ],
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MobileIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  const MobileIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            icon,
            size: 19,
            color: onTap == null ? const Color(0xFFCBD5E1) : mobileInk,
          ),
        ),
      ),
    );

    if (tooltip == null) {
      return button;
    }
    return Tooltip(message: tooltip!, child: button);
  }
}

class MobileSegment<T> {
  final T value;
  final String label;
  final IconData? icon;

  const MobileSegment({
    required this.value,
    required this.label,
    this.icon,
  });
}

class MobileSegmentedControl<T> extends StatelessWidget {
  final List<MobileSegment<T>> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  const MobileSegmentedControl({
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
            _MobileSegmentButton<T>(
              segment: segment,
              selected: segment.value == selected,
              onTap: () => onChanged(segment.value),
            ),
        ],
      ),
    );
  }
}

class _MobileSegmentButton<T> extends StatelessWidget {
  final MobileSegment<T> segment;
  final bool selected;
  final VoidCallback onTap;

  const _MobileSegmentButton({
    required this.segment,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
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
                Icon(
                  segment.icon,
                  size: 14,
                  color: selected ? mobileBlue : mobileSubtleInk,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                segment.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: selected ? mobileInk : mobileSubtleInk,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
