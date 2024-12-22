// efficient list that can remove the first element without reallocating
import 'dart:typed_data';

class BufferedFixedLengthList {
  final Float64List _list;
  int _start = 0;
  int _end = 0;

  BufferedFixedLengthList(int length) : _list = Float64List(length * 2);

  factory BufferedFixedLengthList.filled(int length, double value) {
    final list = BufferedFixedLengthList(length);
    for (int i = 0; i < length; i++) {
      list.add(value);
    }
    return list;
  }

  void add(double v) {
    _list[_end] = v;
    _end++;
    if (_end == _list.length) {
      _moveData();
    }
  }

  void removeFirst() {
    _start++;
  }

  void _moveData() {
    final len = length;
    for (int i = 0; i < len; i++) {
      _list[i] = _list[i + _start];
    }
    _start = 0;
    _end = len;
  }

  int get length => _end - _start;
  bool get isEmpty => _start == _end;
  double get first => _list[_start];
  double get last => _list[_end - 1];
  double operator [](int index) => _list[index + _start];

  double minimum() {
    int m = _start;
    for (int i = _start; i < _end; i++) {
      if (_list[i] < _list[m]) {
        m = i;
      }
    }
    return _list[m];
  }

  double maximum() {
    int m = _start;
    for (int i = _start; i < _end; i++) {
      if (_list[i] > _list[m]) {
        m = i;
      }
    }
    return _list[m];
  }

  void clear() {
    _start = 0;
    _end = 0;
  }

  @override
  String toString() => _list.sublist(_start, _end).toString();
}
