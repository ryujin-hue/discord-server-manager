/// The lifecycle of a queued file.
enum QueueState {
  pending,
  uploading,
  paused,
  completed,
  failed,
  cancelled,
  interrupted,
  sourceMissing;

  String get code => switch (this) {
    QueueState.pending => 'pending',
    QueueState.uploading => 'uploading',
    QueueState.paused => 'paused',
    QueueState.completed => 'completed',
    QueueState.failed => 'failed',
    QueueState.cancelled => 'cancelled',
    QueueState.interrupted => 'interrupted',
    QueueState.sourceMissing => 'source_missing',
  };

  static QueueState fromCode(String code) {
    for (final state in QueueState.values) {
      if (state.code == code) {
        return state;
      }
    }
    return QueueState.pending;
  }

  /// A state the queue never leaves.
  bool get isFinal =>
      this == QueueState.completed ||
      this == QueueState.failed ||
      this == QueueState.cancelled;
}

/// The transitions the queue allows. Any other change is rejected so the
/// interface can never show an impossible state.
const Map<QueueState, Set<QueueState>> allowedTransitions =
    <QueueState, Set<QueueState>>{
      QueueState.pending: <QueueState>{
        QueueState.uploading,
        QueueState.paused,
        QueueState.cancelled,
        QueueState.sourceMissing,
      },
      QueueState.uploading: <QueueState>{
        QueueState.completed,
        QueueState.failed,
        QueueState.paused,
        QueueState.cancelled,
        QueueState.interrupted,
      },
      QueueState.paused: <QueueState>{
        QueueState.pending,
        QueueState.uploading,
        QueueState.cancelled,
        QueueState.interrupted,
        QueueState.sourceMissing,
      },
      QueueState.completed: <QueueState>{},
      QueueState.failed: <QueueState>{QueueState.pending, QueueState.cancelled},
      QueueState.cancelled: <QueueState>{QueueState.pending},
      QueueState.interrupted: <QueueState>{
        QueueState.pending,
        QueueState.cancelled,
      },
      QueueState.sourceMissing: <QueueState>{
        QueueState.pending,
        QueueState.cancelled,
      },
    };

bool canTransition(QueueState from, QueueState to) =>
    allowedTransitions[from]?.contains(to) ?? false;
