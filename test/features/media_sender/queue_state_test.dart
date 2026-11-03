import 'package:discord_server_manager/features/media_sender/domain/queue_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('queue state machine', () {
    test('a pending item may start, pause or be cancelled', () {
      expect(canTransition(QueueState.pending, QueueState.uploading), isTrue);
      expect(canTransition(QueueState.pending, QueueState.paused), isTrue);
      expect(canTransition(QueueState.pending, QueueState.cancelled), isTrue);
      expect(canTransition(QueueState.pending, QueueState.completed), isFalse);
    });

    test('an uploading item may finish, fail, pause or be interrupted', () {
      expect(canTransition(QueueState.uploading, QueueState.completed), isTrue);
      expect(canTransition(QueueState.uploading, QueueState.failed), isTrue);
      expect(canTransition(QueueState.uploading, QueueState.paused), isTrue);
      expect(
        canTransition(QueueState.uploading, QueueState.interrupted),
        isTrue,
      );
      expect(canTransition(QueueState.uploading, QueueState.pending), isFalse);
    });

    test('a completed item is final', () {
      expect(QueueState.completed.isFinal, isTrue);
      expect(canTransition(QueueState.completed, QueueState.pending), isFalse);
      expect(
        canTransition(QueueState.completed, QueueState.uploading),
        isFalse,
      );
    });

    test('a failed item may be retried', () {
      expect(canTransition(QueueState.failed, QueueState.pending), isTrue);
      expect(canTransition(QueueState.failed, QueueState.uploading), isFalse);
    });

    test('a cancelled item may be retried', () {
      expect(canTransition(QueueState.cancelled, QueueState.pending), isTrue);
    });

    test('an interrupted item may be retried', () {
      expect(canTransition(QueueState.interrupted, QueueState.pending), isTrue);
      expect(
        canTransition(QueueState.interrupted, QueueState.completed),
        isFalse,
      );
    });

    test('a missing source may only be cancelled or picked again', () {
      expect(
        canTransition(QueueState.sourceMissing, QueueState.pending),
        isTrue,
      );
      expect(
        canTransition(QueueState.sourceMissing, QueueState.uploading),
        isFalse,
      );
      expect(
        canTransition(QueueState.sourceMissing, QueueState.cancelled),
        isTrue,
      );
    });

    test('the code of a state round trips', () {
      for (final state in QueueState.values) {
        expect(QueueState.fromCode(state.code), state);
      }
      expect(QueueState.fromCode('source_missing'), QueueState.sourceMissing);
      expect(QueueState.fromCode('unknown-value'), QueueState.pending);
    });
  });
}
