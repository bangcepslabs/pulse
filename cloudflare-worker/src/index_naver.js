/**
 * Cloudflare Workers - 트렌드 수집 및 실시간 증시 API
 * Version: 6.0.1 (News AI + Fear/Greed + Yahoo Finance)
 */
const NAVER_CATEGORIES = {
  '경제': '경제',
  '세계': '세계',
  '사회': '사회',
  '정치': '정치',
  '생활/문화': '생활/문화',
  'IT/과학': 'IT',
};

const CATEGORY_SEARCH_TERMS = {
  '경제': ['경제', '주식', '증시', '환율', '금리', '코스피', '코스닥', '미국증시', '기업실적', '실적발표', '달러', '채권'],
  '세계': ['세계', '국제', '미국', '중국', '유럽'],
  '사회': ['사회', '사건', '사고', '범죄', '재난'],
  '정치': ['정치', '국회', '대통령', '선거', '법안'],
  '생활/문화': ['생활', '문화', '연예', '영화', '공연', '전시'],
  'IT/과학': ['IT', 'AI', '반도체', '삼성', '애플'],
};

const MAX_SEARCH_TERMS_PER_RUN = 2;
const MAX_ARTICLE_AGE_HOURS = 12;
const GROQ_MAX_TOKENS = 320;
const NAVER_DISPLAY_COUNT = 30;
const AI_ANALYSIS_INTERVAL_MINUTES = 15;
const MAX_AI_ANALYSIS_PER_CYCLE = 1;
const MAX_CANDIDATE_ATTEMPTS = 3;
const CANDIDATE_LOOKBACK_HOURS = 24;
const MAX_ISSUE_TITLE_GENERATIONS_PER_CYCLE = 2;
const TRACKED_ISSUE_MATCH_WINDOW_HOURS = 48;
const TRACKED_ISSUE_FINGERPRINT_BUCKET_HOURS = 12;
const TRACKED_ISSUE_MIN_WAVE_GAP_MINUTES = 30;
const ISSUE_TIMELINE_TREND_LIMIT = 300;
const ISSUE_TIMELINE_WINDOWS = [
  { period: '1h', hours: 1 },
  { period: '6h', hours: 6 },
  { period: '24h', hours: 24 },
];

const VALID_CATEGORIES = ['경제', '세계', '사회', '정치', '생활/문화', 'IT/과학'];
const ANALYSIS_SLOT_MS = AI_ANALYSIS_INTERVAL_MINUTES * 60 * 1000;
const MARKET_DATA_CACHE_TTL_MS = 45 * 1000;
const SUPABASE_GET_CACHE_TTL_MS = 45 * 1000;
const MARKET_DATA_CACHE = new Map();
const PUBLIC_RATE_LIMIT_WINDOW_MS = 60 * 1000;
const PUBLIC_RATE_LIMIT_BUCKETS = new Map();
const SECURITY_RESPONSE_HEADERS = {
  'X-Content-Type-Options': 'nosniff',
  'X-Frame-Options': 'DENY',
  'Referrer-Policy': 'no-referrer',
  'X-Robots-Tag': 'noindex, nofollow',
  'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
};

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
    }

    const rateLimitResult = enforcePublicRateLimit(request, path, corsHeaders);
    if (rateLimitResult) {
      return rateLimitResult;
    }

    try {
      if (path === '/' || path === '') {
        return jsonResponse({
          message: 'Trend API',
          version: '6.0.1',
          status: 'healthy',
        }, corsHeaders);
      }

      if (path === '/api/trends') {
        return await handleGetTrends(url, env, corsHeaders);
      }

      if (path === '/api/trends/keywords' && request.method === 'GET') {
        return await handleGetTrendKeywords(url, env, corsHeaders);
      }

      if (path === '/api/trends/rising' && request.method === 'GET') {
        return await handleGetRisingIssues(url, env, corsHeaders);
      }

      if (path === '/api/trends/sentiment' && request.method === 'GET') {
        return await handleGetTrendSentiment(url, env, corsHeaders);
      }

      if (path === '/api/trend/timeline' && request.method === 'GET') {
        return await handleGetTrendTimeline(url, env, corsHeaders);
      }

      if (path === '/api/edition/today' && request.method === 'GET') {
        return await handleGetDailyEdition(url, env, corsHeaders);
      }

      if (path.match(/^\/api\/trend\/timeline\/[^/]+\/news$/) && request.method === 'GET') {
        const issueId = path.split('/')[4];
        return await handleGetIssueTimelineNews(url, issueId, env, corsHeaders);
      }

      if (path === '/api/news/search' && request.method === 'GET') {
        return await handleSearchNews(url, env, corsHeaders);
      }

      if (path === '/api/news/by-keyword' && request.method === 'GET') {
        return await handleGetNewsByKeyword(url, env, corsHeaders);
      }

      if (path.match(/^\/api\/trends\/\d+$/)) {
        const id = parseInt(path.split('/').pop(), 10);
        return await handleGetTrendDetail(id, env, corsHeaders);
      }

      if (path === '/api/scheduler/trigger' && request.method === 'POST') {
        return await handleTriggerCollection(request, env, corsHeaders);
      }

      if (path === '/api/fear-and-greed' && request.method === 'GET') {
        return await handleGetFearAndGreed(corsHeaders);
      }

      if (path === '/api/fear-greed/stock' && request.method === 'GET') {
        return await handleGetStockFearGreed(corsHeaders);
      }

      if (path === '/api/fear-greed/crypto' && request.method === 'GET') {
        return await handleGetCryptoFearGreed(corsHeaders);
      }

      if (path === '/api/fear-greed/stock/ai-score' && request.method === 'GET') {
        return await handleGetAiStockSentiment(url, env, corsHeaders);
      }

      if (path === '/api/market-data' && request.method === 'GET') {
        return await handleGetMarketData(url, corsHeaders);
      }

      if (path === '/api/chart-data' && request.method === 'GET') {
        return await handleGetChartData(url, corsHeaders);
      }

      if (path === '/api/debug/latest' && request.method === 'GET') {
        if (!isDebugEndpointEnabled(env)) {
          return jsonResponse({ error: 'Not found' }, corsHeaders, 404);
        }
        const { data } = await querySupabase(
          env,
          'trends?select=id,korean_title,category,importance,created_at&order=id.desc&limit=5'
        );

        return jsonResponse({ latest_by_id: data || [] }, { ...corsHeaders, 'Cache-Control': 'no-store' });
      }

      return jsonResponse({ error: 'Not found' }, corsHeaders, 404);
    } catch (error) {
      console.error('Fetch Error:', error);
      return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
  },

  async scheduled(event, env, ctx) {

    if (!env.SUPABASE_URL || !env.SUPABASE_ANON_KEY || !env.SUPABASE_SERVICE_ROLE_KEY || !env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET) {
      console.error('Missing required environment variables!');
      return;
    }

    try {
      const result = await runNewsCollectionCycle(env);
    } catch (error) {
      console.error('Cron job failed:', error.message);
    }
  },
};

// ─────────────────────────────────────────────────
// API 핸들러
// ─────────────────────────────────────────────────

async function handleGetTrends(url, env, corsHeaders) {
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '20', 10), 1, 50);
  const offset = Math.max(parseInt(url.searchParams.get('offset') || '0', 10), 0);
  const category = url.searchParams.get('category') || '';
  const sort = normalizeSort(url.searchParams.get('sort') || 'latest');
  const period = normalizePeriod(url.searchParams.get('period') || '');

  const query = 'id,korean_title,summary_kr,importance,main_worthiness,tickers,category,link,source,thumbnail_url,published,created_at,view_count';
  const filters = category ? `&category=eq.${encodeURIComponent(category)}` : '';
  const periodFilter = buildPeriodFilter(period);
  const order = buildTrendOrder(sort);

  const { data, error } = await querySupabase(
    env,
    `trends?select=${query}${filters}${periodFilter}&order=${order}&limit=${limit}&offset=${offset}`
  );

  if (error) throw new Error(error.message || 'Failed to fetch trends');

  return jsonResponse({
    success: true,
    count: data.length,
    offset,
    category,
    sort,
    period,
    has_more: data.length === limit,
    data: data.map(row => ({
      ...row,
      tickers: row.tickers ? row.tickers.split(',').filter(Boolean) : [],
    })),
  }, corsHeaders);
}

async function handleGetTrendDetail(id, env, corsHeaders) {
  if (!id || Number.isNaN(id)) {
    return jsonResponse({ error: 'Invalid trend id' }, corsHeaders, 400);
  }

  const { data, error } = await querySupabase(env, `trends?id=eq.${id}`, 'GET', null, true);

  if (error || !data) {
    return jsonResponse({ error: 'Trend not found' }, corsHeaders, 404);
  }

  await querySupabase(env, `trends?id=eq.${id}`, 'PATCH', {
    view_count: (data.view_count || 0) + 1,
  });

  return jsonResponse({ success: true, data }, corsHeaders);
}

async function handleGetTrendKeywords(url, env, corsHeaders) {
  const period = normalizePeriod(url.searchParams.get('period') || '24h');
  const category = url.searchParams.get('category') || '';
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '10', 10), 1, 50);
  const hours = periodToHours(period);
  const trends = await getRecentTrends(env, hours, category, 500);
  const keywords = buildKeywordStats(trends)
    .slice(0, limit)
    .map((item, index) => ({
      keyword: item.keyword,
      category: item.category,
      newsCount: item.newsCount,
      rank: index + 1,
      score: item.score,
      representativeTitle: item.representativeTitle,
      sentimentTemperature: calculateSentimentTemperature(item.news),
    }));

  return jsonResponse({
    success: true,
    period,
    category,
    items: keywords,
  }, corsHeaders);
}

async function handleGetRisingIssues(url, env, corsHeaders) {
  const period = normalizePeriod(url.searchParams.get('period') || '1h');
  const category = url.searchParams.get('category') || '';
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '5', 10), 1, 30);
  const minCount = clampNumber(parseInt(url.searchParams.get('min_count') || '3', 10), 1, 20);
  const hours = periodToHours(period);
  const now = Date.now();
  const trends = await getRecentTrends(env, hours * 2, category, 800);

  const current = trends.filter(row => trendTimestamp(row) >= now - hours * 60 * 60 * 1000);
  const previous = trends.filter(row => {
    const time = trendTimestamp(row);
    return time >= now - hours * 2 * 60 * 60 * 1000 && time < now - hours * 60 * 60 * 1000;
  });

  const currentStats = buildKeywordStats(current);
  const previousStats = buildKeywordStats(previous);
  const previousMap = new Map(previousStats.map(item => [item.keyword, item.newsCount]));

  const items = currentStats
    .map(item => {
      const previousCount = previousMap.get(item.keyword) || 0;
      const increaseCount = item.newsCount - previousCount;
      const isNew = previousCount === 0;
      const growthRate = isNew
        ? 0
        : ((item.newsCount - previousCount) / previousCount) * 100;
      const score = increaseCount * Math.log(item.newsCount + 1) + (isNew ? 1 : 0);

      return {
        keyword: item.keyword,
        category: item.category,
        currentCount: item.newsCount,
        previousCount,
        increaseCount,
        isNew,
        growthRate: Math.round(growthRate),
        score: Math.round(score * 10) / 10,
        representativeTitle: item.representativeTitle,
        representativeNewsId: item.news[0]?.id || null,
      };
    })
    .filter(item =>
      item.currentCount >= minCount &&
      item.increaseCount >= 2 &&
      (item.isNew || item.growthRate >= 50)
    )
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  return jsonResponse({
    success: true,
    period,
    category,
    minCount,
    items,
  }, corsHeaders);
}

async function handleGetTrendSentiment(url, env, corsHeaders) {
  const period = normalizePeriod(url.searchParams.get('period') || '24h');
  const category = url.searchParams.get('category') || '';
  const keyword = normalizeKeyword(url.searchParams.get('keyword') || '');
  const trends = await getRecentTrends(env, periodToHours(period), category, 500);
  const filtered = keyword
    ? trends.filter(row => extractKeywordsFromTrend(row).includes(keyword))
    : trends;
  const sentiment = summarizeSentiment(filtered);

  return jsonResponse({
    success: true,
    period,
    category,
    keyword,
    ...sentiment,
  }, corsHeaders);
}

async function handleGetTrendTimeline(url, env, corsHeaders) {
  const period = normalizePeriod(url.searchParams.get('period') || '24h');
  const category = url.searchParams.get('category') || '';
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '10', 10), 1, 30);
  const minScore = clampNumber(parseInt(url.searchParams.get('min_score') || '0', 10), 0, 100);

  const filters = [
    `period=eq.${encodeURIComponent(period)}`,
    category ? `category=eq.${encodeURIComponent(category)}` : '',
    `score=gte.${minScore}`,
  ].filter(Boolean);
  const endpoint = `issue_clusters?select=id,period,category,canonical_keyword,representative_title,issue_title,summary,article_count,source_count,growth_rate,score,sentiment_temperature,stage,first_seen_at,last_seen_at,created_at,updated_at&${filters.join('&')}&order=score.desc,last_seen_at.desc&limit=${limit}`;
  const { data, error } = await querySupabase(env, endpoint);

  if (error) {
    throw new Error(error.message || 'Failed to fetch trend timeline');
  }

  let items = (data || []).map((row, index) => ({
    id: row.id,
    rank: index + 1,
    period: row.period,
    category: row.category,
    keyword: row.canonical_keyword || '',
    title: row.issue_title || row.representative_title || '',
    representativeTitle: row.representative_title || '',
    summary: row.summary || '',
    articleCount: row.article_count || 0,
    sourceCount: row.source_count || 0,
    growthRate: Number(row.growth_rate || 0),
    score: Number(row.score || 0),
    sentimentTemperature: row.sentiment_temperature == null ? null : Number(row.sentiment_temperature),
    stage: row.stage || 'rising',
    firstSeenAt: row.first_seen_at || row.created_at || '',
    lastSeenAt: row.last_seen_at || row.updated_at || row.created_at || '',
    newsIds: [],
    countsVerified: false,
    thumbnailUrl: '',
  }));

  if (items.length === 0) {
    items = await buildLiveTrendTimelineFromTrends(env, period, category, limit, minScore);
  }

  if (items.length > 0) {
    const issueIds = items.map(item => String(item.id)).filter(Boolean);
    const { data: mappingRows } = await querySupabase(
      env,
      `issue_cluster_articles?select=issue_cluster_id,news_id&issue_cluster_id=in.(${issueIds.join(',')})&order=created_at.desc`
    );

    const mappingMap = new Map();
    for (const row of mappingRows || []) {
      const key = String(row.issue_cluster_id || '');
      if (!key) continue;
      if (!mappingMap.has(key)) {
        mappingMap.set(key, []);
      }
      mappingMap.get(key).push(Number(row.news_id));
    }

    items = items.map(item => ({
      ...item,
      newsIds: Array.from(new Set([
        ...(Array.isArray(item.newsIds) ? item.newsIds : []),
        ...(mappingMap.get(String(item.id)) || []),
      ])).filter(value => Number.isFinite(value) && value > 0),
    }));
  }

  return jsonResponse({
    success: true,
    period,
    category,
    limit,
    items,
  }, corsHeaders);
}

async function handleGetDailyEdition(url, env, corsHeaders) {
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '6', 10), 3, 9);
  const period = '24h';

  const filters = [
    `period=eq.${encodeURIComponent(period)}`,
    'score=gte.45',
  ];

  const endpoint =
    `issue_clusters?select=id,period,category,canonical_keyword,representative_title,issue_title,summary,article_count,source_count,growth_rate,score,sentiment_temperature,stage,first_seen_at,last_seen_at,created_at,updated_at&${filters.join('&')}&order=score.desc,last_seen_at.desc&limit=24`;
  const { data, error } = await querySupabase(env, endpoint);

  if (error) {
    throw new Error(error.message || 'Failed to fetch daily edition');
  }

  let items = (data || []).map((row) => ({
    id: row.id,
    rank: 0,
    period: row.period,
    category: row.category,
    keyword: row.canonical_keyword || '',
    title: row.issue_title || row.representative_title || '',
    representativeTitle: row.representative_title || '',
    summary: row.summary || '',
    articleCount: row.article_count || 0,
    sourceCount: row.source_count || 0,
    growthRate: Number(row.growth_rate || 0),
    score: Number(row.score || 0),
    sentimentTemperature: row.sentiment_temperature == null ? null : Number(row.sentiment_temperature),
    stage: row.stage || 'rising',
    firstSeenAt: row.first_seen_at || row.created_at || '',
    lastSeenAt: row.last_seen_at || row.updated_at || row.created_at || '',
    newsIds: [],
    countsVerified: false,
    thumbnailUrl: '',
  }));

  if (items.length === 0) {
    items = await buildLiveTrendTimelineFromTrends(env, period, '', 18, 45);
  }

  if (items.length > 0) {
    const issueIds = items.map(item => String(item.id)).filter(Boolean);
    const { data: mappingRows, error: mappingError } = await querySupabaseAdmin(
      env,
      `issue_cluster_articles?select=issue_cluster_id,news_id&issue_cluster_id=in.(${issueIds.join(',')})&order=similarity_score.desc,created_at.desc`
    );
    if (mappingError) {
      console.error(`[Issue diagnostics] mapping read failed: ${mappingError.message || ''}`);
    }

    const mappingMap = new Map();
    for (const row of mappingRows || []) {
      const key = String(row.issue_cluster_id || '');
      if (!key) continue;
      if (!mappingMap.has(key)) {
        mappingMap.set(key, []);
      }
      mappingMap.get(key).push(Number(row.news_id));
    }

    items = items.map(item => ({
      ...item,
      newsIds: Array.from(new Set([
        ...(Array.isArray(item.newsIds) ? item.newsIds : []),
        ...(mappingMap.get(String(item.id)) || []),
      ]))
        .filter(value => Number.isFinite(value) && value > 0),
    }));

    const newsIds = Array.from(new Set(
      items.flatMap(item => Array.isArray(item.newsIds) ? item.newsIds : [])
    ));
    if (newsIds.length > 0) {
      const { data: articleRows, error: articleError } = await querySupabaseAdmin(
        env,
        `trends?select=id,source,link,thumbnail_url&id=in.(${newsIds.join(',')})`
      );

      if (!articleError) {
        const articleById = new Map(
          (articleRows || []).map(row => [
            Number(row.id),
            {
              source: String(row.source || '').trim().toLowerCase(),
              key: normalizeLink(row.link) || `id:${Number(row.id)}`,
              thumbnailUrl: String(row.thumbnail_url || '').trim(),
            },
          ])
        );
        items = items.map(item => {
          const seenArticleKeys = new Set();
          const resolvedNewsIds = item.newsIds.filter(id => {
            const article = articleById.get(Number(id));
            if (!article || seenArticleKeys.has(article.key)) {
              return false;
            }
            seenArticleKeys.add(article.key);
            return true;
          });
          const sources = new Set(
            resolvedNewsIds
              .map(id => articleById.get(Number(id))?.source)
              .filter(Boolean)
          );
          const thumbnailUrl = resolvedNewsIds
            .map(id => articleById.get(Number(id))?.thumbnailUrl)
            .find(Boolean) || '';
          return {
            ...item,
            newsIds: resolvedNewsIds,
            articleCount: resolvedNewsIds.length,
            sourceCount: sources.size,
            countsVerified: resolvedNewsIds.length > 0,
            thumbnailUrl,
          };
        });
      }
    }
  }

  const ranked = selectDailyEditionIssues(items, limit);
  const currentCountsByClusterId = new Map(ranked.map(item => [
    String(item.id),
    {
      articleCount: item.countsVerified ? item.articleCount : null,
      sourceCount: item.countsVerified ? item.sourceCount : null,
    },
  ]));
  const timelinesByClusterId = await getIssueTimelinesForClusters(
    ranked.map(item => item.id),
    env,
    currentCountsByClusterId,
  );
  const publishedAt = new Date().toISOString();
  const issueCount = ranked.length;
  const readingMinutes = clampNumber(Math.round(issueCount * 1.4 + 2), 3, 8);

  return jsonResponse({
    success: true,
    editionDate: publishedAt.slice(0, 10),
    publishedAt,
    issueCount,
    readingMinutes,
    topIssues: ranked.map((item, index) => ({
      id: item.id,
      rank: index + 1,
      category: item.category,
      keyword: item.keyword,
      title: item.title,
      summary: item.summary,
      articleCount: item.countsVerified ? item.articleCount : 0,
      sourceCount: item.countsVerified ? item.sourceCount : 0,
      newsIds: item.newsIds || [],
      countsVerified: item.countsVerified === true,
      thumbnailUrl: item.thumbnailUrl || '',
      score: item.score,
      stage: item.stage,
      lastSeenAt: item.lastSeenAt,
      timeline: normalizeIssueTimelineForCurrentCounts(
        timelinesByClusterId.get(String(item.id)) || [],
        item.countsVerified ? item.articleCount : null,
        item.countsVerified ? item.sourceCount : null,
      ),
      selectionReason: buildEditionSelectionReason(item),
    })),
  }, corsHeaders);
}

function normalizeIssueTimelineForCurrentCounts(timeline, currentArticleCount, currentSourceCount) {
  return (timeline || []).map(event => {
    let description = String(event.description || '');
    let context = String(event.context || '');
    if (Number.isFinite(currentArticleCount) && currentArticleCount >= 0) {
      description = description.replace(/(관련 기사(?:가)?\s+)(\d+)(건)/u, (_, prefix, count, suffix) =>
        `${prefix}${Math.min(Number(count), currentArticleCount)}${suffix}`
      );
    }
    if (Number.isFinite(currentSourceCount) && currentSourceCount >= 0) {
      context = context.replace(/(출처\s+)(\d+)(곳)/u, (_, prefix, count, suffix) =>
        `${prefix}${Math.min(Number(count), currentSourceCount)}${suffix}`
      );
    }
    return {
      ...event,
      description,
      ...(context ? { context } : {}),
    };
  }).filter((event, index, events) => {
    const key = `${event.description}|${event.context || ''}`;
    return events.findIndex(item => `${item.description}|${item.context || ''}` === key) === index;
  });
}

async function getIssueTimelinesForClusters(clusterIds, env, currentCountsByClusterId = new Map()) {
  const result = new Map();
  const ids = Array.from(new Set((clusterIds || []).map(id => String(id || '')).filter(Boolean)));
  if (ids.length === 0) return result;

  const { data: currentSnapshots, error: currentError } = await querySupabaseAdmin(
    env,
    `tracked_issue_snapshots?select=tracked_issue_id,issue_cluster_id&issue_cluster_id=in.(${ids.join(',')})&order=observed_at.desc&limit=300`,
  );
  if (currentError || !currentSnapshots?.length) return result;

  const trackedIssueByClusterId = new Map();
  for (const snapshot of currentSnapshots) {
    const clusterId = String(snapshot.issue_cluster_id || '');
    const trackedIssueId = String(snapshot.tracked_issue_id || '');
    if (clusterId && trackedIssueId && !trackedIssueByClusterId.has(clusterId)) {
      trackedIssueByClusterId.set(clusterId, trackedIssueId);
    }
  }
  const trackedIssueIds = Array.from(new Set(trackedIssueByClusterId.values()));
  if (trackedIssueIds.length === 0) return result;

  const { data: snapshots, error: historyError } = await querySupabaseAdmin(
    env,
    `tracked_issue_snapshots?select=tracked_issue_id,observed_at,article_count,source_count,stage,first_seen_at,last_seen_at,snapshot_fingerprint&tracked_issue_id=in.(${trackedIssueIds.join(',')})&order=observed_at.asc&limit=1000`,
  );
  if (historyError) return result;

  const snapshotsByTrackedIssueId = new Map();
  for (const snapshot of snapshots || []) {
    const trackedIssueId = String(snapshot.tracked_issue_id || '');
    if (!trackedIssueId) continue;
    if (!snapshotsByTrackedIssueId.has(trackedIssueId)) snapshotsByTrackedIssueId.set(trackedIssueId, []);
    snapshotsByTrackedIssueId.get(trackedIssueId).push(snapshot);
  }
  for (const [clusterId, trackedIssueId] of trackedIssueByClusterId.entries()) {
    const currentCounts = currentCountsByClusterId.get(clusterId) || {};
    result.set(clusterId, buildIssueTimelineEvents(
      snapshotsByTrackedIssueId.get(trackedIssueId) || [],
      currentCounts.articleCount,
      currentCounts.sourceCount,
    ));
  }
  return result;
}

function buildIssueTimelineEvents(snapshots, currentArticleCount = null, currentSourceCount = null) {
  const grouped = new Map();
  for (const snapshot of snapshots || []) {
    const occurredAt = snapshot.last_seen_at || snapshot.observed_at || '';
    const key = occurredAt || `snapshot:${grouped.size}`;
    const existing = grouped.get(key);
    if (!existing) {
      grouped.set(key, { ...snapshot });
      continue;
    }

    // 한 refresh cycle에서 같은 시각에 여러 snapshot이 생길 수 있다.
    // 해당 시각에는 가장 큰 기사·출처 수만 남겨 중복 이벤트를 방지한다.
    if (Number(snapshot.article_count || 0) >= Number(existing.article_count || 0)) {
      existing.article_count = snapshot.article_count;
      existing.snapshot_fingerprint = snapshot.snapshot_fingerprint;
    }
    if (Number(snapshot.source_count || 0) > Number(existing.source_count || 0)) {
      existing.source_count = snapshot.source_count;
    }
  }

  const events = [];
  let previousArticleCount = 0;
  let previousSourceCount = 0;
  let previousKey = '';
  for (const snapshot of grouped.values()) {
    const rawArticleCount = Number(snapshot.article_count || 0);
    const rawSourceCount = Number(snapshot.source_count || 0);
    const articleCount = Number.isFinite(currentArticleCount) && currentArticleCount >= 0
      ? Math.min(rawArticleCount, currentArticleCount)
      : rawArticleCount;
    const sourceCount = Number.isFinite(currentSourceCount) && currentSourceCount >= 0
      ? Math.min(rawSourceCount, currentSourceCount)
      : rawSourceCount;
    let description = '';
    let context = '';
    if (previousArticleCount === 0 && previousSourceCount === 0) {
      if (articleCount > 0) description = `관련 기사 ${articleCount}건으로 이슈 포착`;
      if (sourceCount > 0) context = `출처 ${sourceCount}곳`;
    } else if (articleCount > previousArticleCount) {
      description = `관련 기사가 ${articleCount}건으로 증가`;
      if (sourceCount > previousSourceCount) context = `출처 ${sourceCount}곳으로 확대`;
    } else if (sourceCount > previousSourceCount) {
      description = `보도 출처가 ${sourceCount}곳으로 확대`;
    }
    const eventKey = `${description}|${context}`;
    if (description && eventKey !== previousKey) {
      events.push({
        occurredAt: snapshot.last_seen_at || snapshot.observed_at || '',
        description,
        ...(context ? { context } : {}),
      });
      previousKey = eventKey;
    }
    // 24시간 창에서 기사·출처가 줄어도 timeline 기준점은 감소시키지 않는다.
    previousArticleCount = Math.max(previousArticleCount, articleCount);
    previousSourceCount = Math.max(previousSourceCount, sourceCount);
  }
  return events.slice(-5);
}

async function handleGetIssueTimelineNews(url, issueId, env, corsHeaders) {
  if (!issueId) {
    return jsonResponse({ success: false, error: 'Missing issue id' }, corsHeaders, 400);
  }

  let cleanIssueId = issueId.split('?')[0];
  try {
    cleanIssueId = decodeURIComponent(cleanIssueId);
  } catch (_) {}
  const keywordHint = normalizeSearchText(url.searchParams.get('keyword') || '');
  const newsIdsParam = String(url.searchParams.get('news_ids') || '').trim();

  if (newsIdsParam) {
    const requestedIds = newsIdsParam
      .split(',')
      .map(value => parseInt(value.trim(), 10))
      .filter(Number.isFinite);

    if (requestedIds.length > 0) {
      const { data: directTrends, error: directError } = await querySupabase(
        env,
        `trends?select=id,korean_title,original_title,summary_kr,importance,tickers,category,link,source,thumbnail_url,published,created_at,view_count&id=in.(${requestedIds.join(',')})&order=published.desc,created_at.desc`
      );

      if (directError) {
        throw new Error(directError.message || 'Failed to fetch issue news');
      }

      return jsonResponse({
        success: true,
        issueId: cleanIssueId,
        total: (directTrends || []).length,
        items: (directTrends || []).map((row) => ({
          ...row,
          tickers: row.tickers ? row.tickers.split(',').filter(Boolean) : [],
        })),
      }, corsHeaders);
    }
  }

  const { data: mapRows, error: mapError } = await querySupabaseAdmin(
    env,
    `issue_cluster_articles?select=news_id,similarity_score,created_at&issue_cluster_id=eq.${encodeURIComponent(cleanIssueId)}&order=similarity_score.desc,created_at.desc&limit=100`
  );

  if (mapError) {
    throw new Error(mapError.message || 'Failed to fetch issue articles');
  }

  const newsIds = (mapRows || [])
    .map((row) => row.news_id)
    .filter((value) => value !== null && value !== undefined)
    .join(',');

  if (!newsIds) {
    const { data: issueRows } = await querySupabaseAdmin(
      env,
      `issue_clusters?select=canonical_keyword,representative_title,summary,category&period=eq.${encodeURIComponent(url.searchParams.get('period') || '24h')}&id=eq.${encodeURIComponent(cleanIssueId)}`
    );

    const issueRow = Array.isArray(issueRows) ? issueRows[0] : null;
    const searchHints = [
      keywordHint,
      normalizeSearchText(issueRow?.canonical_keyword || ''),
    ].filter(Boolean);

    const trends = await getRecentTrends(env, 72, '', 1200);
    const matched = trends.filter(row => {
      const text = trendSearchText(row);
      if (searchHints.length === 0) {
        return false;
      }
      return searchHints.some(hint => {
        const parts = hint.split(/[·|,\/\s]+/g).map(part => normalizeSearchText(part)).filter(Boolean);
        if (parts.length === 0) {
          return text.includes(hint);
        }
        return parts.every(part => text.includes(part));
      });
    });

    return jsonResponse({
      success: true,
      issueId: cleanIssueId,
      total: matched.length,
      items: matched.map((row) => ({
        ...row,
        tickers: row.tickers ? row.tickers.split(',').filter(Boolean) : [],
      })),
    }, corsHeaders);
  }

  const { data: trends, error: trendsError } = await querySupabase(
    env,
    `trends?select=id,korean_title,original_title,summary_kr,importance,tickers,category,link,source,thumbnail_url,published,created_at,view_count&id=in.(${newsIds})&order=published.desc,created_at.desc`
  );

  if (trendsError) {
    throw new Error(trendsError.message || 'Failed to fetch issue news');
  }

  let resolvedTrends = trends || [];

  if (resolvedTrends.length < 2) {
    const { data: issueRows } = await querySupabase(
      env,
      `issue_clusters?select=canonical_keyword,representative_title,summary,category&id=eq.${encodeURIComponent(cleanIssueId)}`
    );

    const issueRow = Array.isArray(issueRows) ? issueRows[0] : null;
    const hints = [
      keywordHint,
      normalizeSearchText(issueRow?.canonical_keyword || ''),
    ].filter(Boolean);

    const trendsPool = await getRecentTrends(env, 72, '', 1200);
    const extraMatches = trendsPool.filter(row => {
      const text = trendSearchText(row);
      return hints.some(hint => {
        const parts = hint.split(/[·|,\/\s]+/g)
          .map(part => normalizeSearchText(part))
          .filter(Boolean);
        if (parts.length === 0) {
          return text.includes(hint);
        }
        return parts.every(part => text.includes(part));
      });
    });

    const merged = new Map();
    for (const row of resolvedTrends) {
      merged.set(row.id, row);
    }
    for (const row of extraMatches) {
      merged.set(row.id, row);
    }

    resolvedTrends = Array.from(merged.values())
      .sort((a, b) => trendTimestamp(b) - trendTimestamp(a));
  }

  return jsonResponse({
    success: true,
    issueId,
    total: resolvedTrends.length,
    items: resolvedTrends.map((row) => ({
      ...row,
      tickers: row.tickers ? row.tickers.split(',').filter(Boolean) : [],
    })),
  }, corsHeaders);
}

async function handleSearchNews(url, env, corsHeaders) {
  const query = normalizeSearchText(url.searchParams.get('q') || '');
  const category = url.searchParams.get('category') || '';
  const period = normalizePeriod(url.searchParams.get('period') || '24h');
  const sort = url.searchParams.get('sort') || 'latest';
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '20', 10), 1, 50);
  const page = Math.max(parseInt(url.searchParams.get('page') || '1', 10), 1);
  const trends = await getRecentTrends(env, periodToHours(period), category, 800);

  let results = query
    ? trends.filter(row => trendSearchText(row).includes(query))
    : trends;

  results = sortNewsResults(results, sort, query);
  const total = results.length;
  const items = results.slice((page - 1) * limit, page * limit).map(formatNewsItem);
  const suggestions = buildKeywordStats(results).slice(0, 8).map(item => item.keyword);

  return jsonResponse({
    success: true,
    query,
    category,
    period,
    sort,
    page,
    total,
    hasMore: page * limit < total,
    suggestions,
    items,
  }, corsHeaders);
}

async function handleGetNewsByKeyword(url, env, corsHeaders) {
  const keyword = normalizeKeyword(url.searchParams.get('keyword') || '');
  if (!keyword) {
    return jsonResponse({ success: false, error: 'Missing keyword' }, corsHeaders, 400);
  }

  const category = url.searchParams.get('category') || '';
  const period = normalizePeriod(url.searchParams.get('period') || '24h');
  const sort = url.searchParams.get('sort') || 'latest';
  const limit = clampNumber(parseInt(url.searchParams.get('limit') || '20', 10), 1, 50);
  const trends = await getRecentTrends(env, periodToHours(period), category, 800);
  const normalizedKeyword = normalizeSearchText(keyword);
  const matches = trends.filter(row =>
    extractKeywordsFromTrend(row).includes(keyword) ||
    trendSearchText(row).includes(normalizedKeyword)
  );
  const items = sortNewsResults(matches, sort, keyword).slice(0, limit).map(formatNewsItem);

  return jsonResponse({
    success: true,
    keyword,
    category,
    period,
    total: matches.length,
    items,
  }, corsHeaders);
}

async function handleTriggerCollection(request, env, corsHeaders) {

  if (!env.SCHEDULER_SECRET) {
    console.error('Missing SCHEDULER_SECRET');
    return jsonResponse({ success: false, error: 'Manual trigger is disabled' }, corsHeaders, 503);
  }

  const authorization = request.headers.get('Authorization') || '';
  const expectedAuthorization = `Bearer ${env.SCHEDULER_SECRET}`;
  if (authorization !== expectedAuthorization) {
    return jsonResponse({ success: false, error: 'Unauthorized' }, corsHeaders, 401);
  }

  if (!env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY || !env.SUPABASE_SERVICE_ROLE_KEY) {
    return jsonResponse({ success: false, error: 'Missing collection environment variables' }, corsHeaders, 500);
  }

  try {
    const result = await runNewsCollectionCycle(env);
    return jsonResponse({
      success: true,
      message: 'Collection completed',
      result,
      issueTimelineResult: result.issueTimeline,
    }, corsHeaders);
  } catch (error) {
    console.error('Trigger error:', error.message);
    return jsonResponse({ success: false, error: error.message }, corsHeaders, 500);
  }
}

// ─────────────────────────────────────────────────
// 핵심 수집 로직
// ─────────────────────────────────────────────────

async function runNewsCollectionCycle(env) {
  const collection = await collectAllNews(env);
  const analysis = env.GROQ_API_KEY
    ? await processPendingCandidate(env)
    : { ran: false, totalAnalyzed: 0, totalInserted: 0, reason: 'Missing GROQ_API_KEY' };
  /** @type {any} */
  let issueTimeline = { skipped: true, reason: 'Not an AI analysis cycle' };

  // Refresh on every scheduled AI cycle, not only after a new article insert.
  // This backfills persisted issue titles and keeps the current ephemeral
  // cluster IDs associated with their tracked issue snapshots.
  if (analysis.ran) {
    issueTimeline = await refreshIssueTimeline(env);
  }

  return { collection, analysis, issueTimeline };
}

async function collectAllNews(env) {
  const categories = Object.keys(NAVER_CATEGORIES);
  const now = new Date();

  const categoryIndex = Math.floor(now.getMinutes() / 5) % categories.length;
  const currentCategory = categories[categoryIndex];
  const allSearchTerms = CATEGORY_SEARCH_TERMS[currentCategory] || [NAVER_CATEGORIES[currentCategory]];
  const searchTermCount = currentCategory === '경제'
    ? Math.min(4, allSearchTerms.length)
    : MAX_SEARCH_TERMS_PER_RUN;
  const searchTerms = pickSearchTermsForThisRun(allSearchTerms, now, searchTermCount);


  let totalFetched = 0;
  let totalCandidates = 0;
  let totalQueued = 0;
  let totalPreFilterDiscarded = 0;
  let totalSkippedExisting = 0;

  const errors = [];

  try {
    const fetchedBuckets = [];

    for (const term of searchTerms) {
      const bucket = await fetchNaverNews(term, env, currentCategory === '경제' ? 15 : 10);
      fetchedBuckets.push(bucket);
    }

    const articleMap = new Map();

    for (const bucket of fetchedBuckets) {
      for (const article of bucket) {
        const key = normalizeLink(article.link) || normalizeTitle(article.title);

        if (!key) continue;

        if (!articleMap.has(key)) {
          articleMap.set(key, article);
        }
      }
    }

    let articles = Array.from(articleMap.values())
      .sort((a, b) => b.pubTimestamp - a.pubTimestamp || b.description.length - a.description.length);

    totalFetched = articles.length;


    if (articles.length === 0) {

      return {
        category: currentCategory,
        totalFetched: 0,
        totalCandidates: 0,
        totalQueued: 0,
        totalPreFilterDiscarded: 0,
        status: 'No articles found from Naver API',
      };
    }

    // 후보를 먼저 보존하고, AI 분석은 별도의 15분 cycle에서 수행한다.
    const existingLinks = await getRecentTrendLinks(env, 24);
    const existingCandidateLinks = await getRecentCandidateLinks(env, CANDIDATE_LOOKBACK_HOURS);

    articles = articles.filter(article => {
      const normalized = normalizeLink(article.link);

      if (normalized && (existingLinks.has(normalized) || existingCandidateLinks.has(normalized))) {
        totalSkippedExisting++;
        return false;
      }

      return true;
    });

    totalCandidates = articles.length;


    if (articles.length === 0) {
      return {
        category: currentCategory,
        totalFetched,
        totalCandidates: 0,
        totalQueued: 0,
        totalPreFilterDiscarded: 0,
        totalSkippedExisting,
        status: 'All articles already exist',
      };
    }

    const preparedCandidates = articles
      .map(article => buildNewsCandidate({ ...article, category: currentCategory }))
      .filter(Boolean);
    totalPreFilterDiscarded = articles.length - preparedCandidates.length;
    totalQueued = await insertNewsCandidates(preparedCandidates, env);

    if (categoryIndex === 0) {
      await cleanupOldTrends(env, 7);
    }
  } catch (error) {
    console.error('Collection Error:', error.message);
    errors.push({ error: error.message });
  }

  return {
    category: currentCategory,
    totalFetched,
    totalCandidates,
    totalQueued,
    totalPreFilterDiscarded,
    totalSkippedExisting,
    errors,
  };
}

function buildNewsCandidate(article) {
  const preFilter = scoreNewsCandidate(article);

  if (preFilter.hardSkip) {
    return null;
  }

  return {
    link: article.link,
    original_title: article.title,
    description: article.description || '',
    category: article.category,
    source: article.source || '',
    thumbnail_url: '',
    published: article.pubDate,
    status: 'pending',
    pre_score: preFilter.score,
    attempts: 0,
  };
}

function scoreNewsCandidate(article) {
  const text = `${article.title || ''} ${article.description || ''}`.toLowerCase();
  const title = String(article.title || '').toLowerCase();
  const hardSkipPatterns = [
    [/^\s*\[(칼럼|기고|연재|리뷰|서평)\]/, 'column_or_review'],
    [/^\s*\[[^\]]*(인물|사람)\]/, 'person_profile'],
    [/(사람 이야기|인생 이야기|책 소개|신간 소개|제품 사용기|사용 후기)/, 'low_value_feature'],
  ];

  for (const [pattern, reason] of hardSkipPatterns) {
    if (pattern instanceof RegExp && pattern.test(title)) {
      return { hardSkip: true, score: 0, reason };
    }
  }

  const signals = [
    { terms: ['기록적 폭우', '집중호우', '태풍', '산불', '지진', '대규모 사고', '사망', '대피', '통제'], score: 9, reason: 'disaster_or_safety' },
    { terms: ['기준금리', '금리 인상', '금리 인하', '환율 급등', '환율 급락', '증시 급등', '증시 급락', '코스피', '코스닥'], score: 8, reason: 'market_change' },
    { terms: ['법안 통과', '정책 확정', '규제 시행', '최종 확정', '선거 결과', '긴급 발표'], score: 8, reason: 'confirmed_policy' },
    { terms: ['대규모 투자', '인수합병', '인수', '공급 계약', '수주', '생산 중단', '파업'], score: 7, reason: 'corporate_change' },
    { terms: ['수출 증가', '수출 감소', '고용', '물가', '실업률', '경제지표', '무역수지'], score: 6, reason: 'economic_indicator' },
    { terms: ['정상회담', '제재', '휴전', '전쟁', '국제 유가', '관세'], score: 6, reason: 'global_event' },
  ];
  const penalties = [
    { terms: ['행사 개최', '전시회', '교육 프로그램', '모집', '공모', '출시', '공개', '인터뷰'], score: 3 },
    { terms: ['촉구', '요구', '주장', '비판', '논평', '전망'], score: 2 },
  ];

  let score = 0;
  const reasons = [];
  for (const signal of signals) {
    if (signal.terms.some(term => text.includes(term))) {
      score += signal.score;
      reasons.push(signal.reason);
    }
  }
  for (const penalty of penalties) {
    if (penalty.terms.some(term => text.includes(term))) {
      score -= penalty.score;
    }
  }

  return {
    hardSkip: false,
    score: Math.max(0, score),
    reason: reasons.join(',') || 'general',
  };
}

async function insertNewsCandidates(candidates, env) {
  if (!candidates.length) return 0;

  const { error } = await querySupabaseAdmin(env, 'news_candidates', 'POST', candidates);
  if (error) {
    throw new Error(`Candidate insert failed: ${error.status || ''} ${error.message || ''}`);
  }

  return candidates.length;
}

async function getRecentCandidateLinks(env, hours = CANDIDATE_LOOKBACK_HOURS) {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
  const { data, error } = await querySupabaseAdmin(
    env,
    `news_candidates?select=link&created_at=gte.${since}&limit=1000`
  );

  if (error || !data) return new Set();
  return new Set(data.map(row => normalizeLink(row.link)).filter(Boolean));
}

function isAiAnalysisCycle(now = new Date()) {
  return now.getUTCMinutes() % AI_ANALYSIS_INTERVAL_MINUTES === 0;
}

async function processPendingCandidate(env) {
  if (!isAiAnalysisCycle()) {
    return { ran: false, totalAnalyzed: 0, totalInserted: 0, reason: 'Not an AI cycle' };
  }

  const { data: candidates, error } = await querySupabaseAdmin(
    env,
    'news_candidates?select=*&status=eq.pending&order=pre_score.desc,created_at.asc&limit=100'
  );
  if (error) throw new Error(`Pending candidate query failed: ${error.message || ''}`);

  const ranked = (candidates || [])
    .map(candidate => ({ candidate, priority: candidatePriority(candidate) }))
    .sort((left, right) => right.priority - left.priority || left.candidate.created_at.localeCompare(right.candidate.created_at));
  const preferredCategory = preferredAnalysisCategory();
  const preferred = ranked.find(({ candidate }) =>
    String(candidate.category || '').trim() === preferredCategory,
  );
  const selected = (preferred ? [preferred] : ranked.slice(0, MAX_AI_ANALYSIS_PER_CYCLE))
    .map(item => item.candidate);

  if (!selected.length) {
    return { ran: true, totalAnalyzed: 0, totalInserted: 0, pendingRemaining: 0 };
  }

  const candidate = selected[0];

  try {
    const analyzed = await analyzeSingleArticle({
      title: candidate.original_title,
      description: candidate.description,
      category: candidate.category,
      link: candidate.link,
      source: candidate.source,
      pubDate: candidate.published,
    }, env);
    if (!analyzed) {
      await updateCandidateStatus(candidate.id, {
        status: 'discarded',
        processed_at: new Date().toISOString(),
        last_error: null,
      }, env);
      return { ran: true, totalAnalyzed: 1, totalInserted: 0, discarded: 1 };
    }

    const inserted = await insertTrends([analyzed], env);
    if (inserted <= 0) {
      throw new Error('Trend insert returned 0 after successful analysis');
    }
    await updateCandidateStatus(candidate.id, {
      status: 'processed',
      processed_at: new Date().toISOString(),
      last_error: null,
    }, env);
    return { ran: true, totalAnalyzed: 1, totalInserted: inserted, processed: 1 };
  } catch (error) {
    const attempts = Number(candidate.attempts || 0) + 1;
    const errorMessage = String(error.message || error).slice(0, 1000);
    const isRateLimited = isGroqRateLimitError(errorMessage);
    const shouldDiscard = !isRateLimited && attempts >= MAX_CANDIDATE_ATTEMPTS;

    await updateCandidateStatus(candidate.id, {
      status: shouldDiscard ? 'discarded' : 'pending',
      attempts,
      last_error: errorMessage,
      processed_at: shouldDiscard ? new Date().toISOString() : null,
    }, env);
    console.error(`Analysis failed for candidate #${candidate.id}: ${errorMessage}`);
    return { ran: true, totalAnalyzed: 0, totalInserted: 0, failed: 1, rateLimited: isRateLimited, attempts };
  }
}

function preferredAnalysisCategory(now = Date.now()) {
  const slot = Math.floor(now / ANALYSIS_SLOT_MS);
  return VALID_CATEGORIES[slot % VALID_CATEGORIES.length];
}

function candidatePriority(candidate) {
  const createdAt = Date.parse(candidate.created_at || '') || Date.now();
  const waitingBonus = Math.min(12, Math.floor((Date.now() - createdAt) / (15 * 60 * 1000)));
  const retryPenalty = Math.min(8, Number(candidate.attempts || 0) * 2);
  return Number(candidate.pre_score || 0) + waitingBonus - retryPenalty;
}

function isGroqRateLimitError(message) {
  return /Groq API failed: 429|rate_limit_exceeded|Rate limit reached/i.test(message);
}

async function updateCandidateStatus(id, patch, env) {
  const { error } = await querySupabaseAdmin(env, `news_candidates?id=eq.${id}`, 'PATCH', patch);
  if (error) throw new Error(`Candidate update failed: ${error.status || ''} ${error.message || ''}`);
}

async function fetchNaverNews(query, env, limit) {
  try {
    const displayCount = clampNumber(NAVER_DISPLAY_COUNT, 10, 100);

    const url = `https://openapi.naver.com/v1/search/news.json?query=${encodeURIComponent(query)}&display=${displayCount}&sort=date`;


    const response = await fetch(url, {
      headers: {
        'X-Naver-Client-Id': env.NAVER_CLIENT_ID,
        'X-Naver-Client-Secret': env.NAVER_CLIENT_SECRET,
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      const errorText = await safeReadText(response);
      console.error(`  ❌ 네이버 API 오류: ${response.status} ${errorText}`);
      return [];
    }

    const data = await response.json();

    const now = Date.now();
    const minTimestamp = now - (MAX_ARTICLE_AGE_HOURS * 60 * 60 * 1000);

    const filtered = (data.items || [])
      .map(item => {
        const rawTitle = stripHTML(item.title || '');
        const rawDesc = stripHTML(item.description || '');

        const pubDate = new Date(item.pubDate);
        const pubTimestamp = pubDate.getTime();

        let hostname = 'naver.com';

        try {
          hostname = new URL(item.originallink || item.link).hostname;
        } catch (e) { }

        return {
          title: decodeHTMLEntities(rawTitle),
          link: item.originallink || item.link,
          description: decodeHTMLEntities(rawDesc),
          pubDate: Number.isNaN(pubTimestamp) ? new Date().toISOString() : pubDate.toISOString(),
          pubTimestamp: Number.isNaN(pubTimestamp) ? now : pubTimestamp,
          source: hostname,
        };
      })
      .filter(article => {
        if (article.pubTimestamp <= minTimestamp) {
          const hoursAgo = Math.floor((now - article.pubTimestamp) / (60 * 60 * 1000));
          return false;
        }

        if (article.description.length < 20) {
          return false;
        }

        return true;
      })
      .sort((a, b) => b.pubTimestamp - a.pubTimestamp)
      .slice(0, limit);


    return filtered;
  } catch (error) {
    console.error(`  ❌ fetchNaverNews 오류: ${error.message}`);
    return [];
  }
}

async function analyzeSingleArticle(article, env) {
  const safeTitle = sanitizePromptText(article.title);
  const safeDescription = truncateText(sanitizePromptText(article.description), 220);
  const isKorean = /[\uAC00-\uD7A3]/.test(safeTitle);

  const prompt = isKorean
    ? `다음 뉴스를 간단히 분석해 주세요.
카테고리: ${article.category}
제목: ${safeTitle}
본문: ${safeDescription}

제공된 structured schema에 맞춰 korean_title은 원문 제목, summary_kr은 핵심 1~2줄 요약으로 작성하세요.
importance와 main_worthiness는 절대 서로 복사하거나 비슷한 값으로 맞추지 말고, 서로 독립적으로 평가하세요.
importance는 이 기사 또는 분야 안에서의 뉴스 자체 중요도이고, main_worthiness는 대한민국 일반 사용자가 오늘 Pulse 첫 화면에서 우선 알아야 할 가치입니다.
두 값이 같은 것은 실제로 같은 평가가 타당할 때만 허용됩니다. tickers는 기사에 해당 기업 또는 자산이 명시적으로 등장하고 식별 가능한 경우만 넣으세요. 시장·업종·지수 일반 기사나 관련 가능성만 있는 종목에는 빈 배열을 사용하세요.

main_worthiness 기준:
5=대부분의 사용자가 오늘 반드시 알아야 할 큰 영향·긴급성·실제 피해/결정/이례적 수치가 함께 있는 뉴스.
4=실제 사건·결정·수치 변화와 상당한 영향이 확인된 주요 뉴스.
3=일반 뉴스로, Main 5개에 반드시 들어갈 정도는 아닌 중간 수준이며 기본값으로 사용하지 마세요.
2=특정 관심층·지역·기관에는 의미가 있으나 Main 우선순위가 낮은 행사, 촉구, 요구, 인터뷰, 교육 프로그램, 미확정 주장/전망.
1=연재, 칼럼, 기고, 리뷰, 도서/서비스 홍보, 정치인 설전·계파 갈등·인물 비판·논평 중심 기사.

실제 결정·발생·통과·확정·시행·급등락·피해·계약·인수·생산 중단/확대는 높게, 단순 촉구·요구·주장·비판·전망·논의·제안·평가·행사 개최는 낮게 평가하세요. 단어 하나가 아니라 제목과 본문 전체 맥락으로 판단하세요.
정치라는 이유만으로 낮추지 마세요. 법안 최종 통과, 세제/제도 확정, 정책 시행, 선거 결과, 긴급 발표는 높을 수 있으나 내부 갈등과 발언 공방은 낮습니다.
기록적 폭우·태풍·산불·지진은 실제 피해·통제·대피·광범위 영향·즉시 안전 정보가 있으면 5가 될 수 있습니다. 평범한 날씨 예보는 그렇지 않습니다.
category는 기사 주제에 따라 독립적으로 정확히 분류하세요. 경제는 금융·시장·기업·고용, 정치는 정부·정당·정책, 세계는 해외·국제 정세, IT/과학은 기술·과학이 중심일 때 사용합니다.`
    : `Analyze this news briefly.
Category: ${article.category}
Title: ${safeTitle}
Content: ${safeDescription}

Follow the provided structured schema. korean_title must be translated Korean, summary_kr a core 1-2 line summary,
and tickers an empty array unless the exact company or asset is explicitly identified in the article.
Evaluate importance and main_worthiness independently; never copy one score to the other. importance is inherent news importance within its field. main_worthiness is whether a general Korean Pulse user should prioritize it today. Equal scores are valid only when independently justified.

main_worthiness: 5=must-know news with multiple strong signals of broad impact, urgency, a real decision/damage, or an exceptional number; 4=major confirmed event, decision, or numeric change with substantial impact; 3=ordinary mid-level news, never a default score; 2=niche, local, institutional, event, request, interview, education, unconfirmed claim, or outlook; 1=series, column, review, promotion, political infighting/rhetoric, or commentary.
Rate actual decisions, confirmed policy, implementation, passage, damage, sharp market moves, contracts, acquisitions, or production changes higher than requests, claims, criticism, forecasts, discussions, proposals, evaluations, or event announcements. Judge the full context, not a single keyword.
Do not penalize politics by category: final legislation, confirmed policy, elections, or emergency announcements may be high, while party conflict and rhetoric are low. Record rain or disaster news can be 5 only with real danger, damage, control/evacuation, broad impact, or urgent safety information.
Classify category independently by the article subject: economy covers finance, markets, companies, and employment; politics covers government, parties, and policy; world is foreign/international affairs; IT/science is technology/science-led news.`;

  const aiResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'openai/gpt-oss-20b',
      messages: [
        {
          role: 'user',
          content: `You are a concise news analyst.\n${prompt}`,
        },
      ],
      max_completion_tokens: 512,
      temperature: 0.1,
      reasoning_effort: 'low',
      reasoning_format: 'hidden',
      response_format: {
        type: 'json_schema',
        json_schema: {
          name: 'article_analysis',
          strict: true,
          schema: {
            type: 'object',
            properties: {
              korean_title: { type: 'string' },
              summary_kr: { type: 'string' },
              importance: { type: 'integer', enum: [1, 2, 3, 4, 5] },
              main_worthiness: { type: 'integer', enum: [1, 2, 3, 4, 5] },
              tickers: {
                type: 'array',
                items: { type: 'string' },
              },
              category: {
                type: 'string',
                enum: ['경제', '세계', '사회', '정치', '생활/문화', 'IT/과학'],
              },
            },
            required: [
              'korean_title',
              'summary_kr',
              'importance',
              'main_worthiness',
              'tickers',
              'category',
            ],
            additionalProperties: false,
          },
        },
      },
    }),
    signal: AbortSignal.timeout(30000),
  });

  if (!aiResponse.ok) {
    const errorText = await safeReadText(aiResponse);
    throw new Error(`Groq API failed: ${aiResponse.status} ${errorText}`);
  }

  const aiData = await aiResponse.json();
  const content = aiData.choices?.[0]?.message?.content || '{}';
  const analysis = parseJSON(content);

  let importanceScore = clampNumber(parseInt(analysis.importance, 10) || 3, 1, 5);
  const parsedMainWorthiness = parseInt(analysis.main_worthiness, 10);
  const mainWorthiness = Number.isFinite(parsedMainWorthiness)
    ? clampNumber(parsedMainWorthiness, 1, 5)
    : null;
  let finalSummary = analysis.summary_kr || analysis.summary || analysis.description || '';
  let finalCategory = analysis.category || article.category;
  const finalTitle = analysis.korean_title || analysis.title || analysis.Korean_title || safeTitle;

  finalSummary = String(finalSummary).trim();
  finalCategory = String(finalCategory).trim();

  if (!finalSummary || finalSummary.includes('cannot fulfill')) {
    importanceScore = 1;
  }

  const titleAndDesc = `${safeTitle} ${safeDescription}`.toLowerCase();

  const correctedCategory = correctArticleCategory(finalCategory, titleAndDesc);
  if (correctedCategory !== finalCategory) {
    finalCategory = correctedCategory;
  }

  if (finalCategory === '경제') {
    const nonEconomicKeywords = ['교회', '목사', '신부', '전도', '예배', '교인', '성경', '종교'];

    if (nonEconomicKeywords.some(kw => titleAndDesc.includes(kw))) {
      finalCategory = '사회';
      importanceScore = 1;
    }
  }

  if (!VALID_CATEGORIES.includes(finalCategory)) {
    finalCategory = article.category;
  }

  const shouldDropForLowValue = mainWorthiness == null
    ? importanceScore <= 2
    : importanceScore <= 2 && mainWorthiness <= 2;
  if (shouldDropForLowValue) {
    return null;
  }

  return {
    original_title: article.title,
    korean_title: finalTitle,
    summary_kr: finalSummary,
    importance: importanceScore,
    main_worthiness: mainWorthiness,
    tickers: normalizeTickers(analysis.tickers),
    category: finalCategory,
    link: article.link,
    thumbnail_url: await fetchArticleThumbnailUrl(article.link),
    published: article.pubDate,
    source: article.source,
    created_at: new Date().toISOString(),
  };
}

async function insertTrends(trends, env) {
  if (trends.length === 0) return 0;

  let inserted = 0;
  let skipped = 0;

  try {
    const twelveHoursAgo = new Date(Date.now() - 12 * 60 * 60 * 1000).toISOString();

    const { data: existing } = await querySupabase(
      env,
      `trends?select=link,korean_title&created_at=gte.${twelveHoursAgo}`
    );

    const existingLinks = new Set((existing || []).map(row => normalizeLink(row.link)));
    const existingTitles = new Set((existing || []).map(row => normalizeTitle(row.korean_title)));

    const newTrends = trends.filter(trend => {
      const normalizedLink = normalizeLink(trend.link);
      const normalizedTitle = normalizeTitle(trend.korean_title);

      if (normalizedLink && existingLinks.has(normalizedLink)) {
        skipped++;
        return false;
      }

      if (normalizedTitle && existingTitles.has(normalizedTitle)) {
        skipped++;
        return false;
      }

      return true;
    });


    if (newTrends.length === 0) return 0;

    const { error: insertError } = await querySupabase(env, 'trends', 'POST', newTrends);

    if (insertError) {
      console.error('  ❌ Batch insert failed. Single insert retry disabled to protect subrequest limit.');
      console.error(`  Supabase insert error: ${insertError.status || ''} ${insertError.message || ''}`);
      return 0;
    }

    inserted = newTrends.length;
  } catch (error) {
    console.error('Insert Error:', error.message);
  }

  return inserted;
}

async function fetchArticleThumbnailUrl(articleUrl) {
  const url = String(articleUrl || '').trim();
  if (!url) return '';

  try {
    const response = await fetch(url, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (compatible; PulseBot/1.0; +https://pulse.app)',
        'Accept': 'text/html,application/xhtml+xml',
      },
      signal: AbortSignal.timeout(6000),
    });

    if (!response.ok) {
      return '';
    }

    const html = await response.text();
    return extractThumbnailUrlFromHtml(html, url);
  } catch (_) {
    return '';
  }
}

function extractThumbnailUrlFromHtml(html, baseUrl) {
  const source = String(html || '');
  if (!source) return '';

  const patterns = [
    /<meta[^>]+property=["']og:image["'][^>]+content=["']([^"']+)["'][^>]*>/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]+property=["']og:image["'][^>]*>/i,
    /<meta[^>]+name=["']twitter:image["'][^>]+content=["']([^"']+)["'][^>]*>/i,
    /<meta[^>]+content=["']([^"']+)["'][^>]+name=["']twitter:image["'][^>]*>/i,
  ];

  for (const pattern of patterns) {
    const match = source.match(pattern);
    const candidate = match?.[1]?.trim();
    if (!candidate) continue;

    try {
      const thumbnailUrl = new URL(candidate, baseUrl);
      const articleUrl = new URL(baseUrl);
      const isHttpImageUrl = ['http:', 'https:'].includes(thumbnailUrl.protocol);
      const resolvesToArticle = thumbnailUrl.origin === articleUrl.origin &&
        thumbnailUrl.pathname === articleUrl.pathname &&
        thumbnailUrl.search === articleUrl.search;

      // Some publishers emit a malformed value such as `https:` for og:image.
      // Resolving it against the article URL turns the article HTML into a fake thumbnail.
      if (!isHttpImageUrl || resolvesToArticle) continue;

      return thumbnailUrl.toString();
    } catch (_) {
      continue;
    }
  }

  return '';
}

async function cleanupOldTrends(env, days) {
  try {
    const cutoffDate = new Date(Date.now() - days * 24 * 60 * 60 * 1000).toISOString();

    const { data: countData } = await querySupabase(
      env,
      `trends?select=id&created_at=lt.${cutoffDate}&limit=1`
    );

    if (countData && countData.length > 0) {
      await querySupabase(env, `trends?created_at=lt.${cutoffDate}`, 'DELETE');
    }
  } catch (error) {
    console.error('Cleanup Error:', error.message);
  }
}

async function refreshIssueTimeline(env) {
  // Timeline/cluster 계산만 bounded input으로 실행해 Cron CPU 사용량을 제한한다.
  // 원본 trends 수집·보관량에는 영향을 주지 않는다.
  const trends = await getRecentTrends(env, 48, '', ISSUE_TIMELINE_TREND_LIMIT);
  const diagnostics = {
    trendCount: trends?.length || 0,
    clusterCandidates: 0,
    rejectedMembership: 0,
    rejectedRetention: 0,
  };

  if (!trends || trends.length === 0) {
    await clearCurrentIssueClusters(env);
    const titleBackfill = await backfillTrackedIssueTitles(env);
    return {
      success: true,
      clusters: 0,
      mappings: 0,
      periods: [],
      diagnostics,
      titleBackfill,
    };
  }

  const keywordStats = buildIssueTitleKeywordStats(trends);
  const keywordStatMap = new Map(keywordStats.map(item => [item.keyword, item]));
  const pairStats = buildIssueTitlePairStats(trends);
  const pairStatMap = new Map(pairStats.map(item => [item.key, item]));
  const clusterRows = [];
  const mappingRows = [];
  const nowIso = new Date().toISOString();

  for (const windowDef of ISSUE_TIMELINE_WINDOWS) {
    const currentCutoff = Date.now() - windowDef.hours * 60 * 60 * 1000;
    const previousCutoff = Date.now() - windowDef.hours * 2 * 60 * 60 * 1000;

    const currentTrends = trends.filter(trend => trendTimestamp(trend) >= currentCutoff);
    const previousTrends = trends.filter(trend => {
      const ts = trendTimestamp(trend);
      return ts >= previousCutoff && ts < currentCutoff;
    });

    if (currentTrends.length === 0) {
      continue;
    }

    const currentLabelMap = buildIssueLabelMap(currentTrends, keywordStatMap, pairStatMap);
    const previousLabelMap = buildIssueLabelMap(previousTrends, keywordStatMap, pairStatMap);
    const clusterMap = new Map();

    const sortedCurrentTrends = currentTrends
      .slice()
      .sort((a, b) => {
        const importanceDiff = (b.importance || 0) - (a.importance || 0);
        if (importanceDiff !== 0) return importanceDiff;
        return trendTimestamp(b) - trendTimestamp(a);
      });

    for (const trend of sortedCurrentTrends) {
      const labelInfo = getTrendIssueLabel(trend, keywordStatMap, pairStatMap);

      if (!labelInfo) continue;

      const bucket = currentLabelMap.get(labelInfo.label);
      if (!bucket) continue;

      if (!clusterMap.has(bucket.label)) {
        clusterMap.set(bucket.label, {
          id: crypto.randomUUID(),
          period: windowDef.period,
          canonical_keyword: bucket.displayKeyword,
          labelKind: bucket.labelKind,
          categoryCounts: new Map(),
          articles: [],
          sources: new Set(),
          firstSeen: trendTimestamp(trend),
          lastSeen: trendTimestamp(trend),
          totalImportance: 0,
        });
      }

      const cluster = clusterMap.get(bucket.label);
      cluster.articles.push(trend);
      cluster.sources.add(trend.source || 'unknown');
      cluster.firstSeen = Math.min(cluster.firstSeen, trendTimestamp(trend));
      cluster.lastSeen = Math.max(cluster.lastSeen, trendTimestamp(trend));
      cluster.totalImportance += Number(trend.importance || 0);
      cluster.categoryCounts.set(trend.category || '기타', (cluster.categoryCounts.get(trend.category || '기타') || 0) + 1);
    }

    for (const cluster of clusterMap.values()) {
      diagnostics.clusterCandidates += 1;
      const currentCount = cluster.articles.length;
      const sourceCount = cluster.sources.size;
      const avgImportance = currentCount > 0 ? cluster.totalImportance / currentCount : 0;
      const sentiment = summarizeSentiment(cluster.articles);
      const previousCount = previousLabelMap.get(cluster.canonical_keyword)?.count || 0;
      const growthRate = previousCount <= 0
        ? (currentCount >= 3 ? 999 : 0)
        : Math.round(((currentCount - previousCount) / previousCount) * 100);
      const score = calculateIssueClusterScore({
        currentCount,
        sourceCount,
        avgImportance,
        growthRate,
        sentimentTemperature: sentiment.temperature,
      });
      const stage = classifyIssueStage(currentCount, previousCount, growthRate, cluster.lastSeen, windowDef.hours);
      const dominantCategory = Array.from(cluster.categoryCounts.entries())
        .sort((a, b) => b[1] - a[1])[0]?.[0] || '기타';
      const representative = cluster.articles
        .slice()
        .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))[0];

      const hasConfidentMembership = hasConfidentIssueMembership(cluster);
      if (!hasConfidentMembership) {
        diagnostics.rejectedMembership += 1;
        console.log('[Issue diagnostics] rejected membership', JSON.stringify({
          period: windowDef.period,
          keyword: cluster.canonical_keyword,
          articleCount: currentCount,
          sourceCount,
          titles: cluster.articles.slice(0, 4).map(article => article.korean_title || article.original_title || ''),
        }));
        continue;
      }
      const hasStrongEvidence = hasStrongIssueEvidence(cluster);
      if (!shouldKeepIssueCluster({
        currentCount,
        sourceCount,
        score,
        hasConfidentMembership,
        hasStrongEvidence,
      })) {
        diagnostics.rejectedRetention += 1;
        console.log('[Issue diagnostics] rejected retention', JSON.stringify({
          period: windowDef.period,
          keyword: cluster.canonical_keyword,
          articleCount: currentCount,
          sourceCount,
          score,
          hasStrongEvidence,
        }));
        continue;
      }

      clusterRows.push({
        id: cluster.id,
        period: windowDef.period,
        category: dominantCategory,
        canonical_keyword: cluster.canonical_keyword,
        representative_title: representative?.korean_title || representative?.original_title || cluster.canonical_keyword,
        summary: buildIssueClusterSummary(cluster.articles, windowDef.period),
        article_count: currentCount,
        source_count: sourceCount,
        growth_rate: growthRate,
        score,
        sentiment_temperature: sentiment.temperature,
        stage,
        first_seen_at: new Date(cluster.firstSeen).toISOString(),
        last_seen_at: new Date(cluster.lastSeen).toISOString(),
        created_at: nowIso,
        updated_at: nowIso,
      });

      for (const article of cluster.articles) {
        mappingRows.push({
          issue_cluster_id: cluster.id,
          news_id: article.id,
          similarity_score: calculateIssueSimilarityScore(article, cluster.canonical_keyword, keywordStatMap, pairStatMap),
          created_at: nowIso,
        });
      }
    }
  }

  if (clusterRows.length === 0) {
    // issue_clusters is an ephemeral home snapshot. Do not keep yesterday's
    // issue visible merely because the current cycle has no eligible cluster.
    await clearCurrentIssueClusters(env);
    // Title backfill is intentionally independent of current cluster output.
    // Existing tracked issues can therefore be completed during quiet cycles.
    const titleBackfill = await backfillTrackedIssueTitles(env);
    return {
      success: true,
      clusters: 0,
      mappings: 0,
      periods: ISSUE_TIMELINE_WINDOWS.map(item => item.period),
      diagnostics,
      titleBackfill,
    };
  }

  await clearCurrentIssueClusters(env);

  const clusterInsert = await querySupabaseAdmin(env, 'issue_clusters', 'POST', clusterRows);
  if (clusterInsert.error) {
    throw new Error(clusterInsert.error.message || 'Failed to insert issue clusters');
  }

  const mappingInsert = await querySupabaseAdmin(env, 'issue_cluster_articles', 'POST', mappingRows);
  if (mappingInsert.error) {
    throw new Error(mappingInsert.error.message || 'Failed to insert issue cluster mappings');
  }
  if (mappingRows.length > 0 && Array.isArray(mappingInsert.data) && mappingInsert.data.length !== mappingRows.length) {
    throw new Error(`Issue cluster mapping count mismatch: expected ${mappingRows.length}, received ${mappingInsert.data.length}`);
  }

  /** @type {any} */
  let trackedSync = { success: false, skipped: true, reason: 'No eligible 24h clusters' };
  try {
    trackedSync = await syncTrackedIssues(clusterRows, mappingRows, trends, env);
    await persistIssueTitlesOnClusters(trackedSync.issueTitlesByClusterId, env);
  } catch (error) {
    // Tracked history is additive. Its failure must not invalidate the current Issue snapshot.
    console.error(`Tracked issue sync failed: ${error.message}`);
    trackedSync = { success: false, error: error.message };
  }

  return {
    success: true,
    clusters: clusterRows.length,
    mappings: mappingRows.length,
    periods: ISSUE_TIMELINE_WINDOWS.map(item => item.period),
    diagnostics,
    trackedSync,
  };
}

async function clearCurrentIssueClusters(env) {
  const mappingDelete = await querySupabaseAdmin(env, 'issue_cluster_articles?created_at=not.is.null', 'DELETE');
  if (mappingDelete.error) {
    throw new Error(mappingDelete.error.message || 'Failed to delete issue cluster mappings');
  }

  const clusterDelete = await querySupabaseAdmin(env, 'issue_clusters?created_at=not.is.null', 'DELETE');
  if (clusterDelete.error) {
    throw new Error(clusterDelete.error.message || 'Failed to delete issue clusters');
  }
}

async function backfillTrackedIssueTitles(env) {
  const result = {
    success: true,
    eligible: 0,
    generated: 0,
    skipped: 0,
  };
  if (!env.GROQ_API_KEY) {
    return { ...result, skipped: 0, reason: 'Missing GROQ_API_KEY' };
  }

  const trackedIssues = await getRecentTrackedIssues(env);
  const titlesNeedingBackfill = trackedIssues.filter(issue =>
    needsIssueTitleRefresh(issue.issue_title)
  );
  result.eligible = titlesNeedingBackfill.length;
  if (titlesNeedingBackfill.length === 0) return result;

  const { latestSnapshots } = await getTrackedSnapshotHistory(
    titlesNeedingBackfill.map(issue => issue.id),
    env,
  );
  const budget = { remaining: MAX_ISSUE_TITLE_GENERATIONS_PER_CYCLE };

  for (const trackedIssue of titlesNeedingBackfill) {
    if (budget.remaining <= 0) break;
    const snapshot = latestSnapshots.get(String(trackedIssue.id));
    const newsIds = Array.from(new Set((snapshot?.news_ids || [])
      .map(value => Number(value))
      .filter(Number.isFinite)));
    if (newsIds.length === 0) {
      result.skipped += 1;
      continue;
    }

    const articles = await getTrendsByIds(newsIds, env);
    if (articles.length === 0) {
      result.skipped += 1;
      continue;
    }

    const issueTitle = await resolveTrackedIssueTitle(
      trackedIssue,
      { articles, summary: snapshot?.summary || trackedIssue.title || '' },
      env,
      budget,
    );
    if (!issueTitle) {
      result.skipped += 1;
      continue;
    }

    const { error } = await querySupabaseAdmin(
      env,
      `tracked_issues?id=eq.${encodeURIComponent(trackedIssue.id)}`,
      'PATCH',
      { issue_title: issueTitle, updated_at: new Date().toISOString() },
    );
    if (error) throw new Error(`Tracked issue title backfill failed: ${error.message || ''}`);
    result.generated += 1;
  }

  return result;
}

async function getTrendsByIds(newsIds, env) {
  const ids = Array.from(new Set((newsIds || [])
    .map(value => Number(value))
    .filter(Number.isFinite)));
  if (ids.length === 0) return [];

  const endpoint = `trends?select=id,korean_title,original_title,summary_kr,importance,main_worthiness,tickers,category,link,source,thumbnail_url,published,created_at,view_count&id=in.(${ids.join(',')})&limit=${ids.length}`;
  const { data, error } = await querySupabaseAdmin(env, endpoint);
  if (error) throw new Error(`Tracked issue article query failed: ${error.message || ''}`);
  return data || [];
}

async function persistIssueTitlesOnClusters(issueTitlesByClusterId, env) {
  for (const [clusterId, issueTitle] of Object.entries(issueTitlesByClusterId || {})) {
    if (!clusterId || !issueTitle) continue;
    const { error } = await querySupabaseAdmin(
      env,
      `issue_clusters?id=eq.${encodeURIComponent(clusterId)}`,
      'PATCH',
      { issue_title: issueTitle },
    );
    if (error) throw new Error(`Issue title persistence failed: ${error.message || ''}`);
  }
}

async function syncTrackedIssues(clusterRows, mappingRows, trends, env) {
  const clusters = buildTrackedClusterCandidates(clusterRows, mappingRows, trends)
    .sort((left, right) => Number(right.score || 0) - Number(left.score || 0));
  if (clusters.length === 0) {
    return { success: true, skipped: true, reason: 'No eligible 24h clusters', candidates: 0 };
  }

  const existingIssues = await getRecentTrackedIssues(env);
  const snapshotHistory = await getTrackedSnapshotHistory(existingIssues.map(issue => issue.id), env);
  const { latestSnapshots, snapshotsByIssue } = snapshotHistory;
  const result = {
    success: true,
    candidates: clusters.length,
    matched: 0,
    created: 0,
    snapshotsAdded: 0,
    snapshotsSkipped: 0,
    activated: 0,
    issueTitlesByClusterId: {},
  };
  const titleGenerationBudget = { remaining: MAX_ISSUE_TITLE_GENERATIONS_PER_CYCLE };

  for (const cluster of clusters) {
    const match = matchTrackedIssue(cluster, existingIssues, latestSnapshots);
    let trackedIssue = match?.issue || null;

    if (trackedIssue) {
      result.matched += 1;
    } else {
      const issueTitle = await resolveTrackedIssueTitle(
        null,
        cluster,
        env,
        titleGenerationBudget,
      );
      trackedIssue = await createTrackedIssue(cluster, issueTitle, env);
      existingIssues.push(trackedIssue);
      result.created += 1;
    }

    const issueTitle = await resolveTrackedIssueTitle(
      trackedIssue,
      cluster,
      env,
      titleGenerationBudget,
    );
    if (issueTitle) {
      trackedIssue.issue_title = issueTitle;
      result.issueTitlesByClusterId[cluster.issueClusterId] = issueTitle;
    }

    const trackedIssueKey = String(trackedIssue.id);
    const previousSnapshot = latestSnapshots.get(trackedIssueKey) || null;
    const snapshot = buildTrackedIssueSnapshot(cluster, trackedIssue.id);
    if (previousSnapshot?.snapshot_fingerprint === snapshot.snapshot_fingerprint) {
      await updateSnapshotClusterAssociation(
        previousSnapshot,
        cluster.issueClusterId,
        env,
      );
      result.snapshotsSkipped += 1;
      continue;
    }

    const history = snapshotsByIssue.get(trackedIssueKey) || [];
    const activation = evaluateTrackedIssueActivation(trackedIssue, cluster, history);

    const snapshotInserted = await insertTrackedIssueSnapshot(snapshot, env);
    if (!snapshotInserted) {
      result.snapshotsSkipped += 1;
      continue;
    }
    latestSnapshots.set(trackedIssueKey, snapshot);
    history.push(snapshot);
    snapshotsByIssue.set(trackedIssueKey, history);
    await updateTrackedIssueAfterSnapshot(trackedIssue, cluster, activation.shouldPromote, env);
    if (activation.shouldPromote) {
      trackedIssue.status = 'active';
      result.activated += 1;
    } else if (String(trackedIssue.status || '') === 'candidate') {
    }
    result.snapshotsAdded += 1;
  }

  return result;
}

async function updateSnapshotClusterAssociation(snapshot, issueClusterId, env) {
  const snapshotId = String(snapshot?.id || '');
  if (!snapshotId || !issueClusterId) return;
  const { error } = await querySupabaseAdmin(
    env,
    `tracked_issue_snapshots?id=eq.${encodeURIComponent(snapshotId)}`,
    'PATCH',
    { issue_cluster_id: issueClusterId },
  );
  if (error) throw new Error(`Snapshot cluster association failed: ${error.message || ''}`);
}

function buildTrackedClusterCandidates(clusterRows, mappingRows, trends) {
  const newsIdsByCluster = new Map();
  for (const row of mappingRows || []) {
    const clusterId = String(row.issue_cluster_id || '');
    const newsId = Number(row.news_id);
    if (!clusterId || !Number.isFinite(newsId) || newsId <= 0) continue;
    if (!newsIdsByCluster.has(clusterId)) newsIdsByCluster.set(clusterId, []);
    newsIdsByCluster.get(clusterId).push(newsId);
  }

  const trendById = new Map((trends || []).map(item => [Number(item.id), item]));
  return (clusterRows || [])
    .filter(row => row.period === '24h' && Number(row.article_count) >= 2 && Number(row.source_count) >= 2)
    .map(row => {
      const newsIds = Array.from(new Set(newsIdsByCluster.get(String(row.id)) || []));
      const articles = newsIds.map(id => trendById.get(id)).filter(Boolean);
      if (newsIds.length < 2 || articles.length < 2) return null;

      const firstSeenAt = row.first_seen_at || new Date(Math.min(...articles.map(trendTimestamp))).toISOString();
      const lastSeenAt = row.last_seen_at || new Date(Math.max(...articles.map(trendTimestamp))).toISOString();
      const semantic = buildTrackedIssueSemantic({
        articles,
        title: row.representative_title,
        keyword: row.canonical_keyword,
        category: row.category,
        firstSeenAt,
      });

      return {
        issueClusterId: String(row.id),
        title: String(row.representative_title || row.canonical_keyword || '').trim(),
        keyword: String(row.canonical_keyword || '').trim(),
        category: String(row.category || '').trim(),
        newsIds,
        articles,
        articleCount: Number(row.article_count || newsIds.length),
        sourceCount: Number(row.source_count || 0),
        summary: String(row.summary || '').trim(),
        stage: String(row.stage || '').trim(),
        score: Number(row.score || 0),
        firstSeenAt,
        lastSeenAt,
        maxMainWorthiness: getMaxMainWorthiness(articles),
        avgImportance: getAverageImportance(articles),
        semantic,
        identityFingerprint: buildTrackedIssueFingerprint(semantic),
      };
    })
    .filter(Boolean);
}

function buildTrackedIssueSemantic({ articles = [], title = '', keyword = '', category = '', firstSeenAt = '' }) {
  const keywordSet = new Set();
  for (const article of articles) {
    for (const value of extractIssueTitleKeywords(article)) keywordSet.add(value);
  }
  for (const value of extractIssueTitleKeywords({ korean_title: title, original_title: keyword })) keywordSet.add(value);
  for (const value of String(keyword).split('·').map(item => item.trim()).filter(Boolean)) keywordSet.add(value);

  const specificKeywords = Array.from(keywordSet)
    .filter(value => isUsefulKeyword(value) && !isGenericClusterKeyword(value))
    .sort((left, right) => left.localeCompare(right, 'ko'));
  const entities = specificKeywords.filter(isStrongEntityAnchor);
  const actions = Array.from(getActionAnchorGroups(specificKeywords)).sort();
  const firstSeenTime = Date.parse(firstSeenAt || '');
  const bucketStart = Number.isFinite(firstSeenTime)
    ? Math.floor(firstSeenTime / (TRACKED_ISSUE_FINGERPRINT_BUCKET_HOURS * 60 * 60 * 1000))
    : 0;

  return {
    category: String(category || '').trim(),
    specificKeywords: specificKeywords.slice(0, 8),
    entities: entities.slice(0, 4),
    actions,
    bucketStart,
  };
}

function buildTrackedIssueFingerprint(semantic) {
  const anchorTerms = semantic.entities.length > 0
    ? semantic.entities
    : semantic.specificKeywords.slice(0, 3);
  const raw = [
    'v1',
    semantic.category,
    anchorTerms.join('·'),
    semantic.actions.join('·'),
    String(semantic.bucketStart),
  ].join('|').toLowerCase();
  return `ti_${stableTextHash(raw)}`;
}

function stableTextHash(value) {
  let hash = 2166136261;
  for (let index = 0; index < value.length; index++) {
    hash ^= value.charCodeAt(index);
    hash = Math.imul(hash, 16777619);
  }
  return (hash >>> 0).toString(36);
}

async function getRecentTrackedIssues(env) {
  const cutoff = new Date(Date.now() - TRACKED_ISSUE_MATCH_WINDOW_HOURS * 60 * 60 * 1000).toISOString();
  const { data, error } = await querySupabaseAdmin(
    env,
    `tracked_issues?select=*&status=in.(candidate,active,quiet)&last_activity_at=gte.${cutoff}&order=last_activity_at.desc&limit=300`
  );
  if (error) throw new Error(`Tracked issue query failed: ${error.message || ''}`);
  return data || [];
}

async function getTrackedSnapshotHistory(trackedIssueIds, env) {
  const latestSnapshots = new Map();
  const snapshotsByIssue = new Map();
  if (!trackedIssueIds.length) return { latestSnapshots, snapshotsByIssue };

  const ids = trackedIssueIds.map(id => String(id)).filter(Boolean);
  const { data, error } = await querySupabaseAdmin(
    env,
    `tracked_issue_snapshots?select=*&tracked_issue_id=in.(${ids.join(',')})&order=observed_at.desc&limit=1000`
  );
  if (error) throw new Error(`Tracked snapshot query failed: ${error.message || ''}`);

  for (const snapshot of data || []) {
    const key = String(snapshot.tracked_issue_id || '');
    if (!key) continue;
    if (!latestSnapshots.has(key)) latestSnapshots.set(key, snapshot);
    if (!snapshotsByIssue.has(key)) snapshotsByIssue.set(key, []);
    snapshotsByIssue.get(key).push(snapshot);
  }
  return { latestSnapshots, snapshotsByIssue };
}

function matchTrackedIssue(cluster, trackedIssues, latestSnapshots) {
  const overlapMatches = trackedIssues
    .map(issue => {
      const snapshot = latestSnapshots.get(String(issue.id));
      const overlap = countNewsIdOverlap(cluster.newsIds, snapshot?.news_ids || []);
      return { issue, overlap };
    })
    .filter(item => item.overlap > 0)
    .sort((left, right) => right.overlap - left.overlap || Date.parse(right.issue.last_activity_at) - Date.parse(left.issue.last_activity_at));
  if (overlapMatches.length > 0) {
    return { issue: overlapMatches[0].issue, reason: 'news overlap' };
  }

  const semanticMatches = trackedIssues.filter(issue => {
    if (String(issue.category || '') !== cluster.category) return false;
    const issueSemantic = buildTrackedIssueSemantic({
      title: issue.title,
      keyword: issue.keyword,
      category: issue.category,
      firstSeenAt: issue.opened_at,
    });
    return hasStrongTrackedSemanticMatch(cluster.semantic, issueSemantic);
  });
  if (semanticMatches.length === 1) {
    return { issue: semanticMatches[0], reason: 'entity/action' };
  }

  const fingerprintMatches = trackedIssues.filter(issue =>
    String(issue.identity_fingerprint || '') === cluster.identityFingerprint &&
    isWithinTrackedIssueMatchWindow(issue.last_activity_at)
  );
  if (fingerprintMatches.length === 1) {
    return { issue: fingerprintMatches[0], reason: 'fingerprint/time' };
  }

  return null;
}

function hasStrongTrackedSemanticMatch(left, right) {
  const sharedEntities = intersectTextValues(left.entities, right.entities);
  const sharedActions = intersectTextValues(left.actions, right.actions);
  return sharedEntities.length > 0 && sharedActions.length > 0;
}

function isWithinTrackedIssueMatchWindow(value) {
  const timestamp = Date.parse(value || '');
  return Number.isFinite(timestamp) && Date.now() - timestamp <= TRACKED_ISSUE_MATCH_WINDOW_HOURS * 60 * 60 * 1000;
}

function countNewsIdOverlap(left, right) {
  const rightIds = new Set((right || []).map(value => Number(value)).filter(Number.isFinite));
  return (left || []).filter(value => rightIds.has(Number(value))).length;
}

function intersectTextValues(left, right) {
  const rightSet = new Set((right || []).map(value => String(value || '').trim()).filter(Boolean));
  return (left || []).filter(value => rightSet.has(String(value || '').trim()));
}

async function createTrackedIssue(cluster, issueTitle, env) {
  const nowIso = new Date().toISOString();
  const { data, error } = await querySupabaseAdmin(env, 'tracked_issues', 'POST', {
    identity_fingerprint: cluster.identityFingerprint,
    title: cluster.title,
    issue_title: issueTitle || null,
    keyword: cluster.keyword,
    category: cluster.category,
    status: 'candidate',
    opened_at: cluster.firstSeenAt,
    last_activity_at: cluster.lastSeenAt,
    last_seen_at: cluster.lastSeenAt,
    created_at: nowIso,
    updated_at: nowIso,
  });
  if (error || !Array.isArray(data) || !data[0]) {
    throw new Error(`Tracked issue insert failed: ${error?.message || 'No row returned'}`);
  }
  return data[0];
}

async function resolveTrackedIssueTitle(trackedIssue, cluster, env, budget) {
  const existingTitle = String(trackedIssue?.issue_title || '').trim();
  if (!needsIssueTitleRefresh(existingTitle)) return existingTitle;
  if (!env.GROQ_API_KEY) {
    return '';
  }
  if (budget.remaining <= 0) {
    return '';
  }

  budget.remaining -= 1;
  try {
    const generatedTitle = await generateIssueTitle(cluster, env);
    return generatedTitle;
  } catch (error) {
    console.error('[Issue title] generation failed', JSON.stringify({
      trackedIssueId: trackedIssue?.id || null,
      clusterId: cluster?.issueClusterId || null,
      message: error.message,
    }));
    return '';
  }
}

function needsIssueTitleRefresh(title) {
  const value = String(title || '').replace(/\s+/g, ' ').trim();
  if (!value || value.length < 12 || value.length > 48) return true;
  if (/[…]|\.\.\./u.test(value) || /["'“”‘’]/u.test(value)) return true;
  if (/(관심 집중|시장 주목|향방 주목|집중시키다|전망이다|밝혔다|전했다)$/u.test(value)) return true;
  return false;
}

async function generateIssueTitle(cluster, env) {
  const articleTitles = (cluster.articles || [])
    .slice()
    .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))
    .slice(0, 3)
    .map(article => article.korean_title || article.original_title || '')
    .filter(Boolean);
  if (articleTitles.length === 0) return '';

  const prompt = `다음은 하나의 뉴스 이슈로 묶인 기사들입니다. 기사 제목을 그대로 복사하거나 단어만 나열하지 말고, 공통 사건의 주체와 변화를 담은 중립적인 한국어 이슈 제목을 작성하세요. 제목은 뉴스 앱에 표시할 20~38자의 짧은 명사형 구문으로 작성하고, 문장 끝을 '~하다', '~시키다', '~전망이다'처럼 서술형으로 만들지 마세요. '관심 집중', '시장 주목', '향방 주목' 같은 추상적인 표현과 선정적 표현, 말줄임표, 느낌표는 사용하지 마세요. 반드시 JSON 객체 형식 {"issue_title":"제목"}으로만 응답하세요.\n\n기사 제목:\n${articleTitles.map((title, index) => `${index + 1}. ${sanitizePromptText(title)}`).join('\n')}\n\n대표 요약:\n${sanitizePromptText(cluster.summary || '')}`;
  const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'openai/gpt-oss-20b',
      messages: [{ role: 'user', content: prompt }],
      max_completion_tokens: 96,
      temperature: 0.1,
      reasoning_effort: 'low',
      reasoning_format: 'hidden',
      // 모델별 response_format 호환성 차이를 피하고, 프롬프트의 JSON 지시와
      // 아래 parseJSON으로 결과를 검증한다.
    }),
    signal: AbortSignal.timeout(30000),
  });
  if (!response.ok) {
    const errorBody = await safeReadText(response);
    throw new Error(`Groq issue title request failed: ${response.status}${errorBody ? `: ${truncateText(errorBody, 240)}` : ''}`);
  }
  const payload = await response.json();
  const content = payload.choices?.[0]?.message?.content || '{}';
  return String(parseJSON(content).issue_title || '').replace(/\s+/g, ' ').trim();
}

function correctArticleCategory(category, text) {
  const value = String(text || '').toLowerCase();
  const scores = {
    경제: 0,
    세계: 0,
    정치: 0,
    'IT/과학': 0,
    사회: 0,
  };

  const weightedTerms = {
    경제: [
      ['기준금리', 4], ['금통위', 4], ['한국은행', 3], ['금리', 2], ['환율', 2],
      ['코스피', 2], ['코스닥', 2], ['물가', 2], ['인플레이션', 2], ['가계대출', 2],
      ['채권', 2], ['증시', 2], ['주가', 2], ['금융', 2], ['pce', 2], ['연준', 2],
      ['기업 실적', 2], ['매출', 1], ['수출', 1],
    ],
    세계: [
      ['미국', 1], ['중국', 1], ['일본', 1], ['이란', 2], ['이스라엘', 2],
      ['러시아', 2], ['우크라이나', 2], ['휴전', 2], ['국제', 1],
    ],
    정치: [
      ['대통령', 2], ['국회', 2], ['총선', 2], ['대선', 2], ['정당', 2],
      ['장관', 2], ['청와대', 2], ['여당', 1], ['야당', 1],
    ],
    'IT/과학': [
      ['인공지능', 2], ['ai', 2], ['반도체', 2], ['소프트웨어', 2], ['로봇', 2],
      ['배터리', 1], ['연구', 1], ['실험', 1],
    ],
    사회: [
      ['사망', 3], ['화재', 3], ['폭발', 3], ['사고', 2], ['범죄', 2],
      ['파업', 2], ['재난', 2], ['대피', 2], ['병원', 1],
    ],
  };

  for (const [target, terms] of Object.entries(weightedTerms)) {
    for (const [term, weight] of terms) {
      if (value.includes(String(term))) scores[target] += Number(weight);
    }
  }

  const ranked = Object.entries(scores).sort((left, right) => right[1] - left[1]);
  const [topCategory, topScore] = ranked[0] || [category, 0];
  const secondScore = ranked[1]?.[1] || 0;

  // 단일 키워드로 분류를 뒤집지 않고, 강한 도메인 신호가 분명할 때만 보정한다.
  if (topScore < 4 || topScore < secondScore + 2) return category;
  return topCategory;
}

function buildTrackedIssueSnapshot(cluster, trackedIssueId) {
  const newsIds = Array.from(new Set(cluster.newsIds.map(value => Number(value)).filter(Number.isFinite))).sort((left, right) => left - right);
  const snapshotBasis = [
    newsIds.join(','),
    cluster.articleCount,
    cluster.sourceCount,
    normalizeSearchText(cluster.summary),
    cluster.stage,
    Math.round(cluster.score),
    cluster.firstSeenAt,
    cluster.lastSeenAt,
  ].join('|');

  return {
    tracked_issue_id: trackedIssueId,
    observed_at: new Date().toISOString(),
    issue_cluster_id: cluster.issueClusterId,
    news_ids: newsIds,
    article_count: cluster.articleCount,
    source_count: cluster.sourceCount,
    summary: cluster.summary,
    stage: cluster.stage,
    score: cluster.score,
    first_seen_at: cluster.firstSeenAt,
    last_seen_at: cluster.lastSeenAt,
    max_main_worthiness: cluster.maxMainWorthiness,
    avg_importance: cluster.avgImportance,
    snapshot_fingerprint: `ts_${stableTextHash(snapshotBasis)}`,
  };
}

async function insertTrackedIssueSnapshot(snapshot, env) {
  const { error } = await querySupabaseAdmin(env, 'tracked_issue_snapshots', 'POST', snapshot);
  if (!error) return true;

  // 같은 tracked issue와 fingerprint는 이미 기록된 snapshot이다.
  // 동시 실행·캐시 지연으로 사전 조회가 놓쳐도 cycle 전체를 실패시키지 않는다.
  if (String(error.code || '') === '23505' || /duplicate key value|unique constraint/i.test(error.message || '')) {
    return false;
  }
  throw new Error(`Tracked snapshot insert failed: ${error.message || ''}`);
}

function evaluateTrackedIssueActivation(trackedIssue, cluster, history) {
  if (String(trackedIssue.status || '') !== 'candidate') {
    return { shouldPromote: false, newNewsIds: [], waveGapMinutes: null, reason: 'already active' };
  }
  if (!history || history.length === 0) {
    return { shouldPromote: false, newNewsIds: [], waveGapMinutes: null, reason: 'initial snapshot' };
  }

  const previouslySeenIds = new Set();
  let previousLastSeenAt = 0;
  for (const snapshot of history) {
    for (const newsId of snapshot.news_ids || []) {
      const normalizedId = Number(newsId);
      if (Number.isFinite(normalizedId)) previouslySeenIds.add(normalizedId);
    }
    const snapshotLastSeenAt = Date.parse(snapshot.last_seen_at || snapshot.observed_at || '');
    if (Number.isFinite(snapshotLastSeenAt)) previousLastSeenAt = Math.max(previousLastSeenAt, snapshotLastSeenAt);
  }

  if (!previousLastSeenAt) {
    previousLastSeenAt = Date.parse(trackedIssue.last_seen_at || trackedIssue.last_activity_at || trackedIssue.opened_at || '');
  }
  const newArticles = (cluster.articles || []).filter(article => !previouslySeenIds.has(Number(article.id)));
  const newNewsIds = newArticles.map(article => Number(article.id)).filter(Number.isFinite);
  if (newNewsIds.length === 0) {
    return { shouldPromote: false, newNewsIds, waveGapMinutes: null, reason: 'no unseen articles' };
  }

  const newestArticleAt = Math.max(...newArticles.map(trendTimestamp).filter(Number.isFinite));
  if (!Number.isFinite(previousLastSeenAt) || !Number.isFinite(newestArticleAt)) {
    return { shouldPromote: false, newNewsIds, waveGapMinutes: null, reason: 'missing article time' };
  }

  const waveGapMinutes = Math.floor((newestArticleAt - previousLastSeenAt) / (60 * 1000));
  if (waveGapMinutes < TRACKED_ISSUE_MIN_WAVE_GAP_MINUTES) {
    return { shouldPromote: false, newNewsIds, waveGapMinutes, reason: 'wave gap below threshold' };
  }
  return { shouldPromote: true, newNewsIds, waveGapMinutes, reason: 'new article after time gap' };
}

async function updateTrackedIssueAfterSnapshot(trackedIssue, cluster, shouldPromote, env) {
  const nowIso = new Date().toISOString();
  const existingLastSeenAt = Date.parse(trackedIssue.last_seen_at || trackedIssue.last_activity_at || '');
  const clusterLastSeenAt = Date.parse(cluster.lastSeenAt || '');
  const lastSeenAt = Number.isFinite(existingLastSeenAt) && existingLastSeenAt > clusterLastSeenAt
    ? new Date(existingLastSeenAt).toISOString()
    : cluster.lastSeenAt;
  const payload = {
    last_activity_at: lastSeenAt,
    last_seen_at: lastSeenAt,
    updated_at: nowIso,
  };
  if (shouldPromote) payload.status = 'active';
  const { error } = await querySupabaseAdmin(env, `tracked_issues?id=eq.${trackedIssue.id}`, 'PATCH', payload);
  if (error) throw new Error(`Tracked issue update failed: ${error.message || ''}`);
}

function getMaxMainWorthiness(articles) {
  const scores = (articles || [])
    .map(article => Number(article.main_worthiness))
    .filter(score => Number.isFinite(score) && score >= 1 && score <= 5);
  return scores.length > 0 ? Math.max(...scores) : null;
}

function getAverageImportance(articles) {
  const scores = (articles || [])
    .map(article => Number(article.importance))
    .filter(score => Number.isFinite(score) && score >= 1 && score <= 5);
  if (scores.length === 0) return null;
  return Math.round((scores.reduce((total, score) => total + score, 0) / scores.length) * 100) / 100;
}

function prioritizeArticlesForAnalysis(articles, currentCategory) {
  const categoryTerms = (CATEGORY_SEARCH_TERMS[currentCategory] || [])
    .map(term => String(term || '').toLowerCase())
    .filter(Boolean);

  return articles
    .slice()
    .sort((a, b) => scoreArticleForAnalysis(b, categoryTerms) - scoreArticleForAnalysis(a, categoryTerms));
}

function scoreArticleForAnalysis(article, categoryTerms) {
  const title = String(article?.title || '').toLowerCase();
  const description = String(article?.description || '').toLowerCase();
  const combined = `${title} ${description}`;
  let score = 0;

  if (categoryTerms.some(term => combined.includes(term))) {
    score += 10;
  }

  if (/(실적|금리|환율|관세|전쟁|폭염|지진|합병|인수|ai|반도체|비트코인|코스피|코스닥|대통령|국회|선거)/i.test(combined)) {
    score += 6;
  }

  if (/\b(삼성|애플|구글|테슬라|엔비디아|메타|마이크로소프트)\b/i.test(article?.title || '')) {
    score += 4;
  }

  const titleLength = (article?.title || '').length;
  if (titleLength >= 12 && titleLength <= 60) {
    score += 2;
  }

  if ((article?.description || '').length >= 80) {
    score += 1;
  }

  return score;
}

function buildIssueLabelMap(trends, keywordStatMap, pairStatMap) {
  const map = new Map();

  for (const trend of trends || []) {
    const labelInfo = getTrendIssueLabel(trend, keywordStatMap, pairStatMap);

    if (!labelInfo) continue;

    if (!map.has(labelInfo.label)) {
      map.set(labelInfo.label, {
        label: labelInfo.label,
        displayKeyword: labelInfo.displayKeyword,
        labelKind: labelInfo.kind,
        count: 0,
      });
    }

    const item = map.get(labelInfo.label);
    item.count += 1;
  }

  return map;
}

function getTrendIssueLabel(trend, keywordStatMap, pairStatMap) {
  const keywords = Array.from(new Set(extractIssueTitleKeywords(trend)))
    .filter(isUsefulKeyword)
    .slice(0, 6);

  if (keywords.length === 0) {
    return null;
  }

  const pairCandidates = [];

  for (let i = 0; i < keywords.length; i++) {
    for (let j = i + 1; j < keywords.length; j++) {
      const pairKey = makePairKey(keywords[i], keywords[j]);
      const pairStat = pairStatMap.get(pairKey);

      if (!pairStat) continue;
      if (pairStat.count < 2) continue;
      if (isGenericClusterKeyword(keywords[i]) && isGenericClusterKeyword(keywords[j])) continue;

      pairCandidates.push({
        label: pairKey,
        displayKeyword: pairKey,
        kind: 'pair',
        score: pairStat.score,
        count: pairStat.count,
      });
    }
  }

  if (pairCandidates.length > 0) {
    pairCandidates.sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (b.count !== a.count) return b.count - a.count;
      return a.label.localeCompare(b.label, 'ko');
    });

    return pairCandidates[0];
  }

  const keywordCandidates = keywords
    .filter(keyword => !isGenericClusterKeyword(keyword))
    .map(keyword => {
      const stat = keywordStatMap.get(keyword);
      return {
        label: keyword,
        displayKeyword: keyword,
        kind: 'single',
        score: stat?.score || 0,
        count: stat?.newsCount || 0,
      };
    })
    .filter(candidate => candidate.count >= 2)
    .sort((a, b) => {
      if (b.score !== a.score) return b.score - a.score;
      if (b.count !== a.count) return b.count - a.count;
      return a.label.localeCompare(b.label, 'ko');
    });

  return keywordCandidates[0] || null;
}

function isGenericClusterKeyword(keyword) {
  return GENERIC_CLUSTER_KEYWORDS.has(String(keyword || '').trim().toUpperCase()) ||
    GENERIC_CLUSTER_KEYWORDS.has(String(keyword || '').trim());
}

function isWeakThemePair(pairKey) {
  return WEAK_THEME_PAIR_TERMS.some(([left, right]) => makePairKey(left, right) === pairKey);
}

function getActionAnchorGroups(keywords) {
  const groups = new Set();

  for (const keyword of keywords) {
    for (const [group, terms] of Object.entries(EVENT_ACTION_ANCHOR_GROUPS)) {
      if (terms.has(keyword)) {
        groups.add(group);
      }
    }
  }

  return groups;
}

function isStrongEntityAnchor(keyword) {
  const value = String(keyword || '').trim();
  if (!value || isGenericClusterKeyword(value)) return false;

  if (KNOWN_EVENT_ENTITIES.has(value) || KNOWN_EVENT_ENTITIES.has(value.toUpperCase())) {
    return true;
  }

  // 영문 대문자/숫자 조합은 기업·지수·제품명일 가능성이 높다. 단, 일반 테마어는 위에서 제외한다.
  if (/^[A-Z][A-Z0-9+.-]{1,}$/.test(value)) return true;

  // 특정 기관명을 계속 열거하지 않고 조직·제도·지표 명칭의 형태를 인식한다.
  // 신규 기관명도 같은 규칙으로 사건 entity 후보가 된다.
  return /(?:위|위원회|협회|노조|은행|공사|공단|법원|검찰|지수|지표|전자|자동차|기본법|특위|특례시|프로젝트|HBM\d+)$/u.test(value);
}

function getClusterEventEvidence(articles) {
  const titleKeywordSets = (articles || []).map(article => new Set(extractIssueTitleKeywords(article)));
  const keywordSets = titleKeywordSets.map(keywords => new Set(
    Array.from(keywords).filter(keyword => !isGenericClusterKeyword(keyword))
  ));

  const sharedSpecificKeywords = keywordSets.length === 0
    ? []
    : Array.from(keywordSets[0]).filter(keyword => keywordSets.every(keywords => keywords.has(keyword)));
  const entitySets = keywordSets.map(keywords => new Set(
    Array.from(keywords).filter(isStrongEntityAnchor)
  ));
  const sharedEntities = entitySets.length === 0
    ? []
    : Array.from(entitySets[0]).filter(entity => entitySets.every(entities => entities.has(entity)));
  // '발표', '논의'처럼 범용 단어여도, 동일하게 반복되면 사건의 행동 맥락이 될 수 있다.
  const actionSets = titleKeywordSets.map(getActionAnchorGroups);
  const sharedActionGroups = actionSets.length === 0
    ? []
    : Array.from(actionSets[0]).filter(group => actionSets.every(groups => groups.has(group)));

  return {
    sharedSpecificKeywords,
    sharedEntities,
    sharedActionGroups,
  };
}

function hasConfidentIssueMembership(cluster) {
  const articles = cluster.articles || [];
  const categories = new Set(articles.map(article => article.category || '기타'));
  const evidence = getClusterEventEvidence(articles);
  const sharedSpecificCount = evidence.sharedSpecificKeywords.length;
  const hasSharedEntity = evidence.sharedEntities.length > 0;
  const hasSharedAction = evidence.sharedActionGroups.length > 0;
  const hasSharedEventAnchor = hasSharedEntity || hasSharedAction;
  const pairKey = String(cluster.canonical_keyword || '').trim();
  const isPairCluster = cluster.labelKind === 'pair' && pairKey.includes('·');
  const pairTerms = isPairCluster ? pairKey.split('·').map(keyword => keyword.trim()) : [];
  const pairHasEventIdentity = pairTerms
    .some(keyword => isStrongEntityAnchor(keyword) || getActionAnchorGroups([keyword]).size > 0);
  // 명시 목록뿐 아니라 entity/action을 전혀 담지 않은 pair도 산업·테마성 pair로 본다.
  const weakThemePair = isPairCluster && (isWeakThemePair(pairKey) || !pairHasEventIdentity);
  const strongEventPair = isPairCluster && !weakThemePair && pairHasEventIdentity;

  // 넓은 산업/테마 pair는 사건 anchor 없이는 어느 category에서도 Issue가 될 수 없다.
  if (weakThemePair) {
    return (sharedSpecificCount >= 2 && hasSharedAction) ||
      (hasSharedEntity && hasSharedAction);
  }

  // 교차 category는 단순 pair 반복이 아니라 공통 사건 근거를 요구한다.
  if (categories.size > 1) {
    return (sharedSpecificCount >= 2 && hasSharedEventAnchor) ||
      (hasSharedEntity && hasSharedAction) ||
      (strongEventPair && sharedSpecificCount >= 3);
  }

  // 같은 category는 구체 공통어 두 개, 또는 entity/action 조합을 요구한다.
  return sharedSpecificCount >= 2 ||
    (hasSharedEntity && hasSharedAction) ||
    (strongEventPair && hasSharedEventAnchor);
}

function hasStrongIssueEvidence(cluster) {
  const evidence = getClusterEventEvidence(cluster.articles || []);
  const hasSharedEntity = evidence.sharedEntities.length > 0;
  const hasSharedAction = evidence.sharedActionGroups.length > 0;
  const hasMultipleSpecificKeywords = evidence.sharedSpecificKeywords.length >= 2;

  return (hasMultipleSpecificKeywords && hasSharedAction) ||
    (hasSharedEntity && (hasSharedAction || hasMultipleSpecificKeywords));
}

function buildIssueClusterSummary(articles, period) {
  const topSummary = articles
    .slice()
    .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))
    .map(article => article.summary_kr || article.korean_title || article.original_title || '')
    .find(Boolean);

  if (!topSummary) {
    return `${period} 기준 주요 기사`;
  }

  return topSummary;
}

function calculateIssueSimilarityScore(article, canonicalKeyword, keywordStatMap, pairStatMap) {
  const keywords = Array.from(new Set(extractIssueTitleKeywords(article)))
    .filter(isUsefulKeyword);

  if (keywords.includes(canonicalKeyword)) {
    return 1;
  }

  if (canonicalKeyword.includes('·')) {
    const [left, right] = canonicalKeyword.split('·').map(part => part.trim());
    if (keywords.includes(left) && keywords.includes(right)) {
      return 0.95;
    }
  }

  const keywordScore = keywords.reduce((acc, keyword) => {
    const stat = keywordStatMap.get(keyword);
    return Math.max(acc, stat?.score || 0);
  }, 0);

  let pairScore = 0;
  for (let i = 0; i < keywords.length; i++) {
    for (let j = i + 1; j < keywords.length; j++) {
      const stat = pairStatMap.get(makePairKey(keywords[i], keywords[j]));
      if (stat) {
        pairScore = Math.max(pairScore, stat.score);
      }
    }
  }

  const combined = Math.max(keywordScore, pairScore);
  if (combined >= 20) return 0.8;
  if (combined >= 10) return 0.6;
  return 0.5;
}

function calculateIssueClusterScore({ currentCount, sourceCount, avgImportance, growthRate, sentimentTemperature }) {
  const articleScore = clampNumber(Math.round(currentCount * 18), 0, 45);
  const sourceScore = clampNumber(Math.round(sourceCount * 8), 0, 20);
  const importanceScore = clampNumber(Math.round(avgImportance * 12), 0, 25);
  const growthScore = growthRate >= 999
    ? 15
    : clampNumber(Math.round(Math.max(growthRate, 0) / 6), 0, 15);
  const sentimentScore = sentimentTemperature >= 70 || sentimentTemperature <= 30 ? 5 : 0;

  return clampNumber(Math.round(articleScore + sourceScore + importanceScore + growthScore + sentimentScore), 0, 100);
}

function classifyIssueStage(currentCount, previousCount, growthRate, lastSeenAt, windowHours) {
  const hoursSinceLastSeen = Math.max(0, (Date.now() - new Date(lastSeenAt).getTime()) / (60 * 60 * 1000));

  if (currentCount <= 0) return 'ended';
  if (previousCount === 0 && currentCount >= 3) return 'new';
  if (growthRate >= 40 && currentCount >= 3) return 'rising';
  if (growthRate <= -35 || hoursSinceLastSeen > windowHours) return 'cooling';
  if (currentCount >= 5 && hoursSinceLastSeen <= Math.max(1, windowHours / 3)) return 'peak';
  return 'rising';
}

function shouldKeepIssueCluster({
  currentCount,
  sourceCount,
  score,
  hasConfidentMembership = false,
  hasStrongEvidence = false,
}) {
  // Membership을 통과하지 못한 theme/false-positive cluster는 유지 단계에서 절대 복구하지 않는다.
  if (!hasConfidentMembership || currentCount < 2 || sourceCount < 2) return false;

  // 3건 이상은 이미 사건 동일성과 출처 다양성이 확인됐으므로 성장률로 다시 제한하지 않는다.
  if (currentCount >= 3) return true;

  // 2건은 독립 출처와 강한 사건 근거가 있을 때만 허용한다.
  if (hasStrongEvidence && score >= 60) return true;
  return false;
}

function selectDailyEditionIssues(items, limit = 3) {
  const scored = (items || [])
    .map(item => ({
      ...item,
      editionPriority: scoreDailyEditionIssue(item),
    }))
    .sort((a, b) => b.editionPriority - a.editionPriority || b.score - a.score || b.lastSeenAt.localeCompare(a.lastSeenAt));

  const selected = [];
  const categoryCounts = new Map();

  for (const item of scored) {
    if (selected.length >= limit) break;
    const category = item.category || '기타';
    const currentCount = categoryCounts.get(category) || 0;

    if ((category === '경제' || category === '정치') && currentCount >= 1) {
      continue;
    }

    if (selected.some(existing => areEditionIssuesOverlapping(existing, item))) {
      continue;
    }

    selected.push(item);
    categoryCounts.set(category, currentCount + 1);
  }

  if (selected.length < limit) {
    for (const item of scored) {
      if (selected.length >= limit) break;
      if (selected.some(existing => existing.id === item.id || areEditionIssuesOverlapping(existing, item))) continue;
      selected.push(item);
    }
  }

  return selected.slice(0, limit);
}

function areEditionIssuesOverlapping(left, right) {
  if (!left || !right || String(left.category || '') !== String(right.category || '')) return false;
  if (String(left.keyword || '') === String(right.keyword || '')) return true;

  const leftKeywords = new Set(extractIssueTitleKeywords({
    korean_title: `${left.keyword || ''} ${left.title || ''}`,
    original_title: left.summary || '',
  }));
  const rightKeywords = new Set(extractIssueTitleKeywords({
    korean_title: `${right.keyword || ''} ${right.title || ''}`,
    original_title: right.summary || '',
  }));
  const shared = Array.from(leftKeywords).filter(keyword => rightKeywords.has(keyword) && !isGenericClusterKeyword(keyword));
  return shared.length >= 2;
}

function scoreDailyEditionIssue(item) {
  const text = `${item.category || ''} ${item.keyword || ''} ${item.title || ''} ${item.summary || ''}`.toLowerCase();
  let score = Number(item.score || 0);

  score += Math.min(Number(item.articleCount || 0) * 4, 24);
  score += Math.min(Number(item.sourceCount || 0) * 7, 28);
  score += Math.min(Math.max(Number(item.growthRate || 0), 0), 80);

  const lastSeenAt = item.lastSeenAt ? new Date(item.lastSeenAt).getTime() : 0;
  const ageHours = lastSeenAt > 0 ? (Date.now() - lastSeenAt) / (60 * 60 * 1000) : 0;
  if (ageHours <= 3) score += 10;
  else if (ageHours <= 8) score += 4;
  else if (ageHours >= 18) score -= 8;

  const categoryBoosts = {
    '경제': 22,
    '정치': 18,
    '사회': 16,
    '세계': 14,
    'IT/과학': 10,
    '생활/문화': 8,
  };
  score += categoryBoosts[item.category] || 0;

  if (/(코스피|코스닥|증시|서킷|사이드카|급등|급락|폭등|폭락|환율|금리|반도체|관세|대출|물가|고용|세금|예산|연준|fomc|수급|외국인|기관|개미|실적|상한가|하한가)/i.test(text)) {
    score += 24;
  }
  if (/(폭염|태풍|호우|지진|화재|파업|리콜|개인정보|해킹|정전|교통|운휴|보안|안전)/i.test(text)) {
    score += 18;
  }
  if (/(대통령|국회|선거|법안|정책|정부)/i.test(text)) {
    score += 10;
  }
  if (/(삼성전자|sk하이닉스|sk스퀘어|삼성전기|현대차|반도체|ai|엔비디아|테슬라)/i.test(text)) {
    score += 10;
  }

  if (/(비트코인|가상자산|암호화폐|코인)/i.test(text)) {
    score -= 18;
  }
  if (/(연예|스포츠|경기 결과|예능)/i.test(text)) {
    score -= 10;
  }
  if (Number(item.sourceCount || 0) <= 1) {
    score -= 8;
  }

  return Math.round(score);
}

function buildEditionSelectionReason(item) {
  const reasons = [];
  if ((item.category || '').trim()) {
    reasons.push(item.category);
  }
  if (Number(item.articleCount || 0) > 0) {
    reasons.push(`기사 ${item.articleCount}건`);
  }
  if (Number(item.sourceCount || 0) > 0) {
    reasons.push(`출처 ${item.sourceCount}곳`);
  }
  if (Number(item.growthRate || 0) >= 50) {
    reasons.push('확산 속도 높음');
  }
  if ((item.keyword || '').match(/코스피|코스닥|증시|환율|금리|반도체|서킷/i)) {
    reasons.push('시장 영향도 높음');
  }
  return reasons.join(' · ');
}

async function buildLiveTrendTimelineFromTrends(env, period, category, limit, minScore) {
  const trends = await getRecentTrends(env, periodToHours(period) * 2, category, 1000);
  if (!trends || trends.length === 0) return [];

  const keywordStats = buildIssueTitleKeywordStats(trends);
  const keywordStatMap = new Map(keywordStats.map(item => [item.keyword, item]));
  const pairStats = buildIssueTitlePairStats(trends);
  const pairStatMap = new Map(pairStats.map(item => [item.key, item]));
  const clusters = buildIssueClustersFromTrends(trends, period, keywordStatMap, pairStatMap);

  return clusters
    .filter(item => item.score >= minScore)
    .sort((a, b) => b.score - a.score || b.lastSeenAt.localeCompare(a.lastSeenAt))
    .slice(0, limit)
    .map((item, index) => ({
      ...item,
      rank: index + 1,
      newsIds: Array.from(new Set((item.newsIds || []).map(value => Number(value)).filter(value => Number.isFinite(value) && value > 0))),
    }));
}

function buildIssueClustersFromTrends(trends, period, keywordStatMap, pairStatMap) {
  const now = Date.now();
  const currentCutoff = now - periodToHours(period) * 60 * 60 * 1000;
  const previousCutoff = now - periodToHours(period) * 2 * 60 * 60 * 1000;
  const currentTrends = trends.filter(trend => trendTimestamp(trend) >= currentCutoff);
  const previousTrends = trends.filter(trend => {
    const ts = trendTimestamp(trend);
    return ts >= previousCutoff && ts < currentCutoff;
  });

  const currentLabelMap = buildIssueLabelMap(currentTrends, keywordStatMap, pairStatMap);
  const previousLabelMap = buildIssueLabelMap(previousTrends, keywordStatMap, pairStatMap);
  const clusterMap = new Map();

  const sortedCurrentTrends = currentTrends
    .slice()
    .sort((a, b) => {
      const importanceDiff = (b.importance || 0) - (a.importance || 0);
      if (importanceDiff !== 0) return importanceDiff;
      return trendTimestamp(b) - trendTimestamp(a);
    });

  for (const trend of sortedCurrentTrends) {
    const labelInfo = getTrendIssueLabel(trend, keywordStatMap, pairStatMap);
    if (!labelInfo) continue;

    const bucket = currentLabelMap.get(labelInfo.label);
    if (!bucket) continue;

    if (!clusterMap.has(bucket.label)) {
      clusterMap.set(bucket.label, {
        id: bucket.label,
        period,
        canonical_keyword: bucket.displayKeyword,
        labelKind: bucket.labelKind,
        categoryCounts: new Map(),
        articles: [],
        sources: new Set(),
        firstSeen: trendTimestamp(trend),
        lastSeen: trendTimestamp(trend),
        totalImportance: 0,
      });
    }

    const cluster = clusterMap.get(bucket.label);
    cluster.articles.push(trend);
    cluster.sources.add(trend.source || 'unknown');
    cluster.firstSeen = Math.min(cluster.firstSeen, trendTimestamp(trend));
    cluster.lastSeen = Math.max(cluster.lastSeen, trendTimestamp(trend));
    cluster.totalImportance += Number(trend.importance || 0);
    cluster.categoryCounts.set(trend.category || '기타', (cluster.categoryCounts.get(trend.category || '기타') || 0) + 1);
  }

  return Array.from(clusterMap.values())
    .map(cluster => {
      const currentCount = cluster.articles.length;
      const sourceCount = cluster.sources.size;
      const avgImportance = currentCount > 0 ? cluster.totalImportance / currentCount : 0;
      const sentiment = summarizeSentiment(cluster.articles);
      const previousCount = previousLabelMap.get(cluster.canonical_keyword)?.count || 0;
      const growthRate = previousCount <= 0
        ? (currentCount >= 3 ? 999 : 0)
        : Math.round(((currentCount - previousCount) / previousCount) * 100);
      const score = calculateIssueClusterScore({
        currentCount,
        sourceCount,
        avgImportance,
        growthRate,
        sentimentTemperature: sentiment.temperature,
      });
      const stage = classifyIssueStage(currentCount, previousCount, growthRate, cluster.lastSeen, periodToHours(period));
      const dominantCategory = Array.from(cluster.categoryCounts.entries())
        .sort((a, b) => b[1] - a[1])[0]?.[0] || '기타';
      const representative = cluster.articles
        .slice()
        .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))[0];

      return {
        id: cluster.id,
        period,
        category: dominantCategory,
        keyword: cluster.canonical_keyword,
        title: representative?.korean_title || representative?.original_title || cluster.canonical_keyword,
        summary: buildIssueClusterSummary(cluster.articles, period),
        articleCount: currentCount,
        sourceCount,
        newsIds: cluster.articles.map(article => article.id).filter(value => value !== null && value !== undefined),
        growthRate,
        score,
        sentimentTemperature: sentiment.temperature,
        stage,
        firstSeenAt: new Date(cluster.firstSeen).toISOString(),
        lastSeenAt: new Date(cluster.lastSeen).toISOString(),
      };
    })
    .filter(item => {
      const cluster = clusterMap.get(item.id);
      if (cluster == null) return false;

      const hasConfidentMembership = hasConfidentIssueMembership(cluster);
      return hasConfidentMembership && shouldKeepIssueCluster({
        currentCount: item.articleCount,
        sourceCount: item.sourceCount,
        score: item.score,
        hasConfidentMembership,
        hasStrongEvidence: hasStrongIssueEvidence(cluster),
      });
    });
}

function buildKeywordPairStats(trends) {
  const bucket = new Map();

  for (const trend of trends || []) {
    const keywords = Array.from(new Set(extractKeywordsFromTrend(trend)))
      .filter(isUsefulKeyword)
      .slice(0, 8);

    for (let i = 0; i < keywords.length; i++) {
      for (let j = i + 1; j < keywords.length; j++) {
        const key = makePairKey(keywords[i], keywords[j]);
        if (!bucket.has(key)) {
          bucket.set(key, {
            key,
            count: 0,
            score: 0,
          });
        }

        const item = bucket.get(key);
        item.count += 1;
        item.score += (trend.importance || 3) + Math.log((trend.view_count || 0) + 1);
      }
    }
  }

  return Array.from(bucket.values())
    .sort((a, b) => b.count - a.count || b.score - a.score || a.key.localeCompare(b.key, 'ko'));
}

function makePairKey(left, right) {
  return [left, right]
    .map(value => String(value || '').trim())
    .filter(Boolean)
    .sort((a, b) => a.localeCompare(b, 'ko'))
    .join('·');
}

function truncateText(text, maxLength) {
  const value = String(text || '').trim();
  if (value.length <= maxLength) {
    return value;
  }

  return `${value.slice(0, Math.max(0, maxLength - 1)).trimEnd()}…`;
}

async function getRecentTrendLinks(env, hours = 24) {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();

  const { data, error } = await querySupabase(
    env,
    `trends?select=link&created_at=gte.${since}`
  );

  if (error || !data) return new Set();

  return new Set(
    data
      .map(row => normalizeLink(row.link))
      .filter(Boolean)
  );
}

// ─────────────────────────────────────────────────
// 미국 주식 공포·탐욕 지수
// ─────────────────────────────────────────────────

async function handleGetFearAndGreed(corsHeaders) {
  return await handleGetStockFearGreed(corsHeaders);
}

async function handleGetStockFearGreed(corsHeaders) {
  try {
    const response = await fetch('https://production.dataviz.cnn.io/index/fearandgreed/graphdata', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      throw new Error('Failed to fetch CNN Fear & Greed data');
    }

    const data = await response.json();
    const current = data.fear_and_greed;

    if (!current) {
      throw new Error('Invalid CNN Fear & Greed response');
    }

    return jsonResponse({
      success: true,
      market: 'stock',
      source: 'CNN Fear & Greed Index',
      score: Math.round(current.score),
      rating: current.rating,
      previous_close: current.previous_close,
      timestamp: current.timestamp,
    }, corsHeaders);
  } catch (error) {
    console.error('CNN API Error:', error.message);

    return jsonResponse({
      success: false,
      error: 'Cannot fetch Fear & Greed Index',
    }, corsHeaders, 500);
  }
}

async function handleGetCryptoFearGreed(corsHeaders) {
  try {
    const response = await fetch('https://api.alternative.me/fng/?limit=1&format=json', {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        'Accept': 'application/json',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      throw new Error('Failed to fetch Crypto Fear & Greed data');
    }

    const data = await response.json();
    const current = Array.isArray(data.data) ? data.data[0] : null;

    if (!current) {
      throw new Error('Invalid Crypto Fear & Greed response');
    }

    return jsonResponse({
      success: true,
      market: 'crypto',
      source: 'Alternative.me Crypto Fear & Greed Index',
      score: clampNumber(parseInt(current.value, 10), 0, 100),
      rating: current.value_classification || 'Neutral',
      timestamp: current.timestamp ? parseInt(current.timestamp, 10) * 1000 : Date.now(),
      time_until_update: current.time_until_update || null,
    }, corsHeaders);
  } catch (error) {
    console.error('Crypto Fear & Greed API Error:', error.message);

    return jsonResponse({
      success: false,
      error: 'Cannot fetch Crypto Fear & Greed Index',
    }, corsHeaders, 500);
  }
}

async function handleGetAiStockSentiment(url, env, corsHeaders) {
  try {
    const period = normalizePeriod(url.searchParams.get('period') || '24h');
    const trends = await getRecentTrends(env, periodToHours(period), '', 800);
    const stockTrends = filterStockMarketTrends(trends);
    const source = stockTrends.length >= 5 ? stockTrends : trends.slice(0, 200);
    const sentiment = summarizeSentiment(source);
    const aiScore = calculateAiStockScore(source, sentiment);
    const keywords = buildKeywordStats(source).slice(0, 6).map(item => ({
      keyword: item.keyword,
      newsCount: item.newsCount,
    }));

    return jsonResponse({
      success: true,
      market: 'stock',
      source: 'Pulse AI Stock Sentiment',
      period,
      score: aiScore.score,
      rating: aiScore.rating,
      summary: aiScore.summary,
      components: aiScore.components,
      newsCount: source.length,
      keywords,
      sentiment,
      timestamp: Date.now(),
    }, corsHeaders);
  } catch (error) {
    console.error('AI Stock Sentiment Error:', error.message);

    return jsonResponse({
      success: false,
      error: 'Cannot calculate AI Stock Sentiment',
    }, corsHeaders, 500);
  }
}

// ─────────────────────────────────────────────────
// 실시간 주가 및 7일 차트 데이터
// ─────────────────────────────────────────────────

async function handleGetMarketData(url, corsHeaders) {
  const symbolsParam = url.searchParams.get('symbols');
  const interval = normalizeChartInterval(url.searchParams.get('interval') || '1d');
  const range = normalizeChartRange(
    url.searchParams.get('range') || defaultChartRangeForInterval(interval),
    interval,
  );

  if (!symbolsParam) {
    return jsonResponse({ success: false, error: 'Missing symbols parameter' }, corsHeaders, 400);
  }

  const symbols = symbolsParam
    .split(',')
    .map(s => s.trim())
    .filter(Boolean)
    .slice(0, 30);

  if (symbols.length === 0) {
    return jsonResponse({ success: false, error: 'No valid symbols' }, corsHeaders, 400);
  }

  const cacheKey = buildMarketDataCacheKey(symbols, interval, range);
  const cachedEntry = MARKET_DATA_CACHE.get(cacheKey);
  const now = Date.now();
  if (cachedEntry && cachedEntry.expiresAt > now) {
    return jsonResponse({
      ...cachedEntry.payload,
      cacheHit: true,
    }, corsHeaders);
  }

  const results = await Promise.all(
    symbols.map(async symbol => {
      try {
        const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=${encodeURIComponent(interval)}&range=${encodeURIComponent(range)}`;

        const response = await fetch(yfUrl, {
          headers: {
            'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
          },
          signal: AbortSignal.timeout(15000),
        });

        if (!response.ok) {
          throw new Error(`Yahoo Finance API failed: ${response.status}`);
        }

        const data = await response.json();
        const result = data.chart?.result?.[0];

        if (!result) {
          throw new Error('No chart data returned');
        }

        const meta = result.meta || {};
        const indicators = result.indicators?.quote?.[0];

        if (!indicators) {
          throw new Error('No quote data returned');
        }

        const currentPrice = Number(meta.regularMarketPrice);

        let previousClose = meta.regularMarketPreviousClose || meta.previousClose || meta.chartPreviousClose;

        if (!previousClose) {
          const closes = (indicators.close || []).filter(v => v !== null && v !== undefined);

          previousClose = closes.length > 1
            ? closes[closes.length - 2]
            : meta.chartPreviousClose;
        }
        previousClose = Number(previousClose);

        const yahooPercentChange = Number(
          meta.regularMarketChangePercent ??
          meta.postMarketChangePercent ??
          meta.preMarketChangePercent
        );

        const percentChange = Number.isFinite(yahooPercentChange)
          ? yahooPercentChange
          : (Number.isFinite(currentPrice) && Number.isFinite(previousClose) && previousClose !== 0)
              ? ((currentPrice - previousClose) / previousClose) * 100
              : 0;

        const priceUpdatedAt = meta.regularMarketTime
          ? new Date(meta.regularMarketTime * 1000).toISOString()
          : (result.timestamp && result.timestamp.length > 0
              ? new Date(result.timestamp[result.timestamp.length - 1] * 1000).toISOString()
              : new Date().toISOString());

        const chartData = (indicators.close || [])
          .map(val => val !== null && val !== undefined ? val : previousClose)
          .filter(val => val !== null && val !== undefined);

        return {
          symbol,
          currentPrice,
          percentChange,
          previousClose: Number.isFinite(previousClose) ? previousClose : null,
          priceUpdatedAt,
          chartData,
        };
      } catch (error) {
        console.error(`Error fetching ${symbol}:`, error.message);

        return {
          symbol,
          error: 'Failed to load',
        };
      }
    })
  );

  const payload = {
    success: true,
    fetchedAt: new Date().toISOString(),
    data: results,
  };

  MARKET_DATA_CACHE.set(cacheKey, {
    expiresAt: now + MARKET_DATA_CACHE_TTL_MS,
    payload,
  });

  return jsonResponse({
    ...payload,
    cacheHit: false,
  }, corsHeaders);
}

// ─────────────────────────────────────────────────
// 차트 상세 데이터 엔드포인트
// ─────────────────────────────────────────────────

async function handleGetChartData(url, corsHeaders) {
  const symbol = url.searchParams.get('symbol');
  const interval = normalizeChartInterval(url.searchParams.get('interval') || '1d');
  const range = normalizeChartRange(
    url.searchParams.get('range') || defaultChartRangeForInterval(interval),
    interval,
  );
  const sourceInterval = getChartSourceInterval(interval);
  const aggregationMinutes = getChartIntervalMinutes(interval);
  const sourceRange = isIntradayChartInterval(interval)
    ? '5d'
    : normalizeChartRange(
        url.searchParams.get('range') || defaultChartRangeForInterval(interval),
        sourceInterval,
      );

  if (!symbol) {
    return jsonResponse({ success: false, error: 'Missing symbol parameter' }, corsHeaders, 400);
  }

  try {
    const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=${encodeURIComponent(sourceInterval)}&range=${encodeURIComponent(sourceRange)}`;

    const response = await fetch(yfUrl, {
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      },
      signal: AbortSignal.timeout(15000),
    });

    if (!response.ok) {
      throw new Error(`Yahoo Finance API failed: ${response.status}`);
    }

    const data = await response.json();
    const result = data.chart?.result?.[0];

    if (!result) {
      throw new Error('No chart data returned');
    }

    const timestamps = result.timestamp || [];
    const ohlc = result.indicators?.quote?.[0];

    if (!ohlc) {
      throw new Error('No OHLC data returned');
    }

    const candleData = timestamps
      .map((time, i) => {
        const close = ohlc.close?.[i] || 0;

        return {
          time,
          open: ohlc.open?.[i] || close || 0,
          high: ohlc.high?.[i] || close || 0,
          low: ohlc.low?.[i] || close || 0,
          close,
        };
      })
      .filter(d => d.close > 0);

    const finalData = aggregationMinutes > getChartIntervalMinutes(sourceInterval) && aggregationMinutes > 0
      ? aggregateCandles(candleData, aggregationMinutes)
      : candleData;

      return jsonResponse({
        success: true,
        symbol,
        interval,
        range,
        sourceInterval,
        sourceRange,
        fetchedAt: new Date().toISOString(),
        data: finalData,
      }, corsHeaders);
  } catch (error) {
    console.error(`Error fetching chart for ${symbol}:`, error.message);

    return jsonResponse({
      success: false,
      error: 'Failed to load chart data',
    }, corsHeaders, 500);
  }
}

// ─────────────────────────────────────────────────
// Supabase
// ─────────────────────────────────────────────────

async function querySupabaseAdmin(env, endpoint, method = 'GET', body = null, single = false) {
  if (!env.SUPABASE_SERVICE_ROLE_KEY) {
    return {
      data: null,
      error: { message: 'Missing SUPABASE_SERVICE_ROLE_KEY' },
    };
  }

  return querySupabase(env, endpoint, method, body, single, env.SUPABASE_SERVICE_ROLE_KEY);
}

async function querySupabase(env, endpoint, method = 'GET', body = null, single = false, apiKey = env.SUPABASE_ANON_KEY) {
  const url = `${env.SUPABASE_URL}/rest/v1/${endpoint}`;
  const isCacheableGet = method === 'GET' && !single;
  const cacheKey = isCacheableGet
    ? new Request(url, {
        method: 'GET',
      })
    : null;

  if (isCacheableGet) {
    try {
      const cached = await caches.default.match(cacheKey);
      if (cached) {
        const cachedJson = await cached.json();
        return {
          data: cachedJson.data,
          error: cachedJson.error || null,
        };
      }
    } catch (_) {}
  }

  const headers = {
    'apikey': apiKey,
    'Authorization': `Bearer ${apiKey}`,
    'Content-Type': 'application/json',
  };

  if (single) {
    headers['Accept'] = 'application/vnd.pgrst.object+json';
  }

  if (method !== 'GET' && method !== 'DELETE') {
    headers['Prefer'] = 'return=representation';
  }

  const options = {
    method,
    headers,
  };

  if (body) {
    options.body = JSON.stringify(body);
  }

  try {
    const response = await fetch(url, options);
    const responseText = await safeReadText(response);

    if (!response.ok) {
      if (isCacheableGet) {
        try {
          const cachePayload = JSON.stringify({
            data: null,
            error: {
              status: response.status,
              message: responseText || response.statusText,
            },
          });
          const cachedResponse = new Response(cachePayload, {
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': `public, max-age=15, stale-while-revalidate=30`,
            },
          });
          await caches.default.put(cacheKey, cachedResponse);
        } catch (_) {}
      }
      return {
        data: null,
        error: {
          status: response.status,
          message: responseText || response.statusText,
        },
      };
    }

    if (method === 'DELETE') {
      return { data: true, error: null };
    }

    let parsed = null;
    try {
      parsed = responseText ? JSON.parse(responseText) : null;
    } catch (_) {
      parsed = null;
    }
    const result = {
      data: parsed,
      error: null,
    };

    if (isCacheableGet) {
      try {
        const cachedResponse = new Response(JSON.stringify(result), {
          headers: {
            'Content-Type': 'application/json',
            'Cache-Control': `public, max-age=${Math.floor(SUPABASE_GET_CACHE_TTL_MS / 1000)}, stale-while-revalidate=${Math.floor((SUPABASE_GET_CACHE_TTL_MS * 2) / 1000)}`,
          },
        });
        await caches.default.put(cacheKey, cachedResponse);
      } catch (_) {}
    }

    return {
      data: parsed,
      error: null,
    };
  } catch (error) {
    return {
      data: null,
      error: {
        message: error.message,
      },
    };
  }
}

// ─────────────────────────────────────────────────
// 유틸리티
// ─────────────────────────────────────────────────

function jsonResponse(data, headers = {}, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      'Content-Type': 'application/json',
      ...SECURITY_RESPONSE_HEADERS,
      ...headers,
    },
  });
}

function enforcePublicRateLimit(request, path, corsHeaders) {
  if (request.method !== 'GET') {
    return null;
  }

  if (!shouldRateLimitPath(path)) {
    return null;
  }

  const clientKey = getClientIdentifier(request);
  const limit = getRateLimitForPath(path);
  const now = Date.now();
  const bucketKey = `${clientKey}:${path}`;
  const bucket = PUBLIC_RATE_LIMIT_BUCKETS.get(bucketKey);

  if (!bucket || bucket.resetAt <= now) {
    PUBLIC_RATE_LIMIT_BUCKETS.set(bucketKey, {
      count: 1,
      resetAt: now + PUBLIC_RATE_LIMIT_WINDOW_MS,
    });
    pruneRateLimitBuckets(now);
    return null;
  }

  if (bucket.count >= limit) {
    const retryAfterSeconds = Math.max(
      1,
      Math.ceil((bucket.resetAt - now) / 1000),
    );
    return jsonResponse(
      {
        success: false,
        error: 'Too many requests',
        retryAfter: retryAfterSeconds,
      },
      {
        ...corsHeaders,
        'Retry-After': String(retryAfterSeconds),
        'Cache-Control': 'no-store',
      },
      429,
    );
  }

  bucket.count += 1;
  return null;
}

function shouldRateLimitPath(path) {
  return (
    path.startsWith('/api/news/search') ||
    path.startsWith('/api/news/by-keyword') ||
    path.startsWith('/api/trend/timeline') ||
    path.startsWith('/api/trends/keywords') ||
    path.startsWith('/api/trends/rising') ||
    path.startsWith('/api/trends/sentiment') ||
    path.startsWith('/api/market-data') ||
    path.startsWith('/api/chart-data')
  );
}

function getRateLimitForPath(path) {
  if (path.startsWith('/api/market-data') || path.startsWith('/api/chart-data')) {
    return 90;
  }

  if (path.startsWith('/api/news/search') || path.startsWith('/api/news/by-keyword')) {
    return 30;
  }

  return 45;
}

function getClientIdentifier(request) {
  return (
    request.headers.get('cf-connecting-ip') ||
    request.headers.get('x-forwarded-for') ||
    request.headers.get('x-real-ip') ||
    'anonymous'
  );
}

function pruneRateLimitBuckets(now = Date.now()) {
  for (const [key, bucket] of PUBLIC_RATE_LIMIT_BUCKETS.entries()) {
    if (!bucket || bucket.resetAt <= now) {
      PUBLIC_RATE_LIMIT_BUCKETS.delete(key);
    }
  }
}

function isDebugEndpointEnabled(env) {
  return String(env?.ENABLE_DEBUG_ENDPOINT || '').toLowerCase() === 'true';
}

function decodeHTMLEntities(text) {
  if (!text) return '';

  const entities = {
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&apos;': "'",
    '&#39;': "'",
    '&nbsp;': ' ',
  };

  let decoded = text;

  for (const [entity, char] of Object.entries(entities)) {
    decoded = decoded.replace(new RegExp(entity, 'g'), char);
  }

  return decoded
    .replace(/&#(\d+);/g, (_, dec) => String.fromCharCode(dec))
    .replace(/&#x([0-9A-Fa-f]+);/g, (_, hex) => String.fromCharCode(parseInt(hex, 16)));
}

function parseJSON(text) {
  try {
    return JSON.parse(text);
  } catch {
    try {
      const match = text.match(/\{[\s\S]*\}/);
      if (match) return JSON.parse(match[0]);
    } catch (e) { }
  }

  return {};
}

function stripHTML(text) {
  return String(text || '').replace(/<[^>]+>/g, '');
}

function sanitizePromptText(text) {
  return String(text || '')
    .replace(/"/g, "'")
    .replace(/\r?\n/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizeTitle(title) {
  return String(title || '')
    .replace(/\s+/g, ' ')
    .trim()
    .toLowerCase();
}

function normalizeLink(link) {
  if (!link) return '';

  try {
    const url = new URL(link);

    url.hash = '';

    const removeParams = [
      'utm_source',
      'utm_medium',
      'utm_campaign',
      'utm_term',
      'utm_content',
      'fbclid',
      'gclid',
    ];

    for (const param of removeParams) {
      url.searchParams.delete(param);
    }

    return url.toString().toLowerCase();
  } catch {
    return String(link).trim().toLowerCase();
  }
}

function normalizeTickers(tickers) {
  if (Array.isArray(tickers)) {
    return tickers
      .map(t => String(t).trim().toUpperCase())
      .filter(Boolean)
      .join(',');
  }

  if (typeof tickers === 'string') {
    return tickers
      .split(',')
      .map(t => t.trim().toUpperCase())
      .filter(Boolean)
      .join(',');
  }

  return '';
}

function clampNumber(value, min, max) {
  const num = Number(value);

  if (Number.isNaN(num)) return min;

  return Math.min(Math.max(num, min), max);
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function safeReadText(response) {
  try {
    return await response.text();
  } catch {
    return '';
  }
}

function pickSearchTermsForThisRun(terms, now, count) {
  if (!terms || terms.length === 0) return [];

  const start = Math.floor(now.getMinutes() / 5) % terms.length;
  const result = [];

  for (let i = 0; i < Math.min(count, terms.length); i++) {
    result.push(terms[(start + i) % terms.length]);
  }

  return result;
}

const KEYWORD_STOPWORDS = new Set([
  '기자', '단독', '속보', '오늘', '이번', '관련', '발표', '공식', '논란', '확인',
  '뉴스', '보도', '사진', '영상', '오전', '오후', '종합', '위원회', '대통령실',
  '대한', '위해', '지난', '오는', '올해', '내년', '최근', '현재', '사실', '입장',
  '정부', '시장', '전망', '가능성', '우리', '국내', '해외', '한국', '미국',
  '위한', '통해', '따르면', '가운데', '이후', '앞두고', '대해', '대비', '대상',
  '예정', '예정이다', '계획', '계획이다', '방침', '방침이다', '것으로', '것이다',
  '문제', '시대', '상황', '경우', '부분', '내용', '결과', '과정', '수준', '기준',
  '있다', '있는', '없다', '한다', '했다', '된다', '됐다', '나선다', '이어진다',
  '밝혔다', '전했다', '말했다', '설명했다', '강조했다', '알려졌다', '보인다',
  '그리고', '하지만', '또한', '관련해', '관해서', '때문에', '위해서', '하면서',
  'the', 'and', 'for', 'with', 'from', 'this', 'that', 'news', 'today',
  '정치', '경제', '사회', '세계', '생활', '문화', '연예', '스포츠', '과학', 'it',
  '증시', '주가', '국제', '국내증시', '글로벌', '산업',
]);

// 기사 제목에 자주 등장하지만 사건 자체를 식별하지는 못하는 단어다.
// 추출 결과에서는 유지하되, 단독 cluster label로는 사용하지 않는다.
const GENERIC_CLUSTER_KEYWORDS = new Set([
  '국회', '정부', '대통령', '정책', '예산', '국비', '경제', '사회',
  '전국', '국내', '관련', '발표', '추진', '계획', '지원', '협의',
  '회의', '의원', '법안', '사업', '대책', '현안', '논의', '요청', '확보',
  'AI', '인공지능',
]);

// 넓은 산업·시장 테마를 나타내므로 pair 자체만으로는 같은 사건을 보장하지 않는다.
const WEAK_THEME_PAIR_TERMS = [
  ['AI', '반도체'],
  ['AI', '시장'],
  ['반도체', '시장'],
  ['경제', '전망'],
  ['수출', '성장'],
  ['부동산', '시장'],
];

// 같은 사건인지 확인할 때 제목에서 공유돼야 하는 행동·변화의 의미 그룹이다.
const EVENT_ACTION_ANCHOR_GROUPS = {
  trade_growth: new Set(['수출', '증가', '성장', '확대']),
  market_movement: new Set(['상승', '하락', '급등', '급락', '반등', '회복', '돌파', '상승세', '하락세', '최고', '최저', '신고가', '신저가', '감소', '축소', '동결']),
  index_change: new Set(['편입', '제외', '추가']),
  supply: new Set(['공급', '생산']),
  transaction: new Set(['인수', '합병', '체결', '협상']),
  launch: new Set(['출시', '발표', '승인']),
  legal_policy: new Set(['규제', '시행', '심사', '조항', '논의']),
  investigation: new Set(['수사', '기소', '판결']),
  price_change: new Set(['인상', '인하']),
  operation_change: new Set(['중단', '재개', '축소']),
};

// 제목 tokenizer만으로도 구분 가능한 대표적인 고유 entity와 제품·법안 표기다.
const KNOWN_EVENT_ENTITIES = new Set([
  '삼성전자', '엔비디아', 'MSCI', 'AI기본법', '정치개혁특위',
  'HBM4', 'OPENAI', '창원특례시',
]);

const POSITIVE_WORDS = [
  '상승', '급등', '호조', '개선', '성장', '확대', '기대', '강세', '최고', '돌파',
  '회복', '성과', '흑자', '수혜', 'positive', 'growth', 'surge', 'record',
];

const NEGATIVE_WORDS = [
  '하락', '급락', '부진', '위기', '우려', '불안', '충격', '논란', '적자', '침체',
  '피해', '사고', '사망', '갈등', '전쟁', '폭락', 'negative', 'crisis', 'risk',
];

async function getRecentTrends(env, hours, category = '', limit = 500) {
  const since = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
  const filters = [
    `created_at=gte.${since}`,
    category ? `category=eq.${encodeURIComponent(category)}` : '',
  ].filter(Boolean).join('&');
  const endpoint = `trends?select=id,korean_title,original_title,summary_kr,importance,main_worthiness,tickers,category,link,source,thumbnail_url,published,created_at,view_count&${filters}&order=published.desc,created_at.desc&limit=${limit}`;
  const { data, error } = await querySupabase(env, endpoint);

  if (error) {
    throw new Error(error.message || 'Failed to fetch recent trends');
  }

  return data || [];
}

function buildKeywordStats(trends) {
  const bucket = new Map();

  for (const trend of trends) {
    const keywords = new Set(extractKeywordsFromTrend(trend));

    for (const keyword of keywords) {
      if (!bucket.has(keyword)) {
        bucket.set(keyword, {
          keyword,
          categoryCounts: new Map(),
          news: [],
          score: 0,
        });
      }

      const item = bucket.get(keyword);
      item.news.push(trend);
      item.score += (trend.importance || 3) + Math.log((trend.view_count || 0) + 1);
      const category = trend.category || '기타';
      item.categoryCounts.set(category, (item.categoryCounts.get(category) || 0) + 1);
    }
  }

  return Array.from(bucket.values())
    .map(item => {
      const topCategory = Array.from(item.categoryCounts.entries())
        .sort((a, b) => b[1] - a[1])[0]?.[0] || '기타';
      const representative = item.news
        .slice()
        .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))[0];

      return {
        keyword: item.keyword,
        category: topCategory,
        newsCount: item.news.length,
        news: item.news,
        score: Math.round(item.score * 10) / 10,
        representativeTitle: representative?.korean_title || representative?.original_title || '',
      };
    })
    .filter(item => item.newsCount >= 1)
    .sort((a, b) => b.newsCount - a.newsCount || b.score - a.score || a.keyword.localeCompare(b.keyword, 'ko'));
}

function buildIssueTitleKeywordStats(trends) {
  const bucket = new Map();

  for (const trend of trends || []) {
    const keywords = new Set(extractIssueTitleKeywords(trend));

    for (const keyword of keywords) {
      if (!bucket.has(keyword)) {
        bucket.set(keyword, {
          keyword,
          categoryCounts: new Map(),
          news: [],
          score: 0,
        });
      }

      const item = bucket.get(keyword);
      item.news.push(trend);
      item.score += (trend.importance || 3) + Math.log((trend.view_count || 0) + 1);
      const category = trend.category || '기타';
      item.categoryCounts.set(category, (item.categoryCounts.get(category) || 0) + 1);
    }
  }

  return Array.from(bucket.values())
    .map(item => {
      const topCategory = Array.from(item.categoryCounts.entries())
        .sort((a, b) => b[1] - a[1])[0]?.[0] || '기타';
      const representative = item.news
        .slice()
        .sort((a, b) => (b.importance || 0) - (a.importance || 0) || trendTimestamp(b) - trendTimestamp(a))[0];

      return {
        keyword: item.keyword,
        category: topCategory,
        newsCount: item.news.length,
        news: item.news,
        score: Math.round(item.score * 10) / 10,
        representativeTitle: representative?.korean_title || representative?.original_title || '',
      };
    })
    .filter(item => item.newsCount >= 1)
    .sort((a, b) => b.newsCount - a.newsCount || b.score - a.score || a.keyword.localeCompare(b.keyword, 'ko'));
}

function buildIssueTitlePairStats(trends) {
  const bucket = new Map();

  for (const trend of trends || []) {
    const keywords = Array.from(new Set(extractIssueTitleKeywords(trend)))
      .filter(isUsefulKeyword)
      .slice(0, 6);

    for (let i = 0; i < keywords.length; i++) {
      for (let j = i + 1; j < keywords.length; j++) {
        const key = makePairKey(keywords[i], keywords[j]);
        if (!bucket.has(key)) {
          bucket.set(key, {
            key,
            count: 0,
            score: 0,
          });
        }

        const item = bucket.get(key);
        item.count += 1;
        item.score += (trend.importance || 3) + Math.log((trend.view_count || 0) + 1);
      }
    }
  }

  return Array.from(bucket.values())
    .sort((a, b) => b.count - a.count || b.score - a.score || a.key.localeCompare(b.key, 'ko'));
}

function extractIssueTitleKeywords(trend) {
  const text = [
    trend.korean_title,
    trend.original_title,
  ].filter(Boolean).join(' ');
  const normalizedText = decodeHTMLEntities(stripHTML(text))
    .replace(/[()[\]{}"'“”‘’.,!?;:<>|/\\+=*&^%$#@~`·…]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const matches = normalizedText.match(/[가-힣A-Za-z0-9][가-힣A-Za-z0-9+.-]{1,}/g) || [];

  return matches
    .map(normalizeKeyword)
    .filter(isUsefulKeyword);
}

function extractKeywordsFromTrend(trend) {
  const text = [
    trend.korean_title,
    trend.original_title,
    trend.summary_kr,
  ].filter(Boolean).join(' ');
  const normalizedText = decodeHTMLEntities(stripHTML(text))
    .replace(/[()[\]{}"'“”‘’.,!?;:<>|/\\+=*&^%$#@~`·…]/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
  const matches = normalizedText.match(/[가-힣A-Za-z0-9][가-힣A-Za-z0-9+.-]{1,}/g) || [];

  return matches
    .map(normalizeKeyword)
    .filter(isUsefulKeyword);
}

function normalizeKeyword(keyword) {
  let value = String(keyword || '')
    .trim()
    .replace(/^[0-9]+$/, '')
    .replace(/(은|는|이|가|을|를|의|에|에서|으로|로|와|과|도|만|부터|까지)$/u, '');

  if (/^[A-Za-z0-9+.-]+$/.test(value)) {
    value = value.toUpperCase();
  }

  return value;
}

function isUsefulKeyword(keyword) {
  if (!keyword || keyword.length < 2 || keyword.length > 20) return false;
  if (KEYWORD_STOPWORDS.has(keyword.toLowerCase()) || KEYWORD_STOPWORDS.has(keyword)) return false;
  if (/^\d+$/.test(keyword)) return false;
  if (/^[가-힣]$/.test(keyword)) return false;
  if (/^[가-힣]+(?:이다|입니다|했다|한다|된다|됐다|있다|없다|왔다|간다|나선다|밝혔다|전했다|말했다)$/u.test(keyword)) return false;
  if (/^[가-힣]+(?:위한|위해|통해|따르면|하면서|이라며|이며|으로서|에게는)$/u.test(keyword)) return false;

  return true;
}

function summarizeSentiment(trends) {
  if (!trends || trends.length === 0) {
    return {
      temperature: 50,
      label: 'neutral',
      positiveRatio: 0,
      neutralRatio: 100,
      negativeRatio: 0,
      count: 0,
      summary: '분석할 뉴스가 아직 충분하지 않습니다.',
    };
  }

  const counts = { positive: 0, neutral: 0, negative: 0 };
  let totalScore = 0;

  for (const trend of trends) {
    const score = calculateSentimentTemperature([trend]);
    totalScore += score;

    if (score >= 71) counts.positive++;
    else if (score <= 30) counts.negative++;
    else counts.neutral++;
  }

  const count = trends.length;
  const temperature = Math.round(totalScore / count);
  const positiveRatio = Math.round((counts.positive / count) * 100);
  const negativeRatio = Math.round((counts.negative / count) * 100);
  const neutralRatio = Math.max(0, 100 - positiveRatio - negativeRatio);
  const label = temperature >= 71 ? 'positive' : temperature <= 30 ? 'negative' : 'neutral';

  return {
    temperature,
    label,
    positiveRatio,
    neutralRatio,
    negativeRatio,
    count,
    summary: label === 'positive'
      ? '오늘 뉴스 분위기는 기대감이 우세합니다.'
      : label === 'negative'
        ? '오늘 뉴스 분위기는 불안감이 큽니다.'
        : '오늘 뉴스 분위기는 중립에 가깝습니다.',
  };
}

function calculateSentimentTemperature(trends) {
  if (!trends || trends.length === 0) return 50;

  let total = 0;

  for (const trend of trends) {
    let score = 50;
    const text = trendSearchText(trend);

    for (const word of POSITIVE_WORDS) {
      if (text.includes(word.toLowerCase())) score += 7;
    }
    for (const word of NEGATIVE_WORDS) {
      if (text.includes(word.toLowerCase())) score -= 7;
    }

    total += clampNumber(score, 0, 100);
  }

  return clampNumber(Math.round(total / trends.length), 0, 100);
}

function filterStockMarketTrends(trends) {
  const stockTerms = [
    '증시', '주식', '코스피', '코스닥', '나스닥', '다우', 's&p', 'sp500', 's&p500',
    '금리', '환율', '채권', '달러', '원화', '연준', 'fed', 'fomc', '실적', '반도체',
    '엔비디아', '테슬라', '애플', '삼성전자', 'sk하이닉스', '시장', '투자',
  ];

  return (trends || []).filter(trend => {
    if ((trend.category || '').includes('경제')) return true;
    const text = trendSearchText(trend);
    return stockTerms.some(term => text.includes(term.toLowerCase()));
  });
}

function calculateAiStockScore(trends, sentiment) {
  if (!trends || trends.length === 0) {
    return {
      score: 50,
      rating: 'neutral',
      summary: '증시 관련 뉴스가 아직 충분하지 않아 중립으로 표시합니다.',
      components: {
        newsSentiment: 50,
        issueMomentum: 50,
        riskBalance: 50,
        importance: 50,
      },
    };
  }

  const count = trends.length;
  const importanceAverage = trends.reduce((sum, item) => sum + (item.importance || 3), 0) / count;
  const importanceScore = clampNumber(Math.round((importanceAverage / 5) * 100), 0, 100);
  const issueMomentum = clampNumber(45 + Math.round(Math.log(count + 1) * 12), 0, 100);
  const riskHits = trends.filter(trend => {
    const text = trendSearchText(trend);
    return NEGATIVE_WORDS.some(word => text.includes(String(word).toLowerCase()));
  }).length;
  const riskBalance = clampNumber(100 - Math.round((riskHits / count) * 100), 0, 100);
  const score = clampNumber(Math.round(
    sentiment.temperature * 0.46 +
    issueMomentum * 0.22 +
    riskBalance * 0.20 +
    importanceScore * 0.12
  ), 0, 100);
  const rating = score >= 75
    ? 'extreme greed'
    : score >= 58
      ? 'greed'
      : score <= 25
        ? 'extreme fear'
        : score <= 42
          ? 'fear'
          : 'neutral';

  return {
    score,
    rating,
    summary: buildAiStockSummary(score, count, sentiment),
    components: {
      newsSentiment: sentiment.temperature,
      issueMomentum,
      riskBalance,
      importance: importanceScore,
    },
  };
}

function buildAiStockSummary(score, count, sentiment) {
  const mood = score >= 75
    ? '강한 낙관'
    : score >= 58
      ? '낙관'
      : score <= 25
        ? '강한 불안'
        : score <= 42
          ? '불안'
          : '중립';

  return `최근 증시 관련 뉴스 ${count}건을 기준으로 ${mood} 흐름입니다. 뉴스 감정온도는 ${sentiment.temperature}점입니다.`;
}

function sortNewsResults(results, sort, query) {
  const list = results.slice();

  if (sort === 'popular') {
    return list.sort((a, b) => (b.view_count || 0) - (a.view_count || 0) || (b.importance || 0) - (a.importance || 0));
  }

  if (sort === 'relevance' && query) {
    return list.sort((a, b) => relevanceScore(b, query) - relevanceScore(a, query) || trendTimestamp(b) - trendTimestamp(a));
  }

  return list.sort((a, b) => trendTimestamp(b) - trendTimestamp(a));
}

function relevanceScore(trend, query) {
  const title = normalizeSearchText(trend.korean_title || trend.original_title || '');
  const summary = normalizeSearchText(trend.summary_kr || '');
  let score = 0;

  if (title.includes(query)) score += 10;
  if (summary.includes(query)) score += 4;
  score += trend.importance || 0;

  return score;
}

function formatNewsItem(row) {
  const temperature = calculateSentimentTemperature([row]);

  return {
    id: row.id,
    title: row.korean_title || row.original_title || '',
    summary: row.summary_kr || '',
    source: row.source || 'Unknown',
    category: row.category || '',
    publishedAt: row.published || row.created_at || '',
    importance: row.importance || 3,
    link: row.link || '',
    thumbnailUrl: row.thumbnail_url || '',
    sentiment: temperature >= 71 ? 'positive' : temperature <= 30 ? 'negative' : 'neutral',
    sentimentScore: temperature,
  };
}

function trendTimestamp(row) {
  const time = Date.parse(row.published || row.created_at || '');
  return Number.isNaN(time) ? 0 : time;
}

function trendSearchText(row) {
  return normalizeSearchText([
    row.korean_title,
    row.original_title,
    row.summary_kr,
    row.category,
    row.source,
  ].filter(Boolean).join(' '));
}

function normalizeSearchText(text) {
  return String(text || '')
    .toLowerCase()
    .replace(/\s+/g, ' ')
    .trim();
}

function normalizePeriod(period) {
  const value = String(period || '').toLowerCase();
  return ['1h', '6h', '24h', '7d'].includes(value) ? value : '24h';
}

function normalizeSort(sort) {
  const value = String(sort || '').toLowerCase();
  return ['latest', 'featured', 'popular', 'relevance'].includes(value) ? value : 'latest';
}

function buildTrendOrder(sort) {
  switch (sort) {
    case 'featured':
      return 'importance.desc,published.desc,created_at.desc';
    case 'popular':
      return 'view_count.desc,importance.desc,published.desc,created_at.desc';
    case 'relevance':
    case 'latest':
    default:
      return 'published.desc,created_at.desc,importance.desc';
  }
}

function buildPeriodFilter(period) {
  if (!period) return '';
  const hours = periodToHours(period);
  const cutoff = new Date(Date.now() - hours * 60 * 60 * 1000).toISOString();
  return `&created_at=gte.${encodeURIComponent(cutoff)}`;
}

function periodToHours(period) {
  switch (period) {
    case '1h':
      return 1;
    case '6h':
      return 6;
    case '7d':
      return 24 * 7;
    case '24h':
    default:
      return 24;
  }
}

function normalizeChartInterval(interval) {
  const value = String(interval || '').toLowerCase();
  return ['1m', '2m', '5m', '15m', '30m', '60m', '90m', '120m', '4h', '1d', '1wk', '1mo'].includes(value)
    ? value
    : '1d';
}

function isIntradayChartInterval(interval) {
  return ['1m', '2m', '5m', '15m', '30m', '60m', '90m', '120m', '4h'].includes(normalizeChartInterval(interval));
}

function getChartIntervalMinutes(interval) {
  switch (normalizeChartInterval(interval)) {
    case '1m':
      return 1;
    case '2m':
      return 2;
    case '5m':
      return 5;
    case '15m':
      return 15;
    case '30m':
      return 30;
    case '60m':
      return 60;
    case '90m':
      return 90;
    case '120m':
      return 120;
    case '4h':
      return 240;
    default:
      return 0;
  }
}

function getChartSourceInterval(interval) {
  const normalized = normalizeChartInterval(interval);
  if (normalized === '120m' || normalized === '4h') return '60m';
  return normalized;
}

function normalizeChartRange(range, interval = '1d') {
  const value = String(range || '').toLowerCase();
  if (isIntradayChartInterval(interval)) {
    return ['1d', '5d', '1mo', '3mo', '6mo'].includes(value) ? value : '1d';
  }
  return ['1d', '5d', '1mo', '3mo', '6mo', '1y', '2y', '5y', '10y', 'ytd', 'max'].includes(value)
    ? value
    : '6mo';
}

function buildMarketDataCacheKey(symbols, interval, range) {
  return [
    normalizeChartInterval(interval),
    normalizeChartRange(range, interval),
    [...symbols].slice().sort().join(','),
  ].join('|');
}

function defaultChartRangeForInterval(interval) {
  if (isIntradayChartInterval(interval)) {
    const normalized = normalizeChartInterval(interval);
    if (normalized === '1m' || normalized === '2m' || normalized === '5m') return '1d';
    if (normalized === '15m' || normalized === '30m') return '5d';
    if (normalized === '60m' || normalized === '90m') return '1mo';
    if (normalized === '120m') return '3mo';
    if (normalized === '4h') return '6mo';
    return '1d';
  }

  switch (normalizeChartInterval(interval)) {
    case '1wk':
      return '5y';
    case '1mo':
      return '10y';
    case '1d':
    default:
      return '6mo';
  }
}

function aggregateCandles(candles, bucketMinutes) {
  if (!Array.isArray(candles) || candles.length === 0) return [];
  if (!bucketMinutes || bucketMinutes <= 0) return candles;

  const bucketSeconds = bucketMinutes * 60;
  const groups = new Map();

  for (const candle of candles) {
    const time = Number(candle?.time);
    if (!Number.isFinite(time)) continue;

    const bucketTime = Math.floor(time / bucketSeconds) * bucketSeconds;
    if (!groups.has(bucketTime)) {
      groups.set(bucketTime, []);
    }
    groups.get(bucketTime).push(candle);
  }

  return Array.from(groups.entries())
    .sort((a, b) => a[0] - b[0])
    .map(([bucketTime, group]) => {
      const first = group[0];
      const last = group[group.length - 1];
      const high = Math.max(...group.map(item => Number(item.high) || 0));
      const low = Math.min(...group.map(item => Number(item.low) || 0));
      return {
        time: bucketTime,
        open: Number(first.open) || Number(first.close) || 0,
        high: high || Number(first.close) || 0,
        low: low || Number(first.close) || 0,
        close: Number(last.close) || Number(first.close) || 0,
      };
    })
    .filter(item => item.close > 0);
}
