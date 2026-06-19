# Cloudflare Workers 배포 가이드

Python FastAPI 백엔드를 **완전히 대체**하는 Cloudflare Workers 버전입니다.

---

## 🚀 배포 준비

### 1. Cloudflare 계정 생성
- https://dash.cloudflare.com 회원가입 (무료)
- Workers & Pages 탭 확인

### 2. Wrangler CLI 설치
```bash
npm install -g wrangler
```

### 3. Cloudflare 로그인
```bash
wrangler login
```

브라우저가 열리면 승인

---

## ⚙️ 환경변수 설정

Supabase 연결 정보를 Workers에 저장:

```bash
cd cloudflare-worker

# Supabase URL 설정 (Settings > API > Project URL)
wrangler secret put SUPABASE_URL
# 입력: https://xxxx.supabase.co

# Supabase anon key 설정 (Settings > API > anon public)
wrangler secret put SUPABASE_ANON_KEY
# 입력: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3...
```

---

## 🎯 배포

```bash
cd cloudflare-worker
npm install
wrangler deploy
```

배포 완료 후 나오는 주소:
```
https://trend-aggregator.YOUR_SUBDOMAIN.workers.dev
```

---

## 🧪 테스트

배포 후 브라우저에서:

```
https://trend-aggregator.YOUR_SUBDOMAIN.workers.dev/
→ 헬스 체크

https://trend-aggregator.YOUR_SUBDOMAIN.workers.dev/api/trends
→ 트렌드 목록
```

---

## 📱 프론트엔드 연결

`frontend/lib/services/api_service.dart` 파일 수정:

```dart
class ApiService {
  // 기존
  // static const String baseUrl = 'http://127.0.0.1:8000';
  
  // 변경
  static const String baseUrl = 'https://trend-aggregator.YOUR_SUBDOMAIN.workers.dev';
```

---

## ⏰ 자동 수집

`wrangler.toml`에 설정된 크론 잡이 **5분마다** 자동으로 뉴스를 수집합니다.

수동 트리거:
```bash
curl -X POST \
  -H "Authorization: Bearer $SCHEDULER_SECRET" \
  https://trend-aggregator.YOUR_SUBDOMAIN.workers.dev/api/scheduler/trigger
```

---

## 💰 요금

- **무료 티어**: 월 10만 요청
- **초과 시**: $0.50 / 100만 요청 (엄청 저렴)
- **크론 잡**: 무료

현실적으로 개인 앱에서는 무료 범위 안에서 충분합니다.

---

## 🔧 로컬 개발

```bash
cd cloudflare-worker
wrangler dev
```

`http://localhost:8787`에서 테스트 가능

---

## 📊 대시보드

Cloudflare 대시보드에서 실시간 모니터링:
- 요청 수
- 에러율
- 응답 시간
- 크론 잡 실행 기록

---

## 🆚 Python 백엔드와 차이점

| 항목 | Python (로컬) | Cloudflare Workers |
|------|---------------|-------------------|
| 배포 | 로컬 PC 필요 | 클라우드 |
| 비용 | 전기세 | 무료 (10만 req/월) |
| 속도 | 회사망 제약 | 전 세계 CDN |
| AI | Ollama (로컬) | Workers AI (내장) |
| 크론 | APScheduler | Cloudflare Cron |
| DB | Supabase | Supabase (동일) |

---

## 🐛 트러블슈팅

### 1. `wrangler: command not found`
```bash
npm install -g wrangler
```

### 2. `Authentication error`
```bash
wrangler login
```

### 3. `Supabase connection failed`
→ 환경변수 확인:
```bash
wrangler secret list
```

### 4. AI 응답이 이상함
→ `src/index.js`의 AI 모델 변경:
```javascript
// 기존: @cf/meta/llama-3.1-8b-instruct
// 대체: @cf/meta/llama-2-7b-chat-int8
```

---

## 📚 참고

- Cloudflare Workers 문서: https://developers.cloudflare.com/workers
- Workers AI 모델 목록: https://developers.cloudflare.com/workers-ai/models
- Wrangler CLI: https://developers.cloudflare.com/workers/wrangler
