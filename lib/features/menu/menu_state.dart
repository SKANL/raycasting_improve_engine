/// Simple state for the menu — tracks which item is selected.
class MenuState {
  const MenuState({this.selectedIndex = 0, this.itemCount = 3});

  final int selectedIndex;
  final int itemCount;

  /// Menu item labels in order.
  static const List<String> labels = [
    'INICIAR',
    'CRÉDITOS',
    'SALIR',
  ];

  MenuState copyWith({int? selectedIndex}) {
    return MenuState(
      selectedIndex: selectedIndex ?? this.selectedIndex,
      itemCount: itemCount,
    );
  }

  MenuState selectNext() {
    return copyWith(selectedIndex: (selectedIndex + 1) % itemCount);
  }

  MenuState selectPrevious() {
    return copyWith(selectedIndex: (selectedIndex - 1 + itemCount) % itemCount);
  }
}
