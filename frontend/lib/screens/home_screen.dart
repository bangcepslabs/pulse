import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:web_smooth_scroll/web_smooth_scroll.dart';
import 'dart:async';
import '../models/trend_item.dart';
import '../services/api_service.dart';
import 'landing_screen.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';

// ── 분야별 탭 설정 ──────────────────────────────
const List<Map<String, dynamic>> kCategories = [
  {'label': '전체',      'value': '',         'icon': Icons.dashboard_rounded},
  {'label': '경제',      'value': '경제',      'icon': Icons.trending_up_rounded},
  {'label': '세계',      'value': '세계',      'icon': Icons.public_rounded},
  {'label': '사회',      'value': '사회',      'icon': Icons.people_rounded},
  {'label': '정치',      'value': '정치',      'icon': Icons.account_balance_rounded},
  {'label': '생활/문화', 'value': '생활/문화', 'icon': Icons.library_books_rounded},
  {'label': 'IT/과학',   'value': 'IT/과학',   'icon': Icons.computer_rounded},
];

// ── 카테고리 색상 ──────────────────────────────
const Map<String, Color> kCategoryColors = {
  '경제':      Color(0xFF4CAF50),
  '세계':      Color(0xFF9C27B0),
  '사회':      Color(0xFFFF9800),
  '정치':      Color(0xFFF44336),
  '생활/문화': Color(0xFFE91E63),
  'IT/과학':   Color(0xFF2196F3),
};
const Color kDefaultColor = Color(0xFF607D8B);

Color _catColor(String cat) => kCategoryColors[cat] ?? kDefaultColor;

Color _catColorAlpha(Color c, int alpha) =>
    Color.fromARGB(alpha, c.red, c.green, c.blue);

// ── 별점 위젯 (const 생성 가능한 형태로 분리) ──────────────────────
class _StarRow extends StatelessWidget {
  final int importance;
  final double size;
  const _StarRow({required this.importance, this.size = 12});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 5; i++)
          Icon(
            i < importance ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: Colors.amber,
          ),
      ],
    );
  }
}

// ── 시간 포맷 유틸 ──────────────────────────────
String _timeAgo(String isoDate) {
  if (isoDate.isEmpty) return '';
  try {
    final diff = DateTime.now().difference(DateTime.parse(isoDate));
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
    return '${diff.inDays}일 전';
  } catch (_) {
    return '';
  }
}

// ════════════════════════════════════════════════
// HomeScreen
// ════════════════════════════════════════════════
DateTime? _trendDate(TrendItem trend) {
  return DateTime.tryParse(trend.published) ??
      DateTime.tryParse(trend.createdAt);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final ApiService _api = ApiService();
  late TabController _tabController;
  Timer? _autoRefreshTimer;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  late String _headerTime;
  Timer? _clockTimer;
  late Future<List<TrendItem>> _featuredFuture;
  bool _isFeaturedExpanded = true;

  /// 5분마다 각 _TrendList에 새로고침 신호를 보내는 notifier
  final ValueNotifier<DateTime> _refreshNotifier =
      ValueNotifier(DateTime.now());

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: kCategories.length, vsync: this);
    _headerTime = DateFormat('HH:mm').format(DateTime.now());
    _featuredFuture = _loadFeaturedNews();

    _clockTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) {
        setState(() {
          _headerTime = DateFormat('HH:mm').format(DateTime.now());
        });
      }
    });

    // 5분마다 notifier를 갱신 → 모든 탭이 API 재호출
    _autoRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) {
        _refreshNotifier.value = DateTime.now();
        if (mounted) {
          setState(() {
            _featuredFuture = _loadFeaturedNews();
          });
        }
      },
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _clockTimer?.cancel();
    _autoRefreshTimer?.cancel();
    _refreshNotifier.dispose();
    super.dispose();
  }

  void _toggleFeaturedNews() {
    setState(() {
      _isFeaturedExpanded = !_isFeaturedExpanded;
    });
  }

  Future<List<TrendItem>> _loadFeaturedNews() async {
    try {
      final trends = await _api.fetchTrends(limit: 30, offset: 0);
      final featured = trends.where((trend) => trend.importance >= 4).toList();
      final source = featured.isNotEmpty ? featured : trends;
      source.sort((a, b) {
        final importanceCompare = b.importance.compareTo(a.importance);
        if (importanceCompare != 0) return importanceCompare;
        final aDate = _trendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = _trendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bDate.compareTo(aDate);
      });
      return source.take(5).toList();
    } catch (_) {
      return const [];
    }
  }

  void _openTrendDetail(TrendItem trend) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _DetailSheet(trend: trend),
    );
  }

  Widget _buildFeaturedNewsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Colors.blue.shade50.withOpacity(0.65),
            ],
          ),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: Colors.blue.shade100.withOpacity(0.7)),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withOpacity(0.08),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: FutureBuilder<List<TrendItem>>(
            future: _featuredFuture,
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final items = snapshot.data ?? const <TrendItem>[];

              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                child: Column(
                  key: ValueKey(
                      '${_isFeaturedExpanded ? 'expanded' : 'collapsed'}-${isLoading ? 'loading' : items.length}'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: _toggleFeaturedNews,
                      borderRadius: BorderRadius.circular(18),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade100,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.auto_awesome_rounded,
                                size: 18,
                                color: Colors.blue.shade700,
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Top Stories',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (!isLoading)
                              Text(
                                '${items.length} items',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.blue.shade700,
                                ),
                              ),
                            const SizedBox(width: 8),
                            Icon(
                              _isFeaturedExpanded
                                  ? Icons.expand_less_rounded
                                  : Icons.expand_more_rounded,
                              color: Colors.blue.shade700,
                            ),
                          ],
                        ),
                      ),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      child: _isFeaturedExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 14),
                              child: isLoading
                                  ? const SizedBox(
                                      height: 118,
                                      child: Center(
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      ),
                                    )
                                  : (items.isEmpty
                                      ? SizedBox(
                                          height: 118,
                                          child: Center(
                                            child: Text(
                                              'No featured news right now.',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Colors.grey.shade500,
                                              ),
                                            ),
                                          ),
                                        )
                                      : SizedBox(
                                          height: 204,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            physics:
                                                const BouncingScrollPhysics(),
                                            itemCount: items.length,
                                            separatorBuilder: (_, __) =>
                                                const SizedBox(width: 12),
                                            itemBuilder: (context, index) {
                                              final trend = items[index];
                                              return _MajorNewsCard(
                                                trend: trend,
                                                index: index,
                                                onTap: () => _openTrendDetail(
                                                    trend),
                                              );
                                            },
                                          ),
                                        )),
                            )
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: const Color(0xFFF5F5F5),
      drawer: const _AppDrawer(), // 좌측 사이드 메뉴
      body: SafeArea(
        child: Column(
          children: [
            // ── 헤더 ──────────────────────────────
            ColoredBox(
              color: Colors.white,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 14, 16, 6),
                    child: Row(
                      children: [
                        // 햄버거 메뉴 버튼
                        IconButton(
                          icon: const Icon(Icons.menu_rounded, size: 24),
                          onPressed: () {
                            _scaffoldKey.currentState?.openDrawer();
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pulse',
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _headerTime,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabAlignment: TabAlignment.start,
                    labelColor: Colors.blue.shade800,
                    unselectedLabelColor: Colors.grey[600],
                    indicator: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    indicatorPadding: const EdgeInsets.symmetric(
                        horizontal: 4, vertical: 6),
                    labelStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    unselectedLabelStyle: const TextStyle(fontSize: 14),
                    dividerColor: Colors.transparent,
                    tabs: [
                      for (final cat in kCategories)
                        Tab(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(cat['icon'] as IconData, size: 14),
                                const SizedBox(width: 6),
                                Text(cat['label'] as String),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // ── 탭 콘텐츠 ──────────────────────────
            _buildFeaturedNewsSection(),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  for (final cat in kCategories)
                    _TrendList(
                      key: ValueKey(cat['value']),
                      category: cat['value'] as String,
                      categoryLabel: cat['label'] as String,
                      refreshNotifier: _refreshNotifier,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 앱 아이콘 ───────────────────────
class _MajorNewsCard extends StatelessWidget {
  final TrendItem trend;
  final int index;
  final VoidCallback onTap;

  const _MajorNewsCard({
    required this.trend,
    required this.index,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = _catColor(trend.category);
    final timeAgo = _timeAgo(trend.published);
    final chipLabel = trend.category.isEmpty ? 'General' : trend.category;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: Duration(milliseconds: 380 + index * 70),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(18 * (1 - value), 12 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 300,
          height: 204,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                color.withOpacity(0.98),
                Color.lerp(color, Colors.black, 0.16) ?? color,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.24),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _CategoryBadge(category: chipLabel, color: Colors.white),
                    const Spacer(),
                    Icon(Icons.trending_up_rounded,
                        size: 18, color: Colors.white.withOpacity(0.9)),
                  ],
                ),
                const SizedBox(height: 10),
                _StarRow(importance: trend.importance, size: 13),
                const Spacer(),
                Text(
                  trend.koreanTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                    color: Colors.white,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  trend.source,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Text(
                  timeAgo.isEmpty ? 'just now' : timeAgo,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.white.withOpacity(0.82),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AppIcon extends StatelessWidget {
  const _AppIcon();
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.blue,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const SizedBox(
        width: 32,
        height: 32,
        child: Icon(Icons.trending_up, size: 20, color: Colors.white),
      ),
    );
  }
}

// ── 좌측 Drawer 메뉴 ───────────────────────
class _AppDrawer extends StatelessWidget {
  const _AppDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 헤더 영역
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade600,
                      Colors.blue.shade400,
                    ],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.asset(
                              'assets/icon/app_icon.png',
                              width: 32,
                              height: 32,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Pulse',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '실시간 트렌드 분석',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),

              // 메뉴 리스트
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _DrawerMenuItem(
                      icon: Icons.home_rounded,
                      title: '홈',
                      subtitle: '랜딩 페이지로',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (context) => const LandingScreen(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.newspaper_rounded,
                      title: '실시간 뉴스',
                      subtitle: '최신 뉴스 확인',
                      onTap: () {
                        Navigator.pop(context);
                        // 이미 뉴스 화면이므로 닫기만 함
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.psychology_rounded,
                      title: '공포탐욕지수',
                      subtitle: '시장 심리 확인',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const FearGreedPage(),
                          ),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    _DrawerMenuItem(
                      icon: Icons.show_chart_rounded,
                      title: '증시',
                      subtitle: '주요 지수 및 종목',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => MarketPage(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 하단 정보
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: Colors.grey.shade200),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                        const SizedBox(width: 8),
                        Text(
                          'Version 1.0.0',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
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

  void _showComingSoonDialog(BuildContext context, String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.schedule, color: Colors.blue),
            SizedBox(width: 8),
            Text('준비중'),
          ],
        ),
        content: Text('$feature 기능은 곧 추가될 예정입니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}

// ── Drawer 메뉴 아이템 ───────────────────────
class _DrawerMenuItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isComingSoon;
  final VoidCallback onTap;

  const _DrawerMenuItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isComingSoon = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isComingSoon ? Colors.grey.shade100 : Colors.blue.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: isComingSoon ? Colors.grey.shade400 : Colors.blue,
          size: 24,
        ),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isComingSoon ? Colors.grey.shade400 : Colors.black87,
            ),
          ),
          if (isComingSoon) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.orange.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '준비중',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade700,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 12,
          color: Colors.grey.shade600,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ════════════════════════════════════════════════
// _TrendList - 탭별 무한 스크롤 리스트
// ════════════════════════════════════════════════
class _TrendList extends StatefulWidget {
  final String category;
  final String categoryLabel;
  final ValueNotifier<DateTime> refreshNotifier;

  const _TrendList({
    super.key,
    required this.category,
    required this.categoryLabel,
    required this.refreshNotifier,
  });

  @override
  State<_TrendList> createState() => _TrendListState();
}

class _TrendListState extends State<_TrendList>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final ApiService _api = ApiService();
  
  // 수정됨: 아래 build 메서드와 변수명을 맞추기 위해 _scrollController로 통일
  final ScrollController _scrollController = ScrollController();

  List<TrendItem> _trends = [];
  bool _isLoading = false;
  bool _isFetchingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  String? _error;
  static const int _pageSize = 20;
  
  // 탭이 다시 보일 때 자동 새로고침을 위한 플래그
  DateTime? _lastLoadTime;
  static const _autoRefreshThreshold = Duration(minutes: 3);

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _load();
    _scrollController.addListener(_onScroll);
    // 부모의 refreshNotifier 변경 시 자동 새로고침
    widget.refreshNotifier.addListener(_onAutoRefresh);
    // 앱 생명주기 관찰 시작
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 앱이 다시 활성화되었을 때
    if (state == AppLifecycleState.resumed) {
      _checkAndRefreshIfNeeded();
    }
  }

  // 탭이 다시 보일 때 자동 새로고침 체크
  void _checkAndRefreshIfNeeded() {
    if (_lastLoadTime != null) {
      final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
      if (timeSinceLastLoad > _autoRefreshThreshold) {
        print('📱 Auto-refreshing ${widget.category} (${timeSinceLastLoad.inMinutes}분 경과)');
        _refresh();
      }
    }
  }

  void _onAutoRefresh() {
    _refresh();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 400) {
      _loadMore();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.refreshNotifier.removeListener(_onAutoRefresh);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_isLoading) return;
    if (!mounted) return;
    print('📱 _load() started for category: ${widget.category}');
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.fetchTrends(
          limit: _pageSize, offset: 0, category: widget.category);
      if (!mounted) return;
      print('📱 _load() success: ${data.length} trends');
      setState(() {
        _trends = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _error = null;
        _isLoading = false;
        _lastLoadTime = DateTime.now(); // 로드 시간 기록
      });
    } catch (e) {
      print('📱 _load() error: $e');
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
      // 5초 후 재시도 (빈 리스트일 때만)
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted && _trends.isEmpty) {
          print('📱 Auto-retrying after error...');
          _load();
        }
      });
    }
  }

  Future<void> _loadMore() async {
    if (_isFetchingMore || !_hasMore) return;
    setState(() => _isFetchingMore = true);
    try {
      final data = await _api.fetchTrends(
          limit: _pageSize, offset: _offset, category: widget.category);
      if (!mounted) return;
      setState(() {
        _trends.addAll(data);
        _offset += data.length;
        _hasMore = data.length == _pageSize;
        _isFetchingMore = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isFetchingMore = false);
    }
  }

  Future<void> _refresh() async {
    try {
      final data = await _api.fetchTrends(
          limit: _pageSize, offset: 0, category: widget.category);
      if (!mounted) return;
      setState(() {
        _trends = data;
        _offset = data.length;
        _hasMore = data.length == _pageSize;
        _error = null;
        _lastLoadTime = DateTime.now(); // 새로고침 시간 기록
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    
    // 탭이 보일 때마다 자동 새로고침 체크
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _checkAndRefreshIfNeeded();
      }
    });

    if (_isLoading && _trends.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _trends.isEmpty) {
      return _ErrorView(onRetry: _load);
    }

    if (_trends.isEmpty) {
      return _EmptyView(
          label: widget.categoryLabel, onRetry: _load);
    }
    
    return RefreshIndicator(
      onRefresh: _refresh,
      child: kIsWeb
          ? WebSmoothScroll(
              controller: _scrollController,
              child: ListView.builder(
                controller: _scrollController,
                physics: const NeverScrollableScrollPhysics(),
                cacheExtent: 1500,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: _trends.length + (_isFetchingMore ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == _trends.length) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  }
                  return _TrendCard(
                    key: ValueKey(_trends[index].id),
                    rank: index + 1,
                    trend: _trends[index],
                  );
                },
              ),
            )
          : ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              cacheExtent: 1500,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              itemCount: _trends.length + (_isFetchingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _trends.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }
                return _TrendCard(
                  key: ValueKey(_trends[index].id),
                  rank: index + 1,
                  trend: _trends[index],
                );
              },
            ),
    );
  }
}

// ════════════════════════════════════════════════
// _TrendCard
// ════════════════════════════════════════════════
class _TrendCard extends StatefulWidget {
  final int rank;
  final TrendItem trend;

  const _TrendCard({super.key, required this.rank, required this.trend});

  @override
  State<_TrendCard> createState() => _TrendCardState();
}

class _TrendCardState extends State<_TrendCard> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.97).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => _DetailSheet(trend: widget.trend),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTop3 = widget.rank <= 3;
    final isImportant = widget.trend.importance >= 4; // 별 4-5개는 중요 뉴스
    final catColor = _catColor(widget.trend.category);
    final cardAccentColor = isTop3 ? catColor : Colors.grey.shade200;
    final badgeColor = isTop3 ? catColor : Colors.grey.shade600;
    final timeStr = _timeAgo(widget.trend.published);

    return ScaleTransition(
      scale: _scaleAnimation,
      child: RepaintBoundary(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: GestureDetector(
            onTapDown: (_) {
              setState(() => _isPressed = true);
              _controller.forward();
            },
            onTapUp: (_) {
              setState(() => _isPressed = false);
              _controller.reverse();
              _showDetail(context);
            },
            onTapCancel: () {
              setState(() => _isPressed = false);
              _controller.reverse();
            },
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: isTop3
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          cardAccentColor.withOpacity(0.06),
                        ],
                      )
                    : null,
                color: isTop3 ? null : Colors.white,
                border: Border.all(
                  color: isTop3
                      ? cardAccentColor.withOpacity(0.18)
                      : Colors.grey.shade200,
                  width: isTop3 ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isTop3
                        ? cardAccentColor.withOpacity(0.12)
                        : Colors.black.withOpacity(0.03),
                    blurRadius: isTop3 ? 12 : 6,
                    offset: Offset(0, isTop3 ? 4 : 2),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 순위 배지
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        gradient: isTop3
                            ? LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Colors.blue.shade400,
                                  Colors.blue.shade600,
                                ],
                              )
                            : null,
                        color: isTop3 ? null : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: Text(
                          '${widget.rank}',
                          style: TextStyle(
                            fontSize: isTop3 ? 16 : 14,
                            fontWeight: FontWeight.bold,
                            color: isTop3 ? Colors.white : Colors.grey[600],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // 내용
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 제목
                          Text(
                            widget.trend.koreanTitle,
                            style: TextStyle(
                              fontSize: isImportant ? 16 : 15,
                              fontWeight: isImportant ? FontWeight.w700 : FontWeight.w600,
                              height: 1.4,
                              color: Colors.black87,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          
                          const SizedBox(height: 10),
                          
                          // 메타 정보
                          Row(
                            children: [
                              _CategoryBadge(
                                category: widget.trend.category.isEmpty ? 'General' : widget.trend.category,
                                color: badgeColor,
                                isImportant: isTop3,
                              ),
                              const SizedBox(width: 8),
                              _StarRow(importance: widget.trend.importance, size: isTop3 ? 14 : 12),
                              const Spacer(),
                              Icon(
                                Icons.access_time_rounded,
                                size: 12,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                timeStr,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[500],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),
                    
                    // 화살표 아이콘
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 14,
                        color: Colors.grey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final String category;
  final Color color;
  final bool isImportant;
  const _CategoryBadge({
    required this.category,
    required this.color,
    this.isImportant = false,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _catColorAlpha(color, 26),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _catColorAlpha(color, 52), width: 1),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: isImportant ? 12 : 10,
          vertical: isImportant ? 5 : 4,
        ),
        child: Text(
          category,
          style: TextStyle(
            fontSize: isImportant ? 11 : 10.5,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════
// _DetailSheet
// ════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final TrendItem trend;
  const _DetailSheet({required this.trend});

  @override
  Widget build(BuildContext context) {
    final catColor = _catColor(trend.category);

    return GestureDetector(
      onTap: () => Navigator.pop(context), // 바깥 영역 클릭 시 닫기
      behavior: HitTestBehavior.opaque, // 투명 영역도 탭 감지
      child: GestureDetector(
        onTap: () {}, // Sheet 내부 클릭은 전파 안 되도록
        child: DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          builder: (_, ctrl) => ColoredBox(
            color: Colors.white,
            child: SafeArea(
              top: false,
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: catColor,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          child: Text(
                            trend.category,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          trend.source,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[500],
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _timeAgo(trend.published),
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Text(
                    trend.koreanTitle,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _StarRow(importance: trend.importance, size: 18),
                  const SizedBox(height: 18),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFAFAFA),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFEEEEEE)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        trend.summaryKr.isNotEmpty
                            ? trend.summaryKr
                            : 'Summary not available.',
                        style: const TextStyle(fontSize: 15, height: 1.7),
                      ),
                    ),
                  ),
                  if (trend.tickers.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text(
                      'Related Tickers',
                      style:
                          TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        for (final t in trend.tickers)
                          Chip(
                            label: Text(t),
                            backgroundColor: const Color(0xFFE3F2FD),
                            shape: StadiumBorder(
                              side: BorderSide(
                                color:
                                    const Color(0xFF90CAF9).withOpacity(0.35),
                              ),
                            ),
                            labelStyle: const TextStyle(
                              color: Color(0xFF1565C0),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 24),
                  if (trend.link.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _openUrl(trend.link, context),
                        icon: const Icon(Icons.open_in_new, size: 18),
                        label: const Text(
                          'Open article',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(String url, BuildContext ctx) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, webOnlyWindowName: '_blank')) {
      if (ctx.mounted) {
        ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('링크를 열 수 없습니다.')),
        );
      }
    }
  }
}

// ── 에러/빈 화면 위젯 ────────────────────────────
class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.cloud_off_rounded,
              size: 64, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 16),
          const Text('백엔드 서버 연결 중...',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          const Text('https://news-summarizer.bum2432.workers.dev',
              style: TextStyle(fontSize: 13, color: Color(0xFF9E9E9E))),
          const SizedBox(height: 4),
          const Text('Ollama 분석 완료 후 자동 로드됩니다',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFFBDBDBD))),
          const SizedBox(height: 24),
          const SizedBox(
              width: 24,
              height: 24,
              child:
                  CircularProgressIndicator(strokeWidth: 2)),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('지금 재시도'),
          ),
        ],
      ),
    );
  }
}

class _EmptyView extends StatelessWidget {
  final String label;
  final VoidCallback onRetry;
  const _EmptyView({required this.label, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.newspaper,
              size: 60, color: Color(0xFFDDDDDD)),
          const SizedBox(height: 12),
          Text('$label 뉴스가 없습니다',
              style: const TextStyle(color: Color(0xFF9E9E9E))),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh),
            label: const Text('새로고침'),
          ),
        ],
      ),
    );
  }
}
