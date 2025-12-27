import 'package:flutter/material.dart';

import 'package:cwatch/models/custom_ssh_host.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_entry.dart';
import 'package:cwatch/services/ssh/builtin/builtin_ssh_key_service.dart';
import 'package:cwatch/shared/theme/app_theme.dart';
import 'package:cwatch/shared/widgets/dialog_keyboard_shortcuts.dart';
import 'add_key_dialog.dart';

/// Dialog for adding or editing a server
class AddServerDialog extends StatefulWidget {
  const AddServerDialog({
    super.key,
    this.initialHost,
    required this.keyService,
    required this.existingNames,
  });

  final CustomSshHost? initialHost;
  final BuiltInSshKeyService keyService;
  final List<String> existingNames;

  @override
  State<AddServerDialog> createState() => _AddServerDialogState();
}

class _AddServerDialogState extends State<AddServerDialog> {
  late final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.initialHost?.name ?? '',
  );
  late final _hostnameController = TextEditingController(
    text: widget.initialHost?.hostname ?? '',
  );
  late final _portController = TextEditingController(
    text: widget.initialHost?.port.toString() ?? '22',
  );
  late final _userController = TextEditingController(
    text: widget.initialHost?.user ?? '',
  );

  String? _selectedKeyId;
  Future<List<BuiltInSshKeyEntry>>? _keysFuture;

  late final Set<String> _existingNamesNormalized;

  @override
  void initState() {
    super.initState();
    _existingNamesNormalized = widget.existingNames
        .map((name) => name.trim().toLowerCase())
        .where((name) => name.isNotEmpty)
        .toSet();
    _keysFuture = widget.keyService.listKeys();
    // Set initial key selection if editing
    if (widget.initialHost?.identityFile != null) {
      // Try to find matching key by ID
      _keysFuture!
          .then((keys) {
            final matchingKey = keys.firstWhere(
              (key) => key.id == widget.initialHost!.identityFile,
              orElse: () =>
                  keys.isNotEmpty ? keys.first : throw StateError('No keys'),
            );
            if (mounted && keys.isNotEmpty) {
              setState(() => _selectedKeyId = matchingKey.id);
            }
          })
          .catchError((_) {
            // Ignore if no matching key found
          });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _hostnameController.dispose();
    _portController.dispose();
    _userController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final spacing = context.appTheme.spacing;
    return DialogKeyboardShortcuts(
      onCancel: () => Navigator.of(context).pop(),
      onConfirm: () {
        if (_formKey.currentState!.validate()) {
          final port = int.tryParse(_portController.text.trim()) ?? 22;
          Navigator.of(context).pop(
            CustomSshHost(
              name: _nameController.text.trim(),
              hostname: _hostnameController.text.trim(),
              port: port,
              user: _userController.text.trim().isEmpty
                  ? null
                  : _userController.text.trim(),
              identityFile: _selectedKeyId,
            ),
          );
        }
      },
      child: AlertDialog(
        title: Text(
          widget.initialHost == null ? 'Add Server' : 'Edit Server',
          overflow: TextOverflow.visible,
          softWrap: true,
        ),
        contentPadding: EdgeInsets.fromLTRB(
          spacing.base * 6,
          spacing.base * 5,
          spacing.base * 6,
          spacing.base * 6,
        ),
        content: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: SizedBox(
            width: MediaQuery.of(context).size.width * 0.8,
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Name',
                        helperText: 'Display name for this server',
                      ),
                      textCapitalization: TextCapitalization.words,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Name is required';
                        }
                        final normalized = value.trim().toLowerCase();
                        // Block duplicate display names when adding or editing.
                        if (_existingNamesNormalized.contains(normalized)) {
                          return 'A server with this name already exists';
                        }
                        return null;
                      },
                      autofocus: true,
                    ),
                    SizedBox(height: spacing.xl),
                    TextFormField(
                      controller: _hostnameController,
                      decoration: const InputDecoration(
                        labelText: 'Hostname',
                        helperText: 'Hostname or IP address',
                      ),
                      keyboardType: TextInputType.url,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Hostname is required';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.xl),
                    TextFormField(
                      controller: _portController,
                      decoration: const InputDecoration(
                        labelText: 'Port',
                        helperText: 'SSH port (default: 22)',
                      ),
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Port is required';
                        }
                        final port = int.tryParse(value.trim());
                        if (port == null || port < 1 || port > 65535) {
                          return 'Invalid port number';
                        }
                        return null;
                      },
                    ),
                    SizedBox(height: spacing.xl),
                    TextFormField(
                      controller: _userController,
                      decoration: const InputDecoration(
                        labelText: 'Username (optional)',
                        helperText: 'SSH username',
                      ),
                    ),
                    SizedBox(height: spacing.xl),
                    FutureBuilder<List<BuiltInSshKeyEntry>>(
                      future: _keysFuture,
                      builder: (context, snapshot) {
                        final keys = snapshot.data ?? [];
                        final keyItems = <DropdownMenuItem<String?>>[
                          const DropdownMenuItem(
                            value: null,
                            child: Text('None (use default)'),
                          ),
                          ...keys.map(
                            (key) => DropdownMenuItem(
                              value: key.id,
                              child: Text(key.label),
                            ),
                          ),
                          DropdownMenuItem(
                            value: '__add_key__',
                            child: Row(
                              children: [
                                Icon(Icons.add, size: 18),
                                SizedBox(width: spacing.md),
                                Text('Add new key...'),
                              ],
                            ),
                          ),
                        ];

                        return DropdownButtonFormField<String?>(
                          initialValue: _selectedKeyId,
                          decoration: const InputDecoration(
                            labelText: 'SSH Key (optional)',
                            helperText: 'Select a configured SSH key',
                          ),
                          items: keyItems,
                          onChanged: (value) async {
                            if (value == '__add_key__') {
                              // Show add key dialog
                              final newKey =
                                  await showDialog<BuiltInSshKeyEntry>(
                                    context: context,
                                    builder: (context) => AddKeyDialog(
                                      keyService: widget.keyService,
                                    ),
                                  );
                              if (newKey != null && mounted) {
                                setState(() {
                                  _selectedKeyId = newKey.id;
                                  _keysFuture = widget.keyService.listKeys();
                                });
                              }
                            } else {
                              setState(() => _selectedKeyId = value);
                            }
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final port = int.tryParse(_portController.text.trim()) ?? 22;
                Navigator.of(context).pop(
                  CustomSshHost(
                    name: _nameController.text.trim(),
                    hostname: _hostnameController.text.trim(),
                    port: port,
                    user: _userController.text.trim().isEmpty
                        ? null
                        : _userController.text.trim(),
                    identityFile: _selectedKeyId,
                  ),
                );
              }
            },
            child: Text(widget.initialHost == null ? 'Add' : 'Save'),
          ),
        ],
      ),
    );
  }
}
