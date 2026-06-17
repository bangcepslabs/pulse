import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:syncfusion_flutter_gauges/gauges.dart';

class FearGreedPage extends StatefulWidget {
  const FearGreedPage({Key? key}) : super(key: key);

  @override
  State<FearGreedPage> createState() => _FearGreedPageState();
}

class _FearGreedPageState extends State<FearGreedPage> {
  double _score = 0;
  String _status = "Loading...";
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFearGreedIndex();
  }

  Future<void> _fetchFearGreedIndex() async {
    try {      
      final url = Uri.parse('https://news-summarizer.bum2432.workers.dev/api/fear-and-greed');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _score = (data['score'] as num).toDouble();
            _status = _translateRating(data['rating']);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        _status = "데이터 오류";
        _isLoading = false;
      });
    }
  }

  // 💡 CNN의 영문 등급을 한국어로 번역하는 도우미 함수
  String _translateRating(String rating) {
    switch (rating.toLowerCase()) {
      case 'extreme fear':
        return '극단적 공포';
      case 'fear':
        return '공포';
      case 'neutral':
        return '중립';
      case 'greed':
        return '탐욕';
      case 'extreme greed':
        return '극단적 탐욕';
      default:
        return '알 수 없음';
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final gaugeSize = isMobile ? screenWidth * 0.85 : 400.0;
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('시장 심리', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.black))
          : SingleChildScrollView(
              padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: isMobile ? 20 : 40),
                  Text(
                    '공포 & 탐욕 지수',
                    style: TextStyle(fontSize: isMobile ? 20 : 24, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '현재 시장의 투자 심리를 확인하세요.',
                    style: TextStyle(fontSize: isMobile ? 13 : 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: isMobile ? 24 : 40),
                  
                  // ✨ 아름다운 게이지 차트 위젯
                  Center(
                    child: Container(
                      width: gaugeSize,
                      height: gaugeSize * 0.75, // 너비의 75% 높이
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(16),
                      child: SfRadialGauge(
                        axes: <RadialAxis>[
                          RadialAxis(
                            minimum: 0,
                            maximum: 100,
                            ranges: <GaugeRange>[
                              GaugeRange(startValue: 0, endValue: 25, color: Colors.red[600], label: '극단적 공포'),
                              GaugeRange(startValue: 25, endValue: 45, color: Colors.orange[400], label: '공포'),
                              GaugeRange(startValue: 45, endValue: 55, color: Colors.yellow[600], label: '중립'),
                              GaugeRange(startValue: 55, endValue: 75, color: Colors.lightGreen[400], label: '탐욕'),
                              GaugeRange(startValue: 75, endValue: 100, color: Colors.green[600], label: '극단적 탐욕'),
                            ],
                            pointers: <GaugePointer>[
                              NeedlePointer(
                                value: _score,
                                enableAnimation: true,
                                animationDuration: 1500,
                                needleColor: Colors.black87,
                                knobStyle: const KnobStyle(color: Colors.black),
                              )
                            ],
                            annotations: <GaugeAnnotation>[
                              GaugeAnnotation(
                                widget: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _score.toInt().toString(),
                                      style: TextStyle(fontSize: isMobile ? 36 : 48, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      _status,
                                      style: TextStyle(fontSize: isMobile ? 14 : 18, color: Colors.grey[700], fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                                angle: 90,
                                positionFactor: 0.8,
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}