/// Historial de comandos deshacibles, acotado en tamaño.
///
/// Los comandos livianos (como agregar un trazo) se pueden deshacer y
/// rehacer libremente. Cuando el historial supera [HistoryManager.maxSteps]
/// pasos, el comando más viejo se "confirma permanentemente" (ver
/// [Command.commitPermanently]) y deja de ocupar lugar en la pila.
abstract class Command {
  Future<void> execute();
  Future<void> undo();

  /// Se llama cuando el comando sale del historial por ser demasiado
  /// viejo. A partir de acá ya no hace falta (ni se puede) deshacerlo:
  /// el comando debe fundir su efecto en un estado permanente.
  Future<void> commitPermanently();
}

class HistoryManager {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  /// Cuántos pasos de deshacer se guardan como máximo antes de fundirse
  /// permanentemente. 40 alcanza de sobra para el uso normal y mantiene
  /// acotada la memoria que usa el historial.
  static const int maxSteps = 40;

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> pushAndExecute(Command command) async {
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear();

    while (_undoStack.length > maxSteps) {
      final evicted = _undoStack.removeAt(0);
      await evicted.commitPermanently();
    }
  }

  Future<void> undo() async {
    if (_undoStack.isEmpty) return;
    final cmd = _undoStack.removeLast();
    await cmd.undo();
    _redoStack.add(cmd);
  }

  Future<void> redo() async {
    if (_redoStack.isEmpty) return;
    final cmd = _redoStack.removeLast();
    await cmd.execute();
    _undoStack.add(cmd);
  }

  void clear() {
    _undoStack.clear();
    _redoStack.clear();
  }
}
