"""
FastAPI 백엔드 서버
트렌드 데이터 API 제공
"""
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from contextlib import asynccontextmanager
from typing import List
import logging

from database import TrendDatabase
from scheduler import TrendScheduler

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

# 전역 변수
scheduler = None
database = TrendDatabase()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작/종료 시 실행"""
    global scheduler
    
    # 시작 시 - 스케줄러를 백그라운드로 시작 (서버 응답을 막지 않도록)
    logger.info("Starting Trend API server...")
    scheduler = TrendScheduler()
    
    # 백그라운드 스레드로 시작 (첫 수집이 서버 시작을 블록하지 않음)
    import threading
    thread = threading.Thread(target=scheduler.start, args=(5,), daemon=True)
    thread.start()
    
    yield
    
    # 종료 시
    logger.info("Shutting down Trend API server...")
    if scheduler:
        scheduler.stop()


app = FastAPI(
    title="Trend Aggregator API",
    description="실시간 뉴스 및 증시 트렌드 API",
    version="1.0.0",
    lifespan=lifespan
)

# CORS 설정 (Flutter 앱에서 접근 허용)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # 프로덕션에서는 특정 도메인만 허용
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def read_root():
    """헬스 체크"""
    return {
        "message": "Trend API is running",
        "version": "1.0.0",
        "status": "healthy"
    }


@app.get("/api/trends")
def get_trends(limit: int = 20, offset: int = 0, category: str = ""):
    """최신 트렌드 목록 조회 (무한 스크롤 + 분야별 필터)"""
    try:
        trends = database.get_latest_trends(limit=limit, offset=offset, category=category)
        return {
            "success": True,
            "count": len(trends),
            "offset": offset,
            "category": category,
            "has_more": len(trends) == limit,
            "data": trends,
            "last_updated": scheduler.last_run.isoformat() if scheduler and scheduler.last_run else None
        }
    except Exception as e:
        logger.error(f"Error fetching trends: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/trends/{trend_id}")
def get_trend_detail(trend_id: int):
    """특정 트렌드 상세 조회"""
    try:
        trend = database.get_trend_by_id(trend_id)
        if not trend:
            raise HTTPException(status_code=404, detail="Trend not found")
        
        # 조회수 증가
        database.increment_view_count(trend_id)
        
        return {
            "success": True,
            "data": trend
        }
    except HTTPException:
        raise
    except Exception as e:
        logger.error(f"Error fetching trend detail: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/scheduler/status")
def get_scheduler_status():
    """스케줄러 상태 조회"""
    if not scheduler:
        return {"status": "not initialized"}
    
    return scheduler.get_status()


@app.post("/api/scheduler/trigger")
def trigger_collection():
    """수동으로 트렌드 수집 실행"""
    if not scheduler:
        raise HTTPException(status_code=503, detail="Scheduler not initialized")
    
    try:
        # 백그라운드에서 실행
        import threading
        thread = threading.Thread(target=scheduler.collect_trends_job)
        thread.start()
        
        return {
            "success": True,
            "message": "Trend collection triggered"
        }
    except Exception as e:
        logger.error(f"Error triggering collection: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8000)
