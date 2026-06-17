"""
스케줄러 모듈
10분마다 뉴스 수집 및 분석 작업 실행
"""
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.interval import IntervalTrigger
from datetime import datetime
import logging

from scraper import NewsScraper
from database import TrendDatabase

logger = logging.getLogger(__name__)


class TrendScheduler:
    """트렌드 수집 스케줄러"""
    
    def __init__(self):
        self.scheduler = BackgroundScheduler()
        self.scraper = NewsScraper()
        self.database = TrendDatabase()
        self.last_run = None
        self.is_running = False
    
    def collect_trends_job(self):
        """트렌드 수집 작업 - 모든 분야"""
        if self.is_running:
            logger.warning("Previous job still running, skipping...")
            return

        self.is_running = True
        try:
            logger.info("=" * 50)
            logger.info(f"Starting scheduled collection at {datetime.now()}")

            from scraper import RSS_FEEDS
            total_inserted = 0

            for category in RSS_FEEDS.keys():
                try:
                    analyzed = self.scraper.collect_and_analyze(category=category, limit=10)
                    inserted = self.database.insert_trends(analyzed)
                    total_inserted += inserted
                    logger.info(f"[{category}] inserted: {inserted}")
                except Exception as e:
                    logger.error(f"[{category}] collection failed: {e}")

            deleted_count = self.database.cleanup_old_trends(days=7)
            self.last_run = datetime.now()
            logger.info(f"Job completed: {total_inserted} new, {deleted_count} deleted")
            logger.info("=" * 50)

        except Exception as e:
            logger.error(f"Error in scheduled job: {str(e)}", exc_info=True)
        finally:
            self.is_running = False
    
    def start(self, interval_minutes: int = 10):
        """스케줄러 시작"""
        # 즉시 한 번 실행
        logger.info("Running initial trend collection...")
        self.collect_trends_job()
        
        # 주기적 실행 설정
        self.scheduler.add_job(
            func=self.collect_trends_job,
            trigger=IntervalTrigger(minutes=interval_minutes),
            id='trend_collection_job',
            name='Collect and analyze trends',
            replace_existing=True
        )
        
        self.scheduler.start()
        logger.info(f"Scheduler started: running every {interval_minutes} minutes")
    
    def stop(self):
        """스케줄러 중지"""
        self.scheduler.shutdown()
        logger.info("Scheduler stopped")
    
    def get_status(self) -> dict:
        """스케줄러 상태 조회"""
        return {
            'is_running': self.scheduler.running,
            'last_run': self.last_run.isoformat() if self.last_run else None,
            'next_run': self.scheduler.get_job('trend_collection_job').next_run_time.isoformat()
            if self.scheduler.get_job('trend_collection_job') else None
        }


# 테스트용
if __name__ == "__main__":
    scheduler = TrendScheduler()
    scheduler.start(interval_minutes=1)  # 테스트: 1분마다
    
    import time
    try:
        while True:
            time.sleep(10)
            print(f"Status: {scheduler.get_status()}")
    except KeyboardInterrupt:
        scheduler.stop()
