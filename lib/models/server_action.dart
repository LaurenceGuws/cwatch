enum ServerAction { fileExplorer, connectivity, resources, empty, trash }

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
