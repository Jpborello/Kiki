import 'dart:async';
import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

import 'blob_store.dart';

BlobStore createBlobStore() => WebBlobStore();

/// Guarda los archivos en IndexedDB, en un único object store con claves
/// `<projectId>/<nombre>`. localStorage no sirve: tiene ~5 MB y cada capa
/// en PNG ya pesa varios cientos de KB.
class WebBlobStore implements BlobStore {
  static const _dbName = 'kikidraw';
  static const _storeName = 'files';

  Future<web.IDBDatabase>? _db;

  Future<web.IDBDatabase> get _database => _db ??= _open();

  Future<web.IDBDatabase> _open() {
    // Pide que el navegador no borre los dibujos cuando le falte espacio.
    // Si no lo concede, igual se guarda (solo que en modo "best effort").
    try {
      web.window.navigator.storage.persist();
    } catch (e) {
      debugPrint('No se pudo pedir almacenamiento persistente: $e');
    }

    final request = web.window.indexedDB.open(_dbName, 1);
    final completer = Completer<web.IDBDatabase>();
    request.onupgradeneeded = ((web.IDBVersionChangeEvent _) {
      final db = request.result as web.IDBDatabase;
      if (!db.objectStoreNames.contains(_storeName)) {
        db.createObjectStore(_storeName);
      }
    }).toJS;
    request.onsuccess = ((web.Event _) {
      completer.complete(request.result as web.IDBDatabase);
    }).toJS;
    request.onerror = ((web.Event _) {
      completer.completeError(
        StateError('No se pudo abrir IndexedDB: ${request.error?.message}'),
      );
    }).toJS;
    return completer.future;
  }

  /// Corre [op] en una transacción y espera a que se confirme, así un
  /// guardado no se da por hecho antes de estar escrito de verdad.
  Future<JSAny?> _run(
    web.IDBTransactionMode mode,
    web.IDBRequest Function(web.IDBObjectStore store) op,
  ) async {
    final db = await _database;
    final tx = db.transaction(_storeName.toJS, mode);
    final request = op(tx.objectStore(_storeName));
    final completer = Completer<JSAny?>();
    void fail(web.Event _) {
      if (completer.isCompleted) return;
      completer.completeError(
        StateError('Error de IndexedDB: ${tx.error?.message ?? request.error?.message}'),
      );
    }

    tx.oncomplete = ((web.Event _) => completer.complete(request.result)).toJS;
    tx.onerror = fail.toJS;
    tx.onabort = fail.toJS;
    return completer.future;
  }

  String _key(String projectId, String name) => '$projectId/$name';

  @override
  Future<List<String>> listProjectIds() async {
    final result = await _run('readonly', (store) => store.getAllKeys());
    final keys = (result as JSArray<JSAny?>).toDart;
    final ids = <String>{};
    for (final key in keys) {
      if (key == null || !key.isA<JSString>()) continue;
      final value = (key as JSString).toDart;
      final slash = value.indexOf('/');
      if (slash > 0) ids.add(value.substring(0, slash));
    }
    return ids.toList();
  }

  @override
  Future<Uint8List?> read(String projectId, String name) async {
    final result = await _run(
      'readonly',
      (store) => store.get(_key(projectId, name).toJS),
    );
    if (result == null || !result.isA<JSUint8Array>()) return null;
    return (result as JSUint8Array).toDart;
  }

  @override
  Future<void> write(String projectId, String name, Uint8List bytes) async {
    await _run(
      'readwrite',
      (store) => store.put(bytes.toJS, _key(projectId, name).toJS),
    );
  }

  @override
  Future<void> deleteProject(String projectId) async {
    // '￿' es mayor que cualquier carácter que pueda tener un nombre
    // de archivo, así el rango cubre todas las claves del proyecto.
    final range = web.IDBKeyRange.bound(
      '$projectId/'.toJS,
      '$projectId/￿'.toJS,
    );
    await _run('readwrite', (store) => store.delete(range));
  }
}
