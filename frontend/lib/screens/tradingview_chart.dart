import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:webview_flutter/webview_flutter.dart';

class TradingViewChart extends StatefulWidget {
  final String symbol; 

  const TradingViewChart({Key? key, required this.symbol}) : super(key: key);

  @override
  State<TradingViewChart> createState() => _TradingViewChartState();
}

class _TradingViewChartState extends State<TradingViewChart> {
  WebViewController? _controller;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 심볼이 변경되면 컨트롤러를 다시 생성
    if (oldWidget.symbol != widget.symbol) {
      print('심볼 변경: ${oldWidget.symbol} -> ${widget.symbol}');
      _initController();
    }
  }

  void _initController() {
    print('Lightweight Chart 초기화: ${widget.symbol}');
    
    final String htmlString = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://unpkg.com/lightweight-charts@4.1.3/dist/lightweight-charts.standalone.production.js"></script>
        <style>
          body { margin: 0; padding: 10px; background: white; font-family: -apple-system, BlinkMacSystemFont, sans-serif; }
          #chart { width: 100%; height: calc(100vh - 60px); }
          #info { padding: 10px; font-size: 14px; color: #333; }
        </style>
      </head>
      <body>
        <div id="info">
          <strong>${widget.symbol}</strong> - 데이터 로딩 중...
        </div>
        <div id="chart"></div>
        
        <script>
          const chart = LightweightCharts.createChart(document.getElementById('chart'), {
            layout: {
              background: { color: '#ffffff' },
              textColor: '#333',
            },
            grid: {
              vertLines: { color: '#f0f0f0' },
              horzLines: { color: '#f0f0f0' },
            },
            timeScale: {
              timeVisible: true,
              secondsVisible: false,
            },
            width: document.getElementById('chart').clientWidth,
            height: document.getElementById('chart').clientHeight,
          });

          // v4 API: addCandlestickSeries 사용
          const candlestickSeries = chart.addCandlestickSeries({
            upColor: '#ef5350',
            downColor: '#26a69a',
            borderVisible: false,
            wickUpColor: '#ef5350',
            wickDownColor: '#26a69a',
          });

          // TradingView 심볼에서 Yahoo Finance 심볼로 변환
          const symbolMap = {
            'KRX:KOSPI': '^KS11',
            'KRX:KOSDAQ': '^KQ11',
            'TVC:DJI': '^DJI',
            'NASDAQ:IXIC': '^IXIC',
            'SP:SPX': '^GSPC',
            'FX_IDC:USDKRW': 'KRW=X',
            'KRX:005930': '005930.KS',
            'KRX:000660': '000660.KS',
            'NASDAQ:AAPL': 'AAPL',
            'NASDAQ:NVDA': 'NVDA'
          };
          
          const tvSymbol = '${widget.symbol}';
          const yahooSymbol = symbolMap[tvSymbol] || tvSymbol.split(':').pop() || tvSymbol;
          
          console.log('Loading chart:', tvSymbol, '→ Yahoo:', yahooSymbol);
          
          // Cloudflare Worker를 통해 데이터 가져오기 (CORS 우회)
          fetch('https://news-summarizer.bum2432.workers.dev/api/chart-data?symbol=' + encodeURIComponent(yahooSymbol))
            .then(response => {
              if (!response.ok) throw new Error('Network error');
              return response.json();
            })
            .then(result => {
              if (!result.success || !result.data || result.data.length === 0) {
                throw new Error('No data available');
              }
              
              const candleData = result.data;
              candlestickSeries.setData(candleData);
              chart.timeScale().fitContent();
              
              const lastCandle = candleData[candleData.length - 1];
              const prevCandle = candleData[candleData.length - 2];
              const lastPrice = lastCandle.close.toFixed(2);
              const change = prevCandle ? ((lastCandle.close - prevCandle.close) / prevCandle.close * 100).toFixed(2) : 0;
              
              document.getElementById('info').innerHTML = 
                '<strong>${widget.symbol}</strong> - 현재가: ' + lastPrice + ' (' + (change >= 0 ? '+' : '') + change + '%)';
            })
            .catch(err => {
              console.error('데이터 로딩 실패:', err);
              document.getElementById('info').innerHTML = 
                '<strong>${widget.symbol}</strong> - 데이터를 불러올 수 없습니다. (' + err.message + ')';
            });
            
          // 창 크기 변경 시 차트 리사이즈
          window.addEventListener('resize', () => {
            chart.resize(document.getElementById('chart').clientWidth, document.getElementById('chart').clientHeight);
          });
        </script>
      </body>
      </html>
    ''';

    _controller = WebViewController();
    
    if (!kIsWeb) {
      _controller!.setJavaScriptMode(JavaScriptMode.unrestricted);
      _controller!.setBackgroundColor(Colors.white);
      _controller!.clearCache();
    }
    
    _controller!.loadHtmlString(htmlString);
    
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) {
      return const Center(child: CircularProgressIndicator());
    }
    return WebViewWidget(controller: _controller!);
  }
}