import 'dart:async';

import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/hittest_result_types.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_hittest_result.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:ar_flutter_plugin_plus/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
// vector_math also declares a `Colors` symbol — hide it so Material's `Colors`
// (and const colour literals) resolve unambiguously.
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import 'set_sticker_screen.dart';

/// True native multi-object AR placement for a whole furniture SET. One ARCore
/// (Android, Filament) / ARKit (iOS) session detects the floor; the FIRST tap
/// drops every model-bearing piece of the set side-by-side as separate anchored
/// nodes, each then independently draggable (handlePans) and rotatable
/// (handleRotation) by the user. Models are placed true-to-size from each
/// piece's real cm dimensions (`ar_flutter_plugin_plus` treats a `.glb` unit as
/// one metre, and Meshy normalises every mesh into a unit cube, so cm/100 per
/// axis restores the real footprint — same normalisation as the model-viewer).
///
/// This is a NATIVE feature: it ships only in a full store release, never a
/// Shorebird patch. Devices without ARCore/ARKit fall back to the 2D sticker
/// overlay via the always-visible "2D" action.
class SetArViewerScreen extends StatefulWidget {
  const SetArViewerScreen({
    super.key,
    required this.pieces,
    required this.setName,
  });

  final List<ArSetPiece> pieces;
  final String setName;

  @override
  State<SetArViewerScreen> createState() => _SetArViewerScreenState();
}

class _SetArViewerScreenState extends State<SetArViewerScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;

  final List<ARNode> _nodes = [];
  final List<ARAnchor> _placedAnchors = [];

  /// Monotonic suffix so re-placing the set never collides node names.
  int _placeCounter = 0;
  bool _placed = false;
  bool _saving = false;

  /// Only model-bearing pieces are 3D-placeable; image-only members are skipped
  /// here (they remain placeable in 2D sticker mode).
  late final List<ArSetPiece> _placeable = widget.pieces
      .where((p) => p.hasModel)
      .toList(growable: false);

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No approved models in the set → AR has nothing to place; send the buyer
    // straight to the 2D sticker overlay (photos are enough there).
    if (_placeable.isEmpty) {
      return _NoModelsView(onUse2d: _open2d, onClose: _close);
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          ARView(
            onARViewCreated: _onArViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          _TopBar(
            title: widget.setName,
            onClose: _close,
            onSwitch2d: _open2d,
            onSave: _placed && !_saving ? _save : null,
            onClear: _placed ? _clearAll : null,
            saving: _saving,
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: MediaQuery.of(context).padding.bottom + 28,
            child: _HintPill(
              text: _placed
                  ? tr('product.set_2d_hint')
                  : tr('product.set_ar_place_hint'),
            ),
          ),
        ],
      ),
    );
  }

  void _onArViewCreated(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) {
    _session = session;
    _objects = objects;
    _anchors = anchors;

    session.onInitialize(
      showAnimatedGuide: true,
      showPlanes: true,
      handleTaps: true,
      handlePans: true, // independent per-node drag
      handleRotation: true, // independent per-node rotate
    );
    // Neutralise the plugin's default model down-scaling so our cm→metre scale
    // is the literal real-world size.
    objects.onInitialize(iosScaleFactor: 1.0, androidScaleFactor: 1.0);
    session.onPlaneOrPointTap = _onPlaneTap;
  }

  Future<void> _onPlaneTap(List<ARHitTestResult> hits) async {
    if (_placed) return; // the set is placed once; "clear" re-arms placement
    final objects = _objects;
    final anchors = _anchors;
    if (objects == null || anchors == null) return;

    ARHitTestResult? plane;
    for (final h in hits) {
      if (h.type == ARHitTestResultType.plane) {
        plane = h;
        break;
      }
    }
    if (plane == null) return;

    final anchor = ARPlaneAnchor(transformation: plane.worldTransform);
    if (await anchors.addAnchor(anchor) != true) return;
    _placedAnchors.add(anchor);

    // Lay the pieces out in a centred row along the anchor's local X so the
    // whole set lands at once; each node is then independently movable.
    final widthsM = _placeable
        .map((p) => ((p.widthCm ?? 60) / 100).clamp(0.2, 3.0))
        .toList(growable: false);
    const gap = 0.15;
    final total =
        widthsM.fold<double>(0, (a, b) => a + b) + gap * (widthsM.length - 1);
    var cursor = -total / 2;
    final batch = _placeCounter++;
    var any = false;

    for (var i = 0; i < _placeable.length; i++) {
      final piece = _placeable[i];
      final half = widthsM[i] / 2;
      final x = cursor + half;
      cursor += widthsM[i] + gap;

      final node = ARNode(
        type: NodeType.webGLB,
        uri: piece.glbUrl!,
        name: 'set_${batch}_$i',
        scale: arScaleVector3(piece.widthCm, piece.heightCm, piece.depthCm),
        position: Vector3(x, 0, 0),
      );
      try {
        if (await objects.addNode(node, planeAnchor: anchor) == true) {
          _nodes.add(node);
          any = true;
        }
      } catch (e, st) {
        talker.handle(e, st, '[set-ar] addNode failed');
      }
    }

    if (any && mounted) {
      setState(() => _placed = true);
    } else {
      anchors.removeAnchor(anchor);
      _placedAnchors.remove(anchor);
    }
  }

  void _clearAll() {
    final objects = _objects;
    final anchors = _anchors;
    for (final n in _nodes) {
      objects?.removeNode(n);
    }
    for (final a in _placedAnchors) {
      anchors?.removeAnchor(a);
    }
    _nodes.clear();
    _placedAnchors.clear();
    if (mounted) setState(() => _placed = false);
  }

  Future<void> _save() async {
    final session = _session;
    if (session == null || _saving) return;
    setState(() => _saving = true);
    try {
      final image = await session.snapshot();
      if (image is! MemoryImage) {
        _toast(tr('product.ar_save_failed'));
        return;
      }
      if (!await Gal.requestAccess()) {
        _toast(tr('product.ar_save_denied'));
        return;
      }
      await Gal.putImageBytes(image.bytes, name: 'woody_ar_set');
      _toast(tr('product.ar_saved'));
    } on GalException catch (e) {
      _toast(
        e.type == GalExceptionType.accessDenied
            ? tr('product.ar_save_denied')
            : tr('product.ar_save_failed'),
      );
    } catch (e, st) {
      talker.handle(e, st, '[set-ar] snapshot save failed');
      _toast(tr('product.ar_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _open2d() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        settings: const RouteSettings(name: '/set-sticker'),
        fullscreenDialog: true,
        builder: (_) =>
            SetStickerScreen(pieces: widget.pieces, setName: widget.setName),
      ),
    );
  }

  void _close() => Navigator.of(context).maybePop();

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black.withValues(alpha: 0.85),
          content: Text(
            text,
            style: const TextStyle(
              fontFamily: AppFonts.body,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      );
  }
}

/// Top control row over the AR scene: close (left) and a cluster of clear /
/// switch-to-2D / save actions (right). Translucent dark chrome reads on any
/// camera scene.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.onClose,
    required this.onSwitch2d,
    this.onSave,
    this.onClear,
    this.saving = false,
  });

  final String title;
  final VoidCallback onClose;
  final VoidCallback onSwitch2d;
  final Future<void> Function()? onSave;
  final VoidCallback? onClear;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              _CircleButton(icon: Icons.close, onTap: onClose),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                  ),
                ),
              ),
              if (onClear != null) ...[
                _CircleButton(icon: Iconsax.broom, onTap: onClear),
                const SizedBox(width: 10),
              ],
              _PillButton(icon: Iconsax.camera, label: '2D', onTap: onSwitch2d),
              const SizedBox(width: 10),
              _CircleButton(icon: Icons.save_alt, busy: saving, onTap: onSave),
            ],
          ),
        ),
      ),
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({required this.icon, this.onTap, this.busy = false});

  final IconData icon;
  final FutureOr<void> Function()? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? () => onTap!() : null,
        child: SizedBox(
          width: 42,
          height: 42,
          child: busy
              ? const Padding(
                  padding: EdgeInsets.all(11),
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Icon(
                  icon,
                  color: enabled
                      ? Colors.white
                      : Colors.white.withValues(alpha: 0.4),
                  size: 21,
                ),
        ),
      ),
    );
  }
}

class _PillButton extends StatelessWidget {
  const _PillButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(21),
      child: InkWell(
        borderRadius: BorderRadius.circular(21),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: SizedBox(
            height: 42,
            child: Row(
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bottom instruction chip (place hint before the set lands, manipulation hint
/// after).
class _HintPill extends StatelessWidget {
  const _HintPill({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: AppFonts.body,
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

/// Shown when the set has no approved 3D models — AR can't place anything, so
/// offer the 2D sticker overlay (which only needs photos).
class _NoModelsView extends StatelessWidget {
  const _NoModelsView({required this.onUse2d, required this.onClose});

  final VoidCallback onUse2d;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Iconsax.d_cube_scan,
                    color: Colors.white70,
                    size: 48,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    tr('product.set_ar_unsupported'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: onUse2d,
                    icon: const Icon(Iconsax.camera, size: 18),
                    label: Text(tr('product.set_2d_title')),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: _CircleButton(icon: Icons.close, onTap: onClose),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
