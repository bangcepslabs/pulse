import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'mini_chart_card.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({Key? key}) : super(key: key);

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  
  // 💡 서버에서 받아온 실시간 데이터를 매핑할 리스트
  List<Map<String, dynamic>> _marketDataList = [];

  // 💡 화면에 띄울 종목들의 설정값 (야후 API 심볼, 트레이딩뷰 심볼, 화면 표시 정보 등)  
  final List<Map<String, dynamic>> _targetStocks = [
    {'yfSymbol': '^KS11', 'symbol': 'KOSPI', 'tvSymbol': 'KRX:KOSPI', 'title': '코스피', 'prefix': ''},
    {'yfSymbol': '^KQ11', 'symbol': 'KOSDAQ', 'tvSymbol': 'KRX:KOSDAQ', 'title': '코스닥', 'prefix': ''},    
    {'yfSymbol': '^DJI', 'symbol': 'DJI', 'tvSymbol': 'TVC:DJI', 'title': '다우존스', 'prefix': ''},
    {'yfSymbol': '^IXIC', 'symbol': 'IXIC', 'tvSymbol': 'NASDAQ:IXIC', 'title': '나스닥 종합', 'prefix': ''},    
    {'yfSymbol': '^GSPC', 'symbol': 'SPX', 'tvSymbol': 'SP:SPX', 'title': 'S&P 500', 'prefix': ''},
    {'yfSymbol': 'KRW=X', 'symbol': 'USDKRW', 'tvSymbol': 'FX_IDC:USDKRW', 'title': '원/달러 환율', 'prefix': '₩'},
    {'yfSymbol': '005930.KS', 'symbol': '005930', 'tvSymbol': 'KRX:005930', 'title': '삼성전자', 'prefix': '₩'},
    {'yfSymbol': '000660.KS', 'symbol': '000660', 'tvSymbol': 'KRX:000660', 'title': 'SK하이닉스', 'prefix': '₩'},
    {'yfSymbol': 'AAPL', 'symbol': 'AAPL', 'tvSymbol': 'NASDAQ:AAPL', 'title': 'Apple', 'prefix': '\$'},
    {'yfSymbol': 'NVDA', 'symbol': 'NVDA', 'tvSymbol': 'NASDAQ:NVDA', 'title': 'NVIDIA', 'prefix': '\$'},
  ];


  @override
  void initState() {
    super.initState();
    _fetchRealtimeMarketData();
  }

  Future<void> _fetchRealtimeMarketData() async {
    try {
      // 1. 요청할 야후 파이낸스 심볼들을 콤마로 연결 (^KS11,^KQ11,^DJI...)
      final String symbolsQuery = _targetStocks.map((e) => e['yfSymbol']).join(',');
      
      // 💡 반드시 방금 배포하신 본인의 Cloudflare Worker 주소로 변경해 주세요!!
      final String workerUrl = 'https://news-summarizer.bum2432.workers.dev'; 
      final Uri url = Uri.parse('$workerUrl/api/market-data?symbols=$symbolsQuery');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final decodedData = json.decode(response.body);
        if (decodedData['success'] == true) {
          final List<dynamic> apiResults = decodedData['data'];
          
          // 2. API 결과와 _targetStocks 설정을 매칭하여 리스트 완성
          List<Map<String, dynamic>> mergedList = [];
          for (var config in _targetStocks) {
            // API 결과에서 해당 심볼 데이터 찾기
            var apiData = apiResults.firstWhere((item) => item['symbol'] == config['yfSymbol'], orElse: () => null);
            
            if (apiData != null && apiData['error'] == null) {
                print('매핑 성공: ${config['title']} -> Yahoo: ${apiData['symbol']}, TV: ${config['tvSymbol']}');
              mergedList.add({
                ...config,
                'currentPrice': (apiData['currentPrice'] as num).toDouble(),
                'percentChange': (apiData['percentChange'] as num).toDouble(),
                // API에서 넘어온 배열 데이터를 double 타입 배열로 변환
                'chartData': (apiData['chartData'] as List<dynamic>).map((e) => (e as num).toDouble()).toList(),
              });
            }
            else{
                print('매핑 실패: ${config['title']} (야후 심볼: ${config['yfSymbol']})');
            }
          }

          setState(() {
            _marketDataList = mergedList;
            _isLoading = false;
          });
        } else {
          throw Exception('API Success is false');
        }
      } else {
        throw Exception('Server returned ${response.statusCode}');
      }
    } catch (e) {
      print('Market Data Fetch Error: $e');
      setState(() {
        _errorMessage = '실시간 데이터를 불러오지 못했습니다.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    int crossAxisCount = 4;
    if (screenWidth < 1100) crossAxisCount = 3;
    if (screenWidth < 800) crossAxisCount = 2;
    // 모바일에서도 2칸 유지 (1칸은 너무 답답함)

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          '증시 동향',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        actions: [
          // 💡 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRealtimeMarketData();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : _errorMessage.isNotEmpty
            ? Center(child: Text(_errorMessage, style: const TextStyle(color: Colors.red)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '글로벌 주요 지수 및 환율',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.grey),
                    ),
                    const SizedBox(height: 24),
                    
                    // 💡 실시간 데이터로 렌더링되는 바둑판 그리드
                    GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 24,
                      mainAxisSpacing: 24,
                      childAspectRatio: 1.0,
                      children: _marketDataList.map((data) {
                        return MiniChartCard(
                          symbol: data['symbol'],
                          tvSymbol: data['tvSymbol'],
                          title: data['title'],
                          prefix: data['prefix'],
                          currentPrice: data['currentPrice'],
                          percentChange: data['percentChange'],
                          chartData: data['chartData'],
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
    );
  }
}
