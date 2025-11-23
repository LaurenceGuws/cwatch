enum ServerAction {
  fileExplorer,
  connectivity,
  resources,
  terminal,
  empty,
  trash,
  editor
}

ServerAction? serverActionFromName(String? value) {
  if (value == null) {
    return null;
  }
  for (final action in ServerAction.values) {
    if (action.name == value) {
      return action;
    }
  }
  return null;
}
