import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/trend_item.dart';

/// API 통신 서비스
class ApiService {
  // Cloudflare Workers 주소
  static const String baseUrl = 'https://news-summarizer.bum2432.workers.dev';
  
  /// 최신 트렌드 목록 가져오기
  Future<List<TrendItem>> fetchTrends({int limit = 20, int offset = 0, String category = ''}) async {
    try {
      print('🌐 Fetching from: $baseUrl/api/trends');
      final uri = Uri.parse(
        '$baseUrl/api/trends?limit=$limit&offset=$offset'
        '${category.isNotEmpty ? '&category=${Uri.encodeComponent(category)}' : ''}'
      );
      print('🔗 Full URI: $uri');
      final response = await http.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        print('✅ Response received: ${response.body.length} bytes');
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        
        if (jsonData['success'] == true) {
          final List<dynamic> trendsJson = jsonData['data'];
          print('✅ Parsed ${trendsJson.length} trends');
          return trendsJson.map((json) => TrendItem.fromJson(json)).toList();
        } else {
          throw Exception('API returned success=false');
        }
      } else {
        print('❌ HTTP Error: ${response.statusCode}');
        throw Exception('Failed to load trends: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ Exception: $e');
      if (offset == 0) {
        // 첫 로드 실패 시 mock 데이터 대신 에러를 throw해서 UI에서 처리
        print('API Error: $e');
        throw Exception('서버에 연결할 수 없습니다');
      }
      return [];
    }
  }

  /// 특정 트렌드 상세 정보 가져오기
  Future<TrendItem?> fetchTrendDetail(int id) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/trends/$id'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final jsonData = json.decode(utf8.decode(response.bodyBytes));
        
        if (jsonData['success'] == true) {
          return TrendItem.fromJson(jsonData['data']);
        }
      }
      return null;
    } catch (e) {
      print('API Error: $e');
      return null;
    }
  }

  /// 스케줄러 상태 확인
  Future<Map<String, dynamic>> getSchedulerStatus() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/scheduler/status'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
      return {'status': 'error'};
    } catch (e) {
      print('API Error: $e');
      return {'status': 'offline'};
    }
  }

  /// 수동으로 트렌드 수집 실행
  Future<bool> triggerCollection() async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/scheduler/trigger'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('API Error: $e');
      return false;
    }
  }
}
