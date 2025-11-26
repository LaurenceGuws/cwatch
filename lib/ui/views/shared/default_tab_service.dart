/// Handles replacing the default/base tab with a new tab instance.
class DefaultTabService<T> {
  DefaultTabService({
    required this.baseTabBuilder,
    required this.tabId,
  });

  final T Function({String? id}) baseTabBuilder;
  final String Function(T tab) tabId;

  T createBase({String? id}) => baseTabBuilder(id: id);

  int? replaceTab(List<T> tabs, String id, T replacement) {
    final index = tabs.indexWhere((tab) => tabId(tab) == id);
    if (index == -1) {
      return null;
    }
    tabs[index] = replacement;
    return index;
  }
}
