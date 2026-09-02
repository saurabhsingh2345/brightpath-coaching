import 'package:flutter/foundation.dart';
import '../core/api_exception.dart';

/// Minimal async wrapper: one place that owns loading / data / error, so every
/// screen renders the same three states without repeating the plumbing.
class AsyncController<T> extends ChangeNotifier {
  AsyncController(this._loader);

  Future<T> Function() _loader;

  T? _data;
  ApiException? _error;
  bool _loading = false;
  bool _disposed = false;

  T? get data => _data;
  ApiException? get error => _error;
  bool get isLoading => _loading;
  bool get hasData => _data != null;
  bool get isFirstLoad => _loading && _data == null;

  void setLoader(Future<T> Function() loader) => _loader = loader;

  Future<void> load({bool silent = false}) async {
    if (_disposed) return;
    if (!silent) {
      _loading = true;
      _error = null;
      notifyListeners();
    }
    try {
      final result = await _loader();
      if (_disposed) return;
      _data = result;
      _error = null;
    } on ApiException catch (e) {
      if (_disposed) return;
      _error = e;
      if (!silent) _data = null;
    } catch (e) {
      if (_disposed) return;
      _error = ApiException('Unexpected error: $e');
      if (!silent) _data = null;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<void> refresh() => load(silent: true);

  void setData(T value) {
    _data = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
