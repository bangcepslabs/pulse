# 📱 실시간 뉴스 트렌드 앱

네이버 검색 API와 Groq AI를 활용한 **실시간 뉴스 트렌드 수집 및 분석 시스템**

## 🏗️ 프로젝트 구조

```
BangProject/
│
├── cloudflare-worker/        # Cloudflare Workers (메인 백엔드)
│   ├── src/
│   │   ├── index.js          # RSS 기반 수집 (Yahoo Finance)
│   │   └── index_naver.js    # 네이버 검색 API 기반 (현재 활성)
│   ├── wrangler.toml         # Cloudflare 배포 설정
│   └── package.json
│
├── backend/                   # Python FastAPI 백엔드 (대체 옵션)
│   ├── main.py               # API 서버
│   ├── scraper.py            # RSS 수집
│   ├── database.py           # SQLite 관리
│   ├── scheduler.py          # 스케줄러
│   └── requirements.txt
│
└── frontend/                  # Flutter 모바일 앱
    ├── lib/
    │   ├── main.dart
    │   ├── models/
    │   │   └── trend_item.dart
    │   ├── services/
    │   │   └── api_service.dart
    │   └── screens/
    │       └── home_screen.dart
    └── pubspec.yaml
```

---

## ✨ 주요 기능

### 🌐 Cloudflare Workers (메인 백엔드)
- **2가지 수집 방식**
  - `index.js`: RSS 피드 기반 (Yahoo Finance)
  - `index_naver.js`: 네이버 검색 API 기반 (현재 활성)
- **Round-Robin 수집**: 5분마다 1개 카테고리씩 순환 (경제 → 사회 → 정치 → 국제 → IT/과학)
- **Groq AI 분석**: llama-3.1-8b-instant 모델로 한국어 번역 및 요약
- **Supabase 저장**: PostgreSQL 데이터베이스
- **자동 중복 제거**: 6시간 기준 링크/제목 검사
- **Cron 스케줄**: 5분마다 자동 실행
- **TPM 최적화**: Groq API 한도 내 안전한 요청 관리

### 📱 Flutter 프론트엔드
- **Material 3 디자인**: 세련된 모던 UI
- **카테고리 탭**: 전체/경제/사회/정치/국제/IT과학
- **실시간 순위**: 최신 뉴스 목록 표시
- **중요도 별점**: 1~5점 시각화
- **시간 표시**: 기사 출간 시간 기준 ("N분 전")
- **무한 스크롤**: 20개씩 자동 로딩
- **자동 새로고침**: 5분마다 업데이트
- **상세 뷰**: 바텀 시트로 요약 및 원문 링크

### 🐍 Python 백엔드 (대체 옵션)
- **RSS 피드 수집**: Yahoo Finance 등
- **Ollama 연동**: 로컬 LLM 분석
- **SQLite 저장**: 경량 데이터베이스
- **FastAPI**: RESTful API 제공

---

## 🚀 빠른 시작

### 방법 1: Cloudflare Workers (권장)

이미 배포되어 작동 중입니다!

**접속 주소:**
- API: https://news-summarizer.bum2432.workers.dev
- 트렌드 목록: https://news-summarizer.bum2432.workers.dev/api/trends

**수동 트리거:**
```bash
curl -X POST \
  -H "Authorization: Bearer $SCHEDULER_SECRET" \
  https://news-summarizer.bum2432.workers.dev/api/scheduler/trigger
```

### 방법 2: Python 백엔드 실행

```bash
# 1. 가상환경 생성
cd backend
python -m venv venv

# 2. 활성화
# Windows:
venv\Scripts\activate
# macOS/Linux:
source venv/bin/activate

# 3. 의존성 설치
pip install -r requirements.txt

# 4. Ollama 실행 (별도 터미널)
ollama serve
ollama pull llama3

# 5. 서버 실행
python main.py
```

서버: http://localhost:8000

### 방법 3: Flutter 앱 실행

```bash
cd frontend

# 의존성 설치
flutter pub get

# API 주소 확인 (frontend/lib/services/api_service.dart)
# Cloudflare Workers 사용:
static const String baseUrl = 'https://news-summarizer.bum2432.workers.dev';

# 로컬 Python 사용:
# static const String baseUrl = 'http://localhost:8000';  # iOS Simulator
# static const String baseUrl = 'http://10.0.2.2:8000';   # Android Emulator

# 앱 실행
flutter run
```

---

## 📊 시스템 아키텍처

### 현재 활성 구성 (Cloudflare + Naver API)

```
네이버 검색 API → Cloudflare Worker → Groq AI → Supabase → Flutter App
      ↓                  ↓                ↓          ↓           ↓
   실시간 뉴스      5분 Round-Robin    AI 분석    PostgreSQL   사용자
   검색 결과        (1개 카테고리)     번역/요약   데이터 저장    UI
```

### 데이터 흐름

1. **5분마다 Cron 실행**
   - Round-Robin으로 카테고리 선택 (경제 → 사회 → 정치 → 국제 → IT/과학)
   - 현재 분: `Math.floor(분/5) % 5` → 카테고리 인덱스

2. **네이버 뉴스 검색**
   - 검색어: "경제 뉴스 오늘" 등
   - 최신순 정렬 (`sort=date`)
   - 1시간 이내 기사만 필터링
   - 8개 기사 수집

3. **Groq AI 분석**
   - 한국어 기사: 요약 생성
   - 영문 기사: 한국어 번역 + 요약
   - 중요도 점수 (1~5)
   - 관련 주식 티커 추출
   - 1초 간격 순차 처리 (TPM 한도 준수)

4. **중복 제거 및 저장**
   - 6시간 기준 링크/제목 중복 체크
   - Supabase에 배치 삽입
   - `published`: 기사 출간 시간
   - `created_at`: DB 삽입 시간

5. **정리**
   - 전체 순환 완료 시 7일 이상 데이터 삭제

---

## ⚙️ 환경 설정

### Cloudflare Workers 환경변수

Cloudflare Dashboard → Workers → `news-summarizer` → Settings → Variables:

```
GROQ_API_KEY=gsk_xxxxxxxxxxxxxxxxxxxx
SUPABASE_URL=https://xxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
NAVER_CLIENT_ID=xxxxxx
NAVER_CLIENT_SECRET=xxxxxx
```

### Supabase 테이블 구조

```sql
CREATE TABLE trends (
    id SERIAL PRIMARY KEY,
    original_title TEXT NOT NULL,
    korean_title TEXT NOT NULL,
    summary_kr TEXT,
    importance INTEGER DEFAULT 3,
    tickers TEXT,
    category TEXT,
    link TEXT,
    published TIMESTAMPTZ,        -- 기사 출간 시간
    source TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),  -- DB 삽입 시간
    view_count INTEGER DEFAULT 0
);

CREATE INDEX idx_created_at ON trends(created_at DESC);
CREATE INDEX idx_importance ON trends(importance DESC);
CREATE INDEX idx_category ON trends(category);
```

---

## 📋 API 엔드포인트

### GET /
헬스 체크

**응답:**
```json
{
  "message": "Trend API (Cloudflare Workers)",
  "version": "3.0.0 (Naver API)",
  "status": "healthy"
}
```

### GET /api/trends
트렌드 목록 조회

**파라미터:**
- `limit` (default: 20): 반환 개수
- `offset` (default: 0): 시작 위치
- `category` (optional): 카테고리 필터

**응답:**
```json
{
  "success": true,
  "count": 20,
  "offset": 0,
  "category": "경제",
  "has_more": true,
  "data": [...]
}
```

### GET /api/trends/{id}
트렌드 상세 조회 (조회수 +1)

### POST /api/scheduler/trigger
수동 수집 트리거

Cloudflare Worker에 `SCHEDULER_SECRET`을 등록하고 Bearer 토큰으로 호출해야 합니다.

```bash
cd cloudflare-worker
wrangler secret put SCHEDULER_SECRET
```

**응답:**
```json
{
  "success": true,
  "message": "Collection completed",
  "result": {
    "category": "경제",
    "totalFetched": 8,
    "totalAnalyzed": 7,
    "totalInserted": 5,
    "timestamp": "2026-06-11T05:00:00.000Z"
  }
}
```

### GET /api/debug/latest
최신 5개 데이터 확인 (디버깅용)

---

## 🔧 커스터마이징

### 수집 주기 변경

`cloudflare-worker/wrangler.toml`:
```toml
[triggers]
crons = ["*/5 * * * *"]  # 5분 → 원하는 간격으로 변경
```

### 카테고리 수정

`cloudflare-worker/src/index_naver.js`:
```javascript
const NAVER_CATEGORIES = {
  '경제': '경제 뉴스 오늘',
  '사회': '사회 뉴스 오늘',
  // 추가 카테고리...
};
```

### AI 모델 변경

```javascript
// Groq API 호출 부분
model: 'llama-3.1-8b-instant',  // 다른 모델로 변경
```

### 중복 체크 기간 변경

```javascript
const sixHoursAgo = new Date(Date.now() - 6 * 60 * 60 * 1000);  // 6시간 → 원하는 시간
```

---

## 🐛 문제 해결

### Cloudflare Workers

**배포 실패:**
```bash
cd cloudflare-worker
npm install
wrangler login
wrangler deploy
```

**환경변수 확인:**
```bash
wrangler secret list
```

**로그 확인:**
Cloudflare Dashboard → Workers → `news-summarizer` → Logs

### Flutter 앱

**API 연결 실패:**
- Android 에뮬레이터: `http://10.0.2.2:8000` (로컬 Python)
- iOS 시뮬레이터: `http://localhost:8000` (로컬 Python)
- 실제 기기: `https://news-summarizer.bum2432.workers.dev` (Cloudflare)

**빌드 오류:**
```bash
flutter clean
flutter pub get
flutter run
```

### Python 백엔드

**Ollama 연결 실패:**
```bash
ollama serve
curl http://localhost:11434/api/tags
```

**모듈 없음:**
```bash
pip install -r requirements.txt
```

---

## 💰 비용 및 한도

### Groq API (무료)
- **TPM**: 6,000 tokens/minute
- **TPD**: 500,000 tokens/day
- **RPD**: 14,400 requests/day

### Cloudflare Workers (무료)
- **요청**: 월 100,000 요청
- **크론**: 무제한 (무료)

### Supabase (무료)
- **데이터베이스**: 500MB
- **API 요청**: 무제한

**현재 사용량:**
- 5분마다 1회 수집 → 하루 288회
- 카테고리당 8개 기사 → 하루 약 2,304회 AI 요청
- Groq 한도: 14,400 / 2,304 = **여유 충분** ✅

---

## 📈 성능 특성

- **수집 주기**: 5분 (카테고리별)
- **전체 순환**: 25분 (5개 카테고리)
- **AI 분석**: 기사당 3~5초
- **전체 수집 시간**: 약 40~60초 (8개 기사)
- **API 응답**: ~100ms
- **중복 제거**: 6시간 기준
- **데이터 보관**: 7일

---

## 📚 기술 스택

### Backend
- **Cloudflare Workers**: Serverless 플랫폼
- **Groq API**: LLM 분석 (llama-3.1-8b-instant)
- **Naver Search API**: 뉴스 검색
- **Supabase**: PostgreSQL 데이터베이스

### Frontend
- **Flutter 3.x**: 크로스 플랫폼 모바일
- **Material 3**: UI 디자인 시스템
- **http**: API 통신
- **intl**: 날짜/시간 포맷

### Alternative Backend
- **Python 3.9+**: FastAPI
- **Ollama**: 로컬 LLM
- **SQLite**: 경량 DB
- **APScheduler**: 스케줄링

---

## 🎯 다음 단계

- [ ] 푸시 알림 기능
- [ ] 사용자 맞춤 카테고리 필터
- [ ] 북마크/즐겨찾기
- [ ] 다크 모드
- [ ] 공유 기능
- [ ] 관련 뉴스 추천
- [ ] 트렌드 분석 차트
- [ ] 키워드 알림

---

## 📄 라이선스

개인 학습 목적 프로젝트

---

## 💡 참고 문서

- [Cloudflare Workers](https://developers.cloudflare.com/workers)
- [Groq API](https://console.groq.com/docs)
- [Naver Search API](https://developers.naver.com/docs/serviceapi/search/news/news.md)
- [Supabase](https://supabase.com/docs)
- [Flutter](https://docs.flutter.dev)

---

**즐거운 개발 되세요! 🚀**
