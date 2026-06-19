import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import '../models/trend_insight.dart';
import '../models/trend_item.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<TrendInsightSnapshot> _insightFuture;

  @override
  void initState() {
    super.initState();
    _insightFuture = _api.fetchTrendInsights();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(),
            ),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.1),
                    Colors.white.withOpacity(0.8),
                    Colors.white,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          SingleChildScrollView(
            child: Column(
              children: [
                _buildAppBar(isMobile),
                _FadeInOnScroll(
                  child: _buildPlatformHero(isMobile),
                ),
                const SizedBox(height: 120),
                _FadeInOnScroll(
                  delay: 200,
                  child: _buildCoreFeatures(isMobile),
                ),
                const SizedBox(height: 120),
                _FadeInOnScroll(
                  child: _buildCategoriesSection(isMobile),
                ),
                const SizedBox(height: 120),
                _FadeInOnScroll(
                  child: _buildFooter(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Pulse',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (!isMobile) ...[
            _navItem(
              '실시간뉴스',
              () => _openPage(const HomeScreen()),
            ),
            const SizedBox(width: 40),
            _navItem(
              '공포탐욕지수',
              () => _openPage(const FearGreedPage()),
            ),
            const SizedBox(width: 40),
            _navItem(
              '증시',
              () => _openPage(const MarketPage()),
            ),
            const SizedBox(width: 40),
            _HoverButton(
              onTap: () {
                _openPage(const HomeScreen());
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Get Started',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87),
                ),
              ),
            ),
          ],
          if (isMobile)
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.black87),
              onPressed: () {
                _scaffoldKey.currentState?.openDrawer();
              },
            ),
        ],
      ),
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Widget _navItem(String text, VoidCallback onTap) {
    return _HoverButton(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.grey[700],
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Colors.blue.shade600, Colors.blue.shade400],
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      padding: const EdgeInsets.all(8),
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
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    ListTile(
                      leading: const Icon(Icons.home, color: Colors.blue),
                      title: const Text('Pulse'),
                      subtitle: const Text('메인 화면'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.newspaper_rounded,
                          color: Colors.blue),
                      title: const Text('실시간뉴스'),
                      subtitle: const Text('최신 뉴스'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const HomeScreen());
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.psychology_rounded,
                          color: Colors.blue),
                      title: const Text('공포탐욕지수'),
                      subtitle: const Text('시장 심리'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const FearGreedPage());
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.show_chart_rounded,
                          color: Colors.blue),
                      title: const Text('증시'),
                      subtitle: const Text('주요 시장 데이터'),
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const MarketPage());
                      },
                    ),
                    const Divider(height: 1),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey.shade200)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: Colors.grey[600]),
                    const SizedBox(width: 8),
                    Text(
                      'Version 1.0.0',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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

  Widget _buildPlatformHero(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final insight = snapshot.data;

        return Container(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 20 : 60,
            isMobile ? 34 : 54,
            isMobile ? 20 : 60,
            isMobile ? 42 : 64,
          ),
          child: isMobile
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _LandingHeroCopy(isMobile: isMobile),
                    const SizedBox(height: 24),
                    _LandingInsightPanelFixed(
                      isLoading: isLoading,
                      insight: insight,
                      searchController: _searchController,
                      onRefresh: _refreshInsights,
                      onSearch: _submitLandingSearch,
                      onStart: () => _openPage(const HomeScreen()),
                      onKeywordTap: _searchLandingKeyword,
                      onRisingIssueTap: _searchLandingRisingIssue,
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      flex: 9,
                      child: _LandingHeroCopy(isMobile: isMobile),
                    ),
                    const SizedBox(width: 34),
                    Expanded(
                      flex: 8,
                      child: _LandingInsightPanelFixed(
                        isLoading: isLoading,
                        insight: insight,
                        searchController: _searchController,
                        onRefresh: _refreshInsights,
                        onSearch: _submitLandingSearch,
                        onStart: () => _openPage(const HomeScreen()),
                        onKeywordTap: _searchLandingKeyword,
                        onRisingIssueTap: _searchLandingRisingIssue,
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _refreshInsights() {
    setState(() {
      _insightFuture = _api.fetchTrendInsights();
    });
  }

  void _submitLandingSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      _openPage(const HomeScreen());
      return;
    }

    _showLandingSearchSheet(
      title: '"$query" 검색 결과',
      future: _api.searchNews(query: query, sort: 'relevance', limit: 30),
    );
  }

  void _searchLandingKeyword(TrendKeyword keyword) {
    final query = keyword.keyword.trim();
    if (query.isEmpty) return;

    _searchController.text = query;
    _showLandingSearchSheet(
      title: '#$query 관련 뉴스',
      future: _api
          .fetchNewsByKeyword(keyword: query, limit: 30)
          .then((result) => result.items),
    );
  }

  void _searchLandingRisingIssue(RisingIssue issue) {
    final query = issue.keyword.trim();
    if (query.isEmpty) return;

    _searchController.text = query;
    _showLandingSearchSheet(
      title: '#$query 관련 뉴스 · 최근 1시간 ${issue.currentCount}건',
      future: _api
          .fetchNewsByKeyword(keyword: query, period: '6h', limit: 30)
          .then((result) => result.items),
    );
  }

  void _showLandingSearchSheet({
    required String title,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: FutureBuilder<List<TrendItem>>(
                future: future,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TrendItem>[];

                  return CustomScrollView(
                    controller: scrollController,
                    slivers: [
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 12, 12, 12),
                          child: Row(
                            children: [
                              Container(
                                width: 38,
                                height: 4,
                                margin: const EdgeInsets.only(right: 12),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(999),
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  title,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: '닫기',
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (snapshot.connectionState == ConnectionState.waiting)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (snapshot.hasError)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: _LandingSearchStateMessage(
                            icon: Icons.error_outline_rounded,
                            title: '검색 결과를 불러오지 못했습니다.',
                            subtitle: '잠시 후 다시 시도해 주세요.',
                          ),
                        )
                      else if (items.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: _LandingSearchStateMessage(
                            icon: Icons.search_off_rounded,
                            title: '검색 결과가 없습니다.',
                            subtitle: '다른 키워드로 다시 검색해 보세요.',
                          ),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          sliver: SliverList.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              return _LandingSearchResultTile(
                                  item: items[index]);
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 24 : 80,
        vertical: isMobile ? 60 : 100,
      ),
      child: Column(
        children: [
          Text(
            'AI가 분석하는\n실시간 뉴스 인사이트',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 36 : 64,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '경제, 사회, 정치, 세계 뉴스를 AI가 실시간 분석합니다.\n중요한 뉴스만 빠르게 확인해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isMobile ? 16 : 20,
              fontWeight: FontWeight.w400,
              color: Colors.grey[600],
              height: 1.6,
            ),
          ),
          const SizedBox(height: 48),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            alignment: WrapAlignment.center,
            children: [
              _HoverButton(
                onTap: () {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.apple, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('App Store',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
              _HoverButton(
                onTap: () {},
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.android, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Play Store',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCoreFeatures(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: isMobile
          ? GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85,
              children: [
                _featureCard(
                    Icons.bolt_rounded, '실시간 속보', '중요 뉴스를 빠르게 확인할 수 있어요.'),
                _featureCard(
                    Icons.psychology_rounded, 'AI 요약', '핵심만 짧고 정확하게 정리합니다.'),
                _featureCard(Icons.category_rounded, '카테고리 분류',
                    '경제, 사회, 정치, 세계별로 나눠 봅니다.'),
                _featureCard(
                    Icons.public_rounded, '글로벌 뉴스', '해외 주요 이슈도 함께 확인할 수 있어요.'),
              ],
            )
          : Row(
              children: [
                Expanded(
                    child: _featureCard(Icons.bolt_rounded, '실시간 속보',
                        '중요 뉴스를 빠르게\n확인할 수 있어요.')),
                const SizedBox(width: 24),
                Expanded(
                    child: _featureCard(Icons.psychology_rounded, 'AI 요약',
                        '핵심만 짧고 정확하게\n정리합니다.')),
                const SizedBox(width: 24),
                Expanded(
                    child: _featureCard(Icons.category_rounded, '카테고리 분류',
                        '경제, 사회, 정치, 세계별로\n나눠 볼 수 있어요.')),
              ],
            ),
    );
  }

  Widget _featureCard(IconData icon, String title, String description) {
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          const Text(
            '다양한 분야의 뉴스',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '관심 있는 카테고리를 골라 필요한 뉴스만 빠르게 확인해보세요.',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isMobile
              ? GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85,
                  children: [
                    _categoryCard(Icons.trending_up_rounded, '경제',
                        '주식, 환율, 금리, 증시', Colors.green),
                    _categoryCard(Icons.public_rounded, '세계', '국제 정세, 해외 이슈',
                        Colors.purple),
                    _categoryCard(Icons.people_rounded, '사회', '사건, 사고, 지역 소식',
                        Colors.orange),
                    _categoryCard(Icons.account_balance_rounded, '정치',
                        '국회, 정부, 정책 이슈', Colors.red),
                    _categoryCard(Icons.library_books_rounded, '생활/문화',
                        '여행, 공연, 전시, 엔터', Colors.pink),
                    _categoryCard(Icons.computer_rounded, 'IT/과학',
                        '기술, AI, 반도체, 테크', Colors.blue),
                  ],
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.trending_up_rounded, '경제',
                            '주식, 환율, 금리, 증시', Colors.green)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.public_rounded, '세계',
                            '국제 정세, 해외 이슈', Colors.purple)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.people_rounded, '사회',
                            '사건, 사고, 지역 소식', Colors.orange)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.account_balance_rounded,
                            '정치', '국회, 정부, 정책 이슈', Colors.red)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.library_books_rounded,
                            '생활/문화', '여행, 공연, 전시, 엔터', Colors.pink)),
                    SizedBox(
                        width:
                            (MediaQuery.of(context).size.width - 160 - 48) / 3,
                        child: _categoryCard(Icons.computer_rounded, 'IT/과학',
                            '기술, AI, 반도체, 테크', Colors.blue)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _categoryCard(
      IconData icon, String title, String description, Color color) {
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 30,
                offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 24, color: color),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration:
                    BoxDecoration(borderRadius: BorderRadius.circular(6)),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.asset(
                    'assets/icon/app_icon.png',
                    width: 32,
                    height: 32,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              const Text('Pulse',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 32),
          Text('2026 Pulse. All rights reserved.',
              style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

class _LandingHeroCopy extends StatelessWidget {
  final bool isMobile;

  const _LandingHeroCopy({required this.isMobile});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          isMobile ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.06),
            borderRadius: BorderRadius.circular(999),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 15, color: Colors.black87),
              SizedBox(width: 6),
              Text(
                'AI Trend Intelligence',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '오늘 뜨는 이슈를\n한눈에 확인하세요',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isMobile ? 42 : 68,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            height: 1.05,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          '실시간 인기 키워드와 급상승 이슈, 뉴스 분위기를 한곳에서 보여드립니다.',
          textAlign: isMobile ? TextAlign.center : TextAlign.left,
          style: TextStyle(
            fontSize: isMobile ? 16 : 20,
            color: Colors.grey.shade700,
            height: 1.55,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 28),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isMobile ? WrapAlignment.center : WrapAlignment.start,
          children: const [
            _LandingPill(icon: Icons.radar_rounded, text: '급상승 이슈'),
            _LandingPill(icon: Icons.thermostat_rounded, text: '뉴스 감정온도'),
            _LandingPill(icon: Icons.search_rounded, text: '키워드 탐색'),
          ],
        ),
      ],
    );
  }
}

class _LandingPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _LandingPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.82),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.blue.shade700),
          const SizedBox(width: 7),
          Text(
            text,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _LandingInsightPanel extends StatelessWidget {
  final bool isLoading;
  final TrendInsightSnapshot? insight;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onStart;
  final ValueChanged<TrendKeyword> onKeywordTap;

  const _LandingInsightPanel({
    required this.isLoading,
    required this.insight,
    required this.searchController,
    required this.onRefresh,
    required this.onStart,
    required this.onKeywordTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || insight == null) {
      return const _LandingInsightSkeleton();
    }

    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final briefing = _landingBriefing(data);
    final keywords = data.keywords.take(8).toList();
    final rising = data.risingIssues.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'AI Briefing',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh_rounded,
                    color: Colors.white, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LandingMetricCard(
                  label: '오늘 이슈강도',
                  value: '$score',
                  suffix: '/100',
                  color: Colors.indigoAccent,
                  changeText: '${delta.abs()}',
                  changeUp: delta >= 0,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LandingMetricCard(
                  label: '감정온도',
                  value: '${data.sentiment.temperature}',
                  suffix: '°',
                  color: data.sentiment.temperature >= 71
                      ? Colors.greenAccent
                      : data.sentiment.temperature <= 30
                          ? Colors.redAccent
                          : Colors.lightBlueAccent,
                  caption: _sentimentCaption(data.sentiment.temperature),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '전일 대비 ${delta >= 0 ? '+' : ''}$delta · 긍정 ${data.sentiment.positiveRatio}% · 중립 ${data.sentiment.neutralRatio}% · 부정 ${data.sentiment.negativeRatio}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onSubmitted: (_) => onStart(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'AI, 환율, 비트코인 검색',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: Icon(Icons.search_rounded,
                  color: Colors.white.withOpacity(0.7)),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: onStart,
                icon: const Icon(Icons.arrow_forward_rounded,
                    color: Colors.white),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.09),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.32)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '실시간 인기 키워드',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < keywords.length; i++)
                ActionChip(
                  label: Text(
                    '${i + 1}. ${keywords[i].keyword} · ${keywords[i].newsCount}',
                  ),
                  onPressed: () => onKeywordTap(keywords[i]),
                  backgroundColor: Colors.white.withOpacity(0.11),
                  side: BorderSide(color: Colors.white.withOpacity(0.12)),
                  labelStyle: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '급상승 이슈',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final issue in rising)
              _LandingRisingIssueRow(issue: issue, onTap: onStart),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('실시간 뉴스 분석 보기'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingInsightSkeleton extends StatelessWidget {
  const _LandingInsightSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 520,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(width: 150, height: 24),
          const SizedBox(height: 18),
          _skeletonBar(width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _skeletonBar(width: 280, height: 16),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(child: _skeletonBar(width: double.infinity, height: 96)),
              const SizedBox(width: 10),
              Expanded(child: _skeletonBar(width: double.infinity, height: 96)),
            ],
          ),
          const SizedBox(height: 18),
          _skeletonBar(width: double.infinity, height: 48),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 6; i++) _skeletonBar(width: 86, height: 34),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _skeletonBar({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _LandingInsightPanelFixed extends StatelessWidget {
  final bool isLoading;
  final TrendInsightSnapshot? insight;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final VoidCallback onStart;
  final ValueChanged<TrendKeyword> onKeywordTap;
  final ValueChanged<RisingIssue> onRisingIssueTap;

  const _LandingInsightPanelFixed({
    required this.isLoading,
    required this.insight,
    required this.searchController,
    required this.onRefresh,
    required this.onSearch,
    required this.onStart,
    required this.onKeywordTap,
    required this.onRisingIssueTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || insight == null) {
      return const _LandingInsightSkeleton();
    }

    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final briefing = _landingBriefingTextSafe(data);
    final keywords = data.keywords
        .where((item) => _isLandingKeywordUseful(item.keyword))
        .take(8)
        .toList();
    final rising = data.risingIssues
        .where((item) => _isLandingKeywordUseful(item.keyword))
        .take(3)
        .toList();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.auto_awesome_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '뉴스 브리핑',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: const Icon(
                  Icons.refresh_rounded,
                  color: Colors.white,
                  size: 19,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: TextStyle(
              color: Colors.white.withOpacity(0.92),
              fontSize: 15,
              height: 1.55,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _LandingMetricCard(
                  label: '트렌드 점수',
                  value: '$score',
                  suffix: '/100',
                  color: Colors.indigoAccent,
                  changeText: '${delta.abs()}',
                  changeUp: delta >= 0,
                  caption: '오늘 이슈 강도',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _LandingMetricCard(
                  label: '감정온도',
                  value: '${data.sentiment.temperature}',
                  suffix: '°',
                  color: data.sentiment.temperature >= 71
                      ? Colors.greenAccent
                      : data.sentiment.temperature <= 30
                          ? Colors.redAccent
                          : Colors.lightBlueAccent,
                  caption: _sentimentCaption(data.sentiment.temperature),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '전일 대비 ${delta >= 0 ? '+' : ''}$delta · 긍정 ${data.sentiment.positiveRatio}% · 중립 ${data.sentiment.neutralRatio}% · 부정 ${data.sentiment.negativeRatio}%',
            style: TextStyle(
              color: Colors.white.withOpacity(0.64),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onSubmitted: (_) => onSearch(),
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: '뉴스 키워드 검색',
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.45)),
              prefixIcon: Icon(
                Icons.search_rounded,
                color: Colors.white.withOpacity(0.7),
              ),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: onSearch,
                icon: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                ),
              ),
              filled: true,
              fillColor: Colors.white.withOpacity(0.09),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.12)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.white.withOpacity(0.32)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            '실시간 인기 키워드',
            style: TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < keywords.length; i++)
                _LandingKeywordChip(
                  rank: i + 1,
                  keyword: keywords[i],
                  onTap: () => onKeywordTap(keywords[i]),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text(
              '급상승 이슈',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            for (final issue in rising)
              _LandingRisingIssueRow(
                issue: issue,
                onTap: () => onRisingIssueTap(issue),
              ),
          ],
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onStart,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: const Text('실시간 뉴스 분석 보기'),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingKeywordChip extends StatelessWidget {
  final int rank;
  final TrendKeyword keyword;
  final VoidCallback onTap;

  const _LandingKeywordChip({
    required this.rank,
    required this.keyword,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withOpacity(0.13),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
          child: Text(
            '$rank. ${keyword.keyword} · ${keyword.newsCount}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _LandingSearchResultTile extends StatelessWidget {
  final TrendItem item;

  const _LandingSearchResultTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final hasLink = item.link.trim().isNotEmpty;
    final meta = [
      if (item.source.trim().isNotEmpty) item.source.trim(),
      if (item.category.trim().isNotEmpty) item.category.trim(),
      if (item.published.trim().isNotEmpty) item.published.trim(),
    ].join(' · ');

    return Material(
      color: const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: hasLink ? () => _openArticle(context, item.link) : null,
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (meta.isNotEmpty) ...[
                Text(
                  meta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
              ],
              Text(
                item.koreanTitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black87,
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w900,
                ),
              ),
              if (item.summaryKr.trim().isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  item.summaryKr.trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontSize: 13,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(
                    Icons.auto_graph_rounded,
                    size: 15,
                    color: Colors.blue.shade700,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    '중요도 ${item.importance}',
                    style: TextStyle(
                      color: Colors.blue.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (hasLink) ...[
                    const Spacer(),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 15,
                      color: Colors.blue.shade700,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '원문 보기',
                      style: TextStyle(
                        color: Colors.blue.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle(BuildContext context, String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null) return;

    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기사 원문을 열 수 없습니다.')),
      );
    }
  }
}

class _LandingSearchStateMessage extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _LandingSearchStateMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: Colors.grey.shade500),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingMetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String suffix;
  final Color color;
  final String? caption;
  final String? changeText;
  final bool changeUp;

  const _LandingMetricCard({
    required this.label,
    required this.value,
    required this.suffix,
    required this.color,
    this.caption,
    this.changeText,
    this.changeUp = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.66),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: RichText(
                  text: TextSpan(
                    text: value,
                    style: TextStyle(
                      color: color,
                      fontSize: 30,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(
                        text: suffix,
                        style: TextStyle(
                          color: color.withOpacity(0.78),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (changeText != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color:
                        (changeUp ? Colors.redAccent : Colors.lightBlueAccent)
                            .withOpacity(0.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        changeUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 12,
                        color: changeUp
                            ? Colors.redAccent
                            : Colors.lightBlueAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        changeText!,
                        style: TextStyle(
                          color: changeUp
                              ? Colors.redAccent
                              : Colors.lightBlueAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (caption != null) ...[
            const SizedBox(height: 7),
            Text(
              caption!,
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 11,
                height: 1.25,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LandingRisingIssueRow extends StatelessWidget {
  final RisingIssue issue;
  final VoidCallback onTap;

  const _LandingRisingIssueRow({required this.issue, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final badgeText = issue.isNew ? 'NEW' : '+${issue.increaseCount}건';
    final detailText = issue.isNew
        ? '최근 1시간 새롭게 포착 · 관련 기사 ${issue.currentCount}건'
        : '직전 1시간보다 기사 ${issue.increaseCount}건 증가';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.redAccent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                badgeText,
                style: const TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    issue.keyword,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detailText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
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

int _landingTrendScore(TrendInsightSnapshot insight) {
  final keywordPower =
      insight.keywords.fold<int>(0, (sum, item) => sum + item.newsCount);
  final risingPower = insight.risingIssues.fold<int>(
    0,
    (sum, item) => sum + item.currentCount + item.increaseCount,
  );
  final sentimentBalance =
      100 - (50 - insight.sentiment.temperature).abs().clamp(0, 50);

  return (keywordPower * 2 + risingPower * 4 + sentimentBalance)
      .clamp(0, 100)
      .toInt();
}

int _landingTrendDelta(TrendInsightSnapshot insight) {
  if (insight.risingIssues.isEmpty) return 0;
  final averageIncrease = insight.risingIssues
          .map((issue) => issue.increaseCount)
          .reduce((a, b) => a + b) /
      insight.risingIssues.length;

  return (averageIncrease * 2).round().clamp(-20, 40);
}

String _sentimentCaption(int temperature) {
  if (temperature >= 71) {
    return '뉴스 분위기: 기대감 우세';
  }
  if (temperature <= 30) {
    return '뉴스 분위기: 불안감 우세';
  }
  return '뉴스 분위기: 중립 흐름';
}

String _landingBriefing(TrendInsightSnapshot insight) {
  final keywords = insight.keywords.take(3).map((e) => e.keyword).toList();
  final rising = insight.risingIssues.take(2).map((e) => e.keyword).toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 이슈를 수집하고 있습니다.\n새 뉴스가 쌓이면 핵심 키워드와 분위기를 자동으로 요약합니다.';
  }

  final keywordText = keywords.isEmpty ? '새로운 뉴스' : keywords.join(', ');
  final risingText = rising.isEmpty
      ? '뚜렷한 급상승 이슈는 아직 없습니다'
      : '${rising.join(', ')} 관련 뉴스가 빠르게 늘고 있습니다';
  final mood = insight.sentiment.temperature >= 71
      ? '기대감이 우세합니다'
      : insight.sentiment.temperature <= 30
          ? '불안감이 큽니다'
          : '중립적인 흐름입니다';

  return '오늘은 $keywordText 이슈가 많이 언급되고 있습니다.\n$risingText.\n전체 뉴스 분위기는 $mood.';
}

String _landingBriefingText(TrendInsightSnapshot insight) {
  final keywords = insight.keywords
      .map((item) => item.keyword.trim())
      .where((keyword) => keyword.isNotEmpty)
      .take(3)
      .toList();
  final rising = insight.risingIssues
      .map((item) => item.keyword.trim())
      .where((keyword) => keyword.isNotEmpty)
      .take(2)
      .toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 뉴스를 분석하고 있습니다.\n데이터가 쌓이면 핵심 이슈와 뉴스 분위기를 자동으로 요약합니다.';
  }

  final keywordSentence = keywords.length == 1
      ? '${keywords.first} 관련 뉴스가 많이 언급되고 있습니다.'
      : '${_joinKoreanList(keywords)} 관련 뉴스가 많이 언급되고 있습니다.';
  final risingSentence = rising.isEmpty
      ? '아직 뚜렷한 급상승 이슈는 감지되지 않았습니다.'
      : '${_joinKoreanList(rising)} 이슈의 언급량이 빠르게 늘고 있습니다.';
  final mood = insight.sentiment.temperature >= 71
      ? '기대감이 우세한 편입니다.'
      : insight.sentiment.temperature <= 30
          ? '불안감이 커진 흐름입니다.'
          : '전반적으로 중립적인 흐름입니다.';

  return '오늘은 $keywordSentence\n$risingSentence\n전체 뉴스 분위기는 $mood';
}

String _joinKoreanList(List<String> values) {
  if (values.length <= 1) return values.join();
  if (values.length == 2) return '${values[0]}와 ${values[1]}';

  return '${values.take(values.length - 1).join(', ')}와 ${values.last}';
}

String _landingBriefingTextSafe(TrendInsightSnapshot insight) {
  final keywords = insight.keywords
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(3)
      .toList();
  final rising = insight.risingIssues
      .map((item) => _cleanLandingKeyword(item.keyword))
      .where(_isLandingKeywordUseful)
      .take(2)
      .toList();

  if (keywords.isEmpty && rising.isEmpty) {
    return 'AI가 오늘의 주요 뉴스를 분석하고 있습니다.\n데이터가 쌓이면 핵심 이슈와 뉴스 분위기를 자동으로 요약합니다.';
  }

  final lines = <String>[];

  if (keywords.isNotEmpty) {
    lines.add('오늘은 ${_joinKoreanListSafe(keywords)} 관련 보도가 많이 나오고 있습니다.');
  }

  if (rising.isNotEmpty) {
    lines.add('${_joinKoreanListSafe(rising)} 관련 보도는 최근 더 빠르게 늘고 있습니다.');
  }

  if (insight.sentiment.temperature >= 71) {
    lines.add('뉴스 분위기는 기대감이 우세한 편입니다.');
  } else if (insight.sentiment.temperature <= 30) {
    lines.add('뉴스 분위기는 다소 불안한 흐름입니다.');
  } else {
    lines.add('뉴스 분위기는 전반적으로 중립에 가깝습니다.');
  }

  return lines.join('\n');
}

String _cleanLandingKeyword(String keyword) {
  return keyword
      .replaceAll(RegExp(r'[^\w가-힣/+.-]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

bool _isLandingKeywordUseful(String keyword) {
  final value = _cleanLandingKeyword(keyword);
  if (value.length < 2 || value.length > 24) return false;
  if (RegExp(r'^[0-9]+$').hasMatch(value)) return false;

  const blocked = {
    '있다',
    '있는',
    '있습니다',
    '했다',
    '한다',
    '된다',
    '됐다',
    '없다',
    '예정',
    '예정이다',
    '계획',
    '계획이다',
    '위한',
    '위해',
    '통해',
    '따르면',
    '가운데',
    '것으로',
    '것이다',
    '밝혔다',
    '전했다',
    '말했다',
    '문제',
    '시대',
    '상황',
    '경우',
    '부분',
    '내용',
    '결과',
    '과정',
    '수준',
    '기준',
    '대한',
    '관련',
    '오늘',
    '이번',
    '속보',
    '단독',
    '기자',
    '뉴스',
    '보도',
    '사진',
    '영상',
    '그리고',
    '하지만',
  };

  if (blocked.contains(value)) return false;
  if (RegExp(
    r'^[가-힣]+(?:이다|입니다|했다|한다|된다|됐다|있다|없다|나선다|밝혔다|전했다|말했다)$',
  ).hasMatch(value)) {
    return false;
  }

  return true;
}

String _joinKoreanListSafe(List<String> values) {
  final cleanValues =
      values.map(_cleanLandingKeyword).where(_isLandingKeywordUseful).toList();
  if (cleanValues.isEmpty) return '';
  if (cleanValues.length == 1) return cleanValues.first;
  if (cleanValues.length == 2) return '${cleanValues[0]}와 ${cleanValues[1]}';

  return '${cleanValues.take(cleanValues.length - 1).join(', ')}와 ${cleanValues.last}';
}

class _FadeInOnScroll extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeInOnScroll({required this.child, this.delay = 0});

  @override
  State<_FadeInOnScroll> createState() => _FadeInOnScrollState();
}

class _FadeInOnScrollState extends State<_FadeInOnScroll>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _isAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _slide =
        Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: ObjectKey(widget),
      onVisibilityChanged: (info) {
        if (info.visibleFraction > 0.1 && !_isAnimated) {
          _isAnimated = true;
          Future.delayed(Duration(milliseconds: widget.delay), () {
            if (mounted) _controller.forward();
          });
        }
      },
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) => Opacity(
          opacity: _fade.value,
          child: SlideTransition(
            position: _slide,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

class _HoverCard extends StatefulWidget {
  final Widget child;
  const _HoverCard({required this.child});

  @override
  State<_HoverCard> createState() => _HoverCardState();
}

class _HoverCardState extends State<_HoverCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -8 : 0, 0),
        child: widget.child,
      ),
    );
  }
}

class _HoverButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  const _HoverButton({required this.child, required this.onTap});

  @override
  State<_HoverButton> createState() => _HoverButtonState();
}

class _HoverButtonState extends State<_HoverButton> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
          child: widget.child,
        ),
      ),
    );
  }
}

class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2)
      ..style = PaintingStyle.fill;

    const double spacing = 30.0;
    const double radius = 1.5;

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
