/// 트렌드 데이터 모델
class TrendItem {
  final int id;
  final String koreanTitle;
  final String summaryKr;
  final int importance;
  final List<String> tickers;
  final String category;
  final String link;
  final String source;
  final String published; // 기사 원본 출간 시간 (사용자에게 표시용)
  final String createdAt; // DB 삽입 시간 (관리용)
  final int viewCount;

  TrendItem({
    required this.id,
    required this.koreanTitle,
    required this.summaryKr,
    required this.importance,
    required this.tickers,
    required this.category,
    required this.link,
    required this.source,
    required this.published,
    required this.createdAt,
    this.viewCount = 0,
  });

  /// JSON에서 TrendItem 객체 생성
  factory TrendItem.fromJson(Map<String, dynamic> json) {
    // id: int or null 모두 처리
    final rawId = json['id'];
    final id = rawId is int ? rawId : int.tryParse(rawId?.toString() ?? '') ?? 0;

    // importance: int or null, 범위 클램프
    final rawImp = json['importance'];
    final importance = (rawImp is int
            ? rawImp
            : int.tryParse(rawImp?.toString() ?? '') ?? 3)
        .clamp(1, 5);

    // tickers: List or comma-separated String or null
    List<String> tickers;
    final rawTickers = json['tickers'];
    if (rawTickers is List) {
      tickers = rawTickers
          .where((e) => e != null && e.toString().isNotEmpty)
          .map((e) => e.toString())
          .toList();
    } else if (rawTickers is String && rawTickers.isNotEmpty) {
      tickers = rawTickers
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else {
      tickers = [];
    }

    return TrendItem(
      id: id,
      koreanTitle: (json['korean_title'] as String? ?? '').trim().isEmpty
          ? (json['original_title'] as String? ?? '제목 없음')
          : json['korean_title'] as String,
      summaryKr: json['summary_kr'] as String? ?? '',
      importance: importance,
      tickers: tickers,
      category: json['category'] as String? ?? '일반',
      link: json['link'] as String? ?? '',
      source: json['source'] as String? ?? 'Unknown',
      published: json['published'] as String? ?? json['created_at'] as String? ?? '', // 출간 시간 우선
      createdAt: json['created_at'] as String? ?? '',
      viewCount: (json['view_count'] as int?) ?? 0,
    );
  }

  /// TrendItem 객체를 JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'korean_title': koreanTitle,
      'summary_kr': summaryKr,
      'importance': importance,
      'tickers': tickers,
      'category': category,
      'link': link,
      'source': source,
      'created_at': createdAt,
      'view_count': viewCount,
    };
  }
}
