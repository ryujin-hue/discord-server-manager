import 'queue_state.dart';

/// One file in the upload queue.
class QueueItem {
  const QueueItem({
    required this.id,
    required this.destinationId,
    required this.destinationName,
    required this.sourcePath,
    required this.fileName,
    required this.sizeBytes,
    required this.kind,
    required this.state,
    required this.progress,
    required this.createdAt,
    this.mimeType,
    this.startedAt,
    this.finishedAt,
    this.errorCode,
    this.errorMessage,
    this.position = 0,
  });

  final int id;
  final String destinationId;
  final String destinationName;
  final String sourcePath;
  final String fileName;
  final int sizeBytes;
  final String kind;
  final QueueState state;
  final double progress;
  final DateTime createdAt;
  final String? mimeType;
  final DateTime? startedAt;
  final DateTime? finishedAt;
  final String? errorCode;
  final String? errorMessage;
  final int position;

  bool get isFinal => state.isFinal;

  QueueItem copyWith({
    QueueState? state,
    double? progress,
    DateTime? startedAt,
    DateTime? finishedAt,
    String? errorCode,
    String? errorMessage,
    int? position,
  }) {
    return QueueItem(
      id: id,
      destinationId: destinationId,
      destinationName: destinationName,
      sourcePath: sourcePath,
      fileName: fileName,
      sizeBytes: sizeBytes,
      kind: kind,
      mimeType: mimeType,
      createdAt: createdAt,
      state: state ?? this.state,
      progress: progress ?? this.progress,
      startedAt: startedAt ?? this.startedAt,
      finishedAt: finishedAt ?? this.finishedAt,
      errorCode: errorCode ?? this.errorCode,
      errorMessage: errorMessage ?? this.errorMessage,
      position: position ?? this.position,
    );
  }
}
