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

const MAX_ANALYSIS_PER_RUN = 4;
const MAX_SEARCH_TERMS_PER_RUN = 2;
const MAX_ARTICLE_AGE_HOURS = 12;
const ANALYSIS_PAUSE_MS = 250;
const NAVER_DISPLAY_COUNT = 30;

const VALID_CATEGORIES = ['경제', '세계', '사회', '정치', '생활/문화', 'IT/과학'];

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const path = url.pathname;

    const corsHeaders = {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type',
    };

    if (request.method === 'OPTIONS') {
      return new Response(null, { headers: corsHeaders });
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

      if (path === '/api/scheduler/trigger') {
        return await handleTriggerCollection(url, env, corsHeaders);
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
        const { data } = await querySupabase(
          env,
          'trends?select=id,korean_title,category,importance,created_at&order=id.desc&limit=5'
        );

        return jsonResponse({ latest_by_id: data || [] }, corsHeaders);
      }

      return jsonResponse({ error: 'Not found' }, corsHeaders, 404);
    } catch (error) {
      console.error('Fetch Error:', error);
      return jsonResponse({ error: error.message }, corsHeaders, 500);
    }
  },

  async scheduled(event, env, ctx) {
    console.log('=== Cron job started at', new Date().toISOString(), '===');

    if (!env.GROQ_API_KEY || !env.SUPABASE_URL || !env.SUPABASE_ANON_KEY || !env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET) {
      console.error('Missing required environment variables!');
      return;
    }

    try {
      const result = await collectAllNews(env);
      console.log('=== Cron job completed ===\nResult:', JSON.stringify(result));
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

  const query = 'id,korean_title,summary_kr,importance,tickers,category,link,source,published,created_at,view_count';
  const filters = category ? `&category=eq.${encodeURIComponent(category)}` : '';

  const { data, error } = await querySupabase(
    env,
    `trends?select=${query}${filters}&order=importance.desc,published.desc,created_at.desc&limit=${limit}&offset=${offset}`
  );

  if (error) throw new Error(error.message || 'Failed to fetch trends');

  return jsonResponse({
    success: true,
    count: data.length,
    offset,
    category,
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

async function handleTriggerCollection(url, env, corsHeaders) {
  console.log('=== Manual trigger requested ===');

  // SCHEDULER_SECRET이 설정된 경우에만 토큰 검증을 수행한다.
  // 기존 환경변수가 없다면 기존처럼 그대로 동작한다.
  if (env.SCHEDULER_SECRET) {
    const token = url.searchParams.get('token');
    if (token !== env.SCHEDULER_SECRET) {
      return jsonResponse({ success: false, error: 'Unauthorized' }, corsHeaders, 401);
    }
  }

  if (!env.NAVER_CLIENT_ID || !env.NAVER_CLIENT_SECRET) {
    return jsonResponse({ success: false, error: 'Missing Naver API keys' }, corsHeaders, 500);
  }

  try {
    const result = await collectAllNews(env);
    return jsonResponse({
      success: true,
      message: 'Collection completed',
      result,
    }, corsHeaders);
  } catch (error) {
    console.error('Trigger error:', error.message);
    return jsonResponse({ success: false, error: error.message }, corsHeaders, 500);
  }
}

// ─────────────────────────────────────────────────
// 핵심 수집 로직
// ─────────────────────────────────────────────────

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

  console.log(`Processing category[${categoryIndex + 1}/${categories.length}]: ${currentCategory} `);

  let totalFetched = 0;
  let totalCandidates = 0;
  let totalAnalyzed = 0;
  let totalInserted = 0;
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

    console.log(`Fetched ${articles.length} unique candidate articles for ${currentCategory}`);

    if (articles.length === 0) {
      console.warn(`No articles found for ${currentCategory}.Search terms: ${searchTerms.join(', ')} `);

      return {
        category: currentCategory,
        totalFetched: 0,
        totalCandidates: 0,
        totalAnalyzed: 0,
        totalInserted: 0,
        status: 'No articles found from Naver API',
      };
    }

    // AI 분석 전에 최근 DB 저장 이력과 비교해서 중복 기사를 먼저 제거한다.
    const existingLinks = await getRecentTrendLinks(env, 24);

    articles = articles.filter(article => {
      const normalized = normalizeLink(article.link);

      if (normalized && existingLinks.has(normalized)) {
        totalSkippedExisting++;
        return false;
      }

      return true;
    });

    articles = articles.slice(0, Math.max(MAX_ANALYSIS_PER_RUN * 2, 12));
    totalCandidates = articles.length;

    console.log(`After DB duplicate filter: ${articles.length} candidates / ${totalSkippedExisting} existing skipped`);

    if (articles.length === 0) {
      return {
        category: currentCategory,
        totalFetched,
        totalCandidates: 0,
        totalAnalyzed: 0,
        totalInserted: 0,
        totalSkippedExisting,
        status: 'All articles already exist',
      };
    }

    console.log(`Starting AI analysis for up to ${MAX_ANALYSIS_PER_RUN} articles...`);

    const analyzed = [];

    for (const article of articles.slice(0, MAX_ANALYSIS_PER_RUN)) {
      try {
        const result = await analyzeSingleArticle({ ...article, category: currentCategory }, env);

        if (result) {
          analyzed.push(result);
          console.log(`  Passed: [${result.importance}] ${result.korean_title.slice(0, 30)} `);
        }

        await sleep(ANALYSIS_PAUSE_MS);
      } catch (error) {
        console.error(`  Analysis failed: "${article.title.slice(0, 30)}" - ${error.message} `);
        errors.push({
          article: article.title.slice(0, 30),
          error: error.message,
        });
      }
    }

    totalAnalyzed = analyzed.length;

    if (analyzed.length > 0) {
      console.log(`Inserting ${analyzed.length} articles to database...`);
      totalInserted = await insertTrends(analyzed, env);
      console.log(`Successfully inserted ${totalInserted} new trends`);
    }

    if (categoryIndex === 0) {
      console.log('Running 7-day cleanup...');
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
    totalAnalyzed,
    totalInserted,
    totalSkippedExisting,
    errors,
  };
}

async function fetchNaverNews(query, env, limit) {
  try {
    const displayCount = clampNumber(NAVER_DISPLAY_COUNT, 10, 100);

    const url = `https://openapi.naver.com/v1/search/news.json?query=${encodeURIComponent(query)}&display=${displayCount}&sort=date`;

    console.log(`  🔍 네이버 API 호출: ${query}`);

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
    console.log(`  📊 네이버 API 응답: ${data.items?.length || 0}개 기사`);

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
          console.log(`  ⏭️ Filtered (${hoursAgo}h old): ${article.title.slice(0, 40)}`);
          return false;
        }

        if (article.description.length < 20) {
          console.log(`  ⏭️ Filtered (Too short): ${article.title.slice(0, 40)}`);
          return false;
        }

        return true;
      })
      .sort((a, b) => b.pubTimestamp - a.pubTimestamp)
      .slice(0, limit);

    console.log(`  ✅ 필터링 완료: ${filtered.length}개 기사 (최근 ${MAX_ARTICLE_AGE_HOURS}시간 이내)`);

    return filtered;
  } catch (error) {
    console.error(`  ❌ fetchNaverNews 오류: ${error.message}`);
    return [];
  }
}

async function analyzeSingleArticle(article, env) {
  const safeTitle = sanitizePromptText(article.title);
  const safeDescription = sanitizePromptText(article.description);
  const isKorean = /[\uAC00-\uD7A3]/.test(safeTitle);

  const prompt = isKorean
    ? `다음 뉴스를 분석해주세요:
원래 카테고리: ${article.category}
제목: ${safeTitle}
내용: ${safeDescription}

[1] 카테고리 분류 규칙
- 경제: 주식, 환율, 금리, 부동산, 기업 실적, 증시, 코스피, 원/달러, 은행, 금융 정책
- 사회: 사건, 사고, 재난, 범죄, 법원 판결, 화재, 교통사고, 보건 이슈
- 정치: 국회, 대통령, 법안, 선거, 정당, 정부 정책, 국내 정치 이슈
- 세계: 국제 정세, 해외 경제, 전쟁, 분쟁, 미국/중국/일본/유럽 주요 사건
- 생활/문화: 영화, 드라마, 음악, 전시, 공연, 패션, 요리, 여행, 레저, 엔터테인먼트, 대중문화
- IT/과학: AI, 반도체, 삼성전자, 애플, 구글, 테슬라, 우주, 과학 기술 혁신

[2] 중요도 산정 기준
- 5점: 글로벌 거시경제 변동, 국가적 대형 재난, 기준금리 결정, 빅테크 중대 발표
- 4점: 주요 대기업 실적/M&A, 국가 주요 법안 통과, 시장 주도 이슈
- 3점: 일반적인 경제 지표, 특정 산업 섹터 동향, 사회적으로 관심이 큰 일반 뉴스
- 2점: 단일 중소기업 소식, 파급력이 적은 일상 뉴스
- 1점: 단순 홍보/광고 기사, 개인 가십, 지역의 작은 사건사고

반드시 아래 형식의 JSON으로만 응답하세요:
{
  "korean_title": "원본 제목 그대로",
  "summary_kr": "핵심만 2~3줄로 요약",
  "importance": 숫자,
  "tickers": ["관련미국주식티커", "없으면빈배열"],
  "category": "올바른카테고리명"
}`
    : `Analyze the following news:
Original Category: ${article.category}
Title: ${safeTitle}
Content: ${safeDescription}

[1] Category Rules
- 경제: Stocks, exchange rates, interest rates, real estate, corporate earnings, KOSPI, USD/KRW, banks, financial policies.
- 사회: Incidents, accidents, disasters, crimes, court rulings, fires, traffic accidents, health issues.
- 정치: Congress, president, legislation, elections, political parties, government policies, domestic politics.
- 세계: International affairs, overseas economy, wars, conflicts, major events in US/China/Japan/Europe.
- 생활/문화: Movies, dramas, music, exhibitions, performances, fashion, food, travel, leisure, entertainment, pop culture.
- IT/과학: AI, semiconductors, Samsung, Apple, Google, Tesla, space, scientific innovations.

[2] Importance Scoring Criteria
- 5: Global macro shifts, national disasters, interest rate decisions, major big tech announcements.
- 4: Major corporate earnings/M&A, key legislation, market-leading issues.
- 3: General economic indicators, sector trends, broadly notable news.
- 2: Small business news, low-impact daily news.
- 1: PR/ads, personal gossip, minor local incidents.

Respond ONLY with valid JSON:
{
  "korean_title": "Translated Korean Title",
  "summary_kr": "Core summary in Korean, 2-3 lines",
  "importance": NUMBER,
  "tickers": ["US_STOCK_TICKER", "OR_EMPTY_ARRAY"],
  "category": "CORRECT_KOREAN_CATEGORY_NAME"
}`;

  const aiResponse = await fetch('https://api.groq.com/openai/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${env.GROQ_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'llama-3.1-8b-instant',
      messages: [
        {
          role: 'system',
          content: 'You are a professional Korean news analyst. Output only valid JSON. Do not include markdown.',
        },
        {
          role: 'user',
          content: prompt,
        },
      ],
      max_tokens: 800,
      temperature: 0.2,
      response_format: { type: 'json_object' },
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
  let finalSummary = analysis.summary_kr || analysis.summary || analysis.description || '';
  let finalCategory = analysis.category || article.category;
  const finalTitle = analysis.korean_title || analysis.title || analysis.Korean_title || safeTitle;

  finalSummary = String(finalSummary).trim();
  finalCategory = String(finalCategory).trim();

  if (!finalSummary || finalSummary.includes('cannot fulfill')) {
    importanceScore = 1;
  }

  const titleAndDesc = `${safeTitle} ${safeDescription}`.toLowerCase();

  if (finalCategory === '경제') {
    const nonEconomicKeywords = ['교회', '목사', '신부', '전도', '예배', '교인', '성경', '종교'];

    if (nonEconomicKeywords.some(kw => titleAndDesc.includes(kw))) {
      console.warn(`  ⚠️ Recategorized to 사회 (Religion detected): ${safeTitle.slice(0, 20)}`);
      finalCategory = '사회';
      importanceScore = 1;
    }
  }

  if (!VALID_CATEGORIES.includes(finalCategory)) {
    finalCategory = article.category;
  }

  if (importanceScore <= 2) {
    console.log(`  🗑️ Dropped (Score ${importanceScore}): ${safeTitle.slice(0, 30)}`);
    return null;
  }

  return {
    original_title: article.title,
    korean_title: finalTitle,
    summary_kr: finalSummary,
    importance: importanceScore,
    tickers: normalizeTickers(analysis.tickers),
    category: finalCategory,
    link: article.link,
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

    console.log(`  📊 Ready to insert: ${newTrends.length} new / ${skipped} duplicates`);

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

  const results = await Promise.all(
    symbols.map(async symbol => {
      try {
        const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=7d`;

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

        const currentPrice = meta.regularMarketPrice;

        let previousClose = meta.previousClose || meta.regularMarketPreviousClose;

        if (!previousClose) {
          const closes = (indicators.close || []).filter(v => v !== null && v !== undefined);

          previousClose = closes.length > 1
            ? closes[closes.length - 2]
            : meta.chartPreviousClose;
        }

        const percentChange = previousClose
          ? ((currentPrice - previousClose) / previousClose) * 100
          : 0;

        const chartData = (indicators.close || [])
          .map(val => val !== null && val !== undefined ? val : previousClose)
          .filter(val => val !== null && val !== undefined);

        return {
          symbol,
          currentPrice,
          percentChange,
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

  return jsonResponse({
    success: true,
    data: results,
  }, corsHeaders);
}

// ─────────────────────────────────────────────────
// 차트 상세 데이터 엔드포인트
// ─────────────────────────────────────────────────

async function handleGetChartData(url, corsHeaders) {
  const symbol = url.searchParams.get('symbol');

  if (!symbol) {
    return jsonResponse({ success: false, error: 'Missing symbol parameter' }, corsHeaders, 400);
  }

  try {
    const yfUrl = `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(symbol)}?interval=1d&range=3mo`;

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

    return jsonResponse({
      success: true,
      symbol,
      data: candleData,
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

async function querySupabase(env, endpoint, method = 'GET', body = null, single = false) {
  const url = `${env.SUPABASE_URL}/rest/v1/${endpoint}`;

  const headers = {
    'apikey': env.SUPABASE_ANON_KEY,
    'Authorization': `Bearer ${env.SUPABASE_ANON_KEY}`,
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

    if (!response.ok) {
      const errorText = await safeReadText(response);

      return {
        data: null,
        error: {
          status: response.status,
          message: errorText || response.statusText,
        },
      };
    }

    if (method === 'DELETE') {
      return { data: true, error: null };
    }

    return {
      data: await response.json(),
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
      ...headers,
    },
  });
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
  const endpoint = `trends?select=id,korean_title,original_title,summary_kr,importance,tickers,category,link,source,published,created_at,view_count&${filters}&order=published.desc,created_at.desc&limit=${limit}`;
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
