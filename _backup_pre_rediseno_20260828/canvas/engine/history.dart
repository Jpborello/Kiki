import 'dart:ui' as ui;

abstract class Command {
  Future<void> execute();
  Future<void> undo();
}

class HistoryManager {
  final List<Command> _undoStack = [];
  final List<Command> _redoStack = [];

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  Future<void> pushAndExecute(Command command) async {
    await command.execute();
    _undoStack.add(command);
    _redoStack.clear();
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

class StrokeCommand extends Command {
  final ui.Image oldImage;
  final ui.Image newImage;
  final Function(ui.Image) onImageChanged;

  StrokeCommand({
    required this.oldImage,
    required this.newImage,
    required this.onImageChanged,
  });

  @override
  Future<void> execute() async {
    onImageChanged(newImage);
  }

  @override
  Future<void> undo() async {
    onImageChanged(oldImage);
  }
}
