import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TradingViewChart extends StatefulWidget {
  final String symbol;
  final String interval;
  final String range;

  const TradingViewChart({
    super.key,
    required this.symbol,
    this.interval = '1d',
    this.range = '6mo',
  });

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
  void didUpdateWidget(covariant TradingViewChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.symbol != widget.symbol ||
        oldWidget.interval != widget.interval ||
        oldWidget.range != widget.range) {
      _initController();
    }
  }

  void _initController() {
    final htmlString = '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <script src="https://unpkg.com/lightweight-charts@4.1.3/dist/lightweight-charts.standalone.production.js"></script>
        <style>
          :root {
            color-scheme: light;
          }

          body {
            margin: 0;
            padding: 12px;
            background: #ffffff;
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            color: #0f172a;
          }

          #header {
            display: flex;
            flex-direction: column;
            gap: 4px;
            padding: 2px 2px 10px;
          }

          #title {
            font-size: 15px;
            font-weight: 700;
            color: #0f172a;
          }

          #meta {
            font-size: 12px;
            color: #64748b;
          }

          #chartWrap {
            position: relative;
          }

          #chart {
            width: 100%;
            height: calc(100vh - 76px);
            min-height: 340px;
          }

          #tooltip {
            position: absolute;
            top: 12px;
            left: 12px;
            z-index: 10;
            display: none;
            min-width: 150px;
            padding: 10px 12px;
            border-radius: 12px;
            background: rgba(15, 23, 42, 0.92);
            color: #ffffff;
            pointer-events: none;
            box-shadow: 0 10px 30px rgba(15, 23, 42, 0.18);
            font-size: 12px;
            line-height: 1.45;
          }

          #tooltip .time {
            font-size: 12px;
            font-weight: 700;
            margin-bottom: 4px;
          }

          #tooltip .price {
            color: #dbeafe;
          }
        </style>
      </head>
      <body>
        <div id="header">
          <div id="title">${widget.symbol}</div>
          <div id="meta">Last updated: loading</div>
        </div>

        <div id="chartWrap">
          <div id="tooltip"></div>
          <div id="chart"></div>
        </div>

        <script>
          const chartEl = document.getElementById('chart');
          const tooltip = document.getElementById('tooltip');
          const tvSymbol = '${widget.symbol}';
          const interval = '${widget.interval}';
          const range = '${widget.range}';
          const isIntraday = interval.endsWith('m') || interval.endsWith('h');

          const chart = LightweightCharts.createChart(chartEl, {
            layout: {
              background: { color: '#ffffff' },
              textColor: '#334155',
            },
            grid: {
              vertLines: { color: '#eef2f7' },
              horzLines: { color: '#eef2f7' },
            },
            rightPriceScale: {
              borderColor: '#e2e8f0',
            },
            timeScale: {
              timeVisible: true,
              secondsVisible: false,
              borderColor: '#e2e8f0',
            },
            localization: {
              timeFormatter: (time) => formatChartTime(time, isIntraday),
            },
            width: chartEl.clientWidth,
            height: chartEl.clientHeight,
          });

          const candlestickSeries = chart.addCandlestickSeries({
            upColor: '#ef4444',
            downColor: '#3b82f6',
            borderVisible: false,
            wickUpColor: '#ef4444',
            wickDownColor: '#3b82f6',
          });

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

          const yahooSymbol = symbolMap[tvSymbol] || tvSymbol.split(':').pop() || tvSymbol;

          function pad(value) {
            return String(value).padStart(2, '0');
          }

          function formatChartTime(time, intraday) {
            let date = null;

            if (typeof time === 'number') {
              date = new Date(time * 1000);
            } else if (typeof time === 'string') {
              date = new Date(time);
            } else if (time && typeof time === 'object') {
              const year = time.year || 1970;
              const month = time.month || 1;
              const day = time.day || 1;
              const hour = time.hour || 0;
              const minute = time.minute || 0;
              date = new Date(Date.UTC(year, month - 1, day, hour, minute));
            }

            if (!date || Number.isNaN(date.getTime())) {
              return '';
            }

            const parts = new Intl.DateTimeFormat('ko-KR', {
              timeZone: 'Asia/Seoul',
              year: '2-digit',
              month: '2-digit',
              day: '2-digit',
              hour: intraday ? '2-digit' : undefined,
              minute: intraday ? '2-digit' : undefined,
              hour12: false,
            }).formatToParts(date);

            const map = {};
            for (const part of parts) {
              if (part.type !== 'literal') {
                map[part.type] = part.value;
              }
            }

            const yy = map.year || String(date.getFullYear()).slice(-2);
            const mm = map.month || pad(date.getMonth() + 1);
            const dd = map.day || pad(date.getDate());

            if (!intraday) {
              return yy + '/' + mm + '/' + dd;
            }

            const hh = map.hour || pad(date.getHours());
            const mi = map.minute || pad(date.getMinutes());
            return yy + '/' + mm + '/' + dd + ' ' + hh + ':' + mi;
          }

          function formatRefreshTime(iso) {
            if (!iso) return 'loading';
            const date = new Date(iso);
            if (Number.isNaN(date.getTime())) return 'loading';

            const parts = new Intl.DateTimeFormat('ko-KR', {
              timeZone: 'Asia/Seoul',
              year: '2-digit',
              month: '2-digit',
              day: '2-digit',
              hour: '2-digit',
              minute: '2-digit',
              hour12: false,
            }).formatToParts(date);

            const map = {};
            for (const part of parts) {
              if (part.type !== 'literal') {
                map[part.type] = part.value;
              }
            }

            return (map.year || '') + '/' + (map.month || '') + '/' + (map.day || '') + ' ' + (map.hour || '') + ':' + (map.minute || '');
          }

          function hideTooltip() {
            tooltip.style.display = 'none';
          }

          fetch('https://news-summarizer.bum2432.workers.dev/api/chart-data?symbol=' + encodeURIComponent(yahooSymbol) + '&interval=' + encodeURIComponent(interval) + '&range=' + encodeURIComponent(range))
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

              document.getElementById('meta').textContent =
                'Last updated: ' + formatRefreshTime(result.fetchedAt);

              chart.subscribeCrosshairMove(param => {
                if (!param || !param.time || !param.point) {
                  hideTooltip();
                  return;
                }

                const data = param.seriesData.get(candlestickSeries);
                if (!data) {
                  hideTooltip();
                  return;
                }

                const formattedTime = formatChartTime(param.time, isIntraday);
                if (!formattedTime) {
                  hideTooltip();
                  return;
                }

                const change = data.open ? ((data.close - data.open) / data.open) * 100 : 0;
                const direction = change >= 0 ? '+' : '';

                tooltip.style.display = 'block';
                tooltip.style.left = Math.min(param.point.x + 12, chartEl.clientWidth - 180) + 'px';
                tooltip.style.top = Math.max(12, param.point.y - 72) + 'px';
                tooltip.innerHTML =
                  '<div class="time">' + formattedTime + '</div>' +
                  '<div>O ' + Number(data.open).toFixed(2) + '</div>' +
                  '<div>H ' + Number(data.high).toFixed(2) + '</div>' +
                  '<div>L ' + Number(data.low).toFixed(2) + '</div>' +
                  '<div class="price">C ' + Number(data.close).toFixed(2) + ' (' + direction + change.toFixed(2) + '%)</div>';
              });
            })
            .catch(() => {
              document.getElementById('meta').textContent = 'Last updated: unavailable';
            });

          window.addEventListener('resize', () => {
            chart.resize(chartEl.clientWidth, chartEl.clientHeight);
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
