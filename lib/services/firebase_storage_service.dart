import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class FirebaseStorageService {
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  // 반려동물 이미지 업로드
  static Future<String> uploadPetImage({
    required String userId,
    required String petId,
    required XFile imageFile,
  }) async {
    try {
      // 저장 경로: pets/{userId}/{petId}/profile.jpg
      final String fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'pets/$userId/$petId/$fileName';

      print('이미지 업로드 시작: $path');
      print('사용자 ID: $userId');
      
      // 파일 참조 생성
      final Reference ref = _storage.ref().child(path);

      // 파일 존재 확인 및 크기 확인
      final File file = File(imageFile.path);
      if (!await file.exists()) {
        throw Exception('이미지 파일이 존재하지 않습니다: ${imageFile.path}');
      }
      
      final fileSize = await file.length();
      print('파일 크기: ${(fileSize / 1024 / 1024).toStringAsFixed(2)} MB');
      
      if (fileSize > 10 * 1024 * 1024) { // 10MB 초과 시 경고
        print('경고: 파일 크기가 10MB를 초과합니다. 업로드가 느릴 수 있습니다.');
      }

      // 파일 업로드
      final UploadTask uploadTask = ref.putFile(
        file,
        SettableMetadata(
          contentType: 'image/jpeg',
          cacheControl: 'max-age=3600',
        ),
      );

      // 업로드 진행 상황 모니터링
      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        final progress = snapshot.bytesTransferred / snapshot.totalBytes;
        print('업로드 진행률: ${(progress * 100).toStringAsFixed(2)}%');
      });

      // 업로드 완료 대기 및 다운로드 URL 가져오기 (타임아웃: 60초로 증가)
      print('업로드 대기 중...');
      final TaskSnapshot snapshot = await uploadTask.timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          print('업로드 타임아웃 발생');
          uploadTask.cancel();
          throw Exception('이미지 업로드 타임아웃: 60초 내에 완료되지 않았습니다. 네트워크 연결을 확인해주세요.');
        },
      );
      
      print('업로드 완료, 다운로드 URL 가져오는 중...');
      final String downloadUrl = await snapshot.ref.getDownloadURL().timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          print('다운로드 URL 가져오기 타임아웃');
          throw Exception('다운로드 URL 가져오기 타임아웃');
        },
      );

      print('이미지 업로드 성공: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('이미지 업로드 에러 상세: $e');
      if (e.toString().contains('permission') || e.toString().contains('unauthorized')) {
        throw Exception('이미지 업로드 권한이 없습니다. Firebase Storage 보안 규칙을 확인해주세요.');
      } else if (e.toString().contains('network') || e.toString().contains('timeout')) {
        throw Exception('네트워크 연결 문제로 이미지 업로드에 실패했습니다. 인터넷 연결을 확인해주세요.');
      } else {
        throw Exception('이미지 업로드 실패: $e');
      }
    }
  }

  // 반려동물 이미지 삭제
  static Future<void> deletePetImage(String imageUrl) async {
    try {
      // URL에서 파일 경로 추출
      final Reference ref = _storage.refFromURL(imageUrl);
      await ref.delete();
    } catch (e) {
      // 이미지가 없거나 삭제 실패해도 계속 진행
      print('이미지 삭제 실패 (무시됨): $e');
    }
  }

  // 이미지 URL 유효성 검사
  static bool isValidImageUrl(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.startsWith('http://') || url.startsWith('https://');
  }
}

