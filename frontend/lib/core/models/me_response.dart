class MeResponse {
  final String userId;
  final String firebaseUid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  MeResponse({
    required this.userId,
    required this.firebaseUid,
    this.email,
    this.displayName,
    this.photoUrl,
  });

  factory MeResponse.fromJson(Map<String, dynamic> j) {
    return MeResponse(
      userId: j['userId'] as String,
      firebaseUid: j['firebaseUid'] as String,
      email: j['email'] as String?,
      displayName: j['displayName'] as String?,
      photoUrl: j['photoUrl'] as String?,
    );
  }
}
