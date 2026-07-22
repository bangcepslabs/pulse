import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../widgets/app_drawer.dart';
import 'fear_greed_page.dart';
import 'home_screen.dart';
import 'landing_screen.dart';
import 'mini_chart_card.dart';

class MarketPage extends StatefulWidget {
  const MarketPage({super.key});

  @override
  State<MarketPage> createState() => _MarketPageState();
}

class _MarketPageState extends State<MarketPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  List<Map<String, dynamic>> _marketDataList = [];

  final List<Map<String, dynamic>> _targetStocks = [
    {
      'yfSymbol': '^KS11',
      'symbol': 'KOSPI',
      'tvSymbol': 'KRX:KOSPI',
      'title': '\uCF54\uC2A4\uD53C',
      'prefix': ''
    },
    {
      'yfSymbol': '^KQ11',
      'symbol': 'KOSDAQ',
      'tvSymbol': 'KRX:KOSDAQ',
      'title': '\uCF54\uC2A4\uB2E5',
      'prefix': ''
    },
    {
      'yfSymbol': '^DJI',
      'symbol': 'DJI',
      'tvSymbol': 'TVC:DJI',
      'title': '\uB2E4\uC6B0\uC874\uC2A4',
      'prefix': ''
    },
    {
      'yfSymbol': '^IXIC',
      'symbol': 'IXIC',
      'tvSymbol': 'NASDAQ:IXIC',
      'title': '\uB098\uC2A4\uB2E5 \uC885\uD569',
      'prefix': ''
    },
    {
      'yfSymbol': '^GSPC',
      'symbol': 'SPX',
      'tvSymbol': 'SP:SPX',
      'title': 'S&P 500',
      'prefix': ''
    },
    {
      'yfSymbol': 'KRW=X',
      'symbol': 'USDKRW',
      'tvSymbol': 'FX_IDC:USDKRW',
      'title': '\uB2EC\uB7EC/\uC6D0 \uD658\uC728',
      'prefix': ''
    },
    {
      'yfSymbol': '005930.KS',
      'symbol': '005930',
      'tvSymbol': 'KRX:005930',
      'title': '\uC0BC\uC131\uC804\uC790',
      'prefix': ''
    },
    {
      'yfSymbol': '000660.KS',
      'symbol': '000660',
      'tvSymbol': 'KRX:000660',
      'title': 'SK\uD558\uC774\uB2C9\uC2A4',
      'prefix': ''
    },
    {
      'yfSymbol': '402340.KS',
      'symbol': '402340',
      'tvSymbol': 'KRX:402340',
      'title': 'SK\uC2A4\uD018\uC5B4',
      'prefix': ''
    },
    {
      'yfSymbol': '009150.KS',
      'symbol': '009150',
      'tvSymbol': 'KRX:009150',
      'title': '\uC0BC\uC131\uC804\uAE30',
      'prefix': ''
    },
    {
      'yfSymbol': '005380.KS',
      'symbol': '005380',
      'tvSymbol': 'KRX:005380',
      'title': '\uD604\uB300\uCC28',
      'prefix': ''
    },
  ];

  String? _naverFinanceUrl(String symbol) {
    if (symbol.isEmpty || symbol.startsWith('^') || symbol.contains('=')) {
      return null;
    }
    return 'https://finance.naver.com/item/main.naver?code=$symbol';
  }

  @override
  void initState() {
    super.initState();
    _fetchRealtimeMarketData();
  }

  Future<void> _fetchRealtimeMarketData() async {
    try {
      final symbolsQuery = _targetStocks.map((e) => e['yfSymbol']).join(',');
      final uri = Uri.parse(
        'https://news-summarizer.bum2432.workers.dev/api/market-data?symbols=$symbolsQuery',
      );
      final response = await http.get(uri);

      if (response.statusCode != 200) {
        throw Exception('Server returned ${response.statusCode}');
      }

      final decodedData = json.decode(response.body) as Map<String, dynamic>;
      if (decodedData['success'] != true) {
        throw Exception('API Success is false');
      }

      final List<dynamic> apiResults = decodedData['data'] as List<dynamic>;
      final mergedList = <Map<String, dynamic>>[];

      for (final config in _targetStocks) {
        dynamic apiData;
        for (final item in apiResults) {
          if (item['symbol'] == config['yfSymbol']) {
            apiData = item;
            break;
          }
        }

        if (apiData != null && apiData['error'] == null) {
          mergedList.add({
            ...config,
            'currentPrice': (apiData['currentPrice'] as num).toDouble(),
            'percentChange': (apiData['percentChange'] as num).toDouble(),
            'chartData': (apiData['chartData'] as List<dynamic>)
                .map((e) => (e as num).toDouble())
                .toList(),
          });
        }
      }

      setState(() {
        _marketDataList = mergedList;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _errorMessage =
            '\uC2E4\uC2DC\uAC04 \uB370\uC774\uD130\uB97C \uBD88\uB7EC\uC624\uC9C0 \uBABB\uD588\uC2B5\uB2C8\uB2E4.';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pageBg = isDark ? const Color(0xFF0B1220) : const Color(0xFFF8FAFC);
    final surface = isDark ? const Color(0xFF111827) : Colors.white;
    final border = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor =
        isDark ? Colors.grey.shade300 : Colors.blueGrey.shade600;
    final screenWidth = MediaQuery.of(context).size.width;
    var crossAxisCount = 4;
    if (screenWidth < 1100) crossAxisCount = 3;
    if (screenWidth < 800) crossAxisCount = 2;
    final childAspectRatio =
        screenWidth < 800 ? 1.18 : (screenWidth < 1100 ? 1.28 : 1.42);

    return Scaffold(
      backgroundColor: pageBg,
      drawer: AppDrawer(
        currentSection: DrawerSection.market,
        homeBuilder: (context) => LandingScreen(),
        newsBuilder: (context) => HomeScreen(),
        fearGreedBuilder: (context) => FearGreedPage(),
        marketBuilder: (context) => MarketPage(),
      ),
      appBar: AppBar(
        backgroundColor: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: titleColor),
        shape: Border(bottom: BorderSide(color: border)),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu_rounded, color: titleColor),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(
          '\uC99D\uC2DC \uB3D9\uD5A5',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: titleColor,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: titleColor),
            onPressed: () {
              setState(() => _isLoading = true);
              _fetchRealtimeMarketData();
            },
          ),
          const SizedBox(width: 16),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: isDark ? Colors.blue.shade200 : const Color(0xFF2563EB),
              ),
            )
          : _errorMessage.isNotEmpty
              ? Center(
                  child: Text(
                    _errorMessage,
                    style: TextStyle(
                      color: isDark ? Colors.red.shade200 : Colors.red,
                    ),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\uAE00\uB85C\uBC8C \uC8FC\uC694 \uC9C0\uC218\uC640 \uC885\uBAA9 \uD750\uB984',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: subtitleColor,
                        ),
                      ),
                      const SizedBox(height: 18),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: childAspectRatio,
                        children: _marketDataList.map((data) {
                          return MiniChartCard(
                            symbol: data['symbol'],
                            tvSymbol: data['tvSymbol'],
                            title: data['title'],
                            prefix: data['prefix'],
                            currentPrice: data['currentPrice'],
                            percentChange: data['percentChange'],
                            chartData: data['chartData'],
                            externalUrl: _naverFinanceUrl(
                              data['symbol']?.toString() ?? '',
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
    );
  }
}
