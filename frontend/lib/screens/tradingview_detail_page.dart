import 'package:flutter/material.dart';
import 'tradingview_chart.dart';

class TradingViewDetailPage extends StatelessWidget {
  final String symbol;
  final String title;

  const TradingViewDetailPage({
    Key? key,
    required this.symbol,
    required this.title,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    print('TradingViewDetailPage 생성: $symbol ($title)');
    
    final screenHeight = MediaQuery.of(context).size.height;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: Text(
          '$title 차트',
          style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            height: screenHeight * 0.7, // 화면 높이의 70%로 제한
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.withOpacity(0.2)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: TradingViewChart(
              key: ValueKey(symbol),
              symbol: symbol,
            ), 
          ),
        ),
      ),
    );
  }
}