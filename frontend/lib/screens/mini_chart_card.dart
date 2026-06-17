import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'tradingview_detail_page.dart'; // 상세 페이지 import

class MiniChartCard extends StatelessWidget {
  final String symbol;      // 💡 화면에 보여줄 짧은 글자 (예: AAPL, KOSPI)
  final String tvSymbol;    // 💡 트레이딩뷰 전용 정확한 코드 (예: NASDAQ:AAPL, KRX:KOSPI)
  final String title;       // 종목명
  final double currentPrice;
  final double percentChange; 
  final List<double> chartData; 
  final String prefix; 

  const MiniChartCard({
    Key? key,
    required this.symbol,
    required this.tvSymbol, // 추가됨
    required this.title,
    required this.currentPrice,
    required this.percentChange,
    required this.chartData,
    this.prefix = '', 
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isUp = percentChange >= 0;
    final Color chartColor = isUp ? Colors.red[500]! : Colors.blue[600]!;

    final formatter = NumberFormat('#,##0.00', 'en_US');

    return GestureDetector(
      onTap: () {
        // 💡 팝업 띄울 때 복잡한 if문 없이, 바로 tvSymbol을 던져줍니다!
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => TradingViewDetailPage(
              symbol: tvSymbol.trim(), 
              title: title,
            ),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(symbol, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey[500])),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: IgnorePointer(
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(show: false),
                    titlesData: FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: LineTouchData(enabled: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value)).toList(),
                        isCurved: true, color: chartColor, barWidth: 2, isStrokeCapRound: true,
                        dotData: FlDotData(show: false),
                        belowBarData: BarAreaData(show: true, color: chartColor.withOpacity(0.1)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text('$prefix${formatter.format(currentPrice)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.black87)),
            Text('${isUp ? '+' : ''}${percentChange.toStringAsFixed(2)}%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: chartColor)),
          ],
        ),
      ),
    );
  }
}