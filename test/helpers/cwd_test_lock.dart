import 'dart:io';

final class CwdTestLock {
  CwdTestLock._(this._raf);

  final RandomAccessFile _raf;

  static Future<CwdTestLock> acquire() async {
    final file = File(
      '${Directory.systemTemp.path}/refractor_cwd_test.lock',
    );
    final raf = await file.open(mode: FileMode.write);
    await raf.lock(FileLock.blockingExclusive);
    return CwdTestLock._(raf);
  }

  Future<void> release() async {
    await _raf.unlock();
    await _raf.close();
  }
}
