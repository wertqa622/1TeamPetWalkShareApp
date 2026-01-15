/// Firestore 문서 ID에 사용할 수 없는 문자를 제거/치환하는 유틸리티 클래스
class NicknameNormalizer {
  /// Firestore 문서 ID에 사용할 수 없는 문자를 언더스코어로 치환
  /// 
  /// Firestore 문서 ID는 다음 문자를 사용할 수 없음: /, ?, #, [, ], *
  /// 
  /// [nickname] 정규화할 닉네임
  /// 
  /// Returns 정규화된 닉네임
  static String normalize(String nickname) {
    return nickname
        .replaceAll('/', '_')
        .replaceAll('?', '_')
        .replaceAll('#', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('*', '_')
        .trim();
  }
}
