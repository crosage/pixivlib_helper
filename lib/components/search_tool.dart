import 'package:flutter/material.dart';
import 'package:tagselector/components/mobile_chrome.dart';

enum TagEntryMode { include, exclude }

class SearchTool extends StatefulWidget {
  final List<String> suggestions;
  final ValueChanged<String> onInclude;
  final ValueChanged<String> onExclude;
  final String hintText;

  const SearchTool({
    super.key,
    required this.suggestions,
    required this.onInclude,
    required this.onExclude,
    this.hintText = '输入 tag 后回车，或点下方建议',
  });

  @override
  State<SearchTool> createState() => _SearchToolState();
}

class _SearchToolState extends State<SearchTool> {
  static const int _maxBrowserTagCount = 240;

  final TextEditingController _controller = TextEditingController();
  TagEntryMode _mode = TagEntryMode.include;

  List<String> get _filteredSuggestions {
    final keyword = _controller.text.trim().toLowerCase();
    if (keyword.isEmpty) {
      return const [];
    }
    return widget.suggestions
        .where((tag) => tag.toLowerCase().contains(keyword))
        .take(12)
        .toList();
  }

  void _submit(String value, {TagEntryMode? mode}) {
    final tag = value.trim();
    if (tag.isEmpty) {
      return;
    }

    final targetMode = mode ?? _mode;
    if (targetMode == TagEntryMode.include) {
      widget.onInclude(tag);
    } else {
      widget.onExclude(tag);
    }

    _controller.clear();
    setState(() {});
  }

  Future<void> _openTagBrowser() async {
    final allTags = widget.suggestions
        .map((tag) => tag.trim())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .toList();

    if (allTags.isEmpty) {
      return;
    }

    final searchController = TextEditingController();
    String keyword = '';

    List<String> visibleTagsFor(String value) {
      final normalized = value.trim().toLowerCase();
      final result = <String>[];
      for (final tag in allTags) {
        if (normalized.isEmpty || tag.toLowerCase().contains(normalized)) {
          result.add(tag);
          if (result.length >= _maxBrowserTagCount) {
            break;
          }
        }
      }
      return result;
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final normalized = keyword.trim().toLowerCase();
            final filteredTags = visibleTagsFor(keyword);
            final capped = filteredTags.length >= _maxBrowserTagCount;

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 8,
                  bottom: MediaQuery.viewInsetsOf(context).bottom + 16,
                ),
                child: SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.76,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '全部标签',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '可以直接搜索并加入筛选，也可以分别点右侧的包含 / 排除。',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF64748B),
                            ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: searchController,
                        autofocus: true,
                        onChanged: (value) {
                          setSheetState(() => keyword = value);
                        },
                        decoration: const InputDecoration(
                          hintText: '搜索 tag',
                          prefixIcon: Icon(Icons.search_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const _BrowserHint(
                            icon: Icons.add_rounded,
                            label: '包含',
                            color: Color(0xFF2563EB),
                          ),
                          const SizedBox(width: 8),
                          const _BrowserHint(
                            icon: Icons.remove_rounded,
                            label: '排除',
                            color: Color(0xFFE11D48),
                          ),
                          const Spacer(),
                          Text(
                            normalized.isEmpty
                                ? '前 ${filteredTags.length} 项'
                                : '${filteredTags.length}${capped ? '+' : ''} 项',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Expanded(
                        child: filteredTags.isEmpty
                            ? const Center(child: Text('没有匹配的标签'))
                            : ListView.separated(
                                itemCount: filteredTags.length,
                                separatorBuilder: (_, __) =>
                                    const Divider(height: 1),
                                itemBuilder: (context, index) {
                                  final tag = filteredTags[index];
                                  return ListTile(
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(tag),
                                    onTap: () {
                                      Navigator.of(context).pop();
                                      _submit(tag);
                                    },
                                    trailing: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _submit(
                                              tag,
                                              mode: TagEntryMode.include,
                                            );
                                          },
                                          icon: const Icon(Icons.add_rounded),
                                          color: const Color(0xFF2563EB),
                                          tooltip: '加入包含',
                                        ),
                                        IconButton(
                                          onPressed: () {
                                            Navigator.of(context).pop();
                                            _submit(
                                              tag,
                                              mode: TagEntryMode.exclude,
                                            );
                                          },
                                          icon:
                                              const Icon(Icons.remove_rounded),
                                          color: const Color(0xFFE11D48),
                                          tooltip: '加入排除',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );

    searchController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final suggestions = _filteredSuggestions;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MobileSegmentedControl<TagEntryMode>(
          selected: _mode,
          segments: const [
            MobileSegment<TagEntryMode>(
              value: TagEntryMode.include,
              icon: Icons.add_rounded,
              label: '包含',
            ),
            MobileSegment<TagEntryMode>(
              value: TagEntryMode.exclude,
              icon: Icons.remove_rounded,
              label: '排除',
            ),
          ],
          onChanged: (value) => setState(() => _mode = value),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _controller,
          onChanged: (_) => setState(() {}),
          onSubmitted: (value) => _submit(value),
          decoration: InputDecoration(
            hintText: widget.hintText,
            prefixIcon: Icon(
              _mode == TagEntryMode.include
                  ? Icons.search_rounded
                  : Icons.block_rounded,
            ),
            suffixIcon: IconButton(
              onPressed: () => _submit(_controller.text),
              icon: const Icon(Icons.keyboard_return_rounded),
              tooltip: _mode == TagEntryMode.include ? '添加包含 tag' : '添加排除 tag',
            ),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: widget.suggestions.isEmpty ? null : _openTagBrowser,
            icon: const Icon(Icons.local_offer_outlined),
            label: Text('查看全部标签 (${widget.suggestions.length})'),
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            '快速建议',
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: suggestions.map((tag) {
              return ActionChip(
                label: Text(tag),
                onPressed: () => _submit(tag),
                backgroundColor: const Color(0xFFF8FAFC),
                side: const BorderSide(color: Color(0xFFE5E7EB)),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class _BrowserHint extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BrowserHint({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
