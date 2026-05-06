import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:tagselector/components/mobile_chrome.dart';
import 'package:tagselector/model/daily_ranking_model.dart';
import 'package:tagselector/pages/full_image_page.dart';
import 'package:tagselector/service/api_service.dart';
import 'package:tagselector/service/app_user_session.dart';
import 'package:tagselector/service/cache_proxy_manager.dart';
import 'package:tagselector/service/image_prefetcher.dart';
import 'package:tagselector/service/remote_image_url.dart';

const _rankingModes = [
  ('daily', '日榜'),
  ('weekly', '周榜'),
  ('monthly', '月榜'),
  ('rookie', '新人'),
  ('original', '原创'),
  ('male', '男性'),
  ('female', '女性'),
];

class DailyRankingPage extends StatefulWidget {
  const DailyRankingPage({super.key});

  @override
  State<DailyRankingPage> createState() => _DailyRankingPageState();
}

class _DailyRankingPageState extends State<DailyRankingPage> {
  final ApiService _api = ApiService.instance;
  final AppUserSession _session = AppUserSession.instance;
  final ImagePrefetcher _prefetcher = ImagePrefetcher.instance;

  late Future<DailyRankingResponse> _future;
  int _page = 1;
  String _mode = 'daily';
  DateTime? _selectedDate;

  @override
  void initState() {
    super.initState();
    _session.addListener(_handleUserChanged);
    _future = _load();
  }

  @override
  void dispose() {
    _session.removeListener(_handleUserChanged);
    super.dispose();
  }

  Future<DailyRankingResponse> _load() {
    return _api.fetchDailyRanking(
      page: _page,
      mode: _mode,
      date: _formatPixivRankingDate(_selectedDate),
    );
  }

  void _reload() {
    setState(() {
      _future = _load();
    });
  }

  void _handleUserChanged() {
    if (!mounted) {
      return;
    }
    _reload();
  }

  void _changePage(int delta) {
    final nextPage = (_page + delta).clamp(1, 999);
    if (nextPage == _page) {
      return;
    }
    setState(() {
      _page = nextPage;
      _future = _load();
    });
  }

  void _changeMode(String mode) {
    if (mode == _mode) return;
    setState(() {
      _mode = mode;
      _page = 1;
      _future = _load();
    });
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now.subtract(const Duration(days: 1)),
      firstDate: DateTime(2007, 9, 10),
      lastDate: now,
    );
    if (picked == null) return;
    setState(() {
      _selectedDate = DateTime(picked.year, picked.month, picked.day);
      _page = 1;
      _future = _load();
    });
  }

  void _clearDate() {
    if (_selectedDate == null) return;
    setState(() {
      _selectedDate = null;
      _page = 1;
      _future = _load();
    });
  }

  String _formatPixivRankingDate(DateTime? date) {
    if (date == null) return '';
    return '${date.year.toString().padLeft(4, '0')}'
        '${date.month.toString().padLeft(2, '0')}'
        '${date.day.toString().padLeft(2, '0')}';
  }

  Future<void> _openImage(DailyRankingModel image) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FullImagePage(image: image.toPlaceholderImage()),
      ),
    );
  }

  void _prefetchAround(List<DailyRankingModel> images, int index) {
    final start = (index + 1).clamp(0, images.length);
    final end = (index + 17).clamp(0, images.length);
    if (start >= end) return;
    _prefetcher.prefetchRankingModels(
      images.sublist(start, end),
      limit: 16,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final phone = constraints.maxWidth < 720;

        return Container(
          decoration: BoxDecoration(
            color: phone ? const Color(0xFFF2F2F7) : Colors.white,
            borderRadius: phone ? BorderRadius.zero : BorderRadius.circular(28),
            border: phone ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: FutureBuilder<DailyRankingResponse>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  snapshot.data == null) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      snapshot.error.toString(),
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                );
              }

              final ranking = snapshot.data!;
              _prefetcher.prefetchRankingModels(
                ranking.images.take(18),
                limit: 18,
              );

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 0 : 24,
                  phone ? 0 : 24,
                  phone ? 0 : 24,
                  phone ? 8 : 24,
                ),
                child: CustomScrollView(
                  slivers: [
                    SliverToBoxAdapter(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _RankingHeader(
                            phone: phone,
                            page: _page,
                            mode: _mode,
                            selectedDate: _selectedDate,
                            dateLabel: ranking.dateLabel,
                            onRefresh: _reload,
                            onPrevPage:
                                _page > 1 ? () => _changePage(-1) : null,
                            onNextPage: () => _changePage(1),
                            onModeChanged: _changeMode,
                            onPickDate: _pickDate,
                            onClearDate: _clearDate,
                          ),
                          SizedBox(height: phone ? 8 : 24),
                          if (ranking.images.isEmpty)
                            Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: phone ? 10 : 0,
                                vertical: 20,
                              ),
                              child: const Text('当前没有获取到榜单数据。'),
                            )
                          else
                            LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final crossAxisCount = phone
                                    ? (gridConstraints.maxWidth < 430 ? 2 : 3)
                                    : (gridConstraints.maxWidth / 240)
                                        .floor()
                                        .clamp(1, 6);
                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: ranking.images.length,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: phone ? 0 : 0,
                                    vertical: phone ? 0 : 0,
                                  ),
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    crossAxisSpacing: phone ? 2 : 12,
                                    mainAxisSpacing: phone ? 6 : 12,
                                    childAspectRatio: phone ? 0.76 : 0.72,
                                  ),
                                  itemBuilder: (context, index) {
                                    if (index % 6 == 0) {
                                      _prefetchAround(ranking.images, index);
                                    }
                                    final item = ranking.images[index];
                                    return _RankingCard(
                                      phone: phone,
                                      item: item,
                                      onTap: () => _openImage(item),
                                    );
                                  },
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _RankingHeader extends StatelessWidget {
  final bool phone;
  final int page;
  final String mode;
  final DateTime? selectedDate;
  final String dateLabel;
  final VoidCallback onRefresh;
  final VoidCallback? onPrevPage;
  final VoidCallback onNextPage;
  final ValueChanged<String> onModeChanged;
  final VoidCallback onPickDate;
  final VoidCallback onClearDate;

  const _RankingHeader({
    required this.phone,
    required this.page,
    required this.mode,
    required this.selectedDate,
    required this.dateLabel,
    required this.onRefresh,
    required this.onPrevPage,
    required this.onNextPage,
    required this.onModeChanged,
    required this.onPickDate,
    required this.onClearDate,
  });

  String get _modeLabel {
    for (final option in _rankingModes) {
      if (option.$1 == mode) return option.$2;
    }
    return mode;
  }

  String get _dateText {
    final date = selectedDate;
    if (date == null) {
      return dateLabel.isEmpty ? '最新' : dateLabel;
    }
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  IconData get _modeIcon {
    switch (mode) {
      case 'weekly':
      case 'weekly_r18':
        return Icons.view_week_rounded;
      case 'monthly':
        return Icons.calendar_view_month_rounded;
      case 'rookie':
        return Icons.rocket_launch_rounded;
      case 'original':
        return Icons.brush_rounded;
      case 'male':
      case 'male_r18':
        return Icons.male_rounded;
      case 'female':
      case 'female_r18':
        return Icons.female_rounded;
      default:
        return Icons.today_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (phone) {
      return MobileToolbar(
        topCenter: MobileBrandMark(label: _modeLabel),
        actions: [
          MobileIconButton(
            icon: Icons.calendar_month_rounded,
            tooltip: '选择日期',
            onTap: onPickDate,
          ),
          MobileIconButton(
            icon: Icons.chevron_left_rounded,
            tooltip: '上一页',
            onTap: onPrevPage,
          ),
          MobileIconButton(
            icon: Icons.chevron_right_rounded,
            tooltip: '下一页',
            onTap: onNextPage,
          ),
          MobileIconButton(
            icon: Icons.refresh_rounded,
            tooltip: '刷新',
            onTap: onRefresh,
          ),
        ],
        chips: [
          for (final option in _rankingModes)
            MobilePill(
              icon: _rankingModeIcon(option.$1),
              label: option.$2,
              selected: mode == option.$1,
              onTap: () => onModeChanged(option.$1),
            ),
          MobilePill(
            icon: Icons.event_rounded,
            label: _dateText,
            selected: selectedDate != null,
            onTap: onPickDate,
          ),
          if (selectedDate != null)
            MobilePill(
              icon: Icons.close_rounded,
              label: '最新',
              onTap: onClearDate,
            ),
          MobilePill(
            icon: Icons.layers_rounded,
            label: '第 $page 页',
            selected: true,
          ),
        ],
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _HeaderIcon(icon: _modeIcon),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Pixiv 榜单',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '$_modeLabel · $_dateText · 第 $page 页',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                _SquareIconButton(
                  icon: Icons.refresh_rounded,
                  onTap: onRefresh,
                ),
                const SizedBox(width: 8),
                _FlatButton(
                  icon: Icons.chevron_left_rounded,
                  label: '上一页',
                  onTap: onPrevPage,
                ),
                const SizedBox(width: 6),
                _FlatButton(
                  icon: Icons.chevron_right_rounded,
                  label: '下一页',
                  onTap: onNextPage,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final option in _rankingModes)
                  _ModeChip(
                    label: option.$2,
                    icon: _rankingModeIcon(option.$1),
                    selected: mode == option.$1,
                    onTap: () => onModeChanged(option.$1),
                  ),
                _ModeChip(
                  label: _dateText,
                  icon: Icons.event_rounded,
                  selected: selectedDate != null,
                  onTap: onPickDate,
                ),
                if (selectedDate != null)
                  _ModeChip(
                    label: '清除日期',
                    icon: Icons.close_rounded,
                    selected: false,
                    onTap: onClearDate,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

IconData _rankingModeIcon(String mode) {
  switch (mode) {
    case 'weekly':
    case 'weekly_r18':
      return Icons.view_week_rounded;
    case 'monthly':
      return Icons.calendar_view_month_rounded;
    case 'rookie':
      return Icons.rocket_launch_rounded;
    case 'original':
      return Icons.brush_rounded;
    case 'male':
    case 'male_r18':
      return Icons.male_rounded;
    case 'female':
    case 'female_r18':
      return Icons.female_rounded;
    default:
      return Icons.today_rounded;
  }
}

class _HeaderIcon extends StatelessWidget {
  final IconData icon;

  const _HeaderIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFEAF4FF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFD6E8FF)),
      ),
      child: Icon(icon, color: const Color(0xFF0A84FF), size: 24),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? const Color(0xFF0A84FF) : const Color(0xFF334155);
    return Material(
      color: selected ? const Color(0xFFEAF4FF) : Colors.white,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  selected ? const Color(0xFFD6E8FF) : const Color(0xFFE5E7EB),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: foreground),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
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

class _RankingCard extends StatelessWidget {
  final bool phone;
  final DailyRankingModel item;
  final VoidCallback onTap;

  const _RankingCard({
    required this.phone,
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(phone ? 0 : 18);
    if (phone) {
      return Material(
        color: Colors.white,
        borderRadius: BorderRadius.zero,
        clipBehavior: Clip.none,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              item.thumbUrl.isEmpty
                  ? const ColoredBox(
                      color: Color(0xFFE5E5EA),
                      child: Center(
                          child: Icon(Icons.image_not_supported_outlined)),
                    )
                  : CachedNetworkImage(
                      imageUrl: proxiedImageUrl(item.thumbUrl),
                      cacheManager: imageProxyCacheManager,
                      httpHeaders: imageRequestHeaders(item.thumbUrl),
                      fit: BoxFit.cover,
                      placeholder: (_, __) =>
                          const ColoredBox(color: Color(0xFFE5E5EA)),
                      errorWidget: (_, __, ___) => const ColoredBox(
                        color: Color(0xFFE5E5EA),
                        child: Center(child: Icon(Icons.broken_image_outlined)),
                      ),
                    ),
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Color(0x66000000),
                        Color(0x00000000),
                        Color(0xCC000000),
                      ],
                      stops: [0, 0.42, 1],
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 7,
                left: 7,
                child: _OverlayPill(label: '#${item.rank}'),
              ),
              if (item.pageCount > 1)
                Positioned(
                  top: 7,
                  right: 7,
                  child: _OverlayPill(label: '${item.pageCount}P'),
                ),
              Positioned(
                left: 8,
                right: 8,
                bottom: 8,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.title.isEmpty ? '未命名作品' : item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.1,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.author.name.isEmpty ? '未知作者' : item.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        shadows: [
                          Shadow(color: Color(0x99000000), blurRadius: 8),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      spacing: 7,
                      runSpacing: 4,
                      children: [
                        _OverlayIconInfo(
                          icon: Icons.favorite_rounded,
                          label: '${item.bookmarkCount}',
                        ),
                        _OverlayIconInfo(
                          icon: Icons.visibility_rounded,
                          label: '${item.viewCount}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Material(
      color: Colors.white,
      borderRadius: radius,
      clipBehavior: Clip.none,
      child: InkWell(
        borderRadius: radius,
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: phone ? Colors.white : const Color(0xFFF8FAFC),
            borderRadius: radius,
            border: phone ? null : Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: item.thumbUrl.isEmpty
                          ? const ColoredBox(
                              color: Color(0xFFF1F5F9),
                              child: Center(
                                child: Icon(Icons.image_not_supported_outlined),
                              ),
                            )
                          : CachedNetworkImage(
                              imageUrl: proxiedImageUrl(item.thumbUrl),
                              cacheManager: imageProxyCacheManager,
                              httpHeaders: imageRequestHeaders(item.thumbUrl),
                              fit: BoxFit.cover,
                              placeholder: (_, __) => const ColoredBox(
                                color: Color(0xFFF1F5F9),
                                child: Center(
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                ),
                              ),
                              errorWidget: (_, __, ___) => const ColoredBox(
                                color: Color(0xFFF1F5F9),
                                child: Center(
                                  child: Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                    ),
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.96),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFD6E8FF)),
                        ),
                        child: Text(
                          '#${item.rank}',
                          style: TextStyle(
                            fontSize: phone ? 11 : 12,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2563EB),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  phone ? 6 : 12,
                  phone ? 6 : 12,
                  phone ? 6 : 12,
                  phone ? 8 : 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title.isEmpty ? '未命名作品' : item.title,
                      maxLines: phone ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: phone ? 12 : 13,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF243B53),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.author.name.isEmpty ? '未知作者' : item.author.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: phone ? 11 : 12,
                        color: const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: phone ? 5 : 8,
                      runSpacing: phone ? 5 : 8,
                      children: [
                        _MiniInfo(
                          icon: Icons.favorite_rounded,
                          label: '${item.bookmarkCount}',
                        ),
                        _MiniInfo(
                          icon: Icons.visibility_rounded,
                          label: '${item.viewCount}',
                        ),
                        if (item.pageCount > 1)
                          _MiniInfo(
                            icon: Icons.auto_stories_rounded,
                            label: '${item.pageCount}P',
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniInfo extends StatelessWidget {
  final String label;
  final IconData icon;

  const _MiniInfo({
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF64748B)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Color(0xFF526176),
            ),
          ),
        ],
      ),
    );
  }
}

class _OverlayIconInfo extends StatelessWidget {
  final IconData icon;
  final String label;

  const _OverlayIconInfo({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: const Color(0xFFE5E7EB)),
        const SizedBox(width: 3),
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w800,
            color: Color(0xFFE5E7EB),
          ),
        ),
      ],
    );
  }
}

class _OverlayPill extends StatelessWidget {
  final String label;

  const _OverlayPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 10,
            height: 1,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _FlatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _FlatButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16),
              const SizedBox(width: 2),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _SquareIconButton({
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Icon(icon, size: 18),
      ),
    );
  }
}
