# TrendApp.AppHost - .NET Aspire 오케스트레이션

이 프로젝트는 .NET Aspire를 사용하여 전체 Trend Aggregator 시스템을 관리하는 AppHost입니다.

## 🎯 역할

- **Python FastAPI 백엔드** 자동 시작 및 모니터링
- **통합 대시보드** 제공 (로그, 메트릭, 상태)
- **서비스 오케스트레이션** 및 의존성 관리

## 🏗️ 관리 대상 서비스

### 1. Python Backend (FastAPI)
- **포트**: 8000
- **경로**: `../backend`
- **명령어**: `python main.py`
- **역할**: RSS 수집, Ollama AI 처리, API 제공

### 2. Ollama (선택사항)
- **포트**: 11434
- **역할**: 로컬 LLM 서버
- **참고**: 별도로 실행 필요 (`ollama serve`)

## 🚀 실행 방법

### 사전 준비
```bash
# 1. Python 가상환경 및 의존성 설치
cd backend
pip install -r requirements.txt

# 2. Ollama 실행 (별도 터미널)
ollama serve

# 3. Ollama 모델 다운로드 (한 번만)
ollama pull llama3
```

### Aspire AppHost 실행
```bash
cd TrendApp.AppHost

# 방법 1: dotnet run
dotnet run

# 방법 2: Visual Studio에서 실행
# TrendApp.AppHost 프로젝트를 시작 프로젝트로 설정 후 F5
```

### 실행 후 확인
실행하면 자동으로 브라우저가 열리며 Aspire Dashboard가 표시됩니다.

**대시보드 URL**: http://localhost:15000

대시보드에서 확인 가능한 정보:
- ✅ **Resources**: 실행 중인 서비스 목록
- 📊 **Metrics**: 성능 메트릭
- 📝 **Logs**: 실시간 로그 스트림
- 🔍 **Traces**: 분산 추적 (향후 추가)

## 📋 대시보드 기능

### Resources 탭
- **python-backend**: Python FastAPI 서버
  - 상태: Running / Stopped
  - 엔드포인트: http://localhost:8000
  - 로그 보기 버튼

### Console Logs
각 서비스의 콘솔 출력을 실시간으로 확인:
- Python 백엔드의 FastAPI 로그
- RSS 수집 및 Ollama 처리 로그
- 스케줄러 실행 로그

### Structured Logs
- 필터링 가능한 구조화된 로그
- 로그 레벨별 필터 (Info, Warning, Error)
- 시간 범위 필터

## 🔧 설정 커스터마이징

### Program.cs
```csharp
// Python 실행 파일 변경
var pythonBackend = builder.AddExecutable(
    name: "python-backend",
    command: "python3",  // python3으로 변경
    workingDirectory: "../backend",
    args: ["main.py"]
)
.WithHttpEndpoint(port: 8000, name: "api")
.WithEnvironment("PYTHONUNBUFFERED", "1")
.WithEnvironment("OLLAMA_HOST", "http://localhost:11434");  // 환경 변수 추가

// Ollama도 Aspire로 관리 (선택사항)
var ollama = builder.AddExecutable(
    name: "ollama",
    command: "ollama",
    workingDirectory: "..",
    args: ["serve"]
)
.WithHttpEndpoint(port: 11434, name: "ollama-api");
```

### 포트 변경
`launchSettings.json`에서 대시보드 포트 변경:
```json
{
  "profiles": {
    "http": {
      "applicationUrl": "http://localhost:15000"  // 원하는 포트로 변경
    }
  }
}
```

## 🐛 문제 해결

### Python 백엔드가 시작되지 않음
```bash
# 1. Python 경로 확인
which python  # macOS/Linux
where python  # Windows

# 2. 수동으로 백엔드 테스트
cd backend
python main.py
```

### Ollama 연결 실패
```bash
# Ollama 실행 확인
ps aux | grep ollama  # macOS/Linux
tasklist | findstr ollama  # Windows

# Ollama 재시작
pkill ollama
ollama serve
```

### 대시보드 접속 불가
- 방화벽 설정 확인
- 포트 15000이 사용 중인지 확인
- `launchSettings.json`의 URL 확인

## 📊 로그 확인 팁

### Python 백엔드 로그
대시보드 Console Logs에서 `python-backend` 선택:
- `INFO`: 일반 정보 (스케줄러 실행, API 요청)
- `WARNING`: 경고 (API 타임아웃, 중복 데이터)
- `ERROR`: 오류 (Ollama 연결 실패, DB 에러)

### 로그 필터링
```
# 특정 키워드로 필터
- "ollama" → Ollama 관련 로그만
- "ERROR" → 에러만
- "trends" → 트렌드 수집 로그만
```

## 🎯 다음 단계

- [ ] **Service Discovery**: 서비스 간 자동 URL 해석
- [ ] **Health Checks**: 헬스 체크 엔드포인트 추가
- [ ] **Redis 통합**: 캐싱 레이어 추가
- [ ] **Metrics**: OpenTelemetry 메트릭 수집
- [ ] **Container Support**: Docker 컨테이너 지원

## 📚 참고 자료

- [.NET Aspire 공식 문서](https://learn.microsoft.com/en-us/dotnet/aspire/)
- [Aspire Dashboard](https://learn.microsoft.com/en-us/dotnet/aspire/fundamentals/dashboard)
- [AddExecutable API](https://learn.microsoft.com/en-us/dotnet/api/aspire.hosting.executableresourcebuilderextensions)

---

**TrendApp.AppHost**: 모든 서비스를 한 곳에서 쉽게 관리하세요! 🚀
