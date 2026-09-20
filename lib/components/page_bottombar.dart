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
  late final TextEditingController _controller =
      TextEditingController(text: '${widget.currentPage}');

  @override
  void didUpdateWidget(covariant PageBottomBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentPage != widget.currentPage) {
      _controller.text = '${widget.currentPage}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final canNext = widget.totalPages == null
        ? widget.canGoNext
        : widget.currentPage < widget.totalPages!;
    return LayoutBuilder(builder: (context, constraints) {
      final compact = constraints.maxWidth < 640;
      return Container(
        height: compact ? 50 : 54,
        padding: EdgeInsets.symmetric(horizontal: compact ? 8 : 14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFE1E5EA)),
          borderRadius: BorderRadius.circular(compact ? 0 : 8),
        ),
        child: Row(children: [
          if (!compact && widget.summary?.isNotEmpty == true)
            Expanded(
              child: Text(
                widget.summary!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF636B76)),
              ),
            )
          else
            const Spacer(),
          _PageButton(
            icon: Icons.arrow_back_rounded,
            label: compact ? null : '上一页',
            enabled: widget.currentPage > 1,
            onTap: () => widget.onPageChange(widget.currentPage - 1),
          ),
          const SizedBox(width: 6),
          _CurrentPageButton(
            currentPage: widget.currentPage,
            totalPages: widget.totalPages,
            controller: _controller,
            onPageChange: widget.onPageChange,
          ),
          const SizedBox(width: 6),
          _PageButton(
            icon: Icons.arrow_forward_rounded,
            label: compact ? null : '下一页',
            enabled: canNext,
            onTap: () => widget.onPageChange(widget.currentPage + 1),
          ),
          const Spacer(),
        ]),
      );
    });
  }
}

class _PageButton extends StatelessWidget {
  final IconData icon;
  final String? label;
  final bool enabled;
  final VoidCallback onTap;

  const _PageButton({
    required this.icon,
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        enabled ? const Color(0xFF343A42) : const Color(0xFFADB3BC);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          height: 34,
          padding: EdgeInsets.symmetric(horizontal: label == null ? 8 : 10),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE1E5EA)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 17, color: foreground),
            if (label != null) ...[
              const SizedBox(width: 6),
              Text(label!,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: foreground)),
            ],
          ]),
        ),
      ),
    );
  }
}

class _CurrentPageButton extends StatelessWidget {
  final int currentPage;
  final int? totalPages;
  final TextEditingController controller;
  final ValueChanged<int> onPageChange;

  const _CurrentPageButton({
    required this.currentPage,
    required this.totalPages,
    required this.controller,
    required this.onPageChange,
  });

  @override
  Widget build(BuildContext context) {
    final label =
        totalPages == null ? '第 $currentPage 页' : '$currentPage / $totalPages';
    return Material(
      color: const Color(0xFFE8F5FF),
      borderRadius: BorderRadius.circular(6),
      child: InkWell(
        borderRadius: BorderRadius.circular(6),
        onTap: () => _showJumpDialog(context),
        child: Container(
          height: 34,
          constraints: const BoxConstraints(minWidth: 72),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.center,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0077C8))),
        ),
      ),
    );
  }

  Future<void> _showJumpDialog(BuildContext context) async {
    controller.text = '$currentPage';
    final nextPage = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转页码'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
              hintText: totalPages == null ? '页码' : '1 - $totalPages'),
          onSubmitted: (value) =>
              Navigator.of(context).pop(int.tryParse(value)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消')),
          FilledButton(
              onPressed: () =>
                  Navigator.of(context).pop(int.tryParse(controller.text)),
              child: const Text('跳转')),
        ],
      ),
    );
    if (nextPage == null || nextPage < 1) return;
    if (totalPages != null && nextPage > totalPages!) return;
    onPageChange(nextPage);
  }
}
