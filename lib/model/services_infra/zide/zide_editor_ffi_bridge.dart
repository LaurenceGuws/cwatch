import 'dart:convert';
import 'dart:ffi';

import 'package:ffi/ffi.dart';

import 'package:cwatch/model/models/app_settings.dart';

import 'zide_ffi_backend_config.dart';
import 'zide_ffi_exception.dart';
import 'zide_ffi_log_config.dart';

final class ZideEditorHandle extends Opaque {}

final class _ZideEditorStringBuffer extends Struct {
  external Pointer<Uint8> ptr;

  @IntPtr()
  external int len;

  external Pointer<Void> ctx;
}

final class _ZideEditorCaretOffset extends Struct {
  @IntPtr()
  external int offset;
}

final class _ZideEditorSearchMatch extends Struct {
  @IntPtr()
  external int start;

  @IntPtr()
  external int end;
}

class ZideEditorSearchMatchData {
  const ZideEditorSearchMatchData({required this.start, required this.end});

  final int start;
  final int end;
}

class ZideEditorSearchActiveData {
  const ZideEditorSearchActiveData({
    required this.hasActive,
    required this.index,
  });

  final bool hasActive;
  final int index;
}

class ZideEditorFfiBridge {
  ZideEditorFfiBridge._({
    required DynamicLibrary library,
    required this.libraryPath,
  }) : _create = library
           .lookupFunction<
             Int32 Function(Pointer<Pointer<ZideEditorHandle>>),
             int Function(Pointer<Pointer<ZideEditorHandle>>)
           >('zide_editor_create'),
       _destroy = library
           .lookupFunction<
             Void Function(Pointer<ZideEditorHandle>),
             void Function(Pointer<ZideEditorHandle>)
           >('zide_editor_destroy'),
       _setText = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, IntPtr),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int)
           >('zide_editor_set_text'),
       _insertText = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, IntPtr),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int)
           >('zide_editor_insert_text'),
       _replaceRange = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               IntPtr,
               IntPtr,
               Pointer<Uint8>,
               IntPtr,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               int,
               int,
               Pointer<Uint8>,
               int,
             )
           >('zide_editor_replace_range'),
       _deleteRange = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, IntPtr, IntPtr),
             int Function(Pointer<ZideEditorHandle>, int, int)
           >('zide_editor_delete_range'),
       _beginUndoGroup = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>),
             int Function(Pointer<ZideEditorHandle>)
           >('zide_editor_begin_undo_group'),
       _endUndoGroup = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>),
             int Function(Pointer<ZideEditorHandle>)
           >('zide_editor_end_undo_group'),
       _textAlloc = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               Pointer<_ZideEditorStringBuffer>,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               Pointer<_ZideEditorStringBuffer>,
             )
           >('zide_editor_text_alloc'),
       _stringFree = library
           .lookupFunction<
             Void Function(Pointer<_ZideEditorStringBuffer>),
             void Function(Pointer<_ZideEditorStringBuffer>)
           >('zide_editor_string_free'),
       _setCursorOffset = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, IntPtr),
             int Function(Pointer<ZideEditorHandle>, int)
           >('zide_editor_set_cursor_offset'),
       _primaryCaretOffset = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_primary_caret_offset'),
       _auxCaretCount = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_aux_caret_count'),
       _auxCaretGet = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, IntPtr, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, int, Pointer<IntPtr>)
           >('zide_editor_aux_caret_get'),
       _clearSelections = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>),
             int Function(Pointer<ZideEditorHandle>)
           >('zide_editor_clear_selections'),
       _setCarets = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               IntPtr,
               Pointer<_ZideEditorCaretOffset>,
               IntPtr,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               int,
               Pointer<_ZideEditorCaretOffset>,
               int,
             )
           >('zide_editor_set_carets'),
       _cursorOffset = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_cursor_offset'),
       _undo = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>)
           >('zide_editor_undo'),
       _redo = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>)
           >('zide_editor_redo'),
       _lineCount = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_line_count'),
       _totalLen = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_total_len'),
       _searchSetQuery = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               Pointer<Uint8>,
               IntPtr,
               Uint8,
             ),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int, int)
           >('zide_editor_search_set_query'),
       _searchMatchCount = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>),
             int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
           >('zide_editor_search_match_count'),
       _searchMatchGet = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               IntPtr,
               Pointer<_ZideEditorSearchMatch>,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               int,
               Pointer<_ZideEditorSearchMatch>,
             )
           >('zide_editor_search_match_get'),
       _searchActiveIndex = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               Pointer<IntPtr>,
               Pointer<Uint8>,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               Pointer<IntPtr>,
               Pointer<Uint8>,
             )
           >('zide_editor_search_active_index'),
       _searchNext = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>)
           >('zide_editor_search_next'),
       _searchPrev = library
           .lookupFunction<
             Int32 Function(Pointer<ZideEditorHandle>, Pointer<Uint8>),
             int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>)
           >('zide_editor_search_prev'),
       _searchReplaceActive = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               Pointer<Uint8>,
               IntPtr,
               Pointer<Uint8>,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               Pointer<Uint8>,
               int,
               Pointer<Uint8>,
             )
           >('zide_editor_search_replace_active'),
       _searchReplaceAll = library
           .lookupFunction<
             Int32 Function(
               Pointer<ZideEditorHandle>,
               Pointer<Uint8>,
               IntPtr,
               Pointer<IntPtr>,
             ),
             int Function(
               Pointer<ZideEditorHandle>,
               Pointer<Uint8>,
               int,
               Pointer<IntPtr>,
             )
           >('zide_editor_search_replace_all'),
       _statusString = library
           .lookupFunction<
             Pointer<Utf8> Function(Int32),
             Pointer<Utf8> Function(int)
           >('zide_editor_status_string');

  factory ZideEditorFfiBridge.open({
    required AppSettings settings,
    String? overrideLibraryPath,
  }) {
    ZideFfiLogConfig.apply(settings: settings);
    final config = ZideFfiBackendConfig(settings: settings);
    final path = config.resolveEditorLibraryPath(
      overridePath: overrideLibraryPath,
    );
    try {
      return ZideEditorFfiBridge._(
        library: DynamicLibrary.open(path),
        libraryPath: path,
      );
    } catch (error) {
      throw ZideFfiException(
        'Failed to open editor ffi library at "$path": $error',
      );
    }
  }

  final String libraryPath;

  final int Function(Pointer<Pointer<ZideEditorHandle>>) _create;
  final void Function(Pointer<ZideEditorHandle>) _destroy;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int) _setText;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int)
  _insertText;
  final int Function(Pointer<ZideEditorHandle>, int, int, Pointer<Uint8>, int)
  _replaceRange;
  final int Function(Pointer<ZideEditorHandle>, int, int) _deleteRange;
  final int Function(Pointer<ZideEditorHandle>) _beginUndoGroup;
  final int Function(Pointer<ZideEditorHandle>) _endUndoGroup;
  final int Function(
    Pointer<ZideEditorHandle>,
    Pointer<_ZideEditorStringBuffer>,
  )
  _textAlloc;
  final void Function(Pointer<_ZideEditorStringBuffer>) _stringFree;
  final int Function(Pointer<ZideEditorHandle>, int) _setCursorOffset;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
  _primaryCaretOffset;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>) _auxCaretCount;
  final int Function(Pointer<ZideEditorHandle>, int, Pointer<IntPtr>)
  _auxCaretGet;
  final int Function(Pointer<ZideEditorHandle>) _clearSelections;
  final int Function(
    Pointer<ZideEditorHandle>,
    int,
    Pointer<_ZideEditorCaretOffset>,
    int,
  )
  _setCarets;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>) _cursorOffset;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>) _undo;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>) _redo;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>) _lineCount;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>) _totalLen;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>, int, int)
  _searchSetQuery;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>)
  _searchMatchCount;
  final int Function(
    Pointer<ZideEditorHandle>,
    int,
    Pointer<_ZideEditorSearchMatch>,
  )
  _searchMatchGet;
  final int Function(Pointer<ZideEditorHandle>, Pointer<IntPtr>, Pointer<Uint8>)
  _searchActiveIndex;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>) _searchNext;
  final int Function(Pointer<ZideEditorHandle>, Pointer<Uint8>) _searchPrev;
  final int Function(
    Pointer<ZideEditorHandle>,
    Pointer<Uint8>,
    int,
    Pointer<Uint8>,
  )
  _searchReplaceActive;
  final int Function(
    Pointer<ZideEditorHandle>,
    Pointer<Uint8>,
    int,
    Pointer<IntPtr>,
  )
  _searchReplaceAll;
  final Pointer<Utf8> Function(int) _statusString;

  Pointer<ZideEditorHandle> create() {
    final outHandle = calloc<Pointer<ZideEditorHandle>>();
    try {
      _throwIfError(_create(outHandle), operation: 'editor_create');
      final handle = outHandle.value;
      if (handle == nullptr) {
        throw const ZideFfiException('editor_create returned a null handle');
      }
      return handle;
    } finally {
      calloc.free(outHandle);
    }
  }

  void destroy(Pointer<ZideEditorHandle> handle) {
    if (handle == nullptr) {
      return;
    }
    _destroy(handle);
  }

  void setText(Pointer<ZideEditorHandle> handle, String text) {
    _withUtf8Bytes(text, (ptr, len) {
      _throwIfError(_setText(handle, ptr, len), operation: 'editor_set_text');
    });
  }

  void insertText(Pointer<ZideEditorHandle> handle, String text) {
    _withUtf8Bytes(text, (ptr, len) {
      _throwIfError(
        _insertText(handle, ptr, len),
        operation: 'editor_insert_text',
      );
    });
  }

  void replaceRange(
    Pointer<ZideEditorHandle> handle, {
    required int start,
    required int end,
    required String text,
  }) {
    _withUtf8Bytes(text, (ptr, len) {
      _throwIfError(
        _replaceRange(handle, start, end, ptr, len),
        operation: 'editor_replace_range',
      );
    });
  }

  void deleteRange(
    Pointer<ZideEditorHandle> handle, {
    required int start,
    required int end,
  }) {
    _throwIfError(
      _deleteRange(handle, start, end),
      operation: 'editor_delete_range',
    );
  }

  void beginUndoGroup(Pointer<ZideEditorHandle> handle) {
    _throwIfError(
      _beginUndoGroup(handle),
      operation: 'editor_begin_undo_group',
    );
  }

  void endUndoGroup(Pointer<ZideEditorHandle> handle) {
    _throwIfError(_endUndoGroup(handle), operation: 'editor_end_undo_group');
  }

  String textAlloc(Pointer<ZideEditorHandle> handle) {
    final out = calloc<_ZideEditorStringBuffer>();
    try {
      _throwIfError(_textAlloc(handle, out), operation: 'editor_text_alloc');
      return _decodeUtf8(out.ref.ptr, out.ref.len);
    } finally {
      _stringFree(out);
      calloc.free(out);
    }
  }

  void setCursorOffset(Pointer<ZideEditorHandle> handle, int offset) {
    _throwIfError(
      _setCursorOffset(handle, offset),
      operation: 'editor_set_cursor_offset',
    );
  }

  int primaryCaretOffset(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_primary_caret_offset',
      call: (out) => _primaryCaretOffset(handle, out),
    );
  }

  int auxCaretCount(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_aux_caret_count',
      call: (out) => _auxCaretCount(handle, out),
    );
  }

  int auxCaretGet(Pointer<ZideEditorHandle> handle, int index) {
    return _readSizeOut(
      operation: 'editor_aux_caret_get',
      call: (out) => _auxCaretGet(handle, index, out),
    );
  }

  void clearSelections(Pointer<ZideEditorHandle> handle) {
    _throwIfError(
      _clearSelections(handle),
      operation: 'editor_clear_selections',
    );
  }

  void setCarets(
    Pointer<ZideEditorHandle> handle, {
    required int primaryOffset,
    List<int> auxiliaryOffsets = const [],
  }) {
    if (auxiliaryOffsets.isEmpty) {
      _throwIfError(
        _setCarets(handle, primaryOffset, nullptr, 0),
        operation: 'editor_set_carets',
      );
      return;
    }

    final aux = calloc<_ZideEditorCaretOffset>(auxiliaryOffsets.length);
    try {
      for (var i = 0; i < auxiliaryOffsets.length; i++) {
        (aux + i).ref.offset = auxiliaryOffsets[i];
      }
      _throwIfError(
        _setCarets(handle, primaryOffset, aux, auxiliaryOffsets.length),
        operation: 'editor_set_carets',
      );
    } finally {
      calloc.free(aux);
    }
  }

  int cursorOffset(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_cursor_offset',
      call: (out) => _cursorOffset(handle, out),
    );
  }

  bool undo(Pointer<ZideEditorHandle> handle) {
    return _readBoolOut(
      operation: 'editor_undo',
      call: (out) => _undo(handle, out),
    );
  }

  bool redo(Pointer<ZideEditorHandle> handle) {
    return _readBoolOut(
      operation: 'editor_redo',
      call: (out) => _redo(handle, out),
    );
  }

  int lineCount(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_line_count',
      call: (out) => _lineCount(handle, out),
    );
  }

  int totalLength(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_total_len',
      call: (out) => _totalLen(handle, out),
    );
  }

  void searchSetQuery(
    Pointer<ZideEditorHandle> handle, {
    required String query,
    bool useRegex = false,
  }) {
    _withUtf8Bytes(query, (ptr, len) {
      _throwIfError(
        _searchSetQuery(handle, ptr, len, useRegex ? 1 : 0),
        operation: 'editor_search_set_query',
      );
    });
  }

  int searchMatchCount(Pointer<ZideEditorHandle> handle) {
    return _readSizeOut(
      operation: 'editor_search_match_count',
      call: (out) => _searchMatchCount(handle, out),
    );
  }

  ZideEditorSearchMatchData searchMatchGet(
    Pointer<ZideEditorHandle> handle,
    int index,
  ) {
    final out = calloc<_ZideEditorSearchMatch>();
    try {
      _throwIfError(
        _searchMatchGet(handle, index, out),
        operation: 'editor_search_match_get',
      );
      return ZideEditorSearchMatchData(start: out.ref.start, end: out.ref.end);
    } finally {
      calloc.free(out);
    }
  }

  ZideEditorSearchActiveData searchActiveIndex(
    Pointer<ZideEditorHandle> handle,
  ) {
    final outIndex = calloc<IntPtr>();
    final outHasActive = calloc<Uint8>();
    try {
      _throwIfError(
        _searchActiveIndex(handle, outIndex, outHasActive),
        operation: 'editor_search_active_index',
      );
      return ZideEditorSearchActiveData(
        hasActive: outHasActive.value != 0,
        index: outIndex.value,
      );
    } finally {
      calloc.free(outIndex);
      calloc.free(outHasActive);
    }
  }

  bool searchNext(Pointer<ZideEditorHandle> handle) {
    return _readBoolOut(
      operation: 'editor_search_next',
      call: (out) => _searchNext(handle, out),
    );
  }

  bool searchPrev(Pointer<ZideEditorHandle> handle) {
    return _readBoolOut(
      operation: 'editor_search_prev',
      call: (out) => _searchPrev(handle, out),
    );
  }

  bool searchReplaceActive(
    Pointer<ZideEditorHandle> handle, {
    required String replacement,
  }) {
    return _withUtf8Bytes(replacement, (bytes, len) {
      return _readBoolOut(
        operation: 'editor_search_replace_active',
        call: (out) => _searchReplaceActive(handle, bytes, len, out),
      );
    });
  }

  int searchReplaceAll(
    Pointer<ZideEditorHandle> handle, {
    required String replacement,
  }) {
    return _withUtf8Bytes(replacement, (bytes, len) {
      return _readSizeOut(
        operation: 'editor_search_replace_all',
        call: (out) => _searchReplaceAll(handle, bytes, len, out),
      );
    });
  }

  String statusString(int status) {
    final pointer = _statusString(status);
    if (pointer == nullptr) {
      return 'unknown';
    }
    return pointer.toDartString();
  }

  void _throwIfError(int status, {required String operation}) {
    if (status == 0) {
      return;
    }
    throw ZideFfiException(
      '$operation failed with status=$status (${statusString(status)})',
    );
  }

  int _readSizeOut({
    required String operation,
    required int Function(Pointer<IntPtr> out) call,
  }) {
    final out = calloc<IntPtr>();
    try {
      _throwIfError(call(out), operation: operation);
      return out.value;
    } finally {
      calloc.free(out);
    }
  }

  bool _readBoolOut({
    required String operation,
    required int Function(Pointer<Uint8> out) call,
  }) {
    final out = calloc<Uint8>();
    try {
      _throwIfError(call(out), operation: operation);
      return out.value != 0;
    } finally {
      calloc.free(out);
    }
  }

  static String _decodeUtf8(Pointer<Uint8> ptr, int len) {
    if (ptr == nullptr || len <= 0) {
      return '';
    }
    return utf8.decode(ptr.asTypedList(len), allowMalformed: true);
  }

  static T _withUtf8Bytes<T>(
    String value,
    T Function(Pointer<Uint8> ptr, int len) callback,
  ) {
    final bytes = utf8.encode(value);
    if (bytes.isEmpty) {
      return callback(nullptr, 0);
    }

    final ptr = calloc<Uint8>(bytes.length);
    try {
      ptr.asTypedList(bytes.length).setAll(0, bytes);
      return callback(ptr, bytes.length);
    } finally {
      calloc.free(ptr);
    }
  }
}
