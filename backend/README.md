# 백엔드 실행 가이드

## 구조

```
backend/
├── main.py          # FastAPI 서버 진입점
├── database.py      # PostgreSQL (Supabase) DB 관리
├── scheduler.py     # 5분 주기 뉴스 수집 스케줄러
├── scraper.py       # RSS 뉴스 스크래핑 및 Ollama 분석
├── requirements.txt # 패키지 목록
├── .env             # 환경변수 (DB 접속 정보) - Git에 올리지 않음
├── .env.example     # 환경변수 예시
└── venv/            # Python 가상환경
```

---

## 최초 1회 세팅

### 1. Supabase 프로젝트 생성

1. https://supabase.com 접속 → 회원가입/로그인
2. **New Project** 클릭
3. 프로젝트 이름, 비밀번호 설정 후 생성
4. 프로젝트 생성 완료 후 → **Settings** → **Database**
5. **Connection string** 섹션에서 **URI** 모드 선택
6. 연결 문자열 복사 (비밀번호는 직접 입력)

예시:
```
postgresql://postgres.abcd1234:YOUR_PASSWORD@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres
```

### 2. 환경변수 설정

`backend/` 폴더에 `.env` 파일 생성:

```bash
cd backend
cp .env.example .env
```

`.env` 파일을 열고 Supabase 연결 정보 입력:

```env
DATABASE_URL=postgresql://postgres.abcd1234:YOUR_PASSWORD@aws-0-ap-northeast-2.pooler.supabase.com:5432/postgres
```

### 3. 가상환경 생성 (venv 폴더가 없을 때만)

```bash
cd backend
python -m venv venv
```

### 4. 패키지 설치

```bash
# Windows
venv\Scripts\pip install -r requirements.txt

# macOS / Linux
venv/bin/pip install -r requirements.txt
```

---

## 서버 실행

**반드시 `backend/` 폴더 안에서 실행해야 합니다.**

### Windows (PowerShell / CMD)
```bash
cd backend
./venv/Scripts/python.exe -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### macOS / Linux
```bash
cd backend
./venv/bin/python -m uvicorn main:app --host 127.0.0.1 --port 8000 --reload
```

### 또는 main.py 직접 실행
```bash
# Windows
./venv/Scripts/python.exe main.py

# macOS / Linux
./venv/bin/python main.py
```

---

## 확인

서버가 뜨면 아래 주소에서 동작을 확인할 수 있습니다.

| 주소 | 설명 |
|------|------|
| http://127.0.0.1:8000 | 헬스 체크 |
| http://127.0.0.1:8000/docs | Swagger UI (API 문서) |
| http://127.0.0.1:8000/api/trends | 트렌드 목록 |
| http://127.0.0.1:8000/api/scheduler/status | 스케줄러 상태 |

**Supabase 콘솔에서 데이터 확인:**
- Supabase 프로젝트 → **Table Editor** → `trends` 테이블

---

## 동작 방식

1. **서버 시작 즉시** → `trends` 테이블 자동 생성 → 뉴스 수집 1회 실행
2. **이후 5분마다** → 자동으로 RSS 피드 수집 및 Ollama 분석
3. **7일 지난 데이터** → 자동 삭제
4. `--reload` 옵션 → 코드 수정 시 서버 자동 재시작 (개발용)

---

## 트러블슈팅

### 1. `ModuleNotFoundError: No module named 'psycopg2'`
→ 패키지를 다시 설치하세요:
```bash
./venv/Scripts/pip install -r requirements.txt
```

### 2. `connection to server failed`
→ `.env` 파일의 `DATABASE_URL`이 올바른지 확인하세요. Supabase 콘솔에서 비밀번호를 다시 확인하세요.

### 3. 테이블이 생성되지 않음
→ 서버를 재시작하면 자동으로 테이블이 생성됩니다. 또는 Supabase 콘솔 **SQL Editor**에서 수동 생성:

```sql
CREATE TABLE IF NOT EXISTS trends (
    id SERIAL PRIMARY KEY,
    original_title TEXT NOT NULL,
    korean_title TEXT NOT NULL,
    summary_kr TEXT,
    importance INTEGER DEFAULT 3,
    tickers TEXT,
    category TEXT,
    link TEXT,
    thumbnail_url TEXT,
    published TEXT,
    source TEXT,
    created_at TIMESTAMP NOT NULL DEFAULT NOW(),
    view_count INTEGER DEFAULT 0
);

CREATE INDEX idx_created_at ON trends(created_at DESC);
CREATE INDEX idx_importance ON trends(importance DESC);
CREATE INDEX idx_category ON trends(category);
```

---

## 종료

터미널에서 `Ctrl + C`
