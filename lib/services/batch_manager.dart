import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class BatchManager {
  final FirebaseFirestore _firestore;
  late WriteBatch _currentBatch;
  int _operationCount = 0;
  final int _maxBatchSize;
  final bool _verbose;
  final Logger _logger = Logger();

  int _totalOperations = 0;
  int _totalCommits = 0;
  final Stopwatch _batchStopwatch = Stopwatch()..start();

  BatchManager(this._firestore, {int maxBatchSize = 450, bool verbose = false})
    : _maxBatchSize = maxBatchSize,
      _verbose = verbose {
    _currentBatch = _firestore.batch();
  }

  int get operationCount => _operationCount;

  int get totalOperations => _totalOperations;

  int get totalCommits => _totalCommits;

  Future<void> set(DocumentReference docRef, Map<String, dynamic> data) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data);
    _operationCount++;
    _totalOperations++;
    if (_verbose) {
      _logger.d('Set operation added for ${docRef.path}');
    }
  }

  Future<void> setWithOptions(
    DocumentReference docRef,
    Map<String, dynamic> data,
    SetOptions options,
  ) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data, options);
    _operationCount++;
    _totalOperations++;
    if (_verbose) {
      _logger.d('Set operation with options added for ${docRef.path}');
    }
  }

  Future<void> update(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    await _checkBatchSize();
    _currentBatch.update(docRef, data);
    _operationCount++;
    _totalOperations++;
    if (_verbose) {
      _logger.d('Update operation added for ${docRef.path}');
    }
  }

  Future<void> delete(DocumentReference docRef) async {
    await _checkBatchSize();
    _currentBatch.delete(docRef);
    _operationCount++;
    _totalOperations++;
    if (_verbose) {
      _logger.d('Delete operation added for ${docRef.path}');
    }
  }

  Future<void> _checkBatchSize() async {
    if (_operationCount >= _maxBatchSize) {
      await commitBatch();
    }
  }

  Future<void> commitBatch() async {
    if (_operationCount > 0) {
      if (_verbose) {
        _logger.i('Committing batch with $_operationCount operations');
      }

      final stopwatch = Stopwatch()..start();
      await _currentBatch.commit();
      final elapsed = stopwatch.elapsedMilliseconds;

      _totalCommits++;
      if (_verbose) {
        _logger.i('Batch committed in ${elapsed}ms');
      }

      _currentBatch = _firestore.batch();
      _operationCount = 0;
    }
  }

  Future<void> commit() async {
    await commitBatch();
    final totalTime = _batchStopwatch.elapsedMilliseconds;

    if (_verbose) {
      _logger.i('''
BatchManager stats:
- Total operations: $_totalOperations
- Total commits: $_totalCommits
- Total time: ${totalTime}ms
- Avg operations per second: ${(_totalOperations * 1000 / totalTime).toStringAsFixed(1)}
''');
    }
  }
}
