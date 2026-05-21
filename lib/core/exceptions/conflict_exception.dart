class ConflictException implements Exception {
  ConflictException({required this.remoteState});

  final Map<String, dynamic> remoteState;

  @override
  String toString() =>
      'ConflictException: Remote state differs from base version.';
}
