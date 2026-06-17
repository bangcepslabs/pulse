"""
RSS 뉴스 수집 및 Ollama AI 처리 모듈
분야별 RSS 피드에서 뉴스를 가져와 Ollama로 한국어 요약 및 분석
"""
import feedparser
import requests
import json
from typing import List, Dict, Optional
from datetime import datetime
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# 분야별 RSS 피드 정의
RSS_FEEDS = {
    "경제": [
        "https://finance.yahoo.com/news/rssindex",              # 야후 파이낸스
        "https://finance.yahoo.com/rss/topstories",             # 야후 파이낸스 주요
        "http://file.mk.co.kr/news/rss/rss_30100041.xml",      # 매일경제 경제
        "http://rss.hankyung.com/economy.xml",                  # 한국경제 경제/금융
        "http://rss.hankyung.com/stock.xml",                    # 한국경제 증권
    ],
    "사회": [
        "https://www.yonhapnews.co.kr/RSS/society.xml",        # 연합뉴스 사회
        "http://imnews.imbc.com/rss/news/news_05.xml",         # MBC 사회
        "http://rss.nocutnews.co.kr/NocutSocial.xml",          # 노컷뉴스 사회
        "http://rss.donga.com/national.xml",                    # 동아일보 사회
        "http://www.khan.co.kr/rss/rssdata/society.xml",       # 경향신문 사회
    ],
    "정치": [
        "https://www.yonhapnews.co.kr/RSS/politics.xml",       # 연합뉴스 정치
        "http://imnews.imbc.com/rss/news/news_01.xml",         # MBC 정치
        "http://rss.nocutnews.co.kr/NocutPolitics.xml",        # 노컷뉴스 정치
        "http://rss.donga.com/politics.xml",                    # 동아일보 정치
    ],
    "국제": [
        "https://www.yonhapnews.co.kr/RSS/international.xml",  # 연합뉴스 국제
        "https://feeds.reuters.com/reuters/topNews",            # 로이터
        "http://rss.donga.com/international.xml",               # 동아일보 국제
        "http://imnews.imbc.com/rss/news/news_03.xml",         # MBC 국제
    ],
    "IT/과학": [
        "http://www.khan.co.kr/rss/rssdata/itnews.xml",        # 경향신문 IT
        "http://file.mk.co.kr/news/rss/rss_30000001.xml",      # 매일경제 IT
        "https://feeds.feedburner.com/venturebeat/SZYF",        # VentureBeat
    ],
}


class NewsScraper:
    """뉴스 수집 및 AI 처리 클래스"""

    def __init__(self, ollama_url: str = "http://localhost:11434/api/chat"):
        self.ollama_url = ollama_url

    def fetch_rss_feeds(self, category: str, limit: int = 10) -> List[Dict]:
        """분야별 RSS 피드에서 최신 뉴스 가져오기"""
        feeds = RSS_FEEDS.get(category, [])
        all_articles = []

        for feed_url in feeds:
            try:
                logger.info(f"Fetching RSS [{category}]: {feed_url}")
                feed = feedparser.parse(feed_url)

                for entry in feed.entries:
                    article = {
                        'title': entry.get('title', ''),
                        'link': entry.get('link', ''),
                        'summary': entry.get('summary', '')[:500],
                        'published': entry.get('published', ''),
                        'source': feed.feed.get('title', feed_url.split('/')[2])
                    }
                    if article['title']:
                        all_articles.append(article)

                if len(all_articles) >= limit * 2:
                    break

            except Exception as e:
                logger.error(f"Error fetching {feed_url}: {str(e)}")
                continue

        # 중복 제거 후 limit 적용
        seen = set()
        unique = []
        for a in all_articles:
            if a['title'] not in seen:
                seen.add(a['title'])
                unique.append(a)

        return unique[:limit]

    def analyze_with_ollama(self, article: Dict, category: str) -> Optional[Dict]:
        """Ollama API를 사용하여 뉴스 분석 및 한국어 요약"""

        # 제목이 한글이면 번역 불필요
        is_korean = any('\uAC00' <= c <= '\uD7A3' for c in article['title'])

        if is_korean:
            prompt = f"""다음 한국어 뉴스를 분석해주세요:

제목: {article['title']}
내용: {article['summary']}

반드시 아래 JSON 형식으로만 응답하세요:
{{
    "korean_title": "{article['title']}",
    "summary_kr": "2~3줄 핵심 요약",
    "importance": 3,
    "tickers": [],
    "category": "{category}"
}}

importance는 1~5 정수, tickers는 관련 주식 종목코드 배열 (없으면 [])"""
        else:
            prompt = f"""다음 영문 뉴스를 한국어로 분석해주세요:

제목: {article['title']}
내용: {article['summary']}

반드시 아래 JSON 형식으로만 응답하세요:
{{
    "korean_title": "한국어 번역 제목",
    "summary_kr": "2~3줄 한국어 핵심 요약",
    "importance": 3,
    "tickers": [],
    "category": "{category}"
}}

importance는 1~5 정수, tickers는 관련 주식 종목코드 배열 (없으면 [])"""

        try:
            response = requests.post(
                self.ollama_url,
                json={
                    "model": "gemma3:4b",
                    "messages": [{"role": "user", "content": prompt}],
                    "stream": False,
                    "format": "json"
                },
                timeout=60
            )

            if response.status_code == 200:
                result = response.json()
                content = result.get('message', {}).get('content', '{}')

                try:
                    analysis = json.loads(content)
                    return {
                        'original_title': article['title'],
                        'korean_title': analysis.get('korean_title', article['title']),
                        'summary_kr': analysis.get('summary_kr', ''),
                        'importance': int(analysis.get('importance', 3)),
                        'tickers': analysis.get('tickers', []),
                        'category': category,
                        'link': article['link'],
                        'published': article['published'],
                        'source': article['source'],
                        'created_at': datetime.now().isoformat()
                    }
                except (json.JSONDecodeError, ValueError) as e:
                    logger.error(f"JSON parsing error: {e}")
                    return None
            else:
                logger.error(f"Ollama API error: {response.status_code}")
                return None

        except requests.exceptions.Timeout:
            logger.error("Ollama API timeout")
            return None
        except Exception as e:
            logger.error(f"Error calling Ollama: {e}")
            return None

    def collect_and_analyze(self, category: str = "경제", limit: int = 10) -> List[Dict]:
        """특정 분야 RSS 수집 및 분석"""
        logger.info(f"Collecting [{category}] news...")

        raw_articles = self.fetch_rss_feeds(category, limit)
        logger.info(f"Collected {len(raw_articles)} articles for [{category}]")

        analyzed = []
        for i, article in enumerate(raw_articles, 1):
            logger.info(f"Analyzing [{category}] {i}/{len(raw_articles)}: {article['title'][:50]}...")
            result = self.analyze_with_ollama(article, category)
            if result:
                analyzed.append(result)

        logger.info(f"[{category}] analyzed: {len(analyzed)} articles")
        return analyzed


if __name__ == "__main__":
    scraper = NewsScraper()
    for cat in ["경제", "사회"]:
        results = scraper.collect_and_analyze(cat, limit=3)
        print(f"\n=== {cat} ===")
        for item in results:
            print(f"  - {item['korean_title']}")
