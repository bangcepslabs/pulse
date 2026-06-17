import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:visibility_detector/visibility_detector.dart'; // 💡 추가된 패키지
import 'home_screen.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';
import 'fear_greed_page.dart';
import 'market_page.dart';

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: Colors.white,
      drawer: isMobile ? _buildDrawer(context) : null, // 모바일에서만 Drawer 표시
      body: Stack(
        children: [
          // 💡 1. 밋밋함을 없애주는 트렌디한 도트 패턴 배경 추가
          Positioned.fill(
            child: CustomPaint(
              painter: DotPatternPainter(),
            ),
          ),
          
          // 💡 2. 상단에서 아래로 갈수록 하얗게 덮어주는 그라데이션 (패턴이 자연스럽게 스며들게 함)
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

          // 메인 컨텐츠 영역
          SingleChildScrollView(
            child: Column(
              children: [
                // App Bar (항상 보이게 애니메이션 제외)
                _buildAppBar(isMobile),
                
                // 💡 여기서부터 각 섹션을 _FadeInOnScroll 로 감싸서 스크롤 애니메이션 적용
                _FadeInOnScroll(
                  child: _buildHeroSection(isMobile),
                ),
                
                const SizedBox(height: 120),
                
                _FadeInOnScroll(
                  delay: 200, // 살짝 늦게 나타나게 딜레이
                  child: _buildCoreFeatures(isMobile),
                ),
                
                const SizedBox(height: 120),
                
                _FadeInOnScroll(
                  child: _buildCategoriesSection(isMobile),
                ),
                
                const SizedBox(height: 120),
                
                _FadeInOnScroll(
                  child: _buildTargetUsers(isMobile),
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

  // ══════════════════════════════════════════════
  // App Bar
  // ══════════════════════════════════════════════
  Widget _buildAppBar(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 20 : 60,
        vertical: 20,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.9), // 약간 투명하게
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
            _navItem('홈'),
            const SizedBox(width: 40),
            _navItem('데스크톱'),
            const SizedBox(width: 40),
            _navItem('회사'),
            const SizedBox(width: 40),
            _navItem('다운로드'),
            const SizedBox(width: 40),
            _HoverButton(
              onTap: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => const HomeScreen()),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '시작하기',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: Colors.black87),
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

  Widget _navItem(String text) {
    return _HoverButton(
      onTap: () {},
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

  // 모바일 Drawer 메뉴
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
                      title: const Text('홈'),
                      subtitle: const Text('메인 페이지'),
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.newspaper_rounded, color: Colors.blue),
                      title: const Text('실시간 뉴스'),
                      subtitle: const Text('최신 뉴스 확인'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const HomeScreen()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.psychology_rounded, color: Colors.blue),
                      title: const Text('공포탐욕지수'),
                      subtitle: const Text('시장 심리 확인'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const FearGreedPage()),
                        );
                      },
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.show_chart_rounded, color: Colors.blue),
                      title: const Text('증시'),
                      subtitle: const Text('주요 지수 및 종목'),
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (context) => const MarketPage()),
                        );
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

  // ══════════════════════════════════════════════
  // Hero Section
  // ══════════════════════════════════════════════
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
              fontWeight: FontWeight.w800, // 굵기 살짝 강화
              color: Colors.black87,
              height: 1.1,
              letterSpacing: -1.5,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '경제, 사회, 정치, 세계 뉴스를 AI가 실시간 분석.\n중요한 뉴스만 빠르게 확인하세요.',
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
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.apple, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('App Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                ),
              ),
              _HoverButton(
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.android, color: Colors.white, size: 20),
                      SizedBox(width: 8),
                      Text('Play Store', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white)),
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

  // ══════════════════════════════════════════════
  // Core Features
  // ══════════════════════════════════════════════
  Widget _buildCoreFeatures(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: isMobile
          ? GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2, // 모바일에서 2칸
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 0.85, // 0.9 -> 0.85로 높이 증가
              children: [
                _featureCard(Icons.bolt_rounded, '실시간 속보', '중요한 뉴스를 가장 먼저 알림으로 받아보세요'),
                _featureCard(Icons.psychology_rounded, 'AI 요약', '수만 개의 뉴스를 분석해 핵심만 간추려 제공합니다'),
                _featureCard(Icons.category_rounded, '카테고리별 분류', '경제, 사회, 정치, 세계 등 원하는 분야만 선택하세요'),
                _featureCard(Icons.public_rounded, '글로벌 뉴스', '전 세계 주요 뉴스를 한눈에 확인하세요'),
              ],
            )
          : Row(
              children: [
                Expanded(child: _featureCard(Icons.bolt_rounded, '실시간 속보', '중요한 뉴스를 가장 먼저\n알림으로 받아보세요')),
                const SizedBox(width: 24),
                Expanded(child: _featureCard(Icons.psychology_rounded, 'AI 요약', '수만 개의 뉴스를 분석해\n핵심만 간추려 제공합니다')),
                const SizedBox(width: 24),
                Expanded(child: _featureCard(Icons.category_rounded, '카테고리별 분류', '경제, 사회, 정치, 세계 등\n원하는 분야만 선택하세요')),
              ],
            ),
    );
  }

  Widget _featureCard(IconData icon, String title, String description) {
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20), // 32 -> 20으로 줄임
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)), // 얇은 테두리로 입체감
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 중앙 정렬
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, // 56 -> 48로 축소
              height: 48,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: Colors.black87), // 28 -> 24로 축소
            ),
            const SizedBox(height: 12), // 20 -> 12로 축소
            Text(
              title, 
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.black87), // 18 -> 15
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6), // 8 -> 6으로 축소
            Text(
              description, 
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4), // 13 -> 12, height 1.5 -> 1.4
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // News Categories Section
  // ══════════════════════════════════════════════
  Widget _buildCategoriesSection(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          const Text(
            '다양한 분야의 뉴스',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '관심있는 카테고리를 선택하고 맞춤형 뉴스를 받아보세요',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 48),
          isMobile
              ? GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2, // 모바일에서 2칸으로 변경
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.85, // 세로 비율 조정
                  children: [
                    _categoryCard(Icons.trending_up_rounded, '경제', '주식, 환율, 금융 정책', Colors.green),
                    _categoryCard(Icons.public_rounded, '세계', '국제 정세, 해외 이슈', Colors.purple),
                    _categoryCard(Icons.people_rounded, '사회', '사건, 사고, 지역 소식', Colors.orange),
                    _categoryCard(Icons.account_balance_rounded, '정치', '국회, 선거, 정책', Colors.red),
                    _categoryCard(Icons.library_books_rounded, '생활/문화', '라이프스타일, 트렌드', Colors.pink),
                    _categoryCard(Icons.computer_rounded, 'IT/과학', '기술, 혁신, 과학 발견', Colors.blue),
                  ],
                )
              : Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  children: [
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.trending_up_rounded, '경제', '주식, 환율, 금융 정책', Colors.green)),
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.public_rounded, '세계', '국제 정세, 해외 이슈', Colors.purple)),
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.people_rounded, '사회', '사건, 사고, 지역 소식', Colors.orange)),
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.account_balance_rounded, '정치', '국회, 선거, 정책', Colors.red)),
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.library_books_rounded, '생활/문화', '라이프스타일, 트렌드', Colors.pink)),
                    SizedBox(width: (MediaQuery.of(context).size.width - 160 - 48) / 3, child: _categoryCard(Icons.computer_rounded, 'IT/과학', '기술, 혁신, 과학 발견', Colors.blue)),
                  ],
                ),
        ],
      ),
    );
  }

  Widget _categoryCard(IconData icon, String title, String description, Color color) {
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20), // 24 -> 20
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 30, offset: const Offset(0, 10)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center, // 중앙 정렬
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 48, // 56 -> 48
              height: 48,
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, size: 24, color: color), // 28 -> 24
            ),
            const SizedBox(height: 12), // 16 -> 12
            Text(
              title, 
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87), // 18 -> 16
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4), // 6 -> 4
            Text(
              description, 
              style: TextStyle(fontSize: 12, color: Colors.grey[600], height: 1.4), // 13 -> 12
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Target Users
  // ══════════════════════════════════════════════
  Widget _buildTargetUsers(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          const Text(
            '모든 사람을 위한 뉴스',
            style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.black87, letterSpacing: -0.5),
          ),
          const SizedBox(height: 48),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: isMobile ? 2 : 3, // 모바일에서 2칸으로 변경
            mainAxisSpacing: 24,
            crossAxisSpacing: 24,
            childAspectRatio: isMobile ? 2.2 : 1.5, // 1.8 -> 2.2로 높이 증가 (더 넓게)
            children: [
              _userCard('직장인', '출퇴근 시간에 핵심 뉴스만'),
              _userCard('학생', '시사 상식과 트렌드 파악'),
              _userCard('투자자', '실시간 경제 뉴스 모니터링'),
              _userCard('자영업자', '업종별 정책과 이슈 확인'),
              _userCard('주부', '생활 밀착형 뉴스와 정보'),
              _userCard('시니어', '큰 글씨와 쉬운 요약'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _userCard(String title, String description) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), // 균등 패딩 대신 세밀하게 조정
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center, // 중앙 정렬
        children: [
          Text(
            title, 
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black87), // 15 -> 14
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3), // 4 -> 3
          Text(
            description, 
            style: TextStyle(fontSize: 11, color: Colors.grey[600]), // 12 -> 11
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════
  // Footer
  // ══════════════════════════════════════════════
  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 60),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!, width: 1))),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
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
              const Text('Pulse', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: Colors.black87)),
            ],
          ),
          const SizedBox(height: 32),
          Text('© 2026 Pulse. All rights reserved.', style: TextStyle(fontSize: 14, color: Colors.grey[500])),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════
// 💡 [신규] 스크롤 시 부드럽게 나타나는 애니메이션 엔진
// ══════════════════════════════════════════════
class _FadeInOnScroll extends StatefulWidget {
  final Widget child;
  final int delay;

  const _FadeInOnScroll({required this.child, this.delay = 0});

  @override
  State<_FadeInOnScroll> createState() => _FadeInOnScrollState();
}

class _FadeInOnScrollState extends State<_FadeInOnScroll> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fade;
  late Animation<Offset> _slide;
  bool _isAnimated = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _fade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart),
    );
    _slide = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
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
        // 화면에 10% 이상 보이고 아직 애니메이션이 실행되지 않았을 때 작동
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

// ══════════════════════════════════════════════
// Hover Effects
// ══════════════════════════════════════════════
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

// ══════════════════════════════════════════════
// 💡 트렌디한 도트 패턴 배경을 그려주는 클래스
// ══════════════════════════════════════════════
class DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.grey.withOpacity(0.2) // 점의 색상과 투명도 (아주 연하게)
      ..style = PaintingStyle.fill;

    const double spacing = 30.0; // 점들 사이의 간격
    const double radius = 1.5;   // 점의 크기

    for (double y = 0; y < size.height; y += spacing) {
      for (double x = 0; x < size.width; x += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}