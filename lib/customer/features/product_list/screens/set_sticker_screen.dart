import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show Uint8List, compute;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/talker.dart';
import '../../../../core/theme/app_fonts.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import '../../home/widgets/premium/premium_tokens.dart';

/// One placed sticker on the room: the source piece plus a mutable transform the
/// buyer drives with one combined pan/scale/rotate gesture. Mutable on purpose —
/// the State edits these in place during a drag rather than rebuilding the list.
class _Sticker {
  _Sticker(this.piece);

  final ArSetPiece piece;

  /// Offset of the sticker's centre from the layer centre, in logical pixels.
  Offset translation = Offset.zero;
  double scale = 1;
  double rotation = 0;

  /// Whether the delete chip shows; set on tap, cleared when another is tapped.
  bool selected = false;

  // Captured at gesture start so an interactive update composes against the
  // value the buyer began from, not the live (already-mutating) one.
  late Offset _baseTranslation;
  late double _baseScale;
  late double _baseRotation;
}

/// Universal "place the whole set in your room" fallback for devices without AR
/// depth tracking (Phase 3). A live camera feed is the background; the buyer
/// drops flat PNG stickers of the set's pieces on top and independently drags,
/// pinch-scales and two-finger-rotates each one to match their room's
/// perspective. No ARCore, no 3D — pure Flutter widgets over a camera texture,
/// so the sticker layer (unlike a model-viewer/camera platform view) is captured
/// straight out of a [RepaintBoundary] for the save-the-room shot.
class SetStickerScreen extends StatefulWidget {
  const SetStickerScreen({
    super.key,
    required this.pieces,
    required this.setName,
  });

  final List<ArSetPiece> pieces;
  final String setName;

  @override
  State<SetStickerScreen> createState() => _SetStickerScreenState();
}

class _SetStickerScreenState extends State<SetStickerScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  Future<void>? _initFuture;

  /// Fatal camera-setup error (no permission / no camera) — takes over the
  /// screen. [_permanentlyDenied] adds an "open settings" affordance.
  String? _error;
  bool _permanentlyDenied = false;

  /// Guards against a second [_setup] running while one is in flight — e.g. the
  /// `resumed` lifecycle event that fires when the iOS permission alert (itself
  /// an app-inactive transition) is dismissed would otherwise start a duplicate.
  bool _settingUp = false;

  bool _saving = false;

  /// Captures the pure-Flutter sticker layer (not the camera texture) as a
  /// transparent PNG for the save composite.
  final GlobalKey _overlayKey = GlobalKey();

  final List<_Sticker> _stickers = [];

  /// Set members that can actually be placed (have a 2D photo). Computed once.
  late final List<ArSetPiece> _placeable = widget.pieces
      .where((p) => p.hasImage)
      .toList(growable: false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initFuture = _setup();
  }

  Future<void> _setup() async {
    if (_settingUp) return;
    _settingUp = true;
    try {
      // The native OS popup fires here on the first request. iOS reports a
      // never-asked permission as `denied` until the alert is answered, so we
      // only treat `permanentlyDenied`/`restricted` as the "go to Settings"
      // state — a plain denial just leaves the bare error, re-askable later.
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) {
          setState(() {
            _permanentlyDenied =
                status.isPermanentlyDenied || status.isRestricted;
            _error = tr('product.ar_fallback_camera_error');
          });
        }
        return;
      }
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) {
          setState(() => _error = tr('product.ar_fallback_camera_error'));
        }
        return;
      }
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        back,
        ResolutionPreset.high,
        enableAudio: false,
      );
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _controller = controller);
    } catch (e, st) {
      talker.handle(e, st, '[set-sticker] camera setup failed');
      if (mounted) {
        setState(() => _error = tr('product.ar_fallback_camera_error'));
      }
    } finally {
      _settingUp = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      final c = _controller;
      if (c != null && c.value.isInitialized) {
        c.dispose();
        _controller = null;
      }
    } else if (state == AppLifecycleState.resumed) {
      // Re-arm the camera on resume. This covers both a normal app background
      // and — crucially — a return from the OS Settings page after the buyer
      // flipped the camera permission on: we clear any prior permission error
      // first so the screen recovers straight into the live camera instead of
      // stranding the user on the "open Settings" surface.
      if (mounted && _controller == null && !_settingUp) {
        setState(() {
          _error = null;
          _permanentlyDenied = false;
          _initFuture = _setup();
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  void _addSticker(ArSetPiece piece) {
    setState(() {
      for (final s in _stickers) {
        s.selected = false;
      }
      _stickers.add(_Sticker(piece)..selected = true);
    });
  }

  void _selectSticker(_Sticker sticker) {
    setState(() {
      for (final s in _stickers) {
        s.selected = false;
      }
      sticker.selected = true;
      // Bring to front so a freshly-tapped sticker drags above its neighbours.
      _stickers
        ..remove(sticker)
        ..add(sticker);
    });
  }

  void _removeSticker(_Sticker sticker) {
    setState(() => _stickers.remove(sticker));
  }

  void _clearAll() {
    setState(_stickers.clear);
  }

  /// Saves "the set in your room": flattens the transparent sticker layer over a
  /// still grabbed from the live camera, watermarks it, and writes it to the
  /// gallery. The camera is a platform view, so it can't ride the
  /// [RepaintBoundary] (it captures black) — the stickers are pure Flutter
  /// widgets that DO capture, so the two layers are grabbed separately and
  /// merged.
  Future<void> _saveToGallery() async {
    if (_saving) return;
    final cam = _controller;
    if (cam == null || !cam.value.isInitialized || _stickers.isEmpty) return;
    setState(() => _saving = true);
    try {
      final overlayPng = await _captureOverlay();

      // The room behind it, from a single camera still (flash forced off so the
      // capture doesn't blast the scene). A failed grab degrades to a black
      // backdrop in the compositor rather than aborting the save.
      Uint8List? cameraBytes;
      try {
        await cam.setFlashMode(FlashMode.off);
        final shot = await cam.takePicture();
        cameraBytes = await shot.readAsBytes();
      } catch (e, st) {
        talker.handle(e, st, '[set-sticker] camera grab failed');
      }

      final framed = await compute(_composeRoomShot, (cameraBytes, overlayPng));
      if (!await Gal.requestAccess()) {
        _toast(tr('product.ar_save_denied'));
        return;
      }
      await Gal.putImageBytes(framed, name: 'woody_ar_set_${_slug()}');
      _toast(tr('product.ar_saved'));
    } on GalException catch (e) {
      _toast(
        e.type == GalExceptionType.accessDenied
            ? tr('product.ar_save_denied')
            : tr('product.ar_save_failed'),
      );
    } catch (e, st) {
      talker.handle(e, st, '[set-sticker] save failed');
      _toast(tr('product.ar_save_failed'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Rasterises the sticker layer at device pixel ratio to a transparent PNG.
  Future<Uint8List> _captureOverlay() async {
    final boundary =
        _overlayKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw StateError('overlay capture returned no bytes');
      return data.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// A stable-ish file suffix from the set name (no DateTime in scope-free
  /// utils); collisions just overwrite, which is fine for a share artefact.
  String _slug() =>
      widget.setName.replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_').toLowerCase();

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: FutureBuilder<void>(
        future: _initFuture,
        builder: (context, snapshot) {
          if (_error != null) {
            return _ErrorView(
              message: _error!,
              showSettings: _permanentlyDenied,
              onClose: () => Navigator.of(context).maybePop(),
            );
          }
          final c = _controller;
          if (c == null || !c.value.isInitialized) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.white),
            );
          }
          final canSave = _stickers.isNotEmpty;
          return Stack(
            fit: StackFit.expand,
            children: [
              _FullBleedCamera(controller: c),

              // The sticker layer — pure Flutter widgets, so this RepaintBoundary
              // captures them (with the camera showing through transparently) for
              // the save composite. A bare tap on empty space deselects.
              RepaintBoundary(
                key: _overlayKey,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: () {
                    if (_stickers.any((s) => s.selected)) {
                      setState(() {
                        for (final s in _stickers) {
                          s.selected = false;
                        }
                      });
                    }
                  },
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      for (final sticker in _stickers)
                        _PlacedSticker(
                          key: ObjectKey(sticker),
                          sticker: sticker,
                          onSelect: () => _selectSticker(sticker),
                          onDelete: () => _removeSticker(sticker),
                          onChanged: () => setState(() {}),
                        ),
                    ],
                  ),
                ),
              ),

              if (_stickers.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 48),
                    child: Text(
                      tr('product.set_2d_empty'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: AppFonts.body,
                        color: Colors.white,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                        shadows: [Shadow(color: Colors.black54, blurRadius: 8)],
                      ),
                    ),
                  ),
                )
              else
                const _InstructionPill(),

              _TopBar(
                onClose: () => Navigator.of(context).maybePop(),
                onSave: _saveToGallery,
                saving: _saving,
                canSave: canSave,
              ),

              _PickerBar(
                pieces: _placeable,
                onPick: _addSticker,
                onClear: _stickers.isEmpty ? null : _clearAll,
              ),
            ],
          );
        },
      ),
    );
  }
}

/// A single placed sticker: a [Transform] (translate → rotate → scale) wrapping
/// the piece's photo, driven by one combined pan/scale/rotate scale-gesture. The
/// delete chip rides in the (unscaled, unrotated) selection layer so it stays a
/// fixed, tappable size regardless of how small or rotated the sticker is.
class _PlacedSticker extends StatelessWidget {
  const _PlacedSticker({
    super.key,
    required this.sticker,
    required this.onSelect,
    required this.onDelete,
    required this.onChanged,
  });

  final _Sticker sticker;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  /// Pumped on every transform tick so the parent State repaints the layer.
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final baseWidth = media.size.width * 0.38;

    return Center(
      // Centre is the transform origin; [translation] then offsets from there.
      child: Transform.translate(
        offset: sticker.translation,
        child: Transform.rotate(
          angle: sticker.rotation,
          child: Transform.scale(
            scale: sticker.scale,
            child: GestureDetector(
              onTap: onSelect,
              onScaleStart: (_) {
                sticker._baseTranslation = sticker.translation;
                sticker._baseScale = sticker.scale;
                sticker._baseRotation = sticker.rotation;
                if (!sticker.selected) onSelect();
              },
              onScaleUpdate: (details) {
                // One gesture handles all three: focalPointDelta is the pan in
                // screen space, details.scale the pinch factor against the
                // gesture's start, details.rotation the two-finger twist.
                sticker
                  ..translation =
                      sticker._baseTranslation + details.focalPointDelta
                  ..scale = (sticker._baseScale * details.scale).clamp(0.2, 4.0)
                  ..rotation = sticker._baseRotation + details.rotation;
                onChanged();
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: baseWidth,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.35),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                          spreadRadius: -6,
                        ),
                      ],
                    ),
                    child: CachedNetworkImage(
                      imageUrl: sticker.piece.imageUrl!,
                      fit: BoxFit.contain,
                      errorWidget: (_, _, _) => const SizedBox.shrink(),
                    ),
                  ),
                  if (sticker.selected)
                    Positioned(
                      top: -10,
                      right: -10,
                      child: _DeleteChip(onTap: onDelete),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small circular X near a selected sticker's top-right that removes it.
class _DeleteChip extends StatelessWidget {
  const _DeleteChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.7),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 1.5),
        ),
        child: const Icon(Icons.close, color: Colors.white, size: 16),
      ),
    );
  }
}

/// Fills the screen with the live feed (BoxFit.cover semantics) — no letterbox
/// bars on any device ratio. Mirrors the seller scan camera's full-bleed math.
class _FullBleedCamera extends StatelessWidget {
  const _FullBleedCamera({required this.controller});
  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    var scale = size.aspectRatio * controller.value.aspectRatio;
    if (scale < 1) scale = 1 / scale;
    return ClipRect(
      child: Transform.scale(
        scale: scale,
        alignment: Alignment.center,
        child: Center(child: CameraPreview(controller)),
      ),
    );
  }
}

/// Top row: a circular close button (left) and an optional save-to-gallery
/// button (right). Pinned clear of the notch. [onSave] null (e.g. on the error
/// surface) renders close only.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.onClose,
    this.onSave,
    this.saving = false,
    this.canSave = false,
  });

  final VoidCallback onClose;
  final Future<void> Function()? onSave;
  final bool saving;
  final bool canSave;

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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(icon: Icons.close, onTap: onClose),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    tr('product.set_2d_title'),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppFonts.body,
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      shadows: [Shadow(color: Colors.black54, blurRadius: 6)],
                    ),
                  ),
                ),
              ),
              if (onSave != null)
                _CircleButton(
                  icon: Icons.save_alt,
                  busy: saving,
                  onTap: (canSave && !saving) ? onSave : null,
                )
              else
                const SizedBox(width: 42),
            ],
          ),
        ),
      ),
    );
  }
}

/// Translucent dark circular button used in the camera overlay's top bar. A
/// null [onTap] dims the glyph; [busy] swaps in a spinner.
class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.onTap,
    this.busy = false,
  });

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
                  size: 22,
                ),
        ),
      ),
    );
  }
}

/// Bottom instruction chip — the drag/scale/rotate hint, shown once at least one
/// sticker is placed.
class _InstructionPill extends StatelessWidget {
  const _InstructionPill();

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 24,
      right: 24,
      // Sit above the picker bar (which clears the home indicator itself).
      bottom: MediaQuery.of(context).padding.bottom + 132,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            tr('product.set_2d_hint'),
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
      ),
    );
  }
}

/// Bottom picker bar (above the home indicator): the set's placeable pieces as
/// rounded thumbnails. Tapping one adds a fresh centred sticker; a "clear all"
/// action wipes the room.
class _PickerBar extends StatelessWidget {
  const _PickerBar({
    required this.pieces,
    required this.onPick,
    required this.onClear,
  });

  final List<ArSetPiece> pieces;
  final ValueChanged<ArSetPiece> onPick;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: BoxDecoration(
          color: pt.surface.withValues(alpha: 0.92),
          border: Border(top: BorderSide(color: pt.divider)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 88,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: pieces.length,
                      separatorBuilder: (_, _) => const SizedBox(width: 12),
                      itemBuilder: (context, i) => _PickerThumb(
                        piece: pieces[i],
                        onTap: () => onPick(pieces[i]),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: onClear,
                  tooltip: tr('product.set_2d_add'),
                  icon: Icon(
                    Icons.delete_sweep_outlined,
                    color: onClear == null ? pt.greyLight : pt.grey,
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

/// One ~64px rounded thumbnail + name label in the picker bar.
class _PickerThumb extends StatelessWidget {
  const _PickerThumb({required this.piece, required this.onTap});

  final ArSetPiece piece;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 64,
                height: 64,
                color: pt.imageBg,
                child: CachedNetworkImage(
                  imageUrl: piece.imageUrl!,
                  fit: BoxFit.cover,
                  errorWidget: (_, _, _) =>
                      Icon(Icons.chair_outlined, color: pt.greyLight),
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              piece.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: PremiumTokens.body(
                size: 10,
                weight: FontWeight.w600,
                color: pt.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Full-screen camera-error surface (permission denied / no camera). Offers an
/// "open settings" route when the permission was permanently denied.
class _ErrorView extends StatelessWidget {
  const _ErrorView({
    required this.message,
    required this.showSettings,
    required this.onClose,
  });

  final String message;
  final bool showSettings;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.photo_camera_back,
                  color: Colors.white70,
                  size: 44,
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: AppFonts.body,
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
                if (showSettings) ...[
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: openAppSettings,
                    child: Text(tr('product.ar_fallback_open_settings')),
                  ),
                ],
              ],
            ),
          ),
        ),
        _TopBar(onClose: onClose),
      ],
    );
  }
}

/// Runs in a background isolate (via `compute`): composites the captured
/// transparent sticker-layer PNG over the camera room still and stamps a
/// "woody.uz" watermark — the shareable "the set in your room" shot.
///
/// The overlay PNG is the on-screen-size transparent layer, so the room still is
/// BoxFit.cover fitted to it (matching the live preview's centre-crop) before
/// the overlay is drawn 1:1 on top. `bakeOrientation` applies the camera's EXIF
/// rotation first, so a sensor-landscape JPEG doesn't land sideways under the
/// upright stickers. A missing/undecodable still degrades to a black backdrop so
/// a save still works.
Uint8List _composeRoomShot((Uint8List?, Uint8List) data) {
  final (cameraBytes, overlayPng) = data;
  final overlay = img.decodeImage(overlayPng);
  if (overlay == null) return overlayPng;
  final w = overlay.width;
  final h = overlay.height;

  final canvas = img.Image(width: w, height: h);
  final decoded = cameraBytes == null ? null : img.decodeImage(cameraBytes);
  final room = decoded == null ? null : img.bakeOrientation(decoded);
  if (room != null) {
    final scale = math.max(w / room.width, h / room.height);
    final rw = (room.width * scale).round();
    final rh = (room.height * scale).round();
    final resized = img.copyResize(room, width: rw, height: rh);
    final cropped = img.copyCrop(
      resized,
      x: ((rw - w) / 2).round(),
      y: ((rh - h) / 2).round(),
      width: w,
      height: h,
    );
    img.compositeImage(canvas, cropped);
  } else {
    canvas.clear(img.ColorRgb8(0, 0, 0));
  }

  // The overlay PNG is transparent everywhere but the stickers, so it overlays
  // 1:1.
  img.compositeImage(canvas, overlay);
  _stampWoodyWatermark(canvas);
  return img.encodePng(canvas);
}

/// Bottom-right translucent "woody.uz" chip — keeps the mark legible on any
/// room/sticker colour (mirrors the buyer viewer's watermark).
void _stampWoodyWatermark(img.Image canvas) {
  const label = 'woody.uz';
  final font = canvas.width >= 1000 ? img.arial48 : img.arial24;
  final textW = _bitmapTextWidth(font, label);
  final textH = font.lineHeight;
  final margin = (canvas.width * 0.04).round().clamp(16, 56);
  final padX = (textH * 0.55).round();
  final padY = (textH * 0.3).round();
  final tx = canvas.width - margin - textW;
  final ty = canvas.height - margin - textH;

  img.fillRect(
    canvas,
    x1: tx - padX,
    y1: ty - padY,
    x2: tx + textW + padX,
    y2: ty + textH + padY,
    color: img.ColorRgba8(17, 17, 28, 115),
    radius: ((textH + padY * 2) / 2).round(),
  );
  img.drawString(
    canvas,
    label,
    font: font,
    x: tx,
    y: ty,
    color: img.ColorRgba8(255, 255, 255, 240),
  );
}

int _bitmapTextWidth(img.BitmapFont font, String text) {
  var width = 0;
  for (final code in text.codeUnits) {
    final ch = font.characters[code];
    if (ch != null) width += ch.xAdvance;
  }
  return width;
}
