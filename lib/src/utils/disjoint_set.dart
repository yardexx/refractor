class DisjointSet<T> {
  final Map<T, T> _parent = {};
  final Map<T, int> _rank = {};

  T find(T x) {
    _parent.putIfAbsent(x, () => x);
    if (_parent[x] != x) {
      _parent[x] = find(_parent[x] as T);
    }
    return _parent[x] as T;
  }

  void union(T a, T b) {
    final rootA = find(a);
    final rootB = find(b);
    if (rootA == rootB) return;

    final rankA = _rank[rootA] ?? 0;
    final rankB = _rank[rootB] ?? 0;
    if (rankA < rankB) {
      _parent[rootA] = rootB;
    } else if (rankA > rankB) {
      _parent[rootB] = rootA;
    } else {
      _parent[rootB] = rootA;
      _rank[rootA] = rankA + 1;
    }
  }
}
