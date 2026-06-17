var builder = DistributedApplication.CreateBuilder(args);

// Python FastAPI 백엔드를 외부 실행 파일로 등록 (가상환경 사용)
var pythonBackend = builder.AddExecutable(
    name: "python-backend",
    command: "../backend/venv/Scripts/python.exe",  // 가상환경의 Python
    workingDirectory: "../backend",
    args: ["main.py"]
)
.WithHttpEndpoint(port: 8000, name: "api")
.WithEnvironment("PYTHONUNBUFFERED", "1"); // Python 로그를 즉시 출력

// Ollama 서버 (이미 실행 중이라고 가정하지만, 모니터링용으로 등록 가능)
// var ollama = builder.AddExecutable(
//     name: "ollama",
//     command: "ollama",
//     workingDirectory: "..",
//     args: ["serve"]
// )
// .WithHttpEndpoint(port: 11434, name: "ollama-api");

// 앱 빌드 및 실행
var app = builder.Build();

await app.RunAsync();
