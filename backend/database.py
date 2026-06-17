"""
PostgreSQL (Supabase) 데이터베이스 관리 모듈
트렌드 데이터 저장 및 조회
"""
import psycopg2
from psycopg2.extras import RealDictCursor
from psycopg2.pool import SimpleConnectionPool
from typing import List, Dict, Optional
from datetime import datetime, timedelta
import logging
import os
from dotenv import load_dotenv

load_dotenv()
logger = logging.getLogger(__name__)


class TrendDatabase:
    """트렌드 데이터베이스 관리 클래스 (PostgreSQL/Supabase)"""
    
    def __init__(self):
        # DATABASE_URL 환경변수 우선, 없으면 개별 설정 조합
        database_url = os.getenv('DATABASE_URL')
        
        if not database_url:
            db_host = os.getenv('DB_HOST', 'localhost')
            db_port = os.getenv('DB_PORT', '5432')
            db_name = os.getenv('DB_NAME', 'postgres')
            db_user = os.getenv('DB_USER', 'postgres')
            db_password = os.getenv('DB_PASSWORD', '')
            database_url = f"postgresql://{db_user}:{db_password}@{db_host}:{db_port}/{db_name}"
        
        try:
            # 커넥션 풀 생성 (동시 연결 관리)
            self.pool = SimpleConnectionPool(1, 10, database_url)
            logger.info("Database connection pool created successfully")
            self.init_database()
        except Exception as e:
            logger.error(f"Failed to create database connection pool: {e}")
            raise
    
    def get_connection(self):
        """커넥션 풀에서 연결 가져오기"""
        return self.pool.getconn()
    
    def return_connection(self, conn):
        """커넥션 풀에 연결 반환"""
        self.pool.putconn(conn)
    
    def init_database(self):
        """데이터베이스 테이블 초기화"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                # trends 테이블 생성
                cur.execute("""
                    CREATE TABLE IF NOT EXISTS trends (
                        id SERIAL PRIMARY KEY,
                        original_title TEXT NOT NULL,
                        korean_title TEXT NOT NULL,
                        summary_kr TEXT,
                        importance INTEGER DEFAULT 3,
                        tickers TEXT,
                        category TEXT,
                        link TEXT,
                        published TEXT,
                        source TEXT,
                        created_at TIMESTAMP NOT NULL DEFAULT NOW(),
                        view_count INTEGER DEFAULT 0
                    )
                """)
                
                # 인덱스 생성 (조회 성능 향상)
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_created_at 
                    ON trends(created_at DESC)
                """)
                
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_importance 
                    ON trends(importance DESC)
                """)
                
                cur.execute("""
                    CREATE INDEX IF NOT EXISTS idx_category 
                    ON trends(category)
                """)
                
                conn.commit()
                logger.info("Database initialized successfully")
        except Exception as e:
            conn.rollback()
            logger.error(f"Error initializing database: {e}")
            raise
        finally:
            self.return_connection(conn)
    
    def insert_trends(self, trends: List[Dict]) -> int:
        """트렌드 데이터 삽입"""
        if not trends:
            return 0
        
        inserted_count = 0
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                for trend in trends:
                    try:
                        # 중복 체크 (같은 링크는 24시간 내 중복 방지)
                        cur.execute(
                            """
                            SELECT id FROM trends 
                            WHERE link = %s 
                            AND created_at > %s
                            """,
                            (trend['link'], 
                             datetime.now() - timedelta(hours=24))
                        )
                        
                        if cur.fetchone():
                            logger.info(f"Duplicate trend skipped: {trend['korean_title'][:30]}")
                            continue
                        
                        # 티커 리스트를 문자열로 변환
                        tickers_str = ','.join(trend.get('tickers', []))
                        
                        cur.execute("""
                            INSERT INTO trends (
                                original_title, korean_title, summary_kr, 
                                importance, tickers, category, link, 
                                published, source, created_at
                            ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                        """, (
                            trend['original_title'],
                            trend['korean_title'],
                            trend['summary_kr'],
                            trend['importance'],
                            tickers_str,
                            trend['category'],
                            trend['link'],
                            trend['published'],
                            trend['source'],
                            datetime.fromisoformat(trend['created_at'])
                        ))
                        
                        inserted_count += 1
                        
                    except Exception as e:
                        logger.error(f"Error inserting trend: {str(e)}")
                        continue
                
                conn.commit()
        except Exception as e:
            conn.rollback()
            logger.error(f"Transaction error: {e}")
        finally:
            self.return_connection(conn)
        
        logger.info(f"Inserted {inserted_count} new trends")
        return inserted_count
    
    def get_latest_trends(self, limit: int = 20, offset: int = 0, category: str = "") -> List[Dict]:
        """최신 트렌드 조회 (분야 필터 + 무한 스크롤 offset 지원)"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                if category:
                    cur.execute("""
                        SELECT 
                            id, korean_title, summary_kr, importance, 
                            tickers, category, link, source, created_at, view_count
                        FROM trends
                        WHERE category = %s
                        ORDER BY importance DESC, created_at DESC
                        LIMIT %s OFFSET %s
                    """, (category, limit, offset))
                else:
                    cur.execute("""
                        SELECT 
                            id, korean_title, summary_kr, importance, 
                            tickers, category, link, source, created_at, view_count
                        FROM trends
                        ORDER BY importance DESC, created_at DESC
                        LIMIT %s OFFSET %s
                    """, (limit, offset))
                
                rows = cur.fetchall()
                
                trends = []
                for row in rows:
                    trends.append({
                        'id': row['id'],
                        'korean_title': row['korean_title'],
                        'summary_kr': row['summary_kr'],
                        'importance': row['importance'],
                        'tickers': row['tickers'].split(',') if row['tickers'] else [],
                        'category': row['category'],
                        'link': row['link'],
                        'source': row['source'],
                        'created_at': row['created_at'].isoformat() if row['created_at'] else '',
                        'view_count': row['view_count']
                    })
                
                return trends
        finally:
            self.return_connection(conn)
    
    def increment_view_count(self, trend_id: int):
        """트렌드 조회수 증가"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cur.execute("""
                    UPDATE trends 
                    SET view_count = view_count + 1 
                    WHERE id = %s
                """, (trend_id,))
                conn.commit()
        finally:
            self.return_connection(conn)
    
    def get_trend_by_id(self, trend_id: int) -> Optional[Dict]:
        """특정 트렌드 상세 조회"""
        conn = self.get_connection()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute("""
                    SELECT * FROM trends WHERE id = %s
                """, (trend_id,))
                
                row = cur.fetchone()
                if row:
                    return dict(row)
                return None
        finally:
            self.return_connection(conn)
    
    def cleanup_old_trends(self, days: int = 7):
        """오래된 트렌드 삭제"""
        conn = self.get_connection()
        try:
            with conn.cursor() as cur:
                cutoff_date = datetime.now() - timedelta(days=days)
                cur.execute("""
                    DELETE FROM trends WHERE created_at < %s
                """, (cutoff_date,))
                
                deleted_count = cur.rowcount
                conn.commit()
                
                logger.info(f"Cleaned up {deleted_count} old trends")
                return deleted_count
        finally:
            self.return_connection(conn)
    
    def close(self):
        """커넥션 풀 종료"""
        if self.pool:
            self.pool.closeall()
            logger.info("Database connection pool closed")


# 테스트용
if __name__ == "__main__":
    db = TrendDatabase()
    trends = db.get_latest_trends(5)
    print(f"Found {len(trends)} trends")
    for t in trends:
        print(f"- {t['korean_title']}")
    db.close()
