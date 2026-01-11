import 'dart:typed_data';
import 'dart:ui' as ui;

/// [이미지 최적화]: 메인 스레드 부하를 방지하기 위해 별도 Isolate에서 실행
Future<Uint8List> createCircularMarkerBytes(Uint8List imageBytes) async {
  // 1. 사이즈 80px로 축소 (가이드 반영)
  final ui.Codec codec = await ui.instantiateImageCodec(
    imageBytes,
    targetWidth: 80,
    targetHeight: 80,
  );

  final ui.FrameInfo frame = await codec.getNextFrame();
  final ui.Image image = frame.image;

  final ui.PictureRecorder recorder = ui.PictureRecorder();
  final ui.Canvas canvas = ui.Canvas(recorder);
  final ui.Paint paint = ui.Paint()..isAntiAlias = true;

  const double size = 80.0;
  const double r = size / 2;

  // 2. 원형 드로잉 및 테두리
  canvas.drawCircle(const ui.Offset(r, r), r, paint);
  paint.blendMode = ui.BlendMode.srcIn;
  canvas.drawImage(image, ui.Offset.zero, paint);

  final ui.Image result = await recorder.endRecording().toImage(size.toInt(), size.toInt());
  final ByteData? data = await result.toByteData(format: ui.ImageByteFormat.png);

  // 3. 사용 끝난 Native 리소스 즉시 파괴 (JNI 에러 방지 핵심)
  image.dispose();
  result.dispose();

  return data!.buffer.asUint8List();
}