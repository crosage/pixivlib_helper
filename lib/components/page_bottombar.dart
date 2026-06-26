import 'package:flutter/material.dart';

class PageBottomBar extends StatefulWidget {
  final ValueChanged<int> onPageChange;
  final int currentPage;
  final int? totalPages;
  final bool canGoNext;
  final String? summary;

  const PageBottomBar({
    super.key,
    required this.onPageChange,
    required this.currentPage,
    this.totalPages,
    this.canGoNext = false,
    this.summary,
  });

  @override
  State<PageBottomBar> createState() => _PageBottomBarState();
}

class _PageBottomBarState extends State<PageBottomBar> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentPage.toString());
  }

  @override
  void didUpdateWidget(PageBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentPage != oldWidget.currentPage) {
      _controller.text = widget.currentPage.toString();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasKnownTotal = widget.totalPages != null;
    final canGoNext = hasKnownTotal
        ? widget.currentPage < widget.totalPages!
        : widget.canGoNext;

    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 640;

        if (compact) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(6, 2, 6, 7),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE8EDF4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _PageControls(
                  controller: _controller,
                  currentPage: widget.currentPage,
                  totalPages: widget.totalPages,
                  canGoNext: canGoNext,
                  compact: compact,
                  onPageChange: widget.onPageChange,
                ),
              ),
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.summary != null)
                _SummaryPill(summary: widget.summary!),
              if (widget.summary != null) const SizedBox(width: 8),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFE8EDF4)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 4,
                  ),
                  child: _PageControls(
                    controller: _controller,
                    currentPage: widget.currentPage,
                    totalPages: widget.totalPages,
                    canGoNext: canGoNext,
                    compact: compact,
                    onPageChange: widget.onPageChange,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SummaryPill extends StatelessWidget {
  final String summary;

  const _SummaryPill({required this.summary});

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE8EDF4)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Text(
            summary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF64748B),
            ),
          ),
        ),
      ),
    );
  }
}

class _PageControls extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onPageChange;
  final int currentPage;
  final int? totalPages;
  final bool canGoNext;
  final bool compact;

  const _PageControls({
    required this.controller,
    required this.onPageChange,
    required this.currentPage,
    required this.totalPages,
    required this.canGoNext,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _PagerIconButton(
          icon: Icons.chevron_left_rounded,
          enabled: currentPage > 1,
          compact: compact,
          onTap: () => onPageChange(currentPage - 1),
        ),
        SizedBox(width: compact ? 2 : 4),
        _PageIndicatorButton(
          controller: controller,
          currentPage: currentPage,
          totalPages: totalPages,
          compact: compact,
          onPageChange: onPageChange,
        ),
        SizedBox(width: compact ? 2 : 4),
        _PagerIconButton(
          icon: Icons.chevron_right_rounded,
          enabled: canGoNext,
          compact: compact,
          onTap: () => onPageChange(currentPage + 1),
        ),
      ],
    );
  }
}

class _PageIndicatorButton extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onPageChange;
  final int currentPage;
  final int? totalPages;
  final bool compact;

  const _PageIndicatorButton({
    required this.controller,
    required this.onPageChange,
    required this.currentPage,
    required this.totalPages,
    required this.compact,
  });

  @override
  Widget build(BuildContext context) {
    final hasKnownTotal = totalPages != null;
    final label = hasKnownTotal
        ? '$currentPage / $totalPages'
        : '\u7b2c $currentPage \u9875';

    return Material(
      color: const Color(0xFFF9FAFB),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: () => _showJumpDialog(context),
        child: Container(
          height: compact ? 30 : 36,
          constraints: BoxConstraints(minWidth: compact ? 50 : 64),
          padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 11),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF334155),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showJumpDialog(BuildContext context) async {
    controller.text = currentPage.toString();
    final nextPage = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('\u8df3\u8f6c\u9875\u7801'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: totalPages == null ? '\u9875\u7801' : '1 - $totalPages',
            ),
            onSubmitted: (value) {
              Navigator.of(context).pop(int.tryParse(value));
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('\u53d6\u6d88'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop(int.tryParse(controller.text));
              },
              child: const Text('\u8df3\u8f6c'),
            ),
          ],
        );
      },
    );
    if (nextPage == null || nextPage < 1) return;
    if (totalPages != null && nextPage > totalPages!) return;
    onPageChange(nextPage);
  }
}

class _PagerIconButton extends StatelessWidget {
  final IconData icon;
  final bool enabled;
  final bool compact;
  final VoidCallback onTap;

  const _PagerIconButton({
    required this.icon,
    required this.enabled,
    required this.compact,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled ? const Color(0xFFF9FAFB) : const Color(0xFFF3F4F6),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: enabled ? onTap : null,
        child: SizedBox(
          width: compact ? 30 : 36,
          height: compact ? 30 : 36,
          child: Icon(
            icon,
            size: compact ? 18 : 19,
            color: enabled ? const Color(0xFF475569) : const Color(0xFF9CA3AF),
          ),
        ),
      ),
    );
  }
}
