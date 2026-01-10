import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import '../models/walk.dart';

class WalkDetailScreen extends StatelessWidget {
  final Walk walk;
  const WalkDetailScreen({super.key, required this.walk});

  @override
  Widget build(BuildContext context) {
    // JSON 경로 데이터를 LatLng 리스트로 변환
    List<LatLng> routePoints = [];
    if (walk.route != null && walk.route!.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(walk.route!);
        routePoints = decoded.map((p) => LatLng(p['lat'], p['lng'])).toList();
      } catch (e) {
        debugPrint("경로 파싱 에러: $e");
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('산책 상세 기록')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // [기능]: 30초마다 수집된 이동 경로 지도 표시
            SizedBox(
              height: 300,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: routePoints.isNotEmpty ? routePoints.first : const LatLng(37.56, 126.97),
                  zoom: 15,
                ),
                polylines: {
                  Polyline(
                    polylineId: const PolylineId('route'),
                    points: routePoints,
                    color: Colors.blue,
                    width: 5,
                  )
                },
              ),
            ),
            // [기능]: 업로드된 사진 표시
            if (walk.imageUrl != null && walk.imageUrl!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(walk.imageUrl!, fit: BoxFit.cover),
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _buildRow('📏 산책 거리', '${walk.distance?.toStringAsFixed(2)} km'),
                  _buildRow('⏱️ 산책 시간', '${((walk.duration ?? 0) ~/ 60)}분 ${((walk.duration ?? 0) % 60)}초'),
                  _buildRow('🕒 시작 시간', DateFormat('HH:mm:ss').format(walk.startTime)),
                  _buildRow('🏁 종료 시간', walk.endTime != null ? DateFormat('HH:mm:ss').format(walk.endTime!) : '-'),
                  _buildRow('😊 산책 기분', walk.mood ?? '😊'),
                  const Divider(height: 40),
                  const Align(alignment: Alignment.centerLeft, child: Text('📝 산책 메모', style: TextStyle(fontWeight: FontWeight.bold))),
                  const SizedBox(height: 10),
                  Align(alignment: Alignment.centerLeft, child: Text(walk.notes ?? '기록된 메모가 없습니다.')),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String l, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l), Text(v, style: const TextStyle(fontWeight: FontWeight.bold))]),
  );
}