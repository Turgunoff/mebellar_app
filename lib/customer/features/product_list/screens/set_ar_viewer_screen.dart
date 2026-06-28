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
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
// vector_math also declares a `Colors` symbol — hide it so Material's `Colors`
// (and const colour literals) resolve unambiguously.
import 'package:vector_math/vector_math_64.dart' hide Colors;

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import 'set_sticker_screen.dart';

/// Brand terracotta — the active-dock / selected-node accent. Fixed in both
/// themes (this screen is its own immersive camera surface, never theme-driven).
const Color _kAccent = Color(0xFFC27A5F);

/// One model-bearing piece placed in the scene: its node, the anchor it rides,
/// and the source piece (for the label shown when it's tapped/selected). A
/// "place all" batch shares one anchor across several nodes; a dock-driven add
/// gives each node its own anchor.
class _PlacedNode {
  const _PlacedNode({
    required this.node,
    required this.anchor,
    required this.piece,
  });

  final ARNode node;
  final ARAnchor anchor;
  final ArSetPiece piece;
}

/// True native multi-object AR placement for a whole furniture SET / garnitur.
/// One ARCore (Android, Filament) / ARKit (iOS) session detects the floor; the
/// first floor tap drops every model-bearing piece side-by-side as separate
/// anchored nodes (a fast "see the whole set" start), and from there the buyer
/// can keep adding pieces one-by-one from the bottom dock, drag/rotate any node
/// independently (handlePans / handleRotation), and tap a placed node to select
/// and delete it. Models are placed true-to-size from each piece's real cm
/// dimensions (`ar_flutter_plugin_plus` treats a `.glb` unit as one metre, and
/// Meshy normalises every mesh into a unit cube, so cm/100 per axis restores the
/// real footprint — same normalisation as the model-viewer).
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

  /// Every placed node, keyed by its unique node name (the key `onNodeTap`
  /// returns). The single source of truth for what's in the scene.
  final Map<String, _PlacedNode> _placed = {};

  /// Monotonic suffix so re-placing / adding never collides node names.
  int _placeCounter = 0;

  /// The dock piece armed to drop on the next floor tap. Null → a floor tap
  /// either places the whole set (nothing placed yet) or is ignored (use the
  /// dock to add more).
  ArSetPiece? _activePiece;

  /// The placed node the buyer tapped — shows its delete/deselect control.
  String? _selectedNodeName;

  bool _saving = false;

  /// Only model-bearing pieces are 3D-placeable; image-only members are skipped
  /// here (they remain placeable in 2D sticker mode).
  late final List<ArSetPiece> _placeable = widget.pieces
      .where((p) => p.hasModel)
      .toList(growable: false);

  bool get _hasPlaced => _placed.isNotEmpty;

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

    final bottomInset = MediaQuery.of(context).padding.bottom;
    final selected = _selectedNodeName == null
        ? null
        : _placed[_selectedNodeName];

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
            onSave: _hasPlaced && !_saving ? _save : null,
            onClear: _hasPlaced ? _clearAll : null,
            saving: _saving,
          ),
          // A tapped node shows its own delete control in place of the hint;
          // otherwise a contextual hint sits just above the dock.
          Positioned(
            left: 20,
            right: 20,
            bottom: bottomInset + 116,
            child: selected != null
                ? _SelectedNodeCard(
                    name: selected.piece.name,
                    onDelete: _deleteSelected,
                    onDeselect: () =>
                        setState(() => _selectedNodeName = null),
                  )
                : _HintPill(text: _hintText()),
          ),
          // In-AR dock: tap a piece to arm it, then tap the floor to drop it.
          _DockBar(
            pieces: _placeable,
            activeId: _activePiece?.id,
            onPick: _setActivePiece,
          ),
        ],
      ),
    );
  }

  String _hintText() {
    if (_activePiece != null) return tr('product.set_ar_tap_floor');
    if (!_hasPlaced) return tr('product.set_ar_place_hint');
    return tr('product.set_ar_add_hint');
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
    objects.onNodeTap = _onNodeTapped;
  }

  Future<void> _onPlaneTap(List<ARHitTestResult> hits) async {
    final plane = _firstPlane(hits);
    if (plane == null) return;

    final active = _activePiece;
    if (active != null) {
      // Dock-armed → drop that one piece at the tapped spot (cumulative add).
      await _placeSingle(active, plane);
      return;
    }
    if (!_hasPlaced) {
      // First tap, nothing armed → drop the whole set so the buyer sees it all.
      await _placeAll(plane);
    }
    // Already placed with nothing armed → ignore; the dock drives further adds.
  }

  ARHitTestResult? _firstPlane(List<ARHitTestResult> hits) {
    for (final h in hits) {
      if (h.type == ARHitTestResultType.plane) return h;
    }
    return null;
  }

  /// Drops every placeable piece in one centred row along the anchor's local X,
  /// all sharing a single anchor — the "whole set at once" start.
  Future<void> _placeAll(ARHitTestResult plane) async {
    final objects = _objects;
    final anchors = _anchors;
    if (objects == null || anchors == null) return;

    final anchor = ARPlaneAnchor(transformation: plane.worldTransform);
    if (await anchors.addAnchor(anchor) != true) return;

    final widthsM = _placeable
        .map((p) => ((p.widthCm ?? 60) / 100).clamp(0.2, 3.0))
        .toList(growable: false);
    const gap = 0.15;
    final total =
        widthsM.fold<double>(0, (a, b) => a + b) + gap * (widthsM.length - 1);
    var cursor = -total / 2;
    var any = false;

    for (var i = 0; i < _placeable.length; i++) {
      final piece = _placeable[i];
      final half = widthsM[i] / 2;
      final x = cursor + half;
      cursor += widthsM[i] + gap;

      final name = 'piece_${_placeCounter++}';
      final node = ARNode(
        type: NodeType.webGLB,
        uri: piece.glbUrl!,
        name: name,
        scale: arScaleVector3(piece.widthCm, piece.heightCm, piece.depthCm),
        position: Vector3(x, 0, 0),
      );
      try {
        if (await objects.addNode(node, planeAnchor: anchor) == true) {
          _placed[name] = _PlacedNode(node: node, anchor: anchor, piece: piece);
          any = true;
        }
      } catch (e, st) {
        appLog.handle(e, st, '[set-ar] addNode failed');
      }
    }

    if (any) {
      if (mounted) setState(() {});
    } else {
      await anchors.removeAnchor(anchor);
    }
  }

  /// Drops a single armed piece at the tapped spot, each on its own anchor so it
  /// can be deleted independently later.
  Future<void> _placeSingle(ArSetPiece piece, ARHitTestResult plane) async {
    final objects = _objects;
    final anchors = _anchors;
    final glb = piece.glbUrl;
    if (objects == null || anchors == null || glb == null) return;

    final anchor = ARPlaneAnchor(transformation: plane.worldTransform);
    if (await anchors.addAnchor(anchor) != true) return;

    final name = 'piece_${_placeCounter++}';
    final node = ARNode(
      type: NodeType.webGLB,
      uri: glb,
      name: name,
      scale: arScaleVector3(piece.widthCm, piece.heightCm, piece.depthCm),
      position: Vector3(0, 0, 0),
    );
    try {
      if (await objects.addNode(node, planeAnchor: anchor) == true) {
        _placed[name] = _PlacedNode(node: node, anchor: anchor, piece: piece);
        if (mounted) setState(() {});
      } else {
        await anchors.removeAnchor(anchor);
      }
    } catch (e, st) {
      appLog.handle(e, st, '[set-ar] addNode failed');
      await anchors.removeAnchor(anchor);
    }
  }

  /// `onNodeTap` returns the names of nodes under the tap. Select the first one
  /// we own so its delete control appears; arming a placement is cleared so the
  /// next floor tap doesn't accidentally add while the buyer adjusts.
  void _onNodeTapped(List<String> names) {
    String? hit;
    for (final n in names) {
      if (_placed.containsKey(n)) {
        hit = n;
        break;
      }
    }
    if (hit == null || !mounted) return;
    setState(() {
      _selectedNodeName = hit;
      _activePiece = null;
    });
  }

  /// Arms / disarms a dock piece for the next floor tap. Re-tapping the armed
  /// piece disarms it; arming always drops any node selection.
  void _setActivePiece(ArSetPiece piece) {
    setState(() {
      _activePiece = _activePiece?.id == piece.id ? null : piece;
      _selectedNodeName = null;
    });
  }

  /// Removes just the selected node. Its anchor is dropped only when no sibling
  /// node still rides it (the "place all" batch shares one anchor).
  void _deleteSelected() {
    final name = _selectedNodeName;
    if (name == null) return;
    final placed = _placed.remove(name);
    if (placed == null) return;
    _objects?.removeNode(placed.node);
    final anchorStillUsed = _placed.values.any(
      (p) => identical(p.anchor, placed.anchor),
    );
    if (!anchorStillUsed) _anchors?.removeAnchor(placed.anchor);
    if (mounted) setState(() => _selectedNodeName = null);
  }

  void _clearAll() {
    final objects = _objects;
    final anchors = _anchors;
    final seenAnchors = <ARAnchor>{};
    for (final p in _placed.values) {
      objects?.removeNode(p.node);
      seenAnchors.add(p.anchor);
    }
    for (final a in seenAnchors) {
      anchors?.removeAnchor(a);
    }
    _placed.clear();
    if (mounted) {
      setState(() {
        _selectedNodeName = null;
        _activePiece = null;
      });
    }
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
      appLog.handle(e, st, '[set-ar] snapshot save failed');
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

/// Bottom instruction chip (place hint before the set lands, add/manipulate hint
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

/// Floating control for a tapped node — its name plus a delete action and a
/// deselect (✕). Drag and two-finger rotate already work on the node itself;
/// this only adds the per-node delete the gestures can't.
class _SelectedNodeCard extends StatelessWidget {
  const _SelectedNodeCard({
    required this.name,
    required this.onDelete,
    required this.onDeselect,
  });

  final String name;
  final VoidCallback onDelete;
  final VoidCallback onDeselect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.62),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kAccent.withValues(alpha: 0.8), width: 1.2),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: AppFonts.body,
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: const Color(0xFFD9534F),
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onDelete,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Iconsax.trash, color: Colors.white, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      tr('product.set_ar_node_delete'),
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            onPressed: onDeselect,
            icon: const Icon(Icons.close, color: Colors.white70, size: 20),
            splashRadius: 20,
          ),
        ],
      ),
    );
  }
}

/// In-AR piece dock pinned to the bottom: every placeable piece as a tappable
/// thumbnail. Tapping arms the piece (accent ring) for the next floor tap.
class _DockBar extends StatelessWidget {
  const _DockBar({
    required this.pieces,
    required this.activeId,
    required this.onPick,
  });

  final List<ArSetPiece> pieces;
  final String? activeId;
  final ValueChanged<ArSetPiece> onPick;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.14)),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: pieces.length,
                separatorBuilder: (_, _) => const SizedBox(width: 12),
                itemBuilder: (context, i) => _DockChip(
                  piece: pieces[i],
                  selected: pieces[i].id == activeId,
                  onTap: () => onPick(pieces[i]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One ~58px rounded thumbnail + name in the dock; an accent ring marks the
/// armed piece. Pieces with no photo fall back to a cube glyph.
class _DockChip extends StatelessWidget {
  const _DockChip({
    required this.piece,
    required this.selected,
    required this.onTap,
  });

  final ArSetPiece piece;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? _kAccent : Colors.white70;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 58,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: selected
                      ? _kAccent
                      : Colors.white.withValues(alpha: 0.25),
                  width: selected ? 2.4 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: piece.hasImage
                  ? CachedNetworkImage(
                      imageUrl: piece.imageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, _, _) => Icon(
                        Iconsax.d_cube_scan,
                        color: fg,
                        size: 20,
                      ),
                    )
                  : Icon(Iconsax.d_cube_scan, color: fg, size: 20),
            ),
            const SizedBox(height: 4),
            Text(
              piece.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: AppFonts.body,
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: selected ? _kAccent : Colors.white,
              ),
            ),
          ],
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
