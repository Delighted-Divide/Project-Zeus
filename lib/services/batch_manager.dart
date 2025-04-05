import 'package:cloud_firestore/cloud_firestore.dart';

/// A class to manage Firestore batch operations safely with automatic commits when approaching limits
class BatchManager {
  final FirebaseFirestore _firestore;
  WriteBatch _currentBatch;
  int _operationCount = 0;
  final int _maxBatchSize;
  final bool _verbose;

  // Performance metrics
  int _totalOperations = 0;
  int _totalCommits = 0;
  Stopwatch _batchStopwatch = Stopwatch()..start();

  // Constructor initializes a new batch
  BatchManager(this._firestore, {int maxBatchSize = 450, bool verbose = false})
    : _maxBatchSize = maxBatchSize,
      _verbose = verbose,
      _currentBatch = _firestore.batch();

  // Get the current operation count
  int get operationCount => _operationCount;
  int get totalOperations => _totalOperations;
  int get totalCommits => _totalCommits;

  // Set document data
  Future<void> set(DocumentReference docRef, Map<String, dynamic> data) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data);
    _operationCount++;
    _totalOperations++;
  }

  // Set document data with options
  Future<void> setWithOptions(
    DocumentReference docRef,
    Map<String, dynamic> data,
    SetOptions options,
  ) async {
    await _checkBatchSize();
    _currentBatch.set(docRef, data, options);
    _operationCount++;
    _totalOperations++;
  }

  // Update document data
  Future<void> update(
    DocumentReference docRef,
    Map<String, dynamic> data,
  ) async {
    await _checkBatchSize();
    _currentBatch.update(docRef, data);
    _operationCount++;
    _totalOperations++;
  }

  // Delete document
  Future<void> delete(DocumentReference docRef) async {
    await _checkBatchSize();
    _currentBatch.delete(docRef);
    _operationCount++;
    _totalOperations++;
  }

  // Check if batch needs to be committed and create a new one if needed
  Future<void> _checkBatchSize() async {
    if (_operationCount >= _maxBatchSize) {
      await commitBatch();
    }
  }

  // Commit the current batch and create a new one
  Future<void> commitBatch() async {
    if (_operationCount > 0) {
      if (_verbose) {
        print('Committing batch with $_operationCount operations');
      }

      final stopwatch = Stopwatch()..start();
      await _currentBatch.commit();
      final elapsed = stopwatch.elapsedMilliseconds;

      _totalCommits++;
      if (_verbose) {
        print('Batch committed in ${elapsed}ms');
      }

      _currentBatch = _firestore.batch();
      _operationCount = 0;
    }
  }

  // Final commit at the end of operations
  Future<void> commit() async {
    await commitBatch();
    final totalTime = _batchStopwatch.elapsedMilliseconds;

    if (_verbose) {
      print('BatchManager stats:');
      print('- Total operations: $_totalOperations');
      print('- Total commits: $_totalCommits');
      print('- Total time: ${totalTime}ms');
      print(
        '- Avg operations per second: ${(_totalOperations * 1000 / totalTime).toStringAsFixed(1)}',
      );
    }
  }
}
