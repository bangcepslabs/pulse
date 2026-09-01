import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/trend_insight.dart';
import '../models/trend_item.dart';
import '../services/api_service.dart';
import '../services/theme_controller.dart';
import '../theme/pulse_ui.dart';
import '../utils/news_grouping.dart';
import '../widgets/network_thumbnail.dart';
import 'home_screen.dart';
import 'fear_greed_page.dart';
import 'contact_page.dart';
import 'issue_detail_screen.dart';
import './market_page.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math' as math;
import 'package:http/http.dart' as http;

String _landingTimeLabel() {
  final now = DateTime.now();
  final hour = now.hour.toString().padLeft(2, '0');
  final minute = now.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String _landingCompactTime(String value) {
  final parsed = _landingParseTimestamp(value);
  if (parsed == null) return _landingTimeLabel();
  final diff = DateTime.now().difference(parsed);
  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
  }
  final month = parsed.month.toString().padLeft(2, '0');
  final day = parsed.day.toString().padLeft(2, '0');
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$month.$day $hour:$minute';
}

String _landingClockLabel(DateTime? dateTime) {
  if (dateTime == null) return '--:--';
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

Widget _landingThumbnailFallback(bool isDark) {
  return Container(
    color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
    alignment: Alignment.center,
    child: Icon(
      Icons.image_not_supported_outlined,
      color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade300,
      size: 22,
    ),
  );
}

Widget _landingThumbnailLoading(bool isDark) {
  return Container(
    color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
    alignment: Alignment.center,
    child: const SizedBox(
      width: 20,
      height: 20,
      child: CircularProgressIndicator(
        strokeWidth: 2,
        color: Color(0xFF2563EB),
      ),
    ),
  );
}

String _landingRelativeTimeLabel(DateTime? dateTime) {
  if (dateTime == null) return '방금 전';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return '방금 전';
  if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
  if (diff.inHours < 24) return '${diff.inHours}시간 전';
  return _landingCompactTime(dateTime.toIso8601String());
}

String _landingFormatCompactPrice(double value) {
  final abs = value.abs();
  if (abs >= 1000) return value.toStringAsFixed(0);
  if (abs >= 100) return value.toStringAsFixed(1);
  return value.toStringAsFixed(2);
}

String _landingFormatNumber(num value, {int decimals = 0}) {
  final fixed = value.toStringAsFixed(decimals);
  final parts = fixed.split('.');
  final whole = parts[0];
  final isNegative = whole.startsWith('-');
  final digits = isNegative ? whole.substring(1) : whole;
  final buffer = StringBuffer();
  for (int i = 0; i < digits.length; i++) {
    buffer.write(digits[i]);
    final remaining = digits.length - i - 1;
    if (remaining > 0 && remaining % 3 == 0) {
      buffer.write(',');
    }
  }
  final formattedWhole =
      isNegative ? '-${buffer.toString()}' : buffer.toString();
  if (parts.length > 1 && decimals > 0) {
    return '$formattedWhole.${parts[1]}';
  }
  return formattedWhole;
}

String _landingFormatPercent(double value) {
  final sign = value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';
  return '$sign${value.abs().toStringAsFixed(2)}%';
}

String _landingFormatPrice(
  double value, {
  required String marketType,
  String? symbol,
}) {
  switch (marketType) {
    case 'kr':
      return '${_landingFormatNumber(value.round())}원';
    case 'usd':
      return '\$${_landingFormatNumber(value.round())}';
    case 'index':
      return _landingFormatNumber(value.round());
    case 'crypto':
      return '\$${_landingFormatNumber(value.round())}';
    case 'fx':
      return _landingFormatCurrencyPair(value, symbol ?? '');
    default:
      return _landingFormatNumber(value.round());
  }
}

String _landingFormatCurrencyPair(double value, String pair) {
  final upper = pair.toUpperCase();
  if (upper.contains('EUR/USD')) {
    return _landingFormatNumber(value, decimals: 4);
  }
  if (upper.contains('USD/JPY')) {
    return _landingFormatNumber(value, decimals: 2);
  }
  if (upper.contains('USD/KRW')) {
    return _landingFormatNumber(value, decimals: 2);
  }
  return _landingFormatNumber(value, decimals: 2);
}

String _landingFormatStockCode(String symbol) {
  return symbol.replaceFirst(RegExp(r'\.(KS|KQ|US|NASD|NYSE|AMEX)$'), '');
}

String _landingFormatUpdatedAt(DateTime? dateTime) {
  if (dateTime == null) return '--:--';
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}

String? _landingNaverFinanceUrl(_LandingMarketQuote quote) {
  final symbol = _landingFormatStockCode(quote.symbol).trim();
  if (symbol.isEmpty ||
      quote.symbol.startsWith('^') ||
      quote.symbol.contains('=')) {
    return null;
  }
  return 'https://finance.naver.com/item/main.naver?code=$symbol';
}

String? _landingDelaySummary(DateTime? dateTime) {
  if (dateTime == null) return '시세 확인 중';
  final age = DateTime.now().difference(dateTime).inMinutes;
  if (age > 30) return '시세 지연 가능 · ${_landingFormatUpdatedAt(dateTime)} 기준';
  if (age > 10) return '시세 지연 가능 · ${_landingFormatUpdatedAt(dateTime)} 기준';
  return null;
}

DateTime? _landingLatestUpdatedAt(Iterable<_LandingMarketQuote> quotes) {
  final dates =
      quotes.map((item) => item.priceUpdatedAt).whereType<DateTime>().toList();
  if (dates.isEmpty) return null;
  dates.sort();
  return dates.last;
}

_LandingMarketQuote? _landingQuoteByTitle(
  List<_LandingMarketQuote> quotes,
  String title,
) {
  for (final quote in quotes) {
    if (quote.title == title) return quote;
  }
  return null;
}

String _landingMarketPriceLabel(_LandingMarketQuote quote) {
  switch (quote.group) {
    case 'fx':
      return _landingFormatCurrencyPair(quote.currentPrice, quote.title);
    case 'crypto':
      return _landingFormatPrice(quote.currentPrice, marketType: 'crypto');
    case 'index':
      return _landingFormatPrice(quote.currentPrice, marketType: 'index');
    case 'equity':
    default:
      return _landingFormatPrice(quote.currentPrice, marketType: 'kr');
  }
}

DateTime? _landingTryParseDate(String value) {
  return _landingParseTimestamp(value);
}

DateTime? _landingParseTimestamp(String value) {
  final raw = value.trim();
  if (raw.isEmpty) return null;

  final candidates = <String>[
    raw,
    raw.replaceFirst(' ', 'T'),
    raw.replaceAll('/', '-').replaceFirst(' ', 'T'),
  ];

  for (final candidate in candidates) {
    final parsed = DateTime.tryParse(candidate);
    if (parsed == null) continue;

    final hasTimezone = RegExp(r'(Z|[+-]\d{2}:?\d{2})$', caseSensitive: false)
        .hasMatch(candidate);
    if (hasTimezone) return parsed.toLocal();
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
  }

  return null;
}

String? _landingSourceLabel(String source) {
  final value = source.trim();
  if (value.isEmpty) return null;
  final lower = value.toLowerCase();
  final looksLikeUrl = lower.startsWith('http://') ||
      lower.startsWith('https://') ||
      lower.contains('www.');
  if (looksLikeUrl) return null;
  if (value.contains('.') || value.contains('/')) return null;
  return value;
}

String? _landingSourceDomainLabel(String url) {
  final value = url.trim();
  if (value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  final host = uri?.host.trim() ?? '';
  if (host.isEmpty) return null;
  return host.startsWith('www.') ? host.substring(4) : host;
}

Future<void> _landingOpenArticle(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('기사 원문을 열 수 없습니다.')),
    );
  }
}

Future<void> _landingOpenExternalLink(BuildContext context, String url) async {
  final uri = Uri.tryParse(url.trim());
  if (uri == null) return;

  final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('외부 링크를 열 수 없습니다.')),
    );
  }
}

class LandingScreen extends StatefulWidget {
  const LandingScreen({super.key});

  @override
  State<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends State<LandingScreen>
    with WidgetsBindingObserver {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _editionSectionKey = GlobalKey();
  final GlobalKey _updatesSectionKey = GlobalKey();
  final GlobalKey _marketSectionKey = GlobalKey();
  final ApiService _api = ApiService();
  final TextEditingController _searchController = TextEditingController();
  late Future<DailyEditionSnapshot> _editionFuture;
  late Future<TrendInsightSnapshot> _insightFuture;
  late Future<List<IssueTimelineItem>> _timelineFuture;
  late Future<List<TrendItem>> _latestNewsFuture;
  final List<_LandingMarketQuote> _marketQuotes = [];
  final Set<int> _readNewsIds = <int>{};
  Timer? _marketRefreshTimer;
  bool _marketFetching = false;
  bool _marketRefreshing = false;
  bool _insightRefreshing = false;
  String? _marketError;
  DateTime? _marketLastUpdatedAt;
  DateTime? _lastInsightRefreshAt;
  DateTime? _lastBackPressedAt;

  bool get isDark => Theme.of(context).brightness == Brightness.dark;
  Color get titleText => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get mutedText =>
      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
  Color get bodyText =>
      isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
  Color get chipBg =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
  Color get chipBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFDCE7FF);
  Color get inputFill =>
      isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get inputBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
  Color get surface =>
      isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC);
  Color get surfaceBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFF0F4F8);
  Color get cardBorder =>
      isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
  Color get ctaBg => isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _editionFuture = _api.fetchDailyEdition();
    _insightFuture = _api.fetchTrendInsights();
    _timelineFuture =
        _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
    _latestNewsFuture =
        _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
    _refreshMarketData(force: true);
    _marketRefreshTimer = Timer.periodic(
      const Duration(minutes: 5),
      (_) => _refreshMarketData(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _marketRefreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshMarketDataIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 768;
    final useDrawerNavigation = screenWidth < 1080;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        await _handleRootBackPressed(useDrawerNavigation);
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: PulseUi.page(context),
        drawer: useDrawerNavigation ? _buildDrawer(context) : null,
        body: _buildHomeShell(isMobile),
        bottomNavigationBar: isMobile ? _buildHomeBottomNavigation() : null,
      ),
    );
  }

  Widget _buildHomeShell(bool isMobile) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final background = dark ? const Color(0xFF0B1220) : const Color(0xFFF5F7FB);

    return ColoredBox(
      color: background,
      child: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _refreshHomeData,
          color: const Color(0xFF2563EB),
          child: SingleChildScrollView(
            controller: _scrollController,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.only(bottom: isMobile ? 92 : 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildAppBar(isMobile),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1180),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        KeyedSubtree(
                          key: _editionSectionKey,
                          child: _buildHomeTopNews(isMobile),
                        ),
                        KeyedSubtree(
                          key: _updatesSectionKey,
                          child: _buildHomeLivePreview(isMobile),
                        ),
                        KeyedSubtree(
                          key: _marketSectionKey,
                          child: _buildHomeMarketSummary(isMobile),
                        ),
                      ],
                    ),
                  ),
                ),
                _buildFooter(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHomeHeader(bool isMobile) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Padding(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 20 : 32, 10, isMobile ? 12 : 32, 8),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 32,
              height: 32,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 9),
          Text(
            'Pulse',
            style: TextStyle(
              color: foreground,
              fontSize: 21,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          IconButton(
            tooltip: '검색',
            onPressed: _submitLandingSearch,
            icon: Icon(Icons.search_rounded, color: muted),
          ),
          IconButton(
            tooltip: dark ? '라이트 모드' : '다크 모드',
            onPressed: () => ThemeController.instance.toggleThemeMode(
              brightness: dark ? Brightness.dark : Brightness.light,
            ),
            icon: Icon(
              dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
              color: muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHomeTopNews(bool isMobile) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = dark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);

    return FutureBuilder<DailyEditionSnapshot>(
      future: _editionFuture,
      builder: (context, editionSnapshot) {
        if (editionSnapshot.connectionState == ConnectionState.waiting) {
          return _homeSectionFrame(
            title: '메인 뉴스',
            child: const _HomeLoadingLine(),
          );
        }

        return FutureBuilder<List<TrendItem>>(
          future: _latestNewsFuture,
          builder: (context, newsSnapshot) {
            final stories = _buildHomeMainStories(
              editionSnapshot.data,
              newsSnapshot.data ?? const <TrendItem>[],
            );
            if (stories.isEmpty &&
                newsSnapshot.connectionState == ConnectionState.waiting) {
              return _homeSectionFrame(
                title: '메인 뉴스',
                child: const _HomeLoadingLine(),
              );
            }
            if (stories.isEmpty) {
              return _homeSectionFrame(
                title: '메인 뉴스',
                child: Text(
                  '현재 확인된 주요 뉴스가 없습니다.',
                  style: TextStyle(color: muted, fontSize: 13),
                ),
              );
            }
            return _homeTopNewsContent(
              stories: stories,
              isMobile: isMobile,
              foreground: foreground,
              muted: muted,
              border: border,
            );
          },
        );
      },
    );
  }

  Widget _homeTopNewsContent({
    required List<_HomeStory> stories,
    required bool isMobile,
    required Color foreground,
    required Color muted,
    required Color border,
  }) {
    return Padding(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 20 : 32, 16, isMobile ? 20 : 32, 20),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: isMobile
              ? const Color(0xFF2563EB).withValues(alpha: 0.045)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(isMobile ? 22 : 0),
          border: Border.all(
            color: isMobile
                ? const Color(0xFF2563EB).withValues(alpha: 0.10)
                : Colors.transparent,
          ),
        ),
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            isMobile ? 14 : 0,
            isMobile ? 15 : 0,
            isMobile ? 14 : 0,
            isMobile ? 14 : 0,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMobile ? '오늘의 핵심 이슈' : '오늘의 핵심 뉴스',
                          style: TextStyle(
                            color: const Color(0xFF2563EB),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                        const SizedBox(height: 3),
                        if (isMobile)
                          Text(
                            '메인 뉴스',
                            style: TextStyle(
                              color: foreground,
                              fontSize: isMobile ? 22 : 26,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _HomeStoryCarousel(
                stories: stories,
                foreground: foreground,
                muted: muted,
                border: border,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _homeSectionFrame({required String title, required Widget child}) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: TextStyle(
                  color: foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  _HomeStory _homeStoryFromEdition(EditionIssue issue) {
    return _HomeStory(
      type: _HomeStoryType.issue,
      title: issue.title.trim().isEmpty ? issue.keyword : issue.title,
      summary: issue.summary,
      category: issue.category,
      time: _landingRelativeTimeLabel(_landingParseTimestamp(issue.lastSeenAt)),
      meta: issue.countsVerified
          ? [
              if (issue.articleCount > 0) '기사 ${issue.articleCount}건',
              if (issue.sourceCount > 0) '출처 ${issue.sourceCount}곳',
            ].join(' · ')
          : '관련 기사 확인 중',
      context: _editionIssueContext(issue),
      thumbnailUrl: issue.thumbnailUrl,
      issueNewsIds: issue.newsIds,
      onTap: () => _openLandingEditionIssue(issue),
    );
  }

  String _editionIssueContext(EditionIssue issue) {
    final countLabel = RegExp(r'^(관련\s*)?기사\s*\d+건$|^출처\s*\d+곳$');
    return issue.selectionReason
        .split('·')
        .map((part) => part.trim())
        .where(
          (part) =>
              part.isNotEmpty &&
              part != issue.category &&
              !countLabel.hasMatch(part),
        )
        .join(' · ');
  }

  _HomeStory _homeStoryFromNews(TrendItem item) {
    return _HomeStory(
      type: _HomeStoryType.article,
      title: item.koreanTitle,
      summary: item.summaryKr,
      category: item.category,
      time: _landingRelativeTimeLabel(_landingTrendDate(item)),
      meta: item.source.trim().isEmpty
          ? ''
          : '${_landingSourceLabel(item.source) ?? item.source} · ${_landingRelativeTimeLabel(_landingTrendDate(item))}',
      thumbnailUrl: item.thumbnailUrl,
      articleId: item.id,
      onTap: () => _openLandingTrendItemArticle(item),
    );
  }

  List<_HomeStory> _buildHomeMainStories(
    DailyEditionSnapshot? edition,
    List<TrendItem> latestNews,
  ) {
    final issueStories = (edition?.topIssues ?? const <EditionIssue>[])
        .take(5)
        .map(_homeStoryFromEdition)
        .toList();
    if (issueStories.length >= 5) return issueStories;

    final usedNewsIds = issueStories
        .expand((story) => story.issueNewsIds)
        .where((id) => id > 0)
        .toSet();
    final usedTitles = issueStories
        .map((story) => _homeNormalizedTitle(story.title))
        .where((title) => title.isNotEmpty)
        .toSet();
    final articleStories = _selectHomeFallbackArticles(
      latestNews,
      excludedNewsIds: usedNewsIds,
      excludedTitles: usedTitles,
      limit: 5 - issueStories.length,
    ).map(_homeStoryFromNews);

    return [...issueStories, ...articleStories];
  }

  List<TrendItem> _selectHomeFallbackArticles(
    List<TrendItem> latestNews, {
    required Set<int> excludedNewsIds,
    required Set<String> excludedTitles,
    required int limit,
    bool prioritizeImportance = true,
  }) {
    final seenTitles = <String>{...excludedTitles};
    final candidates = [...latestNews]..sort(_compareHomeArticleRecency);

    final deduplicated = <TrendItem>[];
    for (final item in candidates) {
      final normalizedTitle = _homeNormalizedTitle(item.koreanTitle);
      if (item.id > 0 && excludedNewsIds.contains(item.id)) continue;
      if (normalizedTitle.isNotEmpty && seenTitles.contains(normalizedTitle))
        continue;

      deduplicated.add(item);
      if (normalizedTitle.isNotEmpty) seenTitles.add(normalizedTitle);
    }

    if (!prioritizeImportance) return deduplicated.take(limit).toList();

    final ranked = deduplicated
        .map((item) => _HomeArticleCandidate(
              item: item,
              eligibility: _evaluateHomeArticleEligibility(item),
            ))
        .where((candidate) => !candidate.eligibility.isHardExcluded)
        .toList()
      ..sort(_compareHomeMainArticleCandidates);

    final selected = <TrendItem>[];
    void addCandidates(Iterable<_HomeArticleCandidate> tier) {
      for (final candidate in tier) {
        if (selected.length >= limit) return;
        selected.add(candidate.item);
      }
    }

    addCandidates(ranked.where(
      (candidate) => (candidate.item.mainWorthiness ?? 0) >= 4,
    ));
    addCandidates(ranked.where(
      (candidate) => candidate.item.mainWorthiness == 3,
    ));
    addCandidates(ranked.where(
      (candidate) =>
          candidate.item.mainWorthiness == null &&
          candidate.eligibility.score >= 3,
    ));
    addCandidates(ranked.where(
      (candidate) =>
          candidate.item.mainWorthiness != null &&
          candidate.item.mainWorthiness! <= 2,
    ));
    addCandidates(ranked.where(
      (candidate) =>
          candidate.item.mainWorthiness == null &&
          candidate.eligibility.score >= 0 &&
          candidate.eligibility.score < 3,
    ));
    addCandidates(ranked.where(
      (candidate) =>
          candidate.item.mainWorthiness == null &&
          candidate.eligibility.score < 0,
    ));

    // Keep the Main section populated during an unusually sparse feed. These
    // normally excluded items remain a last-resort fallback only.
    if (selected.isEmpty) return deduplicated.take(limit).toList();
    return selected;
  }

  int _compareHomeArticleRecency(TrendItem left, TrendItem right) {
    final leftDate =
        _landingTrendDate(left) ?? DateTime.fromMillisecondsSinceEpoch(0);
    final rightDate =
        _landingTrendDate(right) ?? DateTime.fromMillisecondsSinceEpoch(0);
    return rightDate.compareTo(leftDate);
  }

  int _compareHomeMainArticleCandidates(
    _HomeArticleCandidate left,
    _HomeArticleCandidate right,
  ) {
    final leftMainWorthiness = left.item.mainWorthiness;
    final rightMainWorthiness = right.item.mainWorthiness;
    if (leftMainWorthiness != null && rightMainWorthiness != null) {
      final mainWorthiness = rightMainWorthiness.compareTo(leftMainWorthiness);
      if (mainWorthiness != 0) return mainWorthiness;
    } else if (leftMainWorthiness == null && rightMainWorthiness == null) {
      final eligibility =
          right.eligibility.score.compareTo(left.eligibility.score);
      if (eligibility != 0) return eligibility;
    }

    final importance = right.item.importance.compareTo(left.item.importance);
    if (importance != 0) return importance;
    return _compareHomeArticleRecency(left.item, right.item);
  }

  _HomeArticleEligibility _evaluateHomeArticleEligibility(TrendItem item) {
    final title = item.koreanTitle.trim();
    final text = '$title ${item.summaryKr}'.toLowerCase();
    var score = 0;
    var isHardExcluded = false;

    final clearSeriesOrReview = RegExp(
      r'<\s*\d+\s*>|\[(칼럼|기고|사설|오피니언|리뷰|사용기)\]|(연재|기획\s*연재|책\s*소개|도서\s*소개|사용기|리뷰)',
      caseSensitive: false,
    ).hasMatch(title);
    if (clearSeriesOrReview) {
      isHardExcluded = true;
    }

    if (RegExp(r'(인터뷰|대담|에게\s*듣다|이야기)', caseSensitive: false).hasMatch(title)) {
      score -= 3;
    }
    if (RegExp(r'(행사|교육\s*프로그램|모집|체험|전시|공연|개최)', caseSensitive: false)
        .hasMatch(text)) {
      score -= 2;
    }

    if (RegExp(r'(정부|국회|한국은행|금융위원회|검찰|법원|관세청|중앙은행|공식)', caseSensitive: false)
        .hasMatch(text)) {
      score += 2;
    }
    if (RegExp(r'(발표|결정|통과|승인|시행|규제|수사|기소|판결|인수|합병|계약|공급|출시|투자)',
            caseSensitive: false)
        .hasMatch(text)) {
      score += 2;
    }
    if (RegExp(r'(코스피|코스닥|환율|금리|주가|증시|순매수|급등|급락|상승|하락|돌파|반등)',
            caseSensitive: false)
        .hasMatch(text)) {
      score += 2;
    }
    if (RegExp(r'(수출|실적|고용|물가|성장률|무역|분기|매출|영업이익)', caseSensitive: false)
        .hasMatch(text)) {
      score += 2;
    }
    if (RegExp(r'(사고|화재|재난|지진|폭염|전쟁|제재|협상|충돌)', caseSensitive: false)
        .hasMatch(text)) {
      score += 2;
    }
    if (RegExp(r'\d{1,3}(?:[,.]\d+)?\s*(%|억|만|조|달러|원|명|건|개월)').hasMatch(text)) {
      score += 1;
    }
    if (const {'경제', '정치', '사회', '세계'}.contains(item.category.trim())) {
      score += 1;
    }

    return _HomeArticleEligibility(
      score: score,
      isHardExcluded: isHardExcluded,
    );
  }

  List<TrendItem> _buildHomeLiveArticles(
    DailyEditionSnapshot? edition,
    List<TrendItem> latestNews,
  ) {
    final mainStories = _buildHomeMainStories(edition, latestNews);
    final excludedIds = <int>{
      for (final story in mainStories)
        ...story.issueNewsIds.where((id) => id > 0),
      for (final story in mainStories)
        if (story.type == _HomeStoryType.article && story.articleId > 0)
          story.articleId,
    };
    final excludedTitles = mainStories
        .map((story) => _homeNormalizedTitle(story.title))
        .where((title) => title.isNotEmpty)
        .toSet();
    final filtered = _selectHomeFallbackArticles(
      latestNews,
      excludedNewsIds: excludedIds,
      excludedTitles: excludedTitles,
      limit: 5,
      prioritizeImportance: false,
    );
    if (filtered.isNotEmpty) return filtered;

    return _selectHomeFallbackArticles(
      latestNews,
      excludedNewsIds: const <int>{},
      excludedTitles: const <String>{},
      limit: 5,
      prioritizeImportance: false,
    );
  }

  String _homeNormalizedTitle(String value) {
    return value.toLowerCase().replaceAll(RegExp(r'[^0-9a-z가-힣]+'), '').trim();
  }

  Widget _buildHomeLivePreview(bool isMobile) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = dark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    return FutureBuilder<DailyEditionSnapshot>(
      future: _editionFuture,
      builder: (context, editionSnapshot) {
        return FutureBuilder<List<TrendItem>>(
          future: _latestNewsFuture,
          builder: (context, newsSnapshot) {
            final items = _buildHomeLiveArticles(
              editionSnapshot.data,
              newsSnapshot.data ?? const <TrendItem>[],
            );
            final liveList = Column(
              children: [
                ...items.take(5).toList().asMap().entries.map(
                      (entry) => _HomeLiveArticleStory(
                        index: entry.key,
                        item: entry.value,
                        foreground: foreground,
                        muted: muted,
                        border: border,
                        onTap: () => _openLandingTrendItemArticle(entry.value),
                      ),
                    ),
              ],
            );
            return Padding(
              padding: EdgeInsets.fromLTRB(
                isMobile ? 20 : 32,
                0,
                isMobile ? 20 : 32,
                28,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: isMobile ? double.infinity : 960,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '실시간 흐름',
                              style: TextStyle(
                                color: foreground,
                                fontSize: isMobile ? 21 : 24,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => _openPage(const HomeScreen()),
                            icon: const Text('전체보기'),
                            label: const Icon(Icons.arrow_forward_rounded,
                                size: 14),
                            style: TextButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 4),
                              visualDensity: VisualDensity.compact,
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      if (editionSnapshot.connectionState ==
                              ConnectionState.waiting ||
                          newsSnapshot.connectionState ==
                              ConnectionState.waiting)
                        const _HomeLoadingLine()
                      else if (editionSnapshot.hasError ||
                          newsSnapshot.hasError)
                        Text(
                          '새롭게 확인된 소식을 불러오지 못했습니다.',
                          style: TextStyle(color: muted, fontSize: 13),
                        )
                      else if (items.isEmpty)
                        Text(
                          '새롭게 확인된 소식이 없습니다.',
                          style: TextStyle(color: muted, fontSize: 13),
                        )
                      else if (isMobile)
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color:
                                dark ? const Color(0xFF111C30) : Colors.white,
                            border: Border.all(color: border),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: liveList,
                          ),
                        )
                      else
                        liveList,
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHomeMarketSummary(bool isMobile) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final foreground = dark ? Colors.white : const Color(0xFF0F172A);
    final muted = dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final border = dark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    final targets = ['코스피', '코스닥', '나스닥100 선물', 'USD/KRW']
        .map((title) => _landingQuoteByTitle(_marketQuotes, title))
        .whereType<_LandingMarketQuote>()
        .toList();

    return Padding(
      padding:
          EdgeInsets.fromLTRB(isMobile ? 20 : 32, 0, isMobile ? 20 : 32, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                  child: Text('시장 분위기',
                      style: TextStyle(
                          color: foreground,
                          fontSize: isMobile ? 21 : 24,
                          fontWeight: FontWeight.w700))),
              TextButton(
                  onPressed: () => _openPage(const MarketPage()),
                  child: const Text('시장 보기')),
            ],
          ),
          Text(
            '오늘의 주요 지수와 환율',
            style: TextStyle(color: muted, fontSize: 11),
          ),
          const SizedBox(height: 8),
          if (_marketRefreshing && targets.isEmpty)
            const _HomeLoadingLine()
          else if (_marketError != null && targets.isEmpty)
            Text('시장 정보를 불러오지 못했습니다.',
                style: TextStyle(color: muted, fontSize: 13))
          else if (targets.isEmpty)
            Text('현재 시장 정보가 없습니다.',
                style: TextStyle(color: muted, fontSize: 13))
          else
            DecoratedBox(
              decoration: BoxDecoration(
                color: dark
                    ? (isMobile ? const Color(0xFF111C30) : Colors.transparent)
                    : (isMobile ? Colors.white : Colors.transparent),
                border: Border.all(
                  color: isMobile ? border : Colors.transparent,
                ),
                borderRadius: BorderRadius.circular(isMobile ? 20 : 0),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                    isMobile ? 12 : 16, 12, isMobile ? 0 : 16, 12),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final cardWidth = isMobile
                        ? 142.0
                        : (constraints.maxWidth - 30) / targets.length;
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (var index = 0; index < targets.length; index++)
                            Padding(
                              padding: EdgeInsets.only(
                                  right: index == targets.length - 1 ? 0 : 10),
                              child: SizedBox(
                                width: cardWidth,
                                height: isMobile ? 104 : 112,
                                child: _HomeMarketValue(
                                  quote: targets[index],
                                  foreground: foreground,
                                  muted: muted,
                                  isMobile: isMobile,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _refreshHomeData() async {
    if (!mounted) return;
    setState(() {
      _editionFuture = _api.fetchDailyEdition();
      _insightFuture = _api.fetchTrendInsights();
      _timelineFuture =
          _api.fetchTrendTimeline(period: '24h', limit: 5, minScore: 45);
      _latestNewsFuture =
          _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
    });
    await _refreshMarketData(force: true);
  }

  Widget _buildHomeBottomNavigation() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg = dark ? const Color(0xFF111827) : Colors.white;
    return SafeArea(
      top: false,
      child: Container(
        color: bg,
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        child: Row(
          children: [
            _HomeNavItem(
                icon: Icons.home_rounded,
                label: '홈',
                active: true,
                onTap: () => _scrollToSection(_editionSectionKey)),
            _HomeNavItem(
                icon: Icons.bolt_rounded,
                label: '실시간',
                onTap: () => _openPage(const HomeScreen())),
            _HomeNavItem(
                icon: Icons.explore_outlined,
                label: '탐색',
                onTap: () => _openPage(const HomeScreen())),
            _HomeNavItem(
                icon: Icons.show_chart_rounded,
                label: '시장',
                onTap: () => _openPage(const MarketPage())),
            _HomeNavItem(
                icon: Icons.person_outline_rounded,
                label: 'MY',
                onTap: () => _openPage(const ContactPage())),
          ].map((item) => Expanded(child: item)).toList(),
        ),
      ),
    );
  }

  Future<void> _scrollToSection(GlobalKey key) async {
    final context = key.currentContext;
    if (context == null) return;
    await Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      alignment: 0.04,
    );
  }

  Future<void> _handleRootBackPressed(bool useDrawerNavigation) async {
    if (useDrawerNavigation &&
        (_scaffoldKey.currentState?.isDrawerOpen ?? false)) {
      Navigator.of(context).pop();
      return;
    }

    if (kIsWeb) {
      return;
    }

    final now = DateTime.now();
    final shouldExit = _lastBackPressedAt != null &&
        now.difference(_lastBackPressedAt!) <= const Duration(seconds: 2);
    _lastBackPressedAt = now;

    if (shouldExit) {
      await SystemNavigator.pop();
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('한 번 더 누르면 앱이 종료됩니다.'),
          duration: Duration(seconds: 2),
        ),
      );
  }

  Widget _buildAppBar(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final insight = snapshot.data;
        final analyzedCount = insight?.sentiment.count ?? 0;
        final sectorMood =
            insight == null ? '분석 대기' : _landingSectorMoodLabel(insight);
        final viewportWidth = MediaQuery.sizeOf(context).width;
        final topInset = MediaQuery.paddingOf(context).top;
        final compactHeader = viewportWidth < 1080;
        final showFxSummary = viewportWidth >= 1400;
        final fxTargets = [
          _landingQuoteByTitle(_marketQuotes, 'USD/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'JPY/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'EUR/KRW'),
          _landingQuoteByTitle(_marketQuotes, 'CNY/KRW'),
        ].whereType<_LandingMarketQuote>().toList();

        return Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF111827).withOpacity(0.96)
                : Colors.white.withOpacity(0.92),
            border: Border(
              bottom: BorderSide(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.20 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: ConstrainedBox(
              constraints:
                  const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                ).copyWith(
                  top: (isMobile ? 10 : 12) + topInset,
                  bottom: isMobile ? 12 : 14,
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
                        Text(
                          'Pulse',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    if (!compactHeader) ...[
                      if (showFxSummary && fxTargets.isNotEmpty) ...[
                        _LandingHeaderFxInlineBar(quotes: fxTargets),
                        const SizedBox(width: 14),
                      ],
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF172554)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E3A8A)
                                : const Color(0xFFDCE7FF),
                          ),
                        ),
                        child:
                            snapshot.connectionState == ConnectionState.waiting
                                ? Text(
                                    '분석 중',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: isDark
                                          ? Colors.blue.shade100
                                          : Colors.blue.shade700,
                                      letterSpacing: 0,
                                    ),
                                  )
                                : Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Color(0xFF2563EB),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '분석 ${analyzedCount}건 · $sectorMood',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: isDark
                                              ? Colors.white
                                              : Colors.blue.shade700,
                                          letterSpacing: 0,
                                        ),
                                      ),
                                    ],
                                  ),
                      ),
                      const SizedBox(width: 18),
                      _navItem(
                          '오늘', () => _scrollToSection(_editionSectionKey)),
                      const SizedBox(width: 24),
                      _navItem(
                        '업데이트',
                        () => _scrollToSection(_updatesSectionKey),
                      ),
                      const SizedBox(width: 24),
                      _navItem(
                        '실시간 뉴스',
                        () => _openPage(const HomeScreen()),
                      ),
                      const SizedBox(width: 24),
                      _navItem(
                        '시장',
                        () => _openPage(const MarketPage()),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        tooltip: isDark ? '라이트 모드' : '다크 모드',
                        onPressed: () =>
                            ThemeController.instance.toggleThemeMode(
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                        ),
                      ),
                    ],
                    if (compactHeader)
                      IconButton(
                        tooltip: isDark ? '라이트 모드' : '다크 모드',
                        onPressed: () =>
                            ThemeController.instance.toggleThemeMode(
                          brightness:
                              isDark ? Brightness.dark : Brightness.light,
                        ),
                        icon: Icon(
                          isDark
                              ? Icons.light_mode_rounded
                              : Icons.dark_mode_rounded,
                          color: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                        ),
                      ),
                    if (compactHeader)
                      IconButton(
                        icon: Icon(
                          Icons.menu,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        onPressed: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openPage(Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => page),
    );
  }

  Future<void> _openLandingTrendItemArticle(TrendItem item) async {
    if (item.id > 0) {
      setState(() {
        _readNewsIds.add(item.id);
      });
    }
    await _landingOpenArticle(context, item.link);
  }

  Widget _navItem(String text, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return _HoverButton(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey.shade300 : Colors.grey[700],
        ),
      ),
    );
  }

  Widget _themeChip(
    BuildContext context,
    String label,
    bool selected,
    VoidCallback onTap,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: selected
            ? (isDark ? const Color(0xFF08111F) : Colors.white)
            : (isDark ? Colors.grey.shade200 : Colors.blueGrey.shade700),
      ),
      selectedColor: isDark ? const Color(0xFF93C5FD) : const Color(0xFF2563EB),
      backgroundColor: isDark ? const Color(0xFF111827) : Colors.grey.shade100,
      side: BorderSide(
        color: selected
            ? Colors.transparent
            : (isDark ? Colors.grey.shade700 : Colors.grey.shade300),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final drawerBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    return Drawer(
      child: Container(
        color: drawerBg,
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
                    colors: isDark
                        ? [const Color(0xFF1D4ED8), const Color(0xFF0F172A)]
                        : [Colors.blue.shade600, Colors.blue.shade400],
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
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.home,
                      title: '오늘',
                      subtitle: '데일리 에디션',
                      onTap: () {
                        Navigator.pop(context);
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.newspaper_rounded,
                      title: '실시간 뉴스',
                      subtitle: '카테고리별 기사 보기',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const HomeScreen());
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.psychology_rounded,
                      title: '시장 심리',
                      subtitle: '공포탐욕지수',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const FearGreedPage());
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.show_chart_rounded,
                      title: '시장',
                      subtitle: '지수, 환율, 종목 보기',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const MarketPage());
                      },
                    ),
                    const SizedBox(height: 4),
                    _buildDrawerNavTile(
                      context: context,
                      isDark: isDark,
                      icon: Icons.support_agent_rounded,
                      title: '문의 및 운영 정보',
                      subtitle: '이메일, 웹사이트, 개인정보처리방침',
                      onTap: () {
                        Navigator.pop(context);
                        _openPage(const ContactPage());
                      },
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '테마',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ValueListenableBuilder<ThemeMode>(
                  valueListenable: ThemeController.instance.mode,
                  builder: (context, themeMode, _) {
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _themeChip(
                            context,
                            '시스템',
                            themeMode == ThemeMode.system,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.system)),
                        _themeChip(
                            context,
                            '라이트',
                            themeMode == ThemeMode.light,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.light)),
                        _themeChip(
                            context,
                            '다크',
                            themeMode == ThemeMode.dark,
                            () => ThemeController.instance
                                .setThemeMode(ThemeMode.dark)),
                      ],
                    );
                  },
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

  Widget _buildDrawerNavTile({
    required BuildContext context,
    required bool isDark,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final tileBg = isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;

    return Material(
      color: tileBg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: ListTile(
          dense: true,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF172554) : const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
              size: 20,
            ),
          ),
          title: Text(
            title,
            style: TextStyle(
              color: titleColor,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: subtitleColor,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: isDark ? Colors.grey.shade500 : Colors.blueGrey.shade300,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        ),
      ),
    );
  }

  Widget _buildPlatformHero(bool isMobile) {
    return FutureBuilder<List<dynamic>>(
      future: Future.wait<dynamic>([
        _editionFuture,
        _insightFuture,
        _timelineFuture,
        _latestNewsFuture,
      ]),
      builder: (context, snapshot) {
        final isLoading = snapshot.connectionState == ConnectionState.waiting;
        final edition = snapshot.hasData
            ? snapshot.data![0] as DailyEditionSnapshot?
            : null;
        final insight = snapshot.hasData
            ? snapshot.data![1] as TrendInsightSnapshot?
            : null;
        final timelineItems = snapshot.hasData
            ? (snapshot.data![2] as List<IssueTimelineItem>? ?? const [])
            : const <IssueTimelineItem>[];
        final latestNews = snapshot.hasData
            ? (snapshot.data![3] as List<TrendItem>? ?? const [])
            : const <TrendItem>[];

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: _LandingTrendPanel(
                isLoading: isLoading,
                edition: edition,
                insight: insight,
                timelineItems: timelineItems,
                latestNews: latestNews,
                searchController: _searchController,
                onRefresh: _refreshInsights,
                onSearch: _submitLandingSearch,
                onKeywordTap: _searchLandingKeyword,
                onRisingIssueTap: _searchLandingRisingIssue,
                onEditionHeadlineTap: _openLandingEditionIssue,
                onTimelineHeadlineTap: _openLandingTimelineItem,
                onNewsHeadlineTap: _openLandingTrendItemArticle,
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _refreshInsights() async {
    if (!mounted) return;
    if (_insightRefreshing) return;
    if (_lastInsightRefreshAt != null &&
        DateTime.now().difference(_lastInsightRefreshAt!) <
            const Duration(seconds: 8)) {
      return;
    }
    _insightRefreshing = true;
    try {
      setState(() {
        _editionFuture = _api.fetchDailyEdition();
        _insightFuture = _api.fetchTrendInsights();
        _timelineFuture =
            _api.fetchTrendTimeline(period: '24h', limit: 3, minScore: 45);
        _latestNewsFuture =
            _api.fetchTrends(limit: 12, sort: 'latest', period: '24h');
      });
      await _refreshMarketData(force: true);
      _lastInsightRefreshAt = DateTime.now();
    } finally {
      _insightRefreshing = false;
    }
  }

  void _openLandingEditionIssue(EditionIssue issue) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => IssueDetailScreen(
          issue: issue,
          articlesFuture: _resolveEditionRelatedNews(issue),
        ),
      ),
    );
  }

  Future<List<TrendItem>> _resolveEditionRelatedNews(EditionIssue issue) async {
    try {
      final issueItems = await _api.fetchIssueTimelineNews(
        issueId: issue.id,
        keyword: issue.keyword,
        newsIds: issue.newsIds,
      );
      if (issueItems.isNotEmpty) {
        return issueItems;
      }
    } catch (_) {}

    final fallbackQueries = <String>{
      issue.keyword.trim(),
      issue.title.trim(),
    }.where((value) => value.isNotEmpty).toList();

    final merged = <String, TrendItem>{};
    for (final query in fallbackQueries) {
      try {
        final items = await _api.searchNews(
          query: query,
          sort: 'latest',
          period: '24h',
          limit: 12,
        );
        for (final item in items) {
          final key = item.id > 0
              ? 'id:${item.id}'
              : [
                  item.link.trim(),
                  item.koreanTitle.trim(),
                  item.source.trim(),
                  item.published.trim(),
                ].join('|');
          merged.putIfAbsent(key, () => item);
        }
      } catch (_) {}
      if (merged.length >= 8) {
        break;
      }
    }

    return merged.values.toList();
  }

  bool _shouldRefreshMarketData() {
    if (_marketLastUpdatedAt == null) return true;
    return DateTime.now().difference(_marketLastUpdatedAt!) >=
        const Duration(minutes: 5);
  }

  Future<void> _refreshMarketDataIfNeeded() async {
    if (!_shouldRefreshMarketData()) return;
    await _refreshMarketData();
  }

  Future<void> _refreshMarketData({bool force = false}) async {
    if (_marketFetching) return;
    if (!force && !_shouldRefreshMarketData()) return;

    _marketFetching = true;
    if (mounted) {
      setState(() {
        if (_marketQuotes.isNotEmpty) {
          _marketRefreshing = true;
        } else {
          _marketRefreshing = true;
          _marketError = null;
        }
      });
    }

    try {
      final quotes = await _fetchLandingMarketQuotes();
      if (!mounted) return;
      setState(() {
        _marketQuotes
          ..clear()
          ..addAll(quotes);
        _marketError = null;
        _marketLastUpdatedAt = DateTime.now();
        _marketRefreshing = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _marketError = '업데이트 실패';
        _marketRefreshing = false;
      });
    } finally {
      _marketFetching = false;
    }
  }

  Widget _buildBreakingNewsSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final maxItems = isMobile ? 4 : 5;
    return FutureBuilder<List<IssueTimelineItem>>(
      future: _timelineFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final items = (snapshot.data ?? const <IssueTimelineItem>[])
            .take(maxItems)
            .toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
                decoration: PulseUi.sectionDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    PulseSectionHeader(
                      icon: Icons.bolt_rounded,
                      title: '어젯밤 달라진 것',
                      subtitle: '전날 저녁부터 아침까지 바뀐 핵심 이슈만 묶어 보여줍니다',
                      trailing: TextButton(
                        onPressed: () => _openPage(const HomeScreen()),
                        style: TextButton.styleFrom(
                          foregroundColor: isDark
                              ? Colors.blue.shade200
                              : Colors.blue.shade700,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          minimumSize: Size.zero,
                        ),
                        child: const Text(
                          '전체 뉴스 →',
                          style: TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '아직 오늘 아침판에 담을 변화가 충분하지 않습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (int i = 0; i < items.length; i++) ...[
                            _LandingEditionUpdateTile(
                              item: items[i],
                              onTap: () => _openLandingTimelineItem(items[i]),
                            ),
                            if (i != items.length - 1)
                              Divider(
                                height: 18,
                                thickness: 0.5,
                                color: isDark
                                    ? Colors.grey.shade800
                                    : const Color(0xFFE8EEF5),
                              ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketMoodSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final insight = snapshot.data;
        final domesticMood =
            insight == null ? '분석 대기' : _landingSectorMoodLabel(insight);
        final sentiment = insight?.sentiment;
        final sentimentLabel = sentiment == null
            ? '시황 관찰 중'
            : '${sentiment.temperature} · ${_landingSentimentLabel(sentiment.temperature)}';
        final sentimentDetail = sentiment == null
            ? '최근 뉴스 흐름을 집계 중입니다.'
            : sentiment.summary.trim().isEmpty
                ? '뉴스 감정과 시장 흐름을 함께 보고 있습니다.'
                : sentiment.summary.trim();

        final nasdaqQuote = _landingQuoteByTitle(_marketQuotes, '나스닥100 선물');
        final fxQuote = _landingQuoteByTitle(_marketQuotes, 'USD/KRW');
        final usMood = nasdaqQuote == null
            ? '관찰 중'
            : nasdaqQuote.percentChange > 0
                ? '긍정'
                : nasdaqQuote.percentChange < 0
                    ? '부정'
                    : '중립';
        final fxMood = fxQuote == null
            ? '관찰 중'
            : fxQuote.percentChange > 0
                ? '원화 약세'
                : fxQuote.percentChange < 0
                    ? '원화 강세'
                    : '중립';
        final updatedAt = _marketLastUpdatedAt;
        final updatedLabel = updatedAt == null
            ? '업데이트 대기'
            : '마지막 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(9),
                          ),
                          child: Icon(
                            Icons.insights_rounded,
                            size: 16,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘 체크할 흐름',
                                style: TextStyle(
                                  fontSize: 13.8,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                updatedLabel,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 1.6,
                                color: isDark
                                    ? Colors.blue.shade200
                                    : Colors.blue.shade600,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    if (insight == null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF0F172A)
                              : const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF1F2937)
                                : const Color(0xFFE8EEF5),
                          ),
                        ),
                        child: Text(
                          '시장 분위기를 분석하는 중입니다.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.blueGrey.shade500,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      )
                    else
                      _LandingMarketMoodRow(
                        data: insight,
                        marketQuotes: _marketQuotes,
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildMarketOverviewSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targets = [
      _landingQuoteByTitle(_marketQuotes, '코스피'),
      _landingQuoteByTitle(_marketQuotes, '코스닥'),
      _landingQuoteByTitle(_marketQuotes, '나스닥100 선물'),
      _landingQuoteByTitle(_marketQuotes, '비트코인'),
    ].whereType<_LandingMarketQuote>().toList();
    final updatedAt = _landingLatestUpdatedAt(targets) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '최근 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.show_chart_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '시장 한눈에',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '전체 차트 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '시장 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final width = constraints.maxWidth;
                      final crossAxisCount = width < 560
                          ? 2
                          : width < 720
                              ? 2
                              : width < 1040
                                  ? 3
                                  : 4;
                      final aspectRatio = width < 560
                          ? 1.18
                          : width < 720
                              ? 1.32
                              : width < 1040
                                  ? 1.55
                                  : 1.78;
                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: aspectRatio,
                        children: targets
                            .map((quote) =>
                                _LandingMarketSummaryCard(quote: quote))
                            .toList(),
                      );
                    },
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExchangeRateSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final targets = [
      _landingQuoteByTitle(_marketQuotes, 'USD/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'JPY/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'EUR/KRW'),
      _landingQuoteByTitle(_marketQuotes, 'CNY/KRW'),
    ].whereType<_LandingMarketQuote>().toList();
    final updatedAt = _landingLatestUpdatedAt(targets) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '시세 기준 ${_landingFormatUpdatedAt(updatedAt)}';
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.currency_exchange_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '환율 체크',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '매크로 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (targets.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '환율 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < targets.length; i++) ...[
                        _LandingExchangeRateRow(quote: targets[i]),
                        if (i != targets.length - 1)
                          Divider(
                            height: 10,
                            thickness: 0.5,
                            color: isDark
                                ? Colors.grey.shade800
                                : const Color(0xFFE8EEF5),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPopularStocksSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final equityOrder = <String>[
      '삼성전자',
      'SK하이닉스',
      'SK스퀘어',
      '삼성전기',
      '현대차',
    ];
    final items = equityOrder
        .map((title) => _landingQuoteByTitle(_marketQuotes, title))
        .toList();
    final availableItems = items.whereType<_LandingMarketQuote>().toList();
    final updatedAt =
        _landingLatestUpdatedAt(availableItems) ?? _marketLastUpdatedAt;
    final updatedLabel = updatedAt == null
        ? '시세 확인 중'
        : '최근 업데이트 ${_landingFormatUpdatedAt(updatedAt)}';
    final delayLabel = _landingDelaySummary(updatedAt);
    final loading = _marketRefreshing && _marketQuotes.isEmpty;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF111827) : const Color(0xFFFAFBFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: Icon(
                        Icons.trending_up_rounded,
                        size: 16,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '대표 종목 흐름',
                            style: TextStyle(
                              fontSize: 13.8,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            updatedLabel,
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark
                                  ? Colors.grey.shade300
                                  : Colors.blueGrey.shade500,
                            ),
                          ),
                          if (delayLabel != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              delayLabel,
                              style: TextStyle(
                                fontSize: 10.3,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.blueGrey.shade500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (_marketRefreshing && _marketQuotes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.6,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade600,
                          ),
                        ),
                      ),
                    TextButton(
                      onPressed: () => _openPage(const MarketPage()),
                      style: TextButton.styleFrom(
                        foregroundColor: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 3),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        minimumSize: Size.zero,
                      ),
                      child: const Text(
                        '전체 차트 →',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '대표 종목의 최근 변동 흐름만 간단히 정리합니다.',
                  style: TextStyle(
                    fontSize: 11.2,
                    color: isDark
                        ? Colors.grey.shade300
                        : Colors.blueGrey.shade600,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 10),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      _marketError ?? '종목 데이터를 불러오지 못했습니다.',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade600,
                        fontSize: 11,
                      ),
                    ),
                  )
                else
                  Column(
                    children: [
                      for (int i = 0; i < equityOrder.length; i++) ...[
                        items[i] != null
                            ? _LandingMarketRankRow(
                                rank: i + 1,
                                quote: items[i]!,
                              )
                            : _LandingMarketRankPlaceholderRow(
                                rank: i + 1,
                                title: equityOrder[i],
                              ),
                        if (i != equityOrder.length - 1)
                          Divider(
                            height: 10,
                            thickness: 0.5,
                            color: isDark
                                ? Colors.grey.shade800
                                : const Color(0xFFE8EEF5),
                          ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarketDominanceSection(bool isMobile) {
    return FutureBuilder<TrendInsightSnapshot>(
      future: _insightFuture,
      builder: (context, snapshot) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final insight = snapshot.data;
        final sectors = _landingSectorDominanceRows(insight)
            .where((item) => item.ratio > 0)
            .take(isMobile ? 4 : 5)
            .toList();

        return Center(
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.donut_large_rounded,
                            size: 17,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '오늘 많이 언급된 섹터',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '오늘 아침판에서 비중이 높았던 섹터만 간단히 보여줍니다.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade500,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    if (insight == null || sectors.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          '유의미한 섹터 비중 데이터를 준비 중입니다.',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: sectors.map((sector) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _LandingDominanceRow(
                              label: sector.label,
                              valueText: sector.valueText,
                              changeText: sector.changeText,
                              ratio: sector.ratio,
                            ),
                          );
                        }).toList(),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<List<_LandingMarketQuote>> _fetchLandingMarketQuotes() async {
    const configs = <_LandingMarketConfig>[
      _LandingMarketConfig(
        symbol: '^KS11',
        tvSymbol: 'KRX:KOSPI',
        title: '코스피',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: '^KQ11',
        tvSymbol: 'KRX:KOSDAQ',
        title: '코스닥',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: 'NQ=F',
        tvSymbol: 'CME_MINI:NQ1!',
        title: '나스닥100 선물',
        prefix: '',
        group: 'index',
      ),
      _LandingMarketConfig(
        symbol: 'BTC-USD',
        tvSymbol: 'COINBASE:BTCUSD',
        title: '비트코인',
        prefix: '\$',
        group: 'crypto',
      ),
      _LandingMarketConfig(
        symbol: 'KRW=X',
        tvSymbol: 'FX_IDC:USDKRW',
        title: 'USD/KRW',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'EURUSD=X',
        tvSymbol: 'FX:EURUSD',
        title: 'EUR/USD',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'JPY=X',
        tvSymbol: 'FX:USDJPY',
        title: 'USD/JPY',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: 'CNY=X',
        tvSymbol: 'FX:USDCNY',
        title: 'USD/CNY',
        prefix: '',
        group: 'fx',
      ),
      _LandingMarketConfig(
        symbol: '005930.KS',
        tvSymbol: 'KRX:005930',
        title: '삼성전자',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '000660.KS',
        tvSymbol: 'KRX:000660',
        title: 'SK하이닉스',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '402340.KS',
        tvSymbol: 'KRX:402340',
        title: 'SK스퀘어',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '009150.KS',
        tvSymbol: 'KRX:009150',
        title: '삼성전기',
        prefix: '',
        group: 'equity',
      ),
      _LandingMarketConfig(
        symbol: '005380.KS',
        tvSymbol: 'KRX:005380',
        title: '현대차',
        prefix: '',
        group: 'equity',
      ),
    ];

    final symbolsQuery = configs.map((item) => item.symbol).join(',');
    final uri = Uri.parse(
      'https://news-summarizer.bum2432.workers.dev/api/market-data?symbols=$symbolsQuery&interval=5m&range=1d',
    );
    final response = await http.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Market data request failed: ${response.statusCode}');
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['success'] != true) {
      throw Exception('Market data response was not successful');
    }

    final results = (decoded['data'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final bySymbol = {
      for (final item in results) item['symbol']?.toString() ?? '': item,
    };

    final quotes = <_LandingMarketQuote>[];

    _LandingMarketQuote? buildBaseQuote(
      _LandingMarketConfig config, {
      String? titleOverride,
    }) {
      final raw = bySymbol[config.symbol];
      final previous = _marketQuotes.cast<_LandingMarketQuote?>().firstWhere(
            (item) =>
                item != null &&
                (item.symbol == config.symbol ||
                    item.title == (titleOverride ?? config.title)),
            orElse: () => null,
          );
      if (raw == null || raw['error'] != null) return previous;
      final currentPrice = (raw['currentPrice'] as num?)?.toDouble();
      final percentChange = (raw['percentChange'] as num?)?.toDouble();
      if (currentPrice == null || percentChange == null) return previous;
      final priceUpdatedAt = _landingParseTimestamp(
            raw['priceUpdatedAt']?.toString() ?? '',
          ) ??
          previous?.priceUpdatedAt;
      final chartData = (raw['chartData'] as List<dynamic>?)
              ?.whereType<num>()
              .map((value) => value.toDouble())
              .toList() ??
          previous?.chartData ??
          const <double>[];

      return _LandingMarketQuote(
        symbol: config.symbol,
        tvSymbol: config.tvSymbol,
        title: titleOverride ?? config.title,
        prefix: config.prefix,
        group: config.group,
        currentPrice: currentPrice,
        percentChange: percentChange,
        priceUpdatedAt: priceUpdatedAt,
        chartData: chartData,
      );
    }

    final baseQuotes = <String, _LandingMarketQuote>{};
    for (final config in configs) {
      if (config.group != 'fx') {
        final quote = buildBaseQuote(config);
        if (quote != null) {
          quotes.add(quote);
        }
      } else {
        final quote = buildBaseQuote(config);
        if (quote != null) {
          baseQuotes[config.symbol] = quote;
        }
      }
    }

    final usdKrw = baseQuotes['KRW=X'];
    final eurUsd = baseQuotes['EURUSD=X'];
    final usdJpy = baseQuotes['JPY=X'];
    final usdCny = baseQuotes['CNY=X'];

    _LandingMarketQuote? derivedFxQuote({
      required String title,
      required String symbol,
      required double currentPrice,
      required double percentChange,
      required DateTime? updatedAt,
      List<double> chartData = const <double>[],
    }) {
      return _LandingMarketQuote(
        symbol: symbol,
        tvSymbol: symbol,
        title: title,
        prefix: '',
        group: 'fx',
        currentPrice: currentPrice,
        percentChange: percentChange,
        priceUpdatedAt: updatedAt,
        chartData: chartData,
      );
    }

    if (usdKrw != null) {
      quotes.add(derivedFxQuote(
        title: 'USD/KRW',
        symbol: 'KRW=X',
        currentPrice: usdKrw.currentPrice,
        percentChange: usdKrw.percentChange,
        updatedAt: usdKrw.priceUpdatedAt,
        chartData: usdKrw.chartData,
      )!);
    }

    if (usdKrw != null && usdJpy != null && usdJpy.currentPrice > 0) {
      final currentPrice = usdKrw.currentPrice / usdJpy.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) /
                  (1 + usdJpy.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'JPY/KRW',
        symbol: 'JPY=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          usdJpy.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    if (usdKrw != null && eurUsd != null) {
      final currentPrice = usdKrw.currentPrice * eurUsd.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) *
                  (1 + eurUsd.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'EUR/KRW',
        symbol: 'EURUSD=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          eurUsd.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    if (usdKrw != null && usdCny != null && usdCny.currentPrice > 0) {
      final currentPrice = usdKrw.currentPrice / usdCny.currentPrice;
      final percentChange = (((1 + usdKrw.percentChange / 100) /
                  (1 + usdCny.percentChange / 100)) -
              1) *
          100;
      quotes.add(derivedFxQuote(
        title: 'CNY/KRW',
        symbol: 'CNY=X',
        currentPrice: currentPrice,
        percentChange: percentChange,
        updatedAt: [
          usdKrw.priceUpdatedAt,
          usdCny.priceUpdatedAt
        ].whereType<DateTime>().fold<DateTime?>(null,
            (prev, item) => prev == null || item.isAfter(prev) ? item : prev),
      )!);
    }

    return quotes;
  }

  _LandingMarketQuote? _landingQuoteByTitle(
    List<_LandingMarketQuote> quotes,
    String title,
  ) {
    for (final quote in quotes) {
      if (quote.title == title) return quote;
    }
    return null;
  }

  List<_LandingSectorDominanceRowData> _landingSectorDominanceRows(
    TrendInsightSnapshot? insight,
  ) {
    if (insight == null) return const [];

    final rows = <_LandingSectorDominanceRowData>[
      _LandingSectorDominanceRowData(
        '반도체',
        [
          '반도체',
          'HBM',
          'D램',
          '낸드',
          '파운드리',
          '팹리스',
          '메모리',
          '칩',
          '삼성전자',
          'SK하이닉스',
          '엔비디아'
        ],
      ),
      _LandingSectorDominanceRowData(
        '2차전지',
        ['2차전지', '배터리', '전기차', '리튬', '양극재', '음극재', '전해질', '셀'],
      ),
      _LandingSectorDominanceRowData(
        '바이오/제약',
        ['바이오', '제약', '신약', '임상', '헬스케어', 'FDA', '의약'],
      ),
      _LandingSectorDominanceRowData(
        '방산',
        ['방산', 'K방산', '무기', '군수', '전차', '미사일', '드론'],
      ),
      _LandingSectorDominanceRowData(
        '시장 거래대금',
        ['거래대금', '증시', '코스피', '코스닥', '환율', '금리', '채권', '달러', '연준', 'FOMC'],
      ),
    ];

    final scores = rows.map((row) {
      double total = 0;

      for (final keyword in insight.keywords) {
        if (row.matchesText(keyword.keyword) ||
            row.matchesText(keyword.representativeTitle) ||
            row.matchesText(keyword.category)) {
          total += keyword.newsCount * 1.4;
          total += (keyword.sentimentTemperature ?? 50) >= 70
              ? 0.5
              : (keyword.sentimentTemperature ?? 50) <= 30
                  ? 0.25
                  : 0.1;
        }
      }

      for (final issue in insight.risingIssues) {
        if (row.matchesText(issue.keyword) ||
            row.matchesText(issue.representativeTitle) ||
            row.matchesText(issue.category)) {
          total += issue.currentCount * 1.15;
          total +=
              issue.growthRate > 0 ? (issue.growthRate.clamp(0, 200) / 80) : 0;
          total += issue.isNew ? 0.4 : 0.1;
        }
      }

      if (row.label == '시장 거래대금') {
        final marketBias = insight.keywords.where((item) {
          final text =
              '${item.keyword} ${item.representativeTitle} ${item.category}'
                  .toLowerCase();
          return text.contains('코스피') ||
              text.contains('코스닥') ||
              text.contains('증시') ||
              text.contains('금리') ||
              text.contains('환율') ||
              text.contains('달러') ||
              text.contains('채권');
        }).fold<double>(0, (sum, item) => sum + item.newsCount * 0.9);
        total += marketBias;
      }

      return MapEntry(row, total);
    }).toList();

    final totalScore =
        scores.fold<double>(0, (sum, entry) => sum + entry.value);
    if (totalScore <= 0) return const [];

    final output = scores.map((entry) {
      final ratio = entry.value / totalScore;
      return _LandingSectorDominanceRowData(
        entry.key.label,
        entry.key.keywords,
        ratio: ratio,
        valueText: '${(ratio * 100).round()}%',
        changeText: ratio >= 0.25 ? '상위' : '관심',
      );
    }).toList()
      ..sort((a, b) => b.ratio.compareTo(a.ratio));

    return output;
  }

  Widget _buildIssueTimelineSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<IssueTimelineItem>>(
      future: _timelineFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final items = snapshot.data ?? const <IssueTimelineItem>[];

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.24)
                          : const Color(0xFF0F172A).withOpacity(0.04),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.timeline_rounded,
                            size: 17,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.blue.shade700,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '실시간 이슈 타임라인',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                          ),
                        ),
                        Text(
                          '중요 이슈만',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '시간순으로 묶인 핵심 이슈만 보여줍니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else if (items.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Text(
                          '아직 타임라인으로 묶을 만큼 충분한 이슈가 없습니다.',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.grey.shade600,
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final item in items)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: _LandingTimelineItemTile(
                                item: item,
                                onTap: () => _openLandingTimelineItem(item),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _openLandingTimelineItem(IssueTimelineItem item) {
    _showLandingRelatedArticlesSheet(
      title: '${item.keyword} 관련 이슈',
      future: _resolveTimelineRelatedNews(item),
    );
  }

  void _openLandingNewsCluster(NewsCluster cluster) {
    _showLandingRelatedArticlesSheet(
      title: cluster.articleCount > 1
          ? '${cluster.representative.koreanTitle} 외 ${cluster.articleCount - 1}건'
          : cluster.representative.koreanTitle,
      future: _resolveClusterRelatedNews(cluster),
    );
  }

  Future<List<TrendItem>> _resolveTimelineRelatedNews(
      IssueTimelineItem item) async {
    try {
      return await _api.fetchIssueTimelineNews(
        issueId: item.id,
        keyword: item.keyword,
        newsIds: item.newsIds,
      );
    } catch (_) {}

    return const <TrendItem>[];
  }

  Future<List<TrendItem>> _resolveClusterRelatedNews(
      NewsCluster cluster) async {
    final merged = <String, TrendItem>{};
    for (final item in cluster.items) {
      final key = item.id > 0
          ? 'id:${item.id}'
          : [
              item.link.trim(),
              item.koreanTitle.trim(),
              item.source.trim(),
              item.published.trim(),
            ].join('|');
      merged.putIfAbsent(key, () => item);
    }
    return merged.values.toList();
  }

  void _showLandingIssueDetailSheet({
    required EditionIssue issue,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LandingIssueDetailSheet(issue: issue, future: future),
    );
  }

  void _showLandingRelatedArticlesSheet({
    required String title,
    required Future<List<TrendItem>> future,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
        final surface = isDark ? const Color(0xFF111827) : Colors.white;
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade200 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.82,
          minChildSize: 0.45,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: border),
                  left: BorderSide(color: border),
                  right: BorderSide(color: border),
                ),
              ),
              child: FutureBuilder<List<TrendItem>>(
                future: future,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TrendItem>[];
                  final orderedItems = items.toList()
                    ..sort((a, b) {
                      final aDate = _landingTrendDate(a) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      final bDate = _landingTrendDate(b) ??
                          DateTime.fromMillisecondsSinceEpoch(0);
                      return bDate.compareTo(aDate);
                    });
                  final countLabel =
                      snapshot.connectionState == ConnectionState.waiting
                          ? '불러오는 중'
                          : '${orderedItems.length}건';

                  return DefaultTextStyle.merge(
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF172554)
                                            : const Color(0xFFEEF4FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        countLabel,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.blue.shade100
                                              : const Color(0xFF2563EB),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: '닫기',
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : primaryText,
                                    height: 1.28,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '관련 기사들을 최신순으로 모아봤습니다.',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (snapshot.connectionState == ConnectionState.waiting)
                          const SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                          )
                        else if (snapshot.hasError)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.error_outline_rounded,
                              title: '관련 뉴스를 불러오지 못했습니다.',
                              subtitle: '잠시 후 다시 시도해 주세요.',
                            ),
                          )
                        else if (orderedItems.isEmpty)
                          SliverFillRemaining(
                            hasScrollBody: false,
                            child: _LandingSearchStateMessage(
                              icon: Icons.search_off_rounded,
                              title: '관련 뉴스가 없습니다.',
                              subtitle: '다른 키워드로 다시 확인해 보세요.',
                            ),
                          )
                        else
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                            sliver: SliverList.separated(
                              itemCount: orderedItems.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                return _LandingSearchResultTile(
                                  item: orderedItems[index],
                                );
                              },
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
      },
    );
  }

  Widget _buildLatestNewsSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FutureBuilder<List<TrendItem>>(
      future: _latestNewsFuture,
      builder: (context, snapshot) {
        final loading = snapshot.connectionState == ConnectionState.waiting;
        final rawItems = (snapshot.data ?? const <TrendItem>[]).toList()
          ..sort((a, b) {
            final aDate =
                _landingTrendDate(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bDate =
                _landingTrendDate(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bDate.compareTo(aDate);
          });
        final clusters = groupSimilarNews(rawItems, maxClusters: 6);

        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1020),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF111827)
                      : const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF5),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isDark
                          ? Colors.black.withOpacity(0.24)
                          : const Color(0xFF0F172A).withOpacity(0.05),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '최신 뉴스',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '지금 들어온 기사부터 바로 확인합니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (loading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 36),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (clusters.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '아직 불러온 뉴스가 없습니다.',
                          style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey[600]),
                        ),
                      )
                    else
                      Column(
                        children: [
                          for (final cluster in clusters)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _LandingGroupedNewsTile(
                                cluster: cluster,
                                onTap: () => _openLandingNewsCluster(cluster),
                              ),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  DateTime? _landingTrendDate(TrendItem trend) {
    return _landingParseDate(trend.published) ??
        _landingParseDate(trend.createdAt);
  }

  DateTime? _landingParseDate(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return null;

    return DateTime.tryParse(raw) ??
        DateTime.tryParse(raw.replaceFirst(' ', 'T')) ??
        DateTime.tryParse(raw.replaceAll('/', '-').replaceFirst(' ', 'T'));
  }

  Widget _smallNavCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.12);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey.shade600;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF172554)
                    : Colors.blue.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon,
                  color: isDark ? Colors.blue.shade200 : Colors.blue.shade700),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: secondaryText),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
        final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
        final surface = isDark ? const Color(0xFF111827) : Colors.white;
        final border =
            isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
        final primaryText = isDark ? Colors.white : const Color(0xFF0F172A);
        final secondaryText =
            isDark ? Colors.grey.shade200 : Colors.blueGrey.shade500;

        return DraggableScrollableSheet(
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: surface,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: border),
                  left: BorderSide(color: border),
                  right: BorderSide(color: border),
                ),
              ),
              child: FutureBuilder<List<TrendItem>>(
                future: future,
                builder: (context, snapshot) {
                  final items = snapshot.data ?? const <TrendItem>[];
                  final clusters = groupSimilarNews(items, maxClusters: 20);
                  final countLabel =
                      snapshot.connectionState == ConnectionState.waiting
                          ? '불러오는 중'
                          : '${clusters.length}개 묶음';

                  return DefaultTextStyle.merge(
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                    ),
                    child: CustomScrollView(
                      controller: scrollController,
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(18, 12, 18, 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Container(
                                    width: 42,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: isDark
                                          ? Colors.grey.shade700
                                          : Colors.grey.shade300,
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(0xFF172554)
                                            : const Color(0xFFEEF4FF),
                                        borderRadius:
                                            BorderRadius.circular(999),
                                      ),
                                      child: Text(
                                        countLabel,
                                        style: TextStyle(
                                          color: isDark
                                              ? Colors.blue.shade100
                                              : const Color(0xFF2563EB),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    IconButton(
                                      tooltip: '닫기',
                                      onPressed: () =>
                                          Navigator.of(context).pop(),
                                      icon: Icon(
                                        Icons.close_rounded,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: 19,
                                    fontWeight: FontWeight.w900,
                                    color: isDark ? Colors.white : primaryText,
                                    height: 1.28,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '관련 뉴스 묶음을 빠르게 훑어볼 수 있도록 정리했습니다.',
                                  style: TextStyle(
                                    color: secondaryText,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
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
                              itemCount: clusters.length,
                              separatorBuilder: (_, __) =>
                                  const SizedBox(height: 10),
                              itemBuilder: (context, index) {
                                final cluster = clusters[index];
                                if (cluster.articleCount > 1) {
                                  return _LandingGroupedNewsTile(
                                    cluster: cluster,
                                    onTap: () =>
                                        _openLandingNewsCluster(cluster),
                                  );
                                }
                                return _LandingSearchResultTile(
                                  item: cluster.representative,
                                );
                              },
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
      },
    );
  }

  Widget _buildHeroSection(bool isMobile) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade300 : Colors.grey[600];
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
              color: primaryText,
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
              color: secondaryText,
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
                  Navigator.of(context).push(
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.1);
    final iconBg = isDark ? const Color(0xFF0F172A) : Colors.grey[50];
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.24)
                    : Colors.black.withOpacity(0.04),
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
                color: iconBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 24, color: primaryText),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: primaryText),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: secondaryText, height: 1.4),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 24 : 80),
      child: Column(
        children: [
          Text(
            '다양한 분야의 뉴스',
            style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: primaryText,
                letterSpacing: -0.5),
          ),
          const SizedBox(height: 12),
          Text(
            '관심 있는 카테고리를 골라 필요한 뉴스만 빠르게 확인해보세요.',
            style: TextStyle(fontSize: 16, color: secondaryText),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border =
        isDark ? const Color(0xFF1F2937) : Colors.grey.withOpacity(0.1);
    final primaryText = isDark ? Colors.white : Colors.black87;
    final secondaryText = isDark ? Colors.grey.shade400 : Colors.grey[600];
    return _HoverCard(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
                color: isDark
                    ? Colors.black.withOpacity(0.24)
                    : Colors.black.withOpacity(0.04),
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
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: primaryText),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: secondaryText, height: 1.4),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isDesktop = MediaQuery.sizeOf(context).width >= 768;
    final topBorder = isDark ? Colors.grey.shade800 : Colors.grey[200]!;
    return Container(
      decoration: BoxDecoration(
          border: Border(top: BorderSide(color: topBorder, width: 1))),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: PulseUi.maxContentWidth),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: isDesktop
                ? Row(
                    children: [
                      const _LandingFooterBrandBlock(),
                      const Spacer(),
                      TextButton(
                        onPressed: () => _openPage(const HomeScreen()),
                        child: const Text('실시간 뉴스'),
                      ),
                      TextButton(
                        onPressed: () => _openPage(const MarketPage()),
                        child: const Text('증시'),
                      ),
                      TextButton(
                        onPressed: () => _openPage(const ContactPage()),
                        child: const Text('개인정보처리방침'),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '© 2026 Pulse',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  )
                : Column(
                    children: [
                      const _LandingFooterBrandBlock(),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          TextButton(
                            onPressed: () => _openPage(const HomeScreen()),
                            child: const Text('실시간 뉴스'),
                          ),
                          TextButton(
                            onPressed: () => _openPage(const MarketPage()),
                            child: const Text('증시'),
                          ),
                          TextButton(
                            onPressed: () => _openPage(const ContactPage()),
                            child: const Text('개인정보처리방침'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '© 2026 Pulse',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade500,
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isPhone = viewportWidth < 600;
    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final briefing = _landingBriefing(data);
    final keywords = data.keywords.take(8).toList();
    final rising = data.risingIssues.take(3).toList();
    final titleText = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final chipBg = isDark ? const Color(0xFF0F172A) : const Color(0xFFEEF4FF);
    final chipBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFDCE7FF);
    final chipText = isDark ? Colors.blue.shade200 : Colors.blue.shade700;
    final inputFill =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final inputBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final ctaBg = isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFF101827),
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
                  color: chipBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: chipBorder),
                ),
                child:
                    Icon(Icons.auto_awesome_rounded, color: chipText, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'AI Briefing',
                  style: TextStyle(
                    color: titleText,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: Icon(Icons.refresh_rounded, color: mutedText, size: 19),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            briefing,
            style: TextStyle(
              color: bodyText,
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
              color: mutedText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: searchController,
            onSubmitted: (_) => onStart(),
            style: TextStyle(color: titleText),
            decoration: InputDecoration(
              hintText: 'AI, 환율, 비트코인 검색',
              hintStyle: TextStyle(color: mutedText),
              prefixIcon: Icon(Icons.search_rounded, color: mutedText),
              suffixIcon: IconButton(
                tooltip: '검색',
                onPressed: onStart,
                icon: Icon(Icons.arrow_forward_rounded, color: titleText),
              ),
              filled: true,
              fillColor: chipBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: chipBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: chipBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                    color: isDark
                        ? Colors.blue.shade200
                        : const Color(0xFF2563EB)),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '실시간 인기 키워드',
            style: TextStyle(
              color: titleText,
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
                  backgroundColor: chipBg.withOpacity(isDark ? 0.9 : 1.0),
                  side: BorderSide(color: chipBorder),
                  labelStyle: TextStyle(
                    color: chipText,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
            ],
          ),
          if (rising.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              '급상승 이슈',
              style: TextStyle(
                color: titleText,
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
                backgroundColor: ctaBg,
                foregroundColor: Colors.white,
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
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    return Container(
      height: 420,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.20)
                : Colors.black.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _skeletonBar(isDark: isDark, width: 150, height: 24),
          const SizedBox(height: 18),
          _skeletonBar(isDark: isDark, width: double.infinity, height: 16),
          const SizedBox(height: 8),
          _skeletonBar(isDark: isDark, width: 280, height: 16),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                  child: _skeletonBar(
                      isDark: isDark, width: double.infinity, height: 96)),
              const SizedBox(width: 10),
              Expanded(
                  child: _skeletonBar(
                      isDark: isDark, width: double.infinity, height: 96)),
            ],
          ),
          const SizedBox(height: 18),
          _skeletonBar(isDark: isDark, width: double.infinity, height: 48),
          const SizedBox(height: 18),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (int i = 0; i < 6; i++)
                _skeletonBar(isDark: isDark, width: 86, height: 34),
            ],
          ),
        ],
      ),
    );
  }

  static Widget _skeletonBar({
    required bool isDark,
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFEAF1FF),
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

class _LandingTrendPanel extends StatelessWidget {
  final bool isLoading;
  final DailyEditionSnapshot? edition;
  final TrendInsightSnapshot? insight;
  final List<IssueTimelineItem> timelineItems;
  final List<TrendItem> latestNews;
  final TextEditingController searchController;
  final VoidCallback onRefresh;
  final VoidCallback onSearch;
  final ValueChanged<TrendKeyword> onKeywordTap;
  final ValueChanged<RisingIssue> onRisingIssueTap;
  final ValueChanged<EditionIssue> onEditionHeadlineTap;
  final ValueChanged<IssueTimelineItem> onTimelineHeadlineTap;
  final ValueChanged<TrendItem> onNewsHeadlineTap;

  const _LandingTrendPanel({
    required this.isLoading,
    required this.edition,
    required this.insight,
    required this.timelineItems,
    required this.latestNews,
    required this.searchController,
    required this.onRefresh,
    required this.onSearch,
    required this.onKeywordTap,
    required this.onRisingIssueTap,
    required this.onEditionHeadlineTap,
    required this.onTimelineHeadlineTap,
    required this.onNewsHeadlineTap,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading || insight == null) {
      return const _LandingInsightSkeleton();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final isPhone = viewportWidth < 600;
    final data = insight!;
    final score = _landingTrendScore(data);
    final delta = _landingTrendDelta(data);
    final timeLabel = _landingTimeLabel();
    final keywords = data.keywords
        .where((item) => _isLandingKeywordUseful(item.keyword))
        .take(5)
        .toList();
    final headlineItems = edition != null && edition!.topIssues.isNotEmpty
        ? edition!.topIssues
            .take(6)
            .map(
              (issue) => _LandingEditionHeadlineData(
                title: issue.title,
                summary: issue.summary,
                category: issue.category,
                meta: issue.selectionReason.isNotEmpty
                    ? issue.selectionReason
                    : '기사 ${issue.articleCount}건 · 출처 ${issue.sourceCount}곳',
                editionIssue: issue,
              ),
            )
            .toList()
        : _landingEditionHeadlineItems(timelineItems, latestNews)
            .take(6)
            .toList();
    final leadHeadline = headlineItems.isNotEmpty ? headlineItems.first : null;
    final coreIssue =
        leadHeadline?.title ?? _landingEditionLeadLine(data, timelineItems);
    final briefSummary =
        leadHeadline?.summary ?? _landingEditionSummary(data, timelineItems);
    final editionNotes = _landingEditionNotes(data, leadHeadline);
    final issueCount = headlineItems.length +
        data.risingIssues.take(3).length +
        (keywords.isNotEmpty ? 1 : 0);
    final readingMinutes = (4 + (issueCount * 0.7)).round().clamp(4, 8);
    final progressLabel = headlineItems.isEmpty
        ? '오늘 아침판 준비 중'
        : '핵심 이슈 ${headlineItems.length}건 먼저 확인';
    final titleText = Theme.of(context).colorScheme.onSurface;
    final bodyText = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade800;
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final ctaBg = isDark ? Colors.blue.shade600 : const Color(0xFF2563EB);
    final softSurface =
        isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final softBorder =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);

    Widget briefingHeader() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.auto_awesome_rounded,
                        size: 18,
                        color: isDark
                            ? Colors.blue.shade200
                            : Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '오늘의 Pulse',
                        style: TextStyle(
                          color: titleText,
                          fontSize: isPhone ? 17 : 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: '새로고침',
                onPressed: onRefresh,
                icon: Icon(
                  Icons.refresh_rounded,
                  size: 19,
                  color: mutedText,
                ),
                splashRadius: 18,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _LandingHeaderMetaPill(
                icon: Icons.calendar_today_rounded,
                label: _landingEditionDateLabel(),
              ),
              _LandingHeaderMetaPill(
                icon: Icons.schedule_rounded,
                label: '아침 $timeLabel 발행',
              ),
              _LandingHeaderMetaPill(
                icon: Icons.library_books_rounded,
                label: '핵심 변화 ${issueCount.clamp(3, 12)}건',
              ),
              _LandingHeaderMetaPill(
                icon: Icons.timelapse_rounded,
                label: '읽기 약 ${readingMinutes}분',
              ),
            ],
          ),
        ],
      );
    }

    Widget trendScoreBlock() {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: softSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '트렌드 점수',
                  style: TextStyle(
                    color: titleText,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (delta >= 0
                            ? const Color(0xFF2563EB)
                            : Colors.blueGrey.shade500)
                        .withOpacity(isDark ? 0.18 : 0.10),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    delta >= 0 ? '+$delta' : '$delta',
                    style: TextStyle(
                      color: delta >= 0
                          ? (isDark ? Colors.blue.shade200 : ctaBg)
                          : mutedText,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '$score점',
              style: TextStyle(
                color: titleText,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: TweenAnimationBuilder<double>(
                tween: Tween<double>(begin: 0, end: score / 100),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return LinearProgressIndicator(
                    value: value,
                    minHeight: 6,
                    backgroundColor: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFE8EEF7),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      Color(0xFF2563EB),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              progressLabel,
              style: TextStyle(
                color: mutedText,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    Widget summaryRail() {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: softSurface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: softBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '지금 주목할 이슈',
              style: TextStyle(
                color: titleText,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            if (headlineItems.isEmpty)
              Text(
                '핵심 헤드라인을 준비 중입니다.',
                style: TextStyle(
                  color: mutedText,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              _LandingEditionHeadlineCarousel(
                items: headlineItems,
                onTap: (entry) {
                  if (entry.editionIssue != null) {
                    onEditionHeadlineTap(entry.editionIssue!);
                    return;
                  }
                  if (entry.timelineItem != null) {
                    onTimelineHeadlineTap(entry.timelineItem!);
                    return;
                  }
                  if (entry.newsItem != null) {
                    onNewsHeadlineTap(entry.newsItem!);
                  }
                },
              ),
          ],
        ),
      );
    }

    Widget keywordsBlock() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '핵심 키워드',
            style: TextStyle(
              color: titleText,
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final keyword in keywords)
                _LandingEditionKeywordChip(
                  keyword: _cleanLandingKeyword(keyword.keyword),
                  emphasis: keyword.newsCount >=
                      (keywords.isNotEmpty ? keywords.first.newsCount : 0),
                  onTap: () => onKeywordTap(keyword),
                ),
            ],
          ),
        ],
      );
    }

    Widget leftColumn() {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          briefingHeader(),
          const SizedBox(height: 18),
          _LandingEditionLeadCarousel(
            items: headlineItems,
            titleText: titleText,
            bodyText: bodyText,
            mutedText: mutedText,
            isPhone: isPhone,
            fallbackTitle: coreIssue,
            fallbackSummary: briefSummary,
            onTap: (entry) {
              if (entry.editionIssue != null) {
                onEditionHeadlineTap(entry.editionIssue!);
                return;
              }
              if (entry.timelineItem != null) {
                onTimelineHeadlineTap(entry.timelineItem!);
                return;
              }
              if (entry.newsItem != null) {
                onNewsHeadlineTap(entry.newsItem!);
              }
            },
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final note in editionNotes)
                _LandingHeaderMetaPill(
                  icon: Icons.check_circle_outline_rounded,
                  label: note,
                  subtle: true,
                ),
            ],
          ),
          const SizedBox(height: 16),
          trendScoreBlock(),
          const SizedBox(height: 16),
          keywordsBlock(),
          const SizedBox(height: 16),
          _buildSearchAndCta(context, searchController, onSearch),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => _LandingInsightDetailSheet(
                insight: data,
                score: score,
                delta: delta,
                marketImpact: _landingMarketImpactLines(data),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
            label: const Text('AI 브리핑 자세히 보기'),
            style: FilledButton.styleFrom(
              backgroundColor: ctaBg,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 16 : 22),
      decoration: PulseUi.sectionDecoration(context, prominent: true),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isCompact = constraints.maxWidth < 980;
          if (isCompact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                leftColumn(),
                const SizedBox(height: 18),
                summaryRail(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: leftColumn()),
              const SizedBox(width: 18),
              Expanded(flex: 4, child: summaryRail()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSearchAndCta(
    BuildContext context,
    TextEditingController searchController,
    VoidCallback onSearch,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedText = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 620;
        final searchField = TextField(
          controller: searchController,
          onSubmitted: (_) => onSearch(),
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: '뉴스 키워드 검색',
            hintStyle: TextStyle(color: mutedText),
            prefixIcon: Icon(Icons.search_rounded, color: mutedText),
            filled: true,
            fillColor: surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color:
                      isDark ? Colors.blue.shade200 : const Color(0xFF2563EB)),
            ),
            isDense: true,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          ),
        );
        final actionButton = FilledButton.icon(
          onPressed: onSearch,
          icon: const Icon(Icons.bolt_rounded, size: 18),
          label: const Text('전체 뉴스 보기'),
          style: FilledButton.styleFrom(
            backgroundColor:
                isDark ? Colors.blue.shade600 : const Color(0xFF2563EB),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 1,
            shadowColor: const Color(0xFF2563EB).withOpacity(0.20),
          ),
        );

        if (compact) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              searchField,
              const SizedBox(height: 10),
              SizedBox(height: 44, child: actionButton),
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: searchField),
            const SizedBox(width: 10),
            actionButton,
          ],
        );
      },
    );
  }
}

class _LandingMetaStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData? leadingIcon;
  final Color? leadingColor;
  final String? trailingBadge;

  const _LandingMetaStat({
    required this.label,
    required this.value,
    this.leadingIcon,
    this.leadingColor,
    this.trailingBadge,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 170),
        curve: Curves.easeOut,
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
              color:
                  isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (leadingIcon != null) ...[
                  Icon(
                    leadingIcon,
                    size: 13,
                    color: leadingColor ??
                        (isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade500),
                  ),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.blueGrey.shade500,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            if (trailingBadge == null)
              Text(
                value,
                style: TextStyle(
                  color: trailingBadge == null
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : (leadingColor ??
                          (isDark ? Colors.white : const Color(0xFF0F172A))),
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              )
            else
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF063B22)
                          : const Color(0xFFECFDF3),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: Color(0xFF16A34A),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          trailingBadge!,
                          style: TextStyle(
                            color: isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      value,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: leadingColor ??
                            (isDark ? Colors.white : const Color(0xFF0F172A)),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _LandingSentimentMiniBar extends StatelessWidget {
  final NewsSentimentSummary sentiment;

  const _LandingSentimentMiniBar({required this.sentiment});

  @override
  Widget build(BuildContext context) {
    final isDark = ThemeController.instance.mode.value == ThemeMode.dark;
    final total = sentiment.positiveRatio +
        sentiment.neutralRatio +
        sentiment.negativeRatio;
    final positive = total == 0 ? 1 : sentiment.positiveRatio;
    final neutral = total == 0 ? 1 : sentiment.neutralRatio;
    final negative = total == 0 ? 1 : sentiment.negativeRatio;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: const Color(0xFF2563EB).withOpacity(0.75),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '감정 비율',
                style: TextStyle(
                  color:
                      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Row(
                children: [
                  Expanded(
                    flex: positive,
                    child: Container(
                      height: 4.5,
                      color: Colors.green.withOpacity(0.68),
                    ),
                  ),
                  Expanded(
                    flex: neutral,
                    child: Container(
                      height: 4.5,
                      color: Colors.blueGrey.withOpacity(0.48),
                    ),
                  ),
                  Expanded(
                    flex: negative,
                    child: Container(
                      height: 4.5,
                      color: Colors.red.withOpacity(0.60),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '긍정 ${sentiment.positiveRatio}% · 중립 ${sentiment.neutralRatio}% · 부정 ${sentiment.negativeRatio}%',
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingTimelineItemTile extends StatelessWidget {
  final IssueTimelineItem item;
  final VoidCallback onTap;

  const _LandingTimelineItemTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final stageLabel = _landingTimelineStageLabel(item.stage);
    final timeLabel = _landingTimelineTimeLabel(item.lastSeenAt);
    final growthLabel = item.growthRate >= 999
        ? 'NEW'
        : item.growthRate > 0
            ? '+${item.growthRate}%'
            : item.growthRate < 0
                ? '${item.growthRate}%'
                : '0%';

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF111827) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color:
                    isDark ? const Color(0xFF1F2937) : const Color(0xFFE6ECF3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF172554)
                          : const Color(0xFFEEF4FF),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        '${item.rank}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.title.isNotEmpty ? item.title : item.keyword,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item.summary.isNotEmpty
                    ? item.summary
                    : '관련 기사 ${item.articleCount}건이 묶여 있는 이슈입니다.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  color:
                      isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _LandingTinyBadge(
                    text: item.category.isNotEmpty ? item.category : '이슈',
                    foreground: const Color(0xFF2563EB),
                    background: isDark
                        ? const Color(0xFF172554)
                        : const Color(0xFFEEF4FF),
                  ),
                  _LandingTinyBadge(
                    text: '기사 ${item.articleCount}건',
                    foreground:
                        isDark ? Colors.grey.shade100 : const Color(0xFF334155),
                    background: isDark
                        ? const Color(0xFF1F2937)
                        : const Color(0xFFF1F5F9),
                  ),
                  _LandingTinyBadge(
                    text: growthLabel,
                    foreground: isDark
                        ? const Color(0xFFFBBF24)
                        : const Color(0xFFB45309),
                    background: isDark
                        ? const Color(0xFF3F2D12)
                        : const Color(0xFFFFF7E6),
                  ),
                  _LandingTinyBadge(
                    text: stageLabel,
                    foreground:
                        isDark ? Colors.grey.shade100 : const Color(0xFF475569),
                    background: isDark
                        ? const Color(0xFF111827)
                        : const Color(0xFFF8FAFC),
                  ),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark
                          ? Colors.grey.shade200
                          : Colors.blueGrey.shade500,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LandingTinyBadge extends StatelessWidget {
  final String text;
  final Color foreground;
  final Color background;

  const _LandingTinyBadge({
    required this.text,
    required this.foreground,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: foreground,
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LandingUrgencyBadge extends StatelessWidget {
  final String label;
  final int severity;

  const _LandingUrgencyBadge({
    required this.label,
    required this.severity,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final background = severity >= 5
        ? (isDark ? const Color(0xFF3F1D1D) : const Color(0xFFFFF1F2))
        : severity >= 4
            ? (isDark ? const Color(0xFF172554) : const Color(0xFFEEF4FF))
            : (isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6));
    final foreground = severity >= 5
        ? (isDark ? Colors.red.shade200 : Colors.red.shade600)
        : severity >= 4
            ? (isDark ? Colors.blue.shade200 : Colors.blue.shade700)
            : (isDark ? Colors.grey.shade200 : Colors.blueGrey.shade600);
    final dotColor = severity >= 5
        ? (isDark ? Colors.red.shade200 : Colors.red.shade500)
        : severity >= 4
            ? (isDark ? Colors.blue.shade200 : Colors.blue.shade500)
            : (isDark ? Colors.grey.shade300 : Colors.blueGrey.shade400);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: foreground,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingInfoPill extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;
  final Color background;

  const _LandingInfoPill({
    required this.label,
    required this.value,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.transparent : accent.withOpacity(0.08),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500,
              fontSize: 10.3,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13.2,
              fontWeight: FontWeight.w800,
              height: 1.28,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingDetailStatTile extends StatelessWidget {
  final String label;
  final String value;
  final String detail;
  final Color accent;
  final Color background;

  const _LandingDetailStatTile({
    required this.label,
    required this.value,
    required this.detail,
    required this.accent,
    required this.background,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : accent.withOpacity(0.12),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: TextStyle(
                color: accent,
                fontSize: 26,
                height: 1,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600,
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingMiniStateChip extends StatelessWidget {
  final String label;
  final String value;
  final String detail;

  const _LandingMiniStateChip({
    required this.label,
    required this.value,
    required this.detail,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      constraints: const BoxConstraints(minHeight: 72),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 10.0,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: 13.0,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            detail,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500,
              fontSize: 9.8,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingMarketMoodRow extends StatelessWidget {
  final TrendInsightSnapshot data;
  final List<_LandingMarketQuote> marketQuotes;

  const _LandingMarketMoodRow({
    required this.data,
    required this.marketQuotes,
  });

  @override
  Widget build(BuildContext context) {
    final sentiment = data.sentiment;
    final domestic = _landingSectorMoodLabel(data);
    final usQuote = _landingQuoteByTitle(marketQuotes, '나스닥100 선물');
    final fxQuote = _landingQuoteByTitle(marketQuotes, 'USD/KRW');
    final usLabel = usQuote == null
        ? '관찰 중'
        : usQuote.percentChange > 0
            ? '긍정'
            : usQuote.percentChange < 0
                ? '부정'
                : '중립';
    final fxLabel = fxQuote == null
        ? '관찰 중'
        : fxQuote.percentChange > 0
            ? '원화 약세'
            : fxQuote.percentChange < 0
                ? '원화 강세'
                : '중립';
    final greedLabel = _landingSentimentLabel(sentiment.temperature);

    final chips = [
      _LandingMiniStateChip(
        label: '국내 증시',
        value: domestic,
        detail: '경제·세계 뉴스 기준',
      ),
      _LandingMiniStateChip(
        label: '미국 선물',
        value: usLabel,
        detail: usQuote == null
            ? '데이터 대기'
            : '변동 ${_landingFormatPercent(usQuote.percentChange)}',
      ),
      _LandingMiniStateChip(
        label: '환율',
        value: fxLabel,
        detail: fxQuote == null
            ? '데이터 대기'
            : '변동 ${_landingFormatPercent(fxQuote.percentChange)}',
      ),
      _LandingMiniStateChip(
        label: '공포·탐욕',
        value: '$greedLabel ${sentiment.temperature}',
        detail: '뉴스 감정 집계',
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 680 ? 2 : 4;
        final spacing = 8.0;
        final chipWidth =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: chips
              .map(
                (chip) => SizedBox(
                  width: chipWidth,
                  child: chip,
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _LandingInsightDetailSheet extends StatelessWidget {
  final TrendInsightSnapshot insight;
  final int score;
  final int delta;
  final List<String> marketImpact;

  const _LandingInsightDetailSheet({
    required this.insight,
    required this.score,
    required this.delta,
    required this.marketImpact,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final title = isDark ? Colors.white : const Color(0xFF0F172A);
    final body = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700;
    final summaryText = insight.sentiment.summary.trim();
    final bullets = _landingDetailBullets(summaryText);
    final leadLine = bullets.isNotEmpty
        ? bullets.first
        : (summaryText.isEmpty ? '오늘 뉴스 흐름을 요약하고 있습니다.' : summaryText);
    final extraLines = bullets.length > 1
        ? bullets.skip(1).take(2).toList()
        : const <String>[];
    final trendCaption = _sentimentCaption(insight.sentiment.temperature);
    final marketImpacts = marketImpact.take(3).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize: 0.48,
      maxChildSize: 0.92,
      builder: (context, controller) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.30 : 0.12),
                blurRadius: 24,
                offset: const Offset(0, -8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: Container(
              color: surface,
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(18, 14, 18, 24),
                children: [
                  Center(
                    child: Container(
                      width: 46,
                      height: 4,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE2E8F0),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFEEF4FF),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: isDark
                                  ? Colors.blue.shade200
                                  : const Color(0xFF2563EB),
                            ),
                            const SizedBox(width: 5),
                            Text(
                              '실시간 브리핑',
                              style: TextStyle(
                                color: isDark
                                    ? Colors.blue.shade100
                                    : const Color(0xFF2563EB),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${insight.keywords.length}개 키워드',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.blueGrey.shade500,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 10,
                              height: 10,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.blue.shade200
                                    : const Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '상세 AI 요약',
                              style: TextStyle(
                                color: title,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const Spacer(),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                trendCaption,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade100
                                      : const Color(0xFF2563EB),
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '오늘의 핵심 한 줄',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          leadLine,
                          style: TextStyle(
                            color: title,
                            fontSize: 16,
                            height: 1.42,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (extraLines.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          for (final line in extraLines) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 7),
                                  width: 5,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? Colors.blue.shade200
                                        : const Color(0xFF2563EB),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    line,
                                    style: TextStyle(
                                      color: body,
                                      fontSize: 13.4,
                                      height: 1.45,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _LandingDetailStatTile(
                          label: '트렌드 점수',
                          value: '$score',
                          detail: delta == 0
                              ? '전일과 비슷한 흐름'
                              : '전일 대비 ${delta >= 0 ? '+' : ''}$delta',
                          accent: isDark
                              ? Colors.blue.shade200
                              : const Color(0xFF2563EB),
                          background: isDark
                              ? const Color(0xFF111827)
                              : const Color(0xFFEEF4FF),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _LandingDetailStatTile(
                          label: '감정 온도',
                          value: '${insight.sentiment.temperature}°',
                          detail:
                              _sentimentCaption(insight.sentiment.temperature),
                          accent: isDark
                              ? Colors.amber.shade200
                              : const Color(0xFFF59E0B),
                          background: isDark
                              ? const Color(0xFF1F2937)
                              : const Color(0xFFFFFBEB),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '시장 영향',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: marketImpacts.isEmpty
                              ? [
                                  _LandingTinyBadge(
                                    text: '집계 중',
                                    foreground: isDark
                                        ? Colors.grey.shade200
                                        : Colors.blueGrey.shade600,
                                    background: isDark
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFFF3F4F6),
                                  ),
                                ]
                              : marketImpacts.map((impact) {
                                  return _LandingTinyBadge(
                                    text: impact,
                                    foreground: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                    background: isDark
                                        ? const Color(0xFF1F2937)
                                        : const Color(0xFFF3F4F6),
                                  );
                                }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF111827)
                          : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFE8EEF5),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '핵심 키워드',
                          style: TextStyle(
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.blueGrey.shade500,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: insight.keywords.take(6).map((item) {
                            final weight = item.newsCount >= 8
                                ? FontWeight.w900
                                : item.newsCount >= 5
                                    ? FontWeight.w800
                                    : FontWeight.w700;
                            return Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: item.newsCount >= 8 ? 12 : 10,
                                vertical: item.newsCount >= 8 ? 6 : 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : const Color(0xFFE5E7EB),
                                ),
                              ),
                              child: Text(
                                item.keyword,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF0F172A),
                                  fontSize: item.newsCount >= 8 ? 12.5 : 11.5,
                                  fontWeight: weight,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LandingSparkline extends StatelessWidget {
  final List<double> values;
  final Color color;

  const _LandingSparkline({
    required this.values,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) {
      return const SizedBox.shrink();
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final width =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final height =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 24.0;
        return SizedBox(
          width: width,
          height: height,
          child: CustomPaint(
            painter: _LandingSparklinePainter(values: values, color: color),
          ),
        );
      },
    );
  }
}

class _LandingSparklinePainter extends CustomPainter {
  final List<double> values;
  final Color color;

  const _LandingSparklinePainter({
    required this.values,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0 || values.length < 2) return;
    final minValue = values.reduce((a, b) => a < b ? a : b);
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final range =
        (maxValue - minValue).abs() < 0.0001 ? 1.0 : (maxValue - minValue);

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color.withOpacity(0.08)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = (size.width * i) / (values.length - 1);
      final normalized = (values[i] - minValue) / range;
      final y = size.height - (normalized * (size.height - 4)) - 2;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fill);
    canvas.drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(covariant _LandingSparklinePainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.values != values;
  }
}

class _BreakingNewsTimelineTile extends StatelessWidget {
  final TrendItem item;
  final bool isFeatured;
  final bool isRead;
  final VoidCallback? onTap;

  const _BreakingNewsTimelineTile({
    required this.item,
    this.isFeatured = false,
    this.isRead = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dateTime = _landingTryParseDate(
      item.published.isNotEmpty ? item.published : item.createdAt,
    );
    final source = item.source.trim().isEmpty ? '언론사' : item.source.trim();
    final timeLabel = _landingClockLabel(dateTime);
    final relativeLabel = _landingRelativeTimeLabel(dateTime);
    final category =
        item.category.trim().isNotEmpty ? item.category.trim() : '속보';
    final titleColor = isDark
        ? (isRead ? Colors.grey.shade300 : Colors.white)
        : (isRead ? Colors.blueGrey.shade600 : const Color(0xFF0F172A));
    final lineColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE5E7EB);
    final dotColor = isDark ? Colors.blue.shade300 : Colors.blue.shade700;
    final isLatest = isFeatured ||
        (dateTime != null &&
            DateTime.now().difference(dateTime).inMinutes <= 10);
    final latestDotColor =
        isDark ? Colors.blue.shade200 : const Color(0xFF1D4ED8);

    return MouseRegion(
      cursor:
          onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        splashColor: const Color(0xFF2563EB).withOpacity(0.05),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 18,
                  child: Column(
                    children: [
                      Container(
                        width: isLatest ? 12 : 10,
                        height: isLatest ? 12 : 10,
                        margin: const EdgeInsets.only(top: 5),
                        decoration: BoxDecoration(
                          color: isLatest ? latestDotColor : dotColor,
                          shape: BoxShape.circle,
                          boxShadow: isLatest
                              ? [
                                  BoxShadow(
                                    color: latestDotColor.withOpacity(0.24),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Expanded(
                        child: Container(
                          width: 2,
                          color: lineColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF0F172A),
                                height: 1.0,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              relativeLabel,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? Colors.grey.shade300
                                    : Colors.blueGrey.shade500,
                              ),
                            ),
                            _LandingUrgencyBadge(
                              label:
                                  _landingNewsImportanceLabel(item.importance),
                              severity: item.importance,
                            ),
                            _LandingTinyBadge(
                              text: category,
                              foreground: isDark
                                  ? Colors.white
                                  : const Color(0xFF2563EB),
                              background: isDark
                                  ? const Color(0xFF172554)
                                  : const Color(0xFFEEF4FF),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          item.koreanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: titleColor,
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '출처: $source',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.blueGrey.shade600,
                          ),
                        ),
                      ],
                    ),
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

class _LandingSectionDivider extends StatelessWidget {
  const _LandingSectionDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      thickness: 0.4,
      color: Color(0xFFF5F7FA),
    );
  }
}

class _LandingKeywordChipV2 extends StatelessWidget {
  final TrendKeyword keyword;
  final RisingIssue? risingIssue;
  final VoidCallback onTap;

  const _LandingKeywordChipV2({
    required this.keyword,
    required this.risingIssue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondary = risingIssue == null
        ? '관심도 ${keyword.newsCount}'
        : risingIssue?.isNew == true
            ? 'NEW'
            : (risingIssue?.growthRate ?? 0) > 0
                ? '▲${risingIssue!.growthRate}'
                : (risingIssue?.growthRate ?? 0) < 0
                    ? '▼${risingIssue!.growthRate.abs()}'
                    : '관심도 ${keyword.newsCount}';
    return _HoverButton(
      onTap: onTap,
      child: Material(
        color: isDark ? const Color(0xFF111827) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: onTap,
          hoverColor: const Color(0xFF2563EB).withOpacity(0.06),
          splashColor: const Color(0xFF2563EB).withOpacity(0.08),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: keyword.keyword,
                    style: TextStyle(
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  TextSpan(
                    text: ' · $secondary',
                    style: TextStyle(
                      color: isDark
                          ? Colors.grey.shade400
                          : Colors.blueGrey.shade500,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
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
}

class _LandingHotIssueCard extends StatelessWidget {
  final RisingIssue issue;
  final List<String> keywords;
  final VoidCallback onTap;

  const _LandingHotIssueCard({
    required this.issue,
    required this.keywords,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final displayKeywords = keywords.take(2).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF172554)
                      : const Color(0xFFEEF4FF),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.trending_up_rounded,
                    size: 14,
                    color: Color(0xFF2563EB),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      issue.representativeTitle.isNotEmpty
                          ? issue.representativeTitle
                          : issue.keyword,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        fontSize: 14,
                        height: 1.35,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '관련 기사 ${issue.currentCount}건',
                      style: TextStyle(
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.blueGrey.shade600,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.end,
                  children: [
                    if (issue.keyword.trim().isNotEmpty)
                      _LandingMiniTag(text: issue.keyword.trim()),
                    for (final keyword in displayKeywords
                        .where((item) => item != issue.keyword))
                      _LandingMiniTag(text: keyword),
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

class _LandingMiniTag extends StatelessWidget {
  final String text;

  const _LandingMiniTag({required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: isDark ? Colors.grey.shade300 : const Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _LandingGroupedNewsTile extends StatefulWidget {
  final NewsCluster cluster;
  final VoidCallback onTap;

  const _LandingGroupedNewsTile({
    required this.cluster,
    required this.onTap,
  });

  @override
  State<_LandingGroupedNewsTile> createState() =>
      _LandingGroupedNewsTileState();
}

class _LandingGroupedNewsTileState extends State<_LandingGroupedNewsTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    final item = widget.cluster.representative;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final sourceDomain = _landingSourceDomainLabel(item.link);
    final category =
        item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(
        item.published.isNotEmpty ? item.published : item.createdAt);
    final thumbnailUrl = item.thumbnailUrl.trim();
    final extraCount = widget.cluster.articleCount - 1;

    return MouseRegion(
      cursor: hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: Material(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: widget.onTap,
            hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
            splashColor: const Color(0xFF2563EB).withOpacity(0.05),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8E5FF))
                      : (isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(_isHovered ? 0.30 : 0.20)
                        : const Color(0xFF0F172A)
                            .withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                color: isDark ? const Color(0xFF111827) : Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thumbnailUrl.isNotEmpty) ...[
                    SizedBox(
                      width: isCompact ? 72 : 88,
                      child: NetworkThumbnail(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        aspectRatio: 1,
                        borderRadius: BorderRadius.circular(16),
                        collapseOnError: true,
                        errorWidget: _landingThumbnailFallback(isDark),
                        loadingWidget: _landingThumbnailLoading(isDark),
                      ),
                    ),
                    SizedBox(width: isCompact ? 10 : 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  source.isNotEmpty
                                      ? source[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '출처 $source',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : Colors.blueGrey.shade700,
                                  fontSize: isCompact ? 10.5 : 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade100
                                      : Colors.blueGrey.shade600,
                                  fontSize: isCompact ? 9.5 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade100
                                    : Colors.blueGrey.shade500,
                                fontSize: isCompact ? 9.5 : 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.koreanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: isCompact ? 14 : 15,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.summaryKr.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.summaryKr.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade200
                                  : Colors.blueGrey.shade600,
                              fontSize: isCompact ? 13 : 14,
                              height: 1.42,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                extraCount > 0
                                    ? '묶음 ${widget.cluster.articleCount}건'
                                    : '단일 기사',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.blue.shade200
                                      : Colors.blue.shade700,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF111827)
                                    : const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '언론사 ${widget.cluster.sourceCount}곳',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade200
                                      : Colors.blueGrey.shade600,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (sourceDomain != null)
                              Text(
                                '원문 링크 $sourceDomain',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.blueGrey.shade500,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (extraCount > 0)
                              Text(
                                '외 $extraCount건',
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade100
                                      : Colors.blueGrey.shade500,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
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
        ),
      ),
    );
  }
}

class _LandingSearchResultTile extends StatefulWidget {
  final TrendItem item;

  const _LandingSearchResultTile({required this.item});

  @override
  State<_LandingSearchResultTile> createState() =>
      _LandingSearchResultTileState();
}

class _LandingSearchResultTileState extends State<_LandingSearchResultTile> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isCompact = MediaQuery.sizeOf(context).width < 640;
    final item = widget.item;
    final hasLink = item.link.trim().isNotEmpty;
    final source = item.source.trim().isEmpty ? 'News' : item.source.trim();
    final sourceDomain = _landingSourceDomainLabel(item.link);
    final category =
        item.category.trim().isEmpty ? 'General' : item.category.trim();
    final timeLabel = _landingCompactTime(
        item.published.isNotEmpty ? item.published : item.createdAt);
    final thumbnailUrl = item.thumbnailUrl.trim();

    return MouseRegion(
      cursor: hasLink ? SystemMouseCursors.click : SystemMouseCursors.basic,
      onEnter: (_) {
        if (mounted) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (mounted) setState(() => _isHovered = false);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(0, _isHovered ? -2 : 0, 0),
        child: Material(
          color: isDark ? const Color(0xFF111827) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: hasLink ? () => _openArticle(context, item.link) : null,
            hoverColor: const Color(0xFF2563EB).withOpacity(0.03),
            splashColor: const Color(0xFF2563EB).withOpacity(0.05),
            child: Container(
              padding: EdgeInsets.all(isCompact ? 14 : 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _isHovered
                      ? (isDark
                          ? const Color(0xFF334155)
                          : const Color(0xFFD8E5FF))
                      : (isDark
                          ? const Color(0xFF1F2937)
                          : const Color(0xFFE5E7EB)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(_isHovered ? 0.30 : 0.20)
                        : const Color(0xFF0F172A)
                            .withOpacity(_isHovered ? 0.06 : 0.04),
                    blurRadius: _isHovered ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                color: isDark ? const Color(0xFF111827) : Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (thumbnailUrl.isNotEmpty) ...[
                    SizedBox(
                      width: isCompact ? 72 : 88,
                      child: NetworkThumbnail(
                        imageUrl: thumbnailUrl,
                        fit: BoxFit.cover,
                        aspectRatio: 1,
                        borderRadius: BorderRadius.circular(16),
                        collapseOnError: true,
                        errorWidget: _landingThumbnailFallback(isDark),
                        loadingWidget: _landingThumbnailLoading(isDark),
                      ),
                    ),
                    SizedBox(width: isCompact ? 10 : 14),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Center(
                                child: Text(
                                  source.isNotEmpty
                                      ? source[0].toUpperCase()
                                      : 'N',
                                  style: const TextStyle(
                                    color: Color(0xFF2563EB),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '출처 $source',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade200
                                      : Colors.blueGrey.shade700,
                                  fontSize: isCompact ? 10.5 : 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF1F2937)
                                    : const Color(0xFFF3F4F6),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                category,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade300
                                      : Colors.blueGrey.shade600,
                                  fontSize: isCompact ? 9.5 : 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                color: isDark
                                    ? Colors.grey.shade100
                                    : Colors.blueGrey.shade500,
                                fontSize: isCompact ? 9.5 : 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          item.koreanTitle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                isDark ? Colors.white : const Color(0xFF0F172A),
                            fontSize: isCompact ? 14 : 15,
                            height: 1.28,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (item.summaryKr.trim().isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            item.summaryKr.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.grey.shade100
                                  : Colors.blueGrey.shade600,
                              fontSize: isCompact ? 13 : 14,
                              height: 1.42,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.auto_graph_rounded,
                                    size: 13,
                                    color: Colors.blue.shade700,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '중요도 ${item.importance}',
                                    style: TextStyle(
                                      color: Colors.blue.shade700,
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        '출처 $source',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.grey.shade300
                                              : Colors.blueGrey.shade600,
                                        ),
                                      ),
                                      Text(
                                        timeLabel,
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                          color: isDark
                                              ? Colors.grey.shade400
                                              : Colors.blueGrey.shade500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            if (sourceDomain != null)
                              Text(
                                '원문 링크 $sourceDomain',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.grey.shade400
                                      : Colors.blueGrey.shade500,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            if (hasLink)
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 170),
                                curve: Curves.easeOut,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _isHovered
                                      ? const Color(0xFFEEF4FF)
                                      : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(
                                    color: _isHovered
                                        ? const Color(0xFFD8E5FF)
                                        : const Color(0xFFE2E8F0),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.open_in_new_rounded,
                                      size: 13,
                                      color: _isHovered
                                          ? const Color(0xFF2563EB)
                                          : Colors.blueGrey.shade500,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '원문 보기',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: _isHovered
                                            ? const Color(0xFF2563EB)
                                            : Colors.blueGrey.shade600,
                                      ),
                                    ),
                                  ],
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.grey.shade200 : Colors.grey.shade500;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 42, color: iconColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.grey.shade200 : Colors.grey.shade600,
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isDark ? const Color(0xFF111827) : Colors.white.withOpacity(0.09),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: isDark
                ? const Color(0xFF1F2937)
                : Colors.white.withOpacity(0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isDark
                  ? Colors.grey.shade400
                  : Colors.white.withOpacity(0.66),
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
                    color: (changeUp ? Colors.greenAccent : Colors.redAccent)
                        .withOpacity(0.14),
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
                        color: changeUp ? Colors.greenAccent : Colors.redAccent,
                      ),
                      const SizedBox(width: 2),
                      Text(
                        changeText!,
                        style: TextStyle(
                          color:
                              changeUp ? Colors.greenAccent : Colors.redAccent,
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
  final topKeywords = insight.keywords.take(5).toList();
  final topRising = insight.risingIssues.take(3).toList();

  final keywordCount = topKeywords.isEmpty
      ? 0
      : topKeywords.fold<int>(0, (sum, item) => sum + item.newsCount) ~/
          topKeywords.length;
  final risingCount = topRising.isEmpty
      ? 0
      : topRising.fold<int>(
            0,
            (sum, item) => sum + item.currentCount + item.increaseCount,
          ) ~/
          topRising.length;

  final keywordScore = _landingTrendRatioScale(keywordCount, 130);
  final risingScore = _landingTrendRatioScale(risingCount, 90);
  final sentimentScore =
      1.0 - ((insight.sentiment.temperature - 50).abs() / 50).clamp(0, 1);

  final mixed =
      keywordScore * 0.43 + risingScore * 0.37 + sentimentScore * 0.20;
  return (12 + mixed * 76).round().clamp(0, 100);
}

int _landingTrendDelta(TrendInsightSnapshot insight) {
  if (insight.risingIssues.isEmpty) return 0;
  final averageIncrease = insight.risingIssues
          .map((issue) => issue.increaseCount)
          .reduce((a, b) => a + b) /
      insight.risingIssues.length;

  return (averageIncrease * 2).round().clamp(-20, 40);
}

List<String> _landingBriefingBullets(TrendInsightSnapshot insight) {
  final bullets = <String>[];
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

  if (keywords.isNotEmpty) {
    bullets.add('${_joinKoreanListSafe(keywords)} 관련 기사 급증');
  }
  if (rising.isNotEmpty) {
    bullets.add('${_joinKoreanListSafe(rising)} 이슈가 빠르게 확대 중');
  }

  if (insight.sentiment.temperature >= 71) {
    bullets.add('전체 분위기는 긍정적으로 유지되고 있습니다');
  } else if (insight.sentiment.temperature <= 30) {
    bullets.add('전체 분위기는 다소 불안한 흐름입니다');
  } else {
    bullets.add('전체 분위기는 중립권에서 움직이고 있습니다');
  }

  while (bullets.length < 3) {
    bullets.add('실시간 뉴스 흐름을 계속 추적 중입니다');
  }

  return bullets.take(5).toList();
}

List<String> _landingIssueKeywords(RisingIssue issue) {
  final base = _cleanLandingKeyword(issue.keyword);
  final derived = _cleanLandingKeyword(issue.representativeTitle)
      .split(' ')
      .where(_isLandingKeywordUseful)
      .where((value) => value != base)
      .take(2)
      .toList();

  return [
    if (_isLandingKeywordUseful(base)) base,
    ...derived,
  ];
}

String _landingKeywordLabel(TrendKeyword keyword, RisingIssue? risingIssue) {
  final base = _cleanLandingKeyword(keyword.keyword);
  if (risingIssue != null) {
    if (risingIssue.isNew) return '$base NEW';
    if (risingIssue.growthRate > 0) return '$base ▲${risingIssue.growthRate}';
    if (risingIssue.growthRate < 0) {
      return '$base ▼${risingIssue.growthRate.abs()}';
    }
  }

  return '$base · 관심도 ${keyword.newsCount}';
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

List<String> _landingDetailBullets(String summary) {
  final text = summary.trim();
  if (text.isEmpty) return const [];
  final normalized = text.replaceAll('\n', ' ').trim();
  final parts = normalized
      .split(RegExp(r'(?<=[。.!?])\s+|[•·]+'))
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList();
  if (parts.isEmpty) return [normalized];
  final cleaned = <String>[];
  for (final item in parts) {
    if (cleaned.contains(item)) continue;
    cleaned.add(item);
    if (cleaned.length == 3) break;
  }
  return cleaned;
}

String _landingSentimentLabel(int temperature) {
  if (temperature >= 71) return '탐욕';
  if (temperature <= 30) return '불안';
  return '중립';
}

String _landingSectorMoodLabel(TrendInsightSnapshot insight) {
  final sectorTemperatures = insight.keywords
      .where((item) =>
          (item.category == '경제' || item.category == '세계') &&
          item.sentimentTemperature != null)
      .map((item) => item.sentimentTemperature!)
      .toList();

  final temperature = sectorTemperatures.isNotEmpty
      ? (sectorTemperatures.reduce((a, b) => a + b) / sectorTemperatures.length)
          .round()
      : insight.sentiment.temperature;

  if (temperature >= 71) return '긍정 우세';
  if (temperature <= 30) return '경계';
  return '보통';
}

String _landingTimelineStageLabel(String stage) {
  switch (stage) {
    case 'new':
      return '신규';
    case 'peak':
      return '정점';
    case 'cooling':
      return '하락';
    case 'ended':
      return '종료';
    case 'rising':
    default:
      return '상승';
  }
}

String _landingTimelineTimeLabel(String value) {
  final parsed = _landingParseTimestamp(value);
  if (parsed == null) return '방금 전';
  final diff = DateTime.now().difference(parsed);
  if (!diff.isNegative) {
    if (diff.inMinutes < 1) return '방금 전';
    if (diff.inMinutes < 60) return '${diff.inMinutes}분 전';
    if (diff.inHours < 24) return '${diff.inHours}시간 전';
  }
  final hour = parsed.hour.toString().padLeft(2, '0');
  final minute = parsed.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
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

double _landingTrendRatioScale(int value, int cap) {
  if (cap <= 0 || value <= 0) return 0;
  return (value / (value + cap)).clamp(0.0, 1.0);
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

String _landingCoreIssueLine(TrendInsightSnapshot insight) {
  final keyword = insight.keywords.isNotEmpty
      ? _cleanLandingKeyword(insight.keywords.first.keyword)
      : '';
  final rising = insight.risingIssues.isNotEmpty
      ? _cleanLandingKeyword(insight.risingIssues.first.keyword)
      : '';

  if (keyword.isEmpty && rising.isEmpty) {
    return '오늘의 주요 이슈를 분석하고 있습니다. 새로 들어오는 뉴스를 기반으로 핵심 흐름을 정리합니다.';
  }

  if (keyword.isNotEmpty && rising.isNotEmpty) {
    return '$keyword 관련 이슈와 $rising 흐름이 오늘 뉴스의 중심입니다.';
  }

  final base = keyword.isNotEmpty ? keyword : rising;
  return '$base 관련 보도가 오늘 시장과 뉴스 흐름을 이끌고 있습니다.';
}

String _landingRisingIssueLine(TrendInsightSnapshot insight) {
  final issue =
      insight.risingIssues.isNotEmpty ? insight.risingIssues.first : null;
  if (issue == null || issue.keyword.trim().isEmpty) {
    return '뚜렷한 상승 이슈는 아직 제한적입니다.';
  }

  final keyword = _cleanLandingKeyword(issue.keyword);
  final count = issue.currentCount;
  return '$keyword 언급이 빠르게 늘고 있습니다. ($count건)';
}

String _landingFallingIssueLine(TrendInsightSnapshot insight) {
  final weakKeyword = insight.keywords
      .where((item) => (item.sentimentTemperature ?? 50) <= 45)
      .toList()
    ..sort((a, b) {
      final aTemp = a.sentimentTemperature ?? 50;
      final bTemp = b.sentimentTemperature ?? 50;
      return aTemp.compareTo(bTemp);
    });

  if (weakKeyword.isEmpty) {
    return '하락 이슈는 아직 뚜렷하지 않습니다.';
  }

  final item = weakKeyword.first;
  return '${_cleanLandingKeyword(item.keyword)} 관련 뉴스는 상대적으로 약한 흐름입니다.';
}

List<String> _landingMarketImpactLines(TrendInsightSnapshot insight) {
  final lines = <String>[];
  final temp = insight.sentiment.temperature;
  final domestic = temp >= 66
      ? '국내 증시 긍정 흐름'
      : temp <= 40
          ? '국내 증시 경계 흐름'
          : '국내 증시 중립 흐름';
  lines.add(domestic);

  final topKeyword = insight.keywords.isNotEmpty
      ? _cleanLandingKeyword(insight.keywords.first.keyword)
      : '';
  if (topKeyword.contains('반도체') ||
      topKeyword.contains('HBM') ||
      topKeyword.contains('AI')) {
    lines.add('반도체 관심 확대');
  } else if (topKeyword.contains('비트코인') || topKeyword.contains('가상자산')) {
    lines.add('가상자산 변동성 확대');
  } else if (topKeyword.contains('환율') || topKeyword.contains('달러')) {
    lines.add('환율 이슈 주목');
  } else {
    lines.add('업종별 혼조 흐름');
  }

  lines.add(temp >= 66
      ? '환율 부담 낮음'
      : temp <= 40
          ? '환율 변동 주의'
          : '환율 관망');

  return lines;
}

class _LandingHeaderMetaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool subtle;

  const _LandingHeaderMetaPill({
    required this.icon,
    required this.label,
    this.subtle = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isPhone ? 9 : 10,
        vertical: isPhone ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: subtle
            ? (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC))
            : (isDark ? const Color(0xFF172554) : const Color(0xFFEEF4FF)),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              fontSize: isPhone ? 10.8 : 11.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingEditionKeywordChip extends StatelessWidget {
  final String keyword;
  final bool emphasis;
  final VoidCallback onTap;

  const _LandingEditionKeywordChip({
    required this.keyword,
    required this.emphasis,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: emphasis ? 13 : 12,
          vertical: emphasis ? 9 : 8,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          keyword,
          style: TextStyle(
            color: isDark ? Colors.white : const Color(0xFF0F172A),
            fontSize: emphasis ? 12.8 : 12.3,
            fontWeight: emphasis ? FontWeight.w800 : FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _LandingEditionHeadlineCard extends StatelessWidget {
  final _LandingEditionHeadlineData item;
  final int index;
  final VoidCallback? onTap;
  final bool compact;

  const _LandingEditionHeadlineCard({
    required this.item,
    required this.index,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final showSummary = !compact;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700;
    final muted = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: compact ? 22 : 24,
                  height: compact ? 22 : 24,
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF172554)
                        : const Color(0xFFEEF4FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: isDark
                            ? Colors.blue.shade100
                            : const Color(0xFF2563EB),
                        fontSize: compact ? 10.8 : 11.5,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: compact ? 6 : 8),
                Expanded(
                  child: Text(
                    item.category,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: muted,
                      fontSize: compact ? 11.0 : 11.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: compact ? 16 : 18,
                    color: muted,
                  ),
              ],
            ),
            SizedBox(height: compact ? 6 : 8),
            Text(
              item.title,
              maxLines: compact ? 1 : 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: titleColor,
                fontSize:
                    compact ? (isPhone ? 13.1 : 13.6) : (isPhone ? 13.8 : 14.5),
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
            if (showSummary) ...[
              const SizedBox(height: 6),
              Text(
                item.summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: bodyColor,
                  fontSize: isPhone ? 12.1 : 12.5,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 4),
            Text(
              item.meta,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: muted,
                fontSize:
                    compact ? (isPhone ? 10.0 : 10.4) : (isPhone ? 10.5 : 11),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LandingEditionLeadCarousel extends StatefulWidget {
  final List<_LandingEditionHeadlineData> items;
  final Color titleText;
  final Color bodyText;
  final Color mutedText;
  final bool isPhone;
  final String fallbackTitle;
  final String fallbackSummary;
  final ValueChanged<_LandingEditionHeadlineData> onTap;

  const _LandingEditionLeadCarousel({
    required this.items,
    required this.titleText,
    required this.bodyText,
    required this.mutedText,
    required this.isPhone,
    required this.fallbackTitle,
    required this.fallbackSummary,
    required this.onTap,
  });

  @override
  State<_LandingEditionLeadCarousel> createState() =>
      _LandingEditionLeadCarouselState();
}

class _LandingEditionLeadCarouselState
    extends State<_LandingEditionLeadCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = isDark ? Colors.blue.shade200 : const Color(0xFF2563EB);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);

    if (widget.items.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '오늘의 핵심 이슈',
            style: TextStyle(
              color: widget.mutedText,
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            widget.fallbackTitle,
            style: TextStyle(
              color: widget.titleText,
              fontSize: widget.isPhone ? 21 : 24,
              fontWeight: FontWeight.w900,
              height: 1.22,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.fallbackSummary,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: widget.bodyText,
              fontSize: widget.isPhone ? 14.5 : 15.5,
              fontWeight: FontWeight.w600,
              height: 1.55,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '오늘의 핵심 이슈',
              style: TextStyle(
                color: widget.mutedText,
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const Spacer(),
            Text(
              '${_currentIndex + 1} / ${widget.items.length}',
              style: TextStyle(
                color: widget.mutedText,
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: widget.isPhone ? 236 : 214,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.items.length,
            onPageChanged: (value) {
              if (!mounted) return;
              setState(() => _currentIndex = value);
            },
            itemBuilder: (context, index) {
              final item = widget.items[index];
              return InkWell(
                onTap: () => widget.onTap(item),
                borderRadius: BorderRadius.circular(18),
                child: Padding(
                  padding: const EdgeInsets.only(right: 2, bottom: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _LandingTinyBadge(
                            text: item.category.isEmpty ? '핵심' : item.category,
                            foreground: accent,
                            background: isDark
                                ? const Color(0xFF172554)
                                : const Color(0xFFEEF4FF),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.title,
                        maxLines: widget.isPhone ? 2 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.titleText,
                          fontSize: widget.isPhone ? 21 : 24,
                          fontWeight: FontWeight.w900,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        item.summary,
                        maxLines: widget.isPhone ? 3 : 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.bodyText,
                          fontSize: widget.isPhone ? 14.2 : 15.4,
                          fontWeight: FontWeight.w600,
                          height: 1.55,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: widget.mutedText,
                          fontSize: widget.isPhone ? 11.0 : 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          Expanded(
                            child: Wrap(
                              spacing: 6,
                              children:
                                  List.generate(widget.items.length, (dot) {
                                final active = dot == _currentIndex;
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOut,
                                  width: active ? 18 : 7,
                                  height: 7,
                                  decoration: BoxDecoration(
                                    color: active ? accent : border,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                );
                              }),
                            ),
                          ),
                          Icon(
                            Icons.swipe_rounded,
                            size: 16,
                            color: widget.mutedText,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LandingEditionHeadlineCarousel extends StatefulWidget {
  final List<_LandingEditionHeadlineData> items;
  final ValueChanged<_LandingEditionHeadlineData> onTap;

  const _LandingEditionHeadlineCarousel({
    required this.items,
    required this.onTap,
  });

  @override
  State<_LandingEditionHeadlineCarousel> createState() =>
      _LandingEditionHeadlineCarouselState();
}

class _LandingEditionHeadlineCarouselState
    extends State<_LandingEditionHeadlineCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  List<List<_LandingEditionHeadlineData>> _buildPages({
    required double railWidth,
    required double screenWidth,
  }) {
    final perPage = screenWidth >= 980
        ? 3
        : railWidth < 420
            ? 1
            : railWidth < 560
                ? 2
                : 3;
    final pages = <List<_LandingEditionHeadlineData>>[];
    for (var i = 0; i < widget.items.length; i += perPage) {
      pages.add(
        widget.items.sublist(
          i,
          math.min(i + perPage, widget.items.length),
        ),
      );
    }
    return pages;
  }

  @override
  void initState() {
    super.initState();
    _controller = PageController(viewportFraction: 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final muted = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final screenWidth = MediaQuery.sizeOf(context).width;
    return LayoutBuilder(
      builder: (context, constraints) {
        final railWidth = constraints.maxWidth;
        final pages = _buildPages(
          railWidth: railWidth,
          screenWidth: screenWidth,
        );
        final perPage = pages.isEmpty ? 1 : pages.first.length;
        final carouselHeight = perPage == 1
            ? 182.0
            : perPage == 2
                ? 258.0
                : 320.0;

        if (_currentIndex >= pages.length && pages.isNotEmpty) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            setState(() => _currentIndex = pages.length - 1);
          });
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: carouselHeight,
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (value) {
                  if (!mounted) return;
                  setState(() => _currentIndex = value);
                },
                itemBuilder: (context, index) {
                  final pageItems = pages[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 4),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: border),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        for (var itemIndex = 0;
                            itemIndex < pageItems.length;
                            itemIndex++) ...[
                          Expanded(
                            child: Align(
                              alignment: Alignment.topLeft,
                              child: _LandingEditionHeadlineCard(
                                item: pageItems[itemIndex],
                                index: index * 3 + itemIndex,
                                compact: pageItems.length >= 2,
                                onTap: () => widget.onTap(pageItems[itemIndex]),
                              ),
                            ),
                          ),
                          if (itemIndex != pageItems.length - 1) ...[
                            const SizedBox(height: 8),
                            Divider(
                              height: 1,
                              color: border,
                            ),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Wrap(
                  spacing: 6,
                  children: List.generate(pages.length, (index) {
                    final active = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      width: active ? 18 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: active
                            ? (isDark
                                ? Colors.blue.shade200
                                : const Color(0xFF2563EB))
                            : border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                Text(
                  '${pages.isEmpty ? 0 : _currentIndex + 1} / ${pages.length}',
                  style: TextStyle(
                    color: muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _LandingEditionUpdateTile extends StatelessWidget {
  final IssueTimelineItem item;
  final VoidCallback onTap;

  const _LandingEditionUpdateTile({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final timeLabel = _landingTimelineTimeLabel(item.lastSeenAt);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade700;
    final muted = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade500;
    final lineColor =
        isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final dotColor = item.growthRate >= 100
        ? const Color(0xFFDC2626)
        : item.growthRate > 0
            ? const Color(0xFF2563EB)
            : const Color(0xFF94A3B8);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: isPhone ? 54 : 62,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _landingClockLabel(_landingParseTimestamp(item.lastSeenAt)),
                    style: TextStyle(
                      color: titleColor,
                      fontSize: isPhone ? 11.8 : 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeLabel,
                    style: TextStyle(
                      color: muted,
                      fontSize: isPhone ? 10.0 : 10.8,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: isPhone ? 16 : 20,
              child: Column(
                children: [
                  Container(
                    width: isPhone ? 8 : 10,
                    height: isPhone ? 8 : 10,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: BoxDecoration(
                      color: dotColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  Container(
                    width: 2,
                    height: isPhone ? 48 : 56,
                    margin: const EdgeInsets.only(top: 6),
                    color: lineColor,
                  ),
                ],
              ),
            ),
            SizedBox(width: isPhone ? 6 : 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      _LandingTinyBadge(
                        text: item.category.isEmpty ? '이슈' : item.category,
                        foreground: isDark
                            ? Colors.blue.shade100
                            : const Color(0xFF2563EB),
                        background: isDark
                            ? const Color(0xFF172554)
                            : const Color(0xFFEEF4FF),
                      ),
                      _LandingTinyBadge(
                        text: '출처 ${item.sourceCount}곳',
                        foreground: isDark
                            ? Colors.grey.shade100
                            : const Color(0xFF334155),
                        background: isDark
                            ? const Color(0xFF1F2937)
                            : const Color(0xFFF1F5F9),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title.isEmpty ? item.keyword : item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: titleColor,
                      fontSize: isPhone ? 13.5 : 14.5,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                  if (item.summary.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      item.summary.trim(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: bodyColor,
                        fontSize: isPhone ? 11.8 : 12.3,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _landingEditionDateLabel() {
  final now = DateTime.now();
  const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
  final weekday = weekdays[now.weekday - 1];
  return '${now.month}월 ${now.day}일 $weekday요일';
}

String _landingEditionLeadLine(
  TrendInsightSnapshot insight,
  List<IssueTimelineItem> timelineItems,
) {
  final issue = timelineItems.isNotEmpty ? timelineItems.first : null;
  if (issue != null && issue.title.trim().isNotEmpty) {
    return issue.title.trim();
  }

  return _landingCoreIssueLine(insight);
}

String _landingEditionSummary(
  TrendInsightSnapshot insight,
  List<IssueTimelineItem> timelineItems,
) {
  final issue = timelineItems.isNotEmpty ? timelineItems.first : null;
  final summary = issue?.summary.trim() ?? '';
  if (summary.isNotEmpty) {
    return summary;
  }

  return _landingBriefingTextSafe(insight).replaceAll('\n', ' ');
}

List<String> _landingEditionNotes(
  TrendInsightSnapshot insight,
  _LandingEditionHeadlineData? leadHeadline,
) {
  final lines = _landingMarketImpactLines(insight);
  return [
    if (leadHeadline != null)
      leadHeadline.category == '경제' || leadHeadline.category == '증시'
          ? '국내 시장 영향도 높음'
          : '${leadHeadline.category} 흐름 우선 확인',
    if (lines.isNotEmpty) lines.first,
    _sentimentCaption(insight.sentiment.temperature)
        .replaceFirst('뉴스 분위기: ', ''),
  ].take(3).toList();
}

List<_LandingEditionHeadlineData> _landingEditionHeadlineItems(
  List<IssueTimelineItem> timelineItems,
  List<TrendItem> latestNews,
) {
  final items = <_LandingEditionHeadlineData>[];
  final sortedTimelineItems = [...timelineItems]..sort((a, b) =>
      _landingEditionPriorityScore(b)
          .compareTo(_landingEditionPriorityScore(a)));

  for (final item in sortedTimelineItems.take(5)) {
    items.add(
      _LandingEditionHeadlineData(
        title:
            item.title.trim().isEmpty ? item.keyword.trim() : item.title.trim(),
        summary: item.summary.trim().isEmpty
            ? '관련 기사 ${item.articleCount}건, 출처 ${item.sourceCount}곳에서 확인됐습니다.'
            : item.summary.trim(),
        category: item.category.trim().isEmpty ? '이슈' : item.category.trim(),
        meta: '기사 ${item.articleCount}건 · 출처 ${item.sourceCount}곳',
        timelineItem: item,
      ),
    );
  }

  if (items.length >= 3) {
    return items.take(3).toList();
  }

  final sortedNews = [...latestNews]..sort((a, b) =>
      _landingEditionNewsPriorityScore(b)
          .compareTo(_landingEditionNewsPriorityScore(a)));

  for (final item in sortedNews) {
    if (items.length >= 3) break;
    if (item.koreanTitle.trim().isEmpty) continue;
    items.add(
      _LandingEditionHeadlineData(
        title: item.koreanTitle.trim(),
        summary: item.summaryKr.trim().isEmpty
            ? '최신 기사 흐름에서 확인된 주요 이슈입니다.'
            : item.summaryKr.trim(),
        category: item.category.trim().isEmpty ? '일반' : item.category.trim(),
        meta:
            item.source.trim().isEmpty ? '출처 확인 중' : '출처 ${item.source.trim()}',
        newsItem: item,
      ),
    );
  }

  return items;
}

int _landingEditionPriorityScore(IssueTimelineItem item) {
  var score = item.score.round();
  score += item.articleCount * 3;
  score += item.sourceCount * 6;
  score += item.growthRate.round().clamp(0, 120);

  final text = '${item.category} ${item.keyword} ${item.title}'.toLowerCase();

  if (text.contains('코스피') ||
      text.contains('코스닥') ||
      text.contains('증시') ||
      text.contains('금리') ||
      text.contains('환율') ||
      text.contains('반도체') ||
      text.contains('서킷') ||
      text.contains('경제')) {
    score += 42;
  }

  if (text.contains('정치') ||
      text.contains('사회') ||
      text.contains('정부') ||
      text.contains('폭염') ||
      text.contains('안전')) {
    score += 18;
  }

  if (text.contains('비트코인') ||
      text.contains('가상자산') ||
      text.contains('코인') ||
      text.contains('암호화폐')) {
    score -= 20;
  }

  return score;
}

int _landingEditionNewsPriorityScore(TrendItem item) {
  var score = item.importance * 14;
  score += item.viewCount.clamp(0, 200);
  final text = '${item.category} ${item.koreanTitle}'.toLowerCase();

  if (text.contains('코스피') ||
      text.contains('코스닥') ||
      text.contains('증시') ||
      text.contains('금리') ||
      text.contains('환율') ||
      text.contains('반도체') ||
      text.contains('서킷') ||
      text.contains('경제')) {
    score += 34;
  }

  if (text.contains('비트코인') ||
      text.contains('가상자산') ||
      text.contains('코인') ||
      text.contains('암호화폐')) {
    score -= 16;
  }

  return score;
}

String _landingNewsImportanceLabel(int importance) {
  if (importance >= 5) return '긴급';
  if (importance >= 4) return '주요';
  return '일반';
}

int _landingNewsPriorityRank(TrendItem item) {
  final importance = item.importance;
  if (importance >= 5) return 0;
  if (importance >= 4) return 1;
  return 2;
}

String _landingMarketStageLabel(_LandingMarketQuote quote) {
  final updatedAt = quote.priceUpdatedAt;
  if (updatedAt == null) return '시세 지연';
  final age = DateTime.now().difference(updatedAt);
  if (age.inMinutes > 30) return '시세 지연';

  if (quote.group == 'fx' || quote.group == 'crypto') {
    return '시간외';
  }

  final now = DateTime.now();
  final weekday = now.weekday;
  if (weekday == DateTime.saturday || weekday == DateTime.sunday) {
    return '휴장';
  }

  final minutes = now.hour * 60 + now.minute;
  if (minutes < 8 * 60 + 30) return '개장 전';
  if (minutes >= 9 * 60 && minutes < 15 * 60 + 30) return '장중';
  if (minutes >= 15 * 60 + 30 && minutes < 18 * 60) return '시간외';
  return '장 마감';
}

String _landingMarketStageDetail(_LandingMarketQuote quote) {
  final updatedAt = quote.priceUpdatedAt;
  if (updatedAt == null) return '시세 확인 중';
  final age = DateTime.now().difference(updatedAt);
  if (age.inMinutes > 30) return '30분 이상 지연';
  if (age.inMinutes > 10) return '${age.inMinutes}분 지연';
  return '${_landingFormatUpdatedAt(updatedAt)} 기준';
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
  final VoidCallback? onTap;
  const _HoverButton({required this.child, this.onTap});

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
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
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

class _LandingIssueDetailSheet extends StatelessWidget {
  final EditionIssue issue;
  final Future<List<TrendItem>> future;

  const _LandingIssueDetailSheet({required this.issue, required this.future});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    final primary = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondary =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.45,
      maxChildSize: 0.95,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: border)),
        ),
        child: FutureBuilder<List<TrendItem>>(
          future: future,
          builder: (context, snapshot) {
            final articles = (snapshot.data ?? const <TrendItem>[]).toList()
              ..sort((a, b) {
                final aDate = _landingParseTimestamp(
                        a.published.isNotEmpty ? a.published : a.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                final bDate = _landingParseTimestamp(
                        b.published.isNotEmpty ? b.published : b.createdAt) ??
                    DateTime.fromMillisecondsSinceEpoch(0);
                return bDate.compareTo(aDate);
              });
            final isLoading =
                snapshot.connectionState == ConnectionState.waiting;
            final articleCount = isLoading && !issue.countsVerified
                ? null
                : (isLoading ? issue.articleCount : articles.length);
            final sourceCount = isLoading && !issue.countsVerified
                ? null
                : (isLoading
                    ? issue.sourceCount
                    : articles
                        .map((item) => item.source.trim().toLowerCase())
                        .where((value) => value.isNotEmpty)
                        .toSet()
                        .length);
            final commonSummary = _commonSummary();
            final newFinding = issue.newFinding?.trim();
            final timeline =
                issue.timeline.where((item) => item.isUsable).toList();

            return CustomScrollView(
              controller: scrollController,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: Container(
                            width: 42,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF475569)
                                  : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Align(
                          alignment: Alignment.centerRight,
                          child: IconButton(
                            tooltip: '닫기',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close_rounded, color: secondary),
                          ),
                        ),
                        Text(
                          issue.title.trim().isEmpty
                              ? issue.keyword
                              : issue.title,
                          style: TextStyle(
                            color: primary,
                            fontSize: 21,
                            height: 1.3,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _countLabel(articleCount, sourceCount, isLoading),
                          style: TextStyle(
                            color: secondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (commonSummary != null)
                  SliverToBoxAdapter(
                    child: _IssueDetailSection(
                      icon: Icons.adjust_rounded,
                      title: '이 이슈에서 확인된 내용',
                      child: Text(
                        commonSummary,
                        style: TextStyle(
                            color: primary, fontSize: 14, height: 1.6),
                      ),
                    ),
                  ),
                if (newFinding != null && newFinding.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _IssueDetailSection(
                      icon: Icons.auto_awesome_rounded,
                      title: '새로 확인된 점',
                      accent: true,
                      child: Text(
                        newFinding,
                        style: TextStyle(
                            color: primary, fontSize: 14, height: 1.55),
                      ),
                    ),
                  ),
                if (timeline.isNotEmpty)
                  SliverToBoxAdapter(
                    child: _IssueDetailTimelineSection(items: timeline),
                  ),
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.article_outlined,
                            color: Color(0xFF2563EB), size: 20),
                        const SizedBox(width: 8),
                        Text(
                          '관련 보도',
                          style: TextStyle(
                              color: primary,
                              fontSize: 16,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isLoading)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                else if (snapshot.hasError)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LandingSearchStateMessage(
                      icon: Icons.error_outline_rounded,
                      title: '관련 뉴스를 불러오지 못했습니다.',
                      subtitle: '잠시 후 다시 시도해 주세요.',
                    ),
                  )
                else if (articles.isEmpty)
                  const SliverFillRemaining(
                    hasScrollBody: false,
                    child: _LandingSearchStateMessage(
                      icon: Icons.search_off_rounded,
                      title: '관련 뉴스가 없습니다.',
                      subtitle: '다른 키워드로 다시 확인해 보세요.',
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                    sliver: SliverList.separated(
                      itemCount: articles.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) =>
                          _LandingIssueArticleTile(item: articles[index]),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  String _countLabel(int? articleCount, int? sourceCount, bool isLoading) {
    if (articleCount == null || sourceCount == null) {
      return isLoading ? '관련 기사 불러오는 중' : '관련 기사 정보가 없습니다';
    }
    return '관련 기사 $articleCount건 · 출처 $sourceCount곳';
  }

  String? _commonSummary() {
    final summary = issue.summary.trim();
    final title = issue.title.trim();
    final summaryKey = _comparisonText(summary);
    final titleKey = _comparisonText(title);
    if (summaryKey.length < 16 ||
        summaryKey == titleKey ||
        titleKey.contains(summaryKey) ||
        summaryKey.startsWith(titleKey)) {
      return null;
    }
    return summary;
  }

  String _comparisonText(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9가-힣]'), '');
}

class _IssueDetailSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  final bool accent;

  const _IssueDetailSection({
    required this.icon,
    required this.title,
    required this.child,
    this.accent = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = accent
        ? (isDark ? const Color(0xFF1E3A8A) : const Color(0xFFBFDBFE))
        : (isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0));
    final surface = accent
        ? (isDark ? const Color(0xFF172554) : const Color(0xFFF5F9FF))
        : (isDark ? const Color(0xFF141E2E) : const Color(0xFFFAFCFF));
    final primary = isDark ? Colors.white : const Color(0xFF0F172A);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text(title,
                  style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: surface,
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: child,
          ),
        ],
      ),
    );
  }
}

class _IssueDetailTimelineSection extends StatelessWidget {
  final List<IssueTimelineEvent> items;

  const _IssueDetailTimelineSection({required this.items});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final border = isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    final primary = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondary =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.schedule_rounded,
                  color: Color(0xFF2563EB), size: 20),
              const SizedBox(width: 8),
              Text('최근 흐름',
                  style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                for (var index = 0; index < items.length; index++)
                  _IssueDetailTimelineRow(
                    item: items[index],
                    showDivider: index < items.length - 1,
                    primary: primary,
                    secondary: secondary,
                    border: border,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _IssueDetailTimelineRow extends StatelessWidget {
  final IssueTimelineEvent item;
  final bool showDivider;
  final Color primary;
  final Color secondary;
  final Color border;

  const _IssueDetailTimelineRow({
    required this.item,
    required this.showDivider,
    required this.primary,
    required this.secondary,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: showDivider
          ? BoxDecoration(border: Border(bottom: BorderSide(color: border)))
          : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 54,
            child: Text(item.occurredAt,
                style: const TextStyle(
                    color: Color(0xFF2563EB),
                    fontSize: 12,
                    fontWeight: FontWeight.w700)),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.description,
                    style:
                        TextStyle(color: primary, fontSize: 13.5, height: 1.4)),
                if (item.context != null) ...[
                  const SizedBox(height: 2),
                  Text(item.context!,
                      style: TextStyle(color: secondary, fontSize: 12)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingIssueArticleTile extends StatefulWidget {
  final TrendItem item;

  const _LandingIssueArticleTile({required this.item});

  @override
  State<_LandingIssueArticleTile> createState() =>
      _LandingIssueArticleTileState();
}

class _LandingIssueArticleTileState extends State<_LandingIssueArticleTile> {
  bool _thumbnailFailed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final item = widget.item;
    final thumbnailUrl = item.thumbnailUrl.trim();
    final hasThumbnail = thumbnailUrl.isNotEmpty && !_thumbnailFailed;
    final hasLink = item.link.trim().isNotEmpty;
    final primary = isDark ? Colors.white : const Color(0xFF0F172A);
    final secondary =
        isDark ? const Color(0xFFCBD5E1) : const Color(0xFF64748B);
    final border = isDark ? const Color(0xFF243247) : const Color(0xFFE2E8F0);
    final source = item.source.trim().isEmpty ? '출처 미상' : item.source.trim();
    final category = item.category.trim().isEmpty ? '일반' : item.category.trim();
    final time = _landingCompactTime(
        item.published.isNotEmpty ? item.published : item.createdAt);

    return Material(
      color: isDark ? const Color(0xFF141E2E) : Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: hasLink ? _openArticle : null,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: border),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasThumbnail) ...[
                SizedBox(
                  width: 76,
                  height: 76,
                  child: NetworkThumbnail(
                    imageUrl: thumbnailUrl,
                    fit: BoxFit.cover,
                    borderRadius: BorderRadius.circular(8),
                    loadingWidget: DecoratedBox(
                        decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF243247)
                                : const Color(0xFFF1F5F9))),
                    errorWidget: const SizedBox.shrink(),
                    onError: () {
                      if (mounted) setState(() => _thumbnailFailed = true);
                    },
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 3,
                      children: [
                        Text(source,
                            style: TextStyle(
                                color: primary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600)),
                        Text(category,
                            style: TextStyle(color: secondary, fontSize: 12)),
                        Text(time,
                            style: TextStyle(color: secondary, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.koreanTitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: primary,
                          fontSize: 14.5,
                          height: 1.35,
                          fontWeight: FontWeight.w700),
                    ),
                    if (hasLink) ...[
                      const SizedBox(height: 9),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton.icon(
                          onPressed: _openArticle,
                          icon: const Icon(Icons.open_in_new_rounded, size: 14),
                          label: const Text('원문 보기'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF2563EB),
                            textStyle: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openArticle() async {
    final uri = Uri.tryParse(widget.item.link.trim());
    if (uri == null) return;
    final opened = await launchUrl(uri, webOnlyWindowName: '_blank');
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('기사 원문을 열 수 없습니다.')),
      );
    }
  }
}

class _LandingMarketConfig {
  final String symbol;
  final String tvSymbol;
  final String title;
  final String prefix;
  final String group;

  const _LandingMarketConfig({
    required this.symbol,
    required this.tvSymbol,
    required this.title,
    required this.prefix,
    required this.group,
  });
}

class _LandingMarketQuote {
  final String symbol;
  final String tvSymbol;
  final String title;
  final String prefix;
  final String group;
  final double currentPrice;
  final double percentChange;
  final DateTime? priceUpdatedAt;
  final List<double> chartData;

  const _LandingMarketQuote({
    required this.symbol,
    required this.tvSymbol,
    required this.title,
    required this.prefix,
    required this.group,
    required this.currentPrice,
    required this.percentChange,
    required this.priceUpdatedAt,
    this.chartData = const [],
  });
}

class _HomeStory {
  final _HomeStoryType type;
  final String title;
  final String summary;
  final String category;
  final String time;
  final String meta;
  final String context;
  final String thumbnailUrl;
  final int articleId;
  final List<int> issueNewsIds;
  final VoidCallback onTap;

  const _HomeStory({
    required this.type,
    required this.title,
    required this.summary,
    required this.category,
    required this.time,
    this.meta = '',
    this.context = '',
    this.thumbnailUrl = '',
    this.articleId = 0,
    this.issueNewsIds = const <int>[],
    required this.onTap,
  });

  bool get isIssue => type == _HomeStoryType.issue;
  String get actionLabel => isIssue ? '자세히 보기' : '원문 보기';
}

enum _HomeStoryType { issue, article }

class _HomeArticleCandidate {
  final TrendItem item;
  final _HomeArticleEligibility eligibility;

  const _HomeArticleCandidate({
    required this.item,
    required this.eligibility,
  });
}

class _HomeArticleEligibility {
  final int score;
  final bool isHardExcluded;

  const _HomeArticleEligibility({
    required this.score,
    required this.isHardExcluded,
  });
}

class _HomeStoryCarousel extends StatefulWidget {
  final List<_HomeStory> stories;
  final Color foreground;
  final Color muted;
  final Color border;

  const _HomeStoryCarousel({
    required this.stories,
    required this.foreground,
    required this.muted,
    required this.border,
  });

  @override
  State<_HomeStoryCarousel> createState() => _HomeStoryCarouselState();
}

class _HomeStoryCarouselState extends State<_HomeStoryCarousel> {
  late final PageController _controller;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _HomeStoryCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stories.isNotEmpty && _currentIndex >= widget.stories.length) {
      _currentIndex = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.hasClients) {
          _controller.jumpToPage(0);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? const Color(0xFF111C30) : Colors.white;
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final height = isMobile ? 190.0 : 226.0;

    return Column(
      children: [
        SizedBox(
          height: height,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.stories.length,
            onPageChanged: (index) => setState(() => _currentIndex = index),
            itemBuilder: (context, index) {
              final story = widget.stories[index];
              final active = index == _currentIndex;
              return AnimatedScale(
                scale: active ? 1 : 0.985,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                child: AnimatedOpacity(
                  opacity: active ? 1 : 0.9,
                  duration: const Duration(milliseconds: 220),
                  child: Container(
                    key: ValueKey('${story.title}-$index'),
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    padding: EdgeInsets.all(isMobile ? 16 : 18),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: widget.border),
                    ),
                    child: _HomeFeaturedStory(
                      story: story,
                      foreground: widget.foreground,
                      muted: widget.muted,
                      onTap: story.onTap,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Row(
              children: [
                Wrap(
                  spacing: 5,
                  children: List.generate(widget.stories.length, (index) {
                    final active = index == _currentIndex;
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: active ? 16 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: active ? const Color(0xFF2563EB) : widget.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
                const Spacer(),
                Text(
                  '${_currentIndex + 1} / ${widget.stories.length}',
                  style: TextStyle(
                    color: widget.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeLoadingLine extends StatelessWidget {
  const _HomeLoadingLine();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 42,
      child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }
}

class _HomeFeaturedStory extends StatefulWidget {
  final _HomeStory story;
  final Color foreground;
  final Color muted;
  final VoidCallback onTap;

  const _HomeFeaturedStory({
    required this.story,
    required this.foreground,
    required this.muted,
    required this.onTap,
  });

  @override
  State<_HomeFeaturedStory> createState() => _HomeFeaturedStoryState();
}

class _HomeFeaturedStoryState extends State<_HomeFeaturedStory> {
  bool _thumbnailFailed = false;

  @override
  void didUpdateWidget(covariant _HomeFeaturedStory oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.story.thumbnailUrl != widget.story.thumbnailUrl) {
      _thumbnailFailed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 768;
    final thumbnailWidth = isMobile ? 112.0 : 320.0;
    final thumbnailHeight = isMobile ? 102.0 : 180.0;
    final story = widget.story;
    final foreground = widget.foreground;
    final muted = widget.muted;
    final thumbnailUrl = story.thumbnailUrl.trim();
    Widget thumbnail() {
      return SizedBox(
        width: thumbnailWidth,
        height: thumbnailHeight,
        child: NetworkThumbnail(
          imageUrl: thumbnailUrl,
          fit: BoxFit.cover,
          borderRadius: BorderRadius.circular(10),
          loadingWidget: DecoratedBox(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF1F5F9),
            ),
          ),
          errorWidget: const SizedBox.shrink(),
          onError: () {
            if (mounted) setState(() => _thumbnailFailed = true);
          },
        ),
      );
    }

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: SizedBox.expand(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (!isMobile &&
                        thumbnailUrl.isNotEmpty &&
                        !_thumbnailFailed) ...[
                      thumbnail(),
                      const SizedBox(width: 18),
                    ],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  '${story.isIssue ? '메인 이슈' : '주요 뉴스'}${story.category.trim().isEmpty ? '' : ' · ${story.category}'}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      color: Color(0xFF2563EB),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(story.time,
                                  style: TextStyle(color: muted, fontSize: 11)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            story.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: foreground,
                                fontSize: isMobile ? 18 : 20,
                                height: 1.28,
                                fontWeight: FontWeight.w700),
                          ),
                          if (story.summary.trim().isNotEmpty) ...[
                            const SizedBox(height: 7),
                            Text(
                              story.summary.trim(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: muted, fontSize: 12.5, height: 1.4),
                            ),
                          ],
                          const Spacer(),
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  story.meta.trim(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(color: muted, fontSize: 11),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                story.actionLabel,
                                style: const TextStyle(
                                  color: Color(0xFF2563EB),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 3),
                              const Icon(
                                Icons.arrow_forward_rounded,
                                size: 14,
                                color: Color(0xFF2563EB),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (isMobile &&
                        thumbnailUrl.isNotEmpty &&
                        !_thumbnailFailed) ...[
                      const SizedBox(width: 12),
                      thumbnail(),
                    ],
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

class _HomeSecondaryStory extends StatelessWidget {
  final _HomeStory story;
  final Color foreground;
  final Color muted;

  const _HomeSecondaryStory({
    required this.story,
    required this.foreground,
    required this.muted,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: story.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${story.category.isEmpty ? '뉴스' : story.category} · ${story.time}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    story.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: foreground,
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w700),
                  ),
                  if (story.meta.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(story.meta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: muted, size: 18),
          ],
        ),
      ),
    );
  }
}

class _HomeLiveArticleStory extends StatelessWidget {
  final int index;
  final TrendItem item;
  final Color foreground;
  final Color muted;
  final Color border;
  final VoidCallback onTap;

  const _HomeLiveArticleStory({
    required this.index,
    required this.item,
    required this.foreground,
    required this.muted,
    required this.border,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final title = item.koreanTitle;
    final summary = item.summaryKr.trim();
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 180 + (index * 35)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
          offset: Offset(0, 5 * (1 - value)),
          child: child,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration:
              BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                padding: const EdgeInsets.only(right: 10),
                decoration: BoxDecoration(
                  border: Border(
                    right: BorderSide(
                      color: index == 0
                          ? const Color(0xFF2563EB).withValues(alpha: 0.55)
                          : border,
                      width: index == 0 ? 2 : 1,
                    ),
                  ),
                ),
                child: Text(
                  _landingClockLabel(
                    _landingParseTimestamp(
                      item.published.isNotEmpty
                          ? item.published
                          : item.createdAt,
                    ),
                  ),
                  style: TextStyle(
                      color: index == 0 ? const Color(0xFF2563EB) : muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w700),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category.isEmpty ? '뉴스' : item.category,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: foreground,
                            fontSize: 14,
                            height: 1.32,
                            fontWeight: FontWeight.w700)),
                    if (summary.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(summary,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: muted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, color: muted, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _HomeMarketValue extends StatelessWidget {
  final _LandingMarketQuote quote;
  final Color foreground;
  final Color muted;
  final bool isMobile;

  const _HomeMarketValue({
    required this.quote,
    required this.foreground,
    required this.muted,
    required this.isMobile,
  });

  @override
  Widget build(BuildContext context) {
    final isPositive = quote.percentChange >= 0;
    final changeColor =
        isPositive ? const Color(0xFFDC2626) : const Color(0xFF2563EB);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tileSurface =
        dark ? const Color(0xFF16233A) : const Color(0xFFF8FAFC);
    final tileBorder = dark ? const Color(0xFF2A3B55) : const Color(0xFFE2E8F0);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 8),
      decoration: BoxDecoration(
        color: tileSurface,
        border: Border.all(color: tileBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                color: muted,
                fontSize: isMobile ? 11 : 11.5,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  _landingMarketPriceLabel(quote),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: foreground,
                      fontSize: isMobile ? 14 : 15,
                      fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: 5),
              Text(
                _landingFormatPercent(quote.percentChange),
                style: TextStyle(
                    color: changeColor,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: SizedBox(
              width: double.infinity,
              child: quote.chartData.length > 1
                  ? _LandingSparkline(
                      values: quote.chartData, color: changeColor)
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _HomeNavItem(
      {required this.icon,
      required this.label,
      this.active = false,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = active
        ? const Color(0xFF2563EB)
        : (dark ? const Color(0xFF94A3B8) : const Color(0xFF64748B));
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: color, size: 21),
          const SizedBox(height: 2),
          Text(label,
              style: TextStyle(
                  color: color,
                  fontSize: 10.5,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w600)),
        ]),
      ),
    );
  }
}

class _LandingSectorDominanceRowData {
  final String label;
  final List<String> keywords;
  final double ratio;
  final String valueText;
  final String changeText;

  const _LandingSectorDominanceRowData(
    this.label,
    this.keywords, {
    this.ratio = 0,
    this.valueText = '',
    this.changeText = '',
  });

  bool matchesText(String keyword) {
    final lower = keyword.toLowerCase();
    return keywords.any((item) => lower.contains(item.toLowerCase()));
  }
}

class _LandingEditionHeadlineData {
  final String title;
  final String summary;
  final String category;
  final String meta;
  final EditionIssue? editionIssue;
  final IssueTimelineItem? timelineItem;
  final TrendItem? newsItem;

  const _LandingEditionHeadlineData({
    required this.title,
    required this.summary,
    required this.category,
    required this.meta,
    this.editionIssue,
    this.timelineItem,
    this.newsItem,
  });
}

class _LandingMarketRankRow extends StatelessWidget {
  final int rank;
  final _LandingMarketQuote quote;

  const _LandingMarketRankRow({
    required this.rank,
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final isPhone = width < 600;
    final up = quote.percentChange >= 0;
    final changeColor = quote.percentChange == 0
        ? (isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500)
        : up
            ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final priceTextColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final code = _landingFormatStockCode(quote.symbol);
    final naverUrl = _landingNaverFinanceUrl(quote);
    final updatedAt = quote.priceUpdatedAt;
    final ageMinutes = updatedAt == null
        ? null
        : DateTime.now().difference(updatedAt).inMinutes;
    final staleState = ageMinutes == null ? '시세 확인 중' : null;

    final badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: changeColor.withOpacity(isDark ? 0.18 : 0.10),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
            size: 13,
            color: changeColor,
          ),
          const SizedBox(width: 3),
          Text(
            _landingFormatPercent(quote.percentChange),
            style: TextStyle(
              fontSize: 10.8,
              fontWeight: FontWeight.w800,
              color: changeColor,
            ),
          ),
        ],
      ),
    );

    return _HoverButton(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: isPhone ? 10 : 12,
          vertical: isPhone ? 9 : 10,
        ),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border),
        ),
        child: isPhone
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 26,
                        child: Text(
                          rank.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 11.8,
                            fontWeight: FontWeight.w900,
                            color: isDark
                                ? Colors.grey.shade300
                                : Colors.blueGrey.shade500,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              quote.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: priceTextColor,
                              ),
                            ),
                            const SizedBox(height: 2),
                            if (naverUrl != null)
                              InkWell(
                                onTap: () =>
                                    _landingOpenExternalLink(context, naverUrl),
                                borderRadius: BorderRadius.circular(999),
                                child: Text(
                                  '실시간 시세 보기',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    color: isDark
                                        ? Colors.blue.shade100
                                        : const Color(0xFF2563EB),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerRight,
                              child: Text(
                                _landingFormatPrice(
                                  quote.currentPrice,
                                  marketType: 'kr',
                                  symbol: quote.symbol,
                                ),
                                maxLines: 1,
                                style: TextStyle(
                                  fontSize: 12.2,
                                  fontWeight: FontWeight.w800,
                                  color: priceTextColor,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                            badge,
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    updatedAt == null
                        ? '시간 확인 중'
                        : '${_landingFormatUpdatedAt(updatedAt)} 기준',
                    style: TextStyle(
                      fontSize: 9.4,
                      fontWeight: FontWeight.w600,
                      color: muted,
                    ),
                  ),
                  if (staleState != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      staleState,
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w600,
                        color: muted,
                      ),
                    ),
                  ],
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 34,
                    child: Text(
                      rank.toString().padLeft(2, '0'),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w900,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.blueGrey.shade500,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 11,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          quote.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.2,
                            fontWeight: FontWeight.w800,
                            color: priceTextColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          code,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        if (naverUrl != null) ...[
                          const SizedBox(height: 6),
                          InkWell(
                            onTap: () =>
                                _landingOpenExternalLink(context, naverUrl),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF172554)
                                    : const Color(0xFFEEF4FF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '실시간 시세 보기',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.blue.shade100
                                      : const Color(0xFF2563EB),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        badge,
                        const SizedBox(height: 3),
                        Text(
                          '24시간 변동률',
                          style: TextStyle(
                            fontSize: 9.6,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerRight,
                          child: Text(
                            _landingFormatPrice(
                              quote.currentPrice,
                              marketType: 'kr',
                              symbol: quote.symbol,
                            ),
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: priceTextColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          updatedAt == null
                              ? '시간 확인 중'
                              : '${_landingFormatUpdatedAt(updatedAt)} 기준',
                          style: TextStyle(
                            fontSize: 9.8,
                            fontWeight: FontWeight.w600,
                            color: muted,
                          ),
                        ),
                        if (staleState != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            staleState,
                            style: TextStyle(
                              fontSize: 9.2,
                              fontWeight: FontWeight.w600,
                              color: muted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _LandingMarketRankPlaceholderRow extends StatelessWidget {
  final int rank;
  final String title;

  const _LandingMarketRankPlaceholderRow({
    required this.rank,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 34,
            child: Text(
              rank.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.2,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '시세 확인 중',
                  style: TextStyle(
                    fontSize: 9.8,
                    fontWeight: FontWeight.w600,
                    color: muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '대기',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: muted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingFooterBrandBlock extends StatelessWidget {
  const _LandingFooterBrandBlock();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final bodyColor = isDark ? Colors.grey.shade400 : Colors.blueGrey.shade600;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(6)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 26,
              height: 26,
              fit: BoxFit.cover,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Pulse',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: titleColor,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '뉴스와 시장 흐름을 빠르게 확인합니다.',
              style: TextStyle(
                fontSize: 11.5,
                color: bodyColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _LandingHeaderFxStrip extends StatelessWidget {
  final List<_LandingMarketQuote> quotes;

  const _LandingHeaderFxStrip({
    required this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);
    final surface = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            for (int i = 0; i < quotes.take(4).length; i++) ...[
              _LandingHeaderFxItem(quote: quotes[i]),
              if (i != quotes.take(4).length - 1)
                Container(
                  width: 1,
                  height: 18,
                  margin: const EdgeInsets.symmetric(horizontal: 10),
                  color: border,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LandingHeaderFxInlineBar extends StatelessWidget {
  final List<_LandingMarketQuote> quotes;

  const _LandingHeaderFxInlineBar({
    required this.quotes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE5E7EB);

    String shortLabel(String title) {
      switch (title) {
        case 'USD/KRW':
          return 'USD';
        case 'JPY/KRW':
          return 'JPY';
        case 'EUR/KRW':
          return 'EUR';
        case 'CNY/KRW':
          return 'CNY';
        default:
          return title;
      }
    }

    String shortPrice(_LandingMarketQuote quote) {
      if (quote.title == 'USD/KRW' ||
          quote.title == 'JPY/KRW' ||
          quote.title == 'CNY/KRW') {
        return _landingFormatNumber(quote.currentPrice, decimals: 0);
      }
      if (quote.title == 'EUR/KRW') {
        return _landingFormatNumber(quote.currentPrice, decimals: 0);
      }
      return _landingMarketPriceLabel(quote);
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < quotes.take(2).length; i++) ...[
            Builder(
              builder: (context) {
                final quote = quotes[i];
                final changeColor = quote.percentChange == 0
                    ? muted
                    : quote.percentChange > 0
                        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
                        : (isDark
                            ? Colors.blue.shade300
                            : Colors.blue.shade600);
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shortLabel(quote.title),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: muted,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      shortPrice(quote),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _landingFormatPercent(quote.percentChange),
                      style: TextStyle(
                        fontSize: 9.8,
                        fontWeight: FontWeight.w800,
                        color: changeColor,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (i != quotes.take(4).length - 1) ...[
              const SizedBox(width: 10),
              Container(
                width: 1,
                height: 12,
                color: border,
              ),
              const SizedBox(width: 10),
            ],
          ],
        ],
      ),
    );
  }
}

class _LandingHeaderFxItem extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingHeaderFxItem({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final changeColor = quote.percentChange == 0
        ? muted
        : quote.percentChange > 0
            ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
            : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          quote.title,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: muted,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _landingMarketPriceLabel(quote),
          style: TextStyle(
            fontSize: 11.8,
            fontWeight: FontWeight.w800,
            color: textColor,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          _landingFormatPercent(quote.percentChange),
          style: TextStyle(
            fontSize: 10.8,
            fontWeight: FontWeight.w800,
            color: changeColor,
          ),
        ),
      ],
    );
  }
}

class _LandingMarketSummaryCard extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingMarketSummaryCard({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 900;
    final isPhone = width < 600;
    final up = quote.percentChange >= 0;
    final accent = up
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final surface = isDark ? const Color(0xFF0F172A) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF5);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final formattedPrice = _landingMarketPriceLabel(quote);
    final updatedAt = quote.priceUpdatedAt;
    final ageMinutes = updatedAt == null
        ? null
        : DateTime.now().difference(updatedAt).inMinutes;
    final staleState = ageMinutes == null
        ? '시세 확인 중'
        : ageMinutes > 30
            ? '시세 지연 가능'
            : ageMinutes > 10
                ? '시세 지연 가능'
                : null;
    final stageLine = staleState != null
        ? '${_landingMarketStageLabel(quote)} · $staleState'
        : updatedAt != null
            ? '${_landingMarketStageLabel(quote)} · ${_landingFormatUpdatedAt(updatedAt)} 기준'
            : _landingMarketStageLabel(quote);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 10,
        vertical: compact ? 6 : 7,
      ),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 11.4 : 12.0,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          SizedBox(height: compact ? 2 : 3),
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    formattedPrice,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: compact ? 15.4 : 17.0,
                      fontWeight: FontWeight.w900,
                      color: textColor,
                    ),
                  ),
                ),
              ),
              SizedBox(width: compact ? 6 : 8),
              Flexible(
                fit: FlexFit.loose,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        up
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: compact ? 12 : 13,
                        color: accent,
                      ),
                      SizedBox(width: compact ? 2 : 3),
                      Text(
                        _landingFormatPercent(quote.percentChange),
                        style: TextStyle(
                          fontSize: compact ? 10.1 : 10.8,
                          fontWeight: FontWeight.w800,
                          color: accent,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: compact ? 2 : 3),
          Text(
            stageLine,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: compact ? 8.8 : 9.4,
              fontWeight: FontWeight.w700,
              color: muted,
            ),
          ),
          SizedBox(height: compact ? 4 : 6),
          SizedBox(
            height: compact ? 14 : 18,
            child: _LandingSparkline(
              values: quote.chartData,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _LandingExchangeRateRow extends StatelessWidget {
  final _LandingMarketQuote quote;

  const _LandingExchangeRateRow({
    required this.quote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isPhone = MediaQuery.sizeOf(context).width < 600;
    final up = quote.percentChange >= 0;
    final accent = up
        ? (isDark ? Colors.red.shade300 : Colors.red.shade600)
        : (isDark ? Colors.blue.shade300 : Colors.blue.shade600);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;
    final deltaValue = quote.currentPrice * quote.percentChange / 100;
    final deltaLabel =
        '${deltaValue >= 0 ? '+' : ''}${_landingFormatNumber(deltaValue.abs(), decimals: 2)}원';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: isPhone
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        quote.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _landingMarketPriceLabel(quote),
                        textAlign: TextAlign.right,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13.2,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          up
                              ? Icons.arrow_upward_rounded
                              : Icons.arrow_downward_rounded,
                          size: 12,
                          color: accent,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          _landingFormatPercent(quote.percentChange),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      '전일 대비 $deltaLabel',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      quote.priceUpdatedAt == null
                          ? '기준 시각 --:--'
                          : '${_landingFormatUpdatedAt(quote.priceUpdatedAt)} 기준',
                      style: TextStyle(
                        color: muted,
                        fontSize: 9.6,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Row(
              children: [
                SizedBox(
                  width: 88,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        quote.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: textColor,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        '전일 대비',
                        style: TextStyle(
                          color: muted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _landingMarketPriceLabel(quote),
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      color: textColor,
                      fontSize: 14.0,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      up
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 13,
                      color: accent,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      _landingFormatPercent(quote.percentChange),
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 8),
                Text(
                  '전일 대비 $deltaLabel',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  quote.priceUpdatedAt == null
                      ? '기준 시각 --:--'
                      : '${_landingFormatUpdatedAt(quote.priceUpdatedAt)} 기준',
                  style: TextStyle(
                    color: muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }
}

class _LandingDominanceRow extends StatelessWidget {
  final String label;
  final String valueText;
  final String changeText;
  final double ratio;

  const _LandingDominanceRow({
    required this.label,
    required this.valueText,
    required this.changeText,
    required this.ratio,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final muted = isDark ? Colors.grey.shade300 : Colors.blueGrey.shade500;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                color: textColor,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              changeText,
              style: TextStyle(
                color: muted,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            minHeight: 5,
            value: ratio.clamp(0.0, 1.0),
            backgroundColor:
                isDark ? const Color(0xFF1F2937) : const Color(0xFFE8EEF7),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2563EB)),
          ),
        ),
      ],
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
