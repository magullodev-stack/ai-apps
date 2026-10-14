import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Inspector común de AI-APPS: controla las cargas de Image.asset y
/// AssetImage que usan el DefaultAssetBundle de Flutter.
/// No altera ni elimina los recursos originales; no existe en release.
class AiAppsVisualAssetController extends ChangeNotifier {
  static const MethodChannel _channel = MethodChannel('ai_apps/visual_inspector');
  final Set<String> _hidden = <String>{};
  int _revision = 0;

  int get revision => _revision;

  bool isVisible(String asset) => !_hidden.contains(asset);

  /// Devuelve false para claves no válidas o llamadas fuera de debug.
  bool setVisible(String asset, bool visible) {
    if (!kDebugMode ||
        !asset.startsWith('assets/') ||
        asset.contains('..') ||
        !RegExp(r'^assets/[a-zA-Z0-9_./-]+\.(png|jpg|jpeg|webp)$',
            caseSensitive: false).hasMatch(asset)) {
      return false;
    }
    final changed = visible ? _hidden.remove(asset) : _hidden.add(asset);
    if (changed) {
      _revision++;
      notifyListeners();
    }
    return true;
  }

  /// Se instala una vez por app, no una vez por pantalla.
  /// El host Android solo retransmite órdenes explícitas de desarrollo.
  void connectDebugChannel() {
    if (!kDebugMode) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method != 'setAssetVisibility' || call.arguments is! Map) {
        throw MissingPluginException('Orden de inspector desconocida.');
      }
      final args = call.arguments as Map;
      final path = args['asset'];
      final visible = args['visible'];
      if (path is! String || visible is! bool ||
          !setVisible(path, visible)) {
        throw ArgumentError('Recurso visual inválido.');
      }
    });
  }

  @override
  void dispose() {
    if (kDebugMode) _channel.setMethodCallHandler(null);
    super.dispose();
  }
}

/// Instalar en MaterialApp.builder, alrededor del contenido habitual.
/// Al cambiar una capa reconstruye solo el árbol de debug, con un bundle
/// nuevo para no reutilizar imágenes antiguas de ImageCache.
class AiAppsVisualAssetScope extends StatefulWidget {
  const AiAppsVisualAssetScope({
    super.key,
    required this.controller,
    required this.child,
  });

  final AiAppsVisualAssetController controller;
  final Widget child;

  @override
  State<AiAppsVisualAssetScope> createState() =>
      _AiAppsVisualAssetScopeState();
}

class _AiAppsVisualAssetScopeState extends State<AiAppsVisualAssetScope> {
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) return widget.child;
    final parentBundle = DefaultAssetBundle.of(context);
    return AnimatedBuilder(
      animation: widget.controller,
      builder: (context, _) => DefaultAssetBundle(
        bundle: _InspectorAssetBundle(parentBundle, widget.controller),
        child: KeyedSubtree(
          key: ValueKey(widget.controller.revision),
          child: widget.child,
        ),
      ),
    );
  }
}

class _InspectorAssetBundle extends AssetBundle {
  _InspectorAssetBundle(this._delegate, this._controller);

  final AssetBundle _delegate;
  final AiAppsVisualAssetController _controller;

  // PNG transparente válido (RGBA 1x1). Solo se emplea en modo debug.
  static final ByteData _clearPixel = ByteData.sublistView(
    base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJ'
      'AAAADUlEQVR4nGNgYGBgAAAABQABpfZFQAAAAABJRU5ErkJggg==',
    ),
  );

  @override
  Future<ByteData> load(String key) {
    if (!_controller.isVisible(key) &&
        RegExp(r'\.(png|jpg|jpeg|webp)$', caseSensitive: false)
            .hasMatch(key)) {
      return SynchronousFuture<ByteData>(_clearPixel);
    }
    return _delegate.load(key);
  }

  @override
  Future<String> loadString(String key, {bool cache = true}) =>
      _delegate.loadString(key, cache: cache);

  @override
  Future<T> loadStructuredData<T>(
    String key,
    Future<T> Function(String value) parser,
  ) => _delegate.loadStructuredData<T>(key, parser);

  @override
  void evict(String key) => _delegate.evict(key);

  @override
  void clear() => _delegate.clear();
}
