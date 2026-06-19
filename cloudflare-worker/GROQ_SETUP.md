# Groq API 설정 가이드

Cloudflare Workers AI 대신 **Groq 무료 API**를 사용합니다.

---

## 🎁 Groq 무료 티어

- **일 14,400 요청** (분당 30 요청)
- **Llama 3.1 8B** 모델 사용 (빠르고 정확)
- 신용카드 등록 불필요
- **완전 무료**

---

## 🔑 API 키 발급

### 1. Groq 계정 생성
https://console.groq.com 접속 → Sign Up

### 2. API 키 생성
- 로그인 후 좌측 메뉴 → **API Keys**
- **Create API Key** 클릭
- 키 이름 입력 (예: `news-summarizer`)
- 생성된 키 복사 (예: `gsk_...`)

⚠️ 키는 한 번만 보여주므로 반드시 복사해두세요!

---

## ⚙️ Cloudflare Workers 설정

### 1. 환경변수 추가

Cloudflare 대시보드:
- Workers & Pages → `news-summarizer`
- **Settings** → **Variables**
- **Add variable** 클릭

```
Variable name: GROQ_API_KEY
Value: gsk_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
Type: Encrypted (체크)
```

**Save** 클릭

### 2. AI 바인딩 제거 (선택)

Settings → **Bindings** → `AI` 바인딩 삭제 (더 이상 필요 없음)

### 3. 코드 재배포

Quick Edit에서 `index.js` 코드를 최신 버전으로 교체 후 **Save and Deploy**

---

## ✅ 테스트

```bash
curl -X POST \
  -H "Authorization: Bearer $SCHEDULER_SECRET" \
  https://news-summarizer.bum2432.workers.dev/api/scheduler/trigger
```

Logs 탭에서 정상 작동 확인

---

## 📊 요금 비교

| | Cloudflare AI | Groq API |
|---|---|---|
| 무료 한도 | 일 10,000 Neurons<br>(~40회) | 일 14,400 요청 |
| 초과 비용 | $1,184/월 | **무료** |
| 속도 | 보통 | 매우 빠름 |
| 모델 | Llama 3.1 8B | Llama 3.1 8B |

---

## 🐛 트러블슈팅

### 1. `401 Unauthorized`
→ `GROQ_API_KEY` 환경변수 확인

### 2. `429 Rate Limit`
→ 일 14,400 요청 초과 (다음날 리셋)

### 3. 응답이 느림
→ Groq는 오히려 Cloudflare AI보다 빠름. 네트워크 확인

---

## 🔗 참고

- Groq 콘솔: https://console.groq.com
- Groq 문서: https://console.groq.com/docs
- 요금제: https://console.groq.com/settings/limits
