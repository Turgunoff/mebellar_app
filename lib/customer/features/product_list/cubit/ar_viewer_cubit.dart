import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../shared/ar/ar_scale.dart';
import '../../../../shared/ar/ar_set_piece.dart';
import '../../../../shared/ar/glb_cache_manager.dart';
import '../../../../shared/models/ar_part.dart';
import '../../../../shared/models/product_model.dart';
import '../../../../shared/models/product_set.dart';
import '../../../../shared/repositories/product_data_source.dart';
import '../../../../shared/repositories/woody_set_repository.dart';

/// Lifecycle of the model currently shown in the 3D viewer:
/// - [downloading] — the `.glb` is being fetched to the file cache; no model is
///   mounted yet, the loading overlay covers the stage.
/// - [rendering]   — the file is resolved and `<model-viewer>` is mounting /
///   decoding it; the overlay stays up until it reports `load`.
/// - [ready]       — the model is on screen and interactive.
/// - [failed]      — the load gave up (download fell back AND model-viewer
///   errored, or the watchdog elapsed); the retry surface is shown.
enum ArViewerPhase { downloading, rendering, ready, failed }

/// One togglable model in the viewer — a single product, or one member of a
/// furniture set (garnitur). Carries everything `<model-viewer>` needs to render
/// and AR-place it true-to-size.
class ArViewerPart extends Equatable {
  const ArViewerPart({
    required this.id,
    required this.name,
    required this.glbUrl,
    this.usdzUrl,
    this.posterUrl,
    this.widthCm,
    this.heightCm,
    this.depthCm,
  });

  final String id;
  final String name;

  /// Approved `.glb` URL. Empty only defensively (the viewer is opened for
  /// approved-model products); an empty url short-circuits to [ArViewerPhase.failed].
  final String glbUrl;

  /// iOS AR Quick Look source (`.usdz`); null falls back to the in-page WebGL view.
  final String? usdzUrl;

  /// 2D photo used as the model-viewer loading poster + the selector thumbnail.
  final String? posterUrl;

  final num? widthCm;
  final num? heightCm;
  final num? depthCm;

  bool get hasModel => glbUrl.isNotEmpty;

  /// `<model-viewer>` `scale` string (`x y z` metre multipliers) when all real
  /// dimensions are known, else null → the model renders unscaled.
  String? get scaleString => arScaleString(widthCm, heightCm, depthCm);

  factory ArViewerPart.fromProduct(ProductModel p) => ArViewerPart(
    id: p.id,
    name: p.name,
    glbUrl: p.arModelUrl ?? '',
    usdzUrl: p.usdzUrl,
    posterUrl: p.thumbnail,
    widthCm: p.widthCm,
    heightCm: p.heightCm,
    depthCm: p.depthCm,
  );

  /// One of a product's own per-part models (a garnitur's bed, wardrobe, …).
  /// Parts carry no thumbnail, so the selector chip falls back to a cube glyph.
  factory ArViewerPart.fromArPart(ArPart p, {String? posterUrl}) =>
      ArViewerPart(
        id: p.id,
        name: p.label,
        glbUrl: p.arModelUrl ?? '',
        usdzUrl: p.usdzUrl,
        posterUrl: posterUrl,
        widthCm: p.widthCm,
        heightCm: p.heightCm,
        depthCm: p.depthCm,
      );

  /// Maps this togglable model to the native multi-object placement value type.
  /// Lets the inline viewer hand its whole part list (a garnitur's bed/wardrobe/
  /// dresser, OR a set's sibling products) to [SetArViewerScreen] so every piece
  /// is placed together — `<model-viewer>`'s OS AR can only push one `.glb`, so
  /// a true multi-object scene must go through the native plugin instead.
  ArSetPiece toSetPiece() => ArSetPiece(
    id: id,
    name: name,
    glbUrl: glbUrl.isNotEmpty ? glbUrl : null,
    imageUrl: posterUrl,
    widthCm: widthCm,
    heightCm: heightCm,
    depthCm: depthCm,
  );

  @override
  List<Object?> get props => [
    id,
    name,
    glbUrl,
    usdzUrl,
    posterUrl,
    widthCm,
    heightCm,
    depthCm,
  ];
}

class ArViewerState extends Equatable {
  const ArViewerState({
    required this.parts,
    required this.selectedIndex,
    required this.phase,
    required this.src,
    required this.renderToken,
  });

  factory ArViewerState.initial(ArViewerPart first) => ArViewerState(
    parts: [first],
    selectedIndex: 0,
    phase: ArViewerPhase.downloading,
    src: null,
    renderToken: 0,
  );

  /// Every togglable model, in display order. A single-element list renders a
  /// plain viewer with no selector.
  final List<ArViewerPart> parts;

  final int selectedIndex;
  final ArViewerPhase phase;

  /// Resolved source for the selected part — a `file://` path (cached) or, as a
  /// fallback, the remote URL. Null only while [phase] is [ArViewerPhase.downloading].
  final String? src;

  /// Bumped on every part switch / retry. Used as the `<model-viewer>` widget
  /// key so Flutter tears down the previous WebView (disposing its WebGL
  /// context + proxy) and mounts a fresh one for the new model — the clean
  /// hand-off that prevents leaking the old model.
  final int renderToken;

  ArViewerPart get selectedPart => parts[selectedIndex];
  bool get hasMultipleParts => parts.length > 1;
  bool get isReady => phase == ArViewerPhase.ready;
  bool get isFailed => phase == ArViewerPhase.failed;

  /// `<model-viewer>` is mounted whenever a source is resolved — i.e. any phase
  /// except [ArViewerPhase.downloading], where there is nothing to show yet.
  bool get showModel => src != null && phase != ArViewerPhase.downloading;

  ArViewerState copyWith({
    List<ArViewerPart>? parts,
    int? selectedIndex,
    ArViewerPhase? phase,
    int? renderToken,
    String? src,
    bool clearSrc = false,
  }) => ArViewerState(
    parts: parts ?? this.parts,
    selectedIndex: selectedIndex ?? this.selectedIndex,
    phase: phase ?? this.phase,
    renderToken: renderToken ?? this.renderToken,
    src: clearSrc ? null : (src ?? this.src),
  );

  @override
  List<Object?> get props => [parts, selectedIndex, phase, src, renderToken];
}

/// Drives the buyer 3D / AR viewer: which part is on screen, the file-cached
/// source for it, and the load lifecycle. Switching parts resolves the new
/// `.glb` from the on-disk cache (instant) or downloads it once (overlay), then
/// remounts `<model-viewer>` against a `file://` source so there are never
/// redundant network fetches for an already-seen model.
class ArViewerCubit extends Cubit<ArViewerState> {
  ArViewerCubit({
    required ProductModel product,
    required GlbCacheService cache,
    WoodySetRepository? setRepository,
    ProductDataSource? productDataSource,
  }) : _cache = cache,
       _setRepo = setRepository,
       _dataSource = productDataSource,
       _productId = product.id,
       _setId = product.hasSet ? product.setId : null,
       _productParts = product.arParts,
       _posterUrl = product.thumbnail,
       super(ArViewerState.initial(ArViewerPart.fromProduct(product))) {
    _bootstrap();
  }

  final GlbCacheService _cache;
  final WoodySetRepository? _setRepo;
  final ProductDataSource? _dataSource;
  final String _productId;
  final String? _setId;

  /// This product's own per-part models (a garnitur listing's bed, wardrobe,
  /// …). When ≥2 carry a model, the viewer toggles between them — taking
  /// precedence over set-member hydration. Populated from the opener's product
  /// or refreshed from catalog detail when the list row omitted `ar_parts`.
  List<ArPart> _productParts;

  /// The product photo, reused as the poster for every part chip (parts have no
  /// thumbnail of their own).
  final String? _posterUrl;

  /// Monotonic guard so only the most recent selection's async resolution may
  /// emit — a fast tap-through of the selector can't let an earlier (slower)
  /// download land on top of a later one.
  int _loadToken = 0;

  Future<void> _bootstrap() async {
    await _refreshProductArParts();
    await _load(0);
    // A multi-part product (a garnitur listing with its own bed/wardrobe/…
    // models) drives the toggle directly. Only when the product isn't itself
    // multi-part do we fall back to set-member hydration (sibling products).
    if (_hydrateFromProductParts()) return;
    final setId = _setId;
    if (setId != null && _setRepo != null) await _hydrateSet(setId);
  }

  /// `ar_parts` is detail-only — list/feed rows never carry it. Refresh from
  /// catalog detail when the opener passed a shallow product so garnitur buyers
  /// get the same part toggle the seller preview has.
  Future<void> _refreshProductArParts() async {
    if (_productParts.isNotEmpty) return;
    final ds = _dataSource;
    if (ds == null) return;
    try {
      final detail = await ds.getById(_productId);
      if (!isClosed && detail.arParts.isNotEmpty) {
        _productParts = detail.arParts;
      }
    } catch (e, st) {
      appLog.handle(e, st, '[ar-viewer] product detail refresh failed');
    }
  }

  /// Builds the toggle from this product's own per-part models. Returns true
  /// when it produced a multi-part viewer (so the caller skips set hydration).
  /// The part matching the already-loaded primary stays selected, so the model
  /// on screen never flickers.
  bool _hydrateFromProductParts() {
    if (isClosed) return false;
    final parts = <ArViewerPart>[
      for (final p in _productParts)
        if (p.hasModel) ArViewerPart.fromArPart(p, posterUrl: _posterUrl),
    ];
    if (parts.length < 2) return false;
    final selected = state.selectedPart;
    var index = parts.indexWhere((p) => p.glbUrl == selected.glbUrl);
    if (index < 0) {
      parts.insert(0, selected);
      index = 0;
    }
    emit(state.copyWith(parts: parts, selectedIndex: index));
    return true;
  }

  /// Pulls the sibling set members (each an approved-model product) so the buyer
  /// can toggle through every piece of the garnitur in one viewer. The tapped
  /// product stays selected. Best-effort: a fetch failure (or a set with <2
  /// model-bearing members) simply leaves the single-part viewer intact.
  Future<void> _hydrateSet(String setId) async {
    SetDetail? set;
    try {
      set = await _setRepo!.fetchSet(setId);
    } catch (e, st) {
      appLog.handle(e, st, '[ar-viewer] set fetch failed');
    }
    if (set == null || isClosed) return;

    final selected = state.selectedPart;
    final parts = <ArViewerPart>[
      for (final p in set.items)
        if (p.hasAr) ArViewerPart.fromProduct(p),
    ];
    if (parts.length < 2) return; // nothing extra to toggle between

    var index = parts.indexWhere((p) => p.id == selected.id);
    if (index < 0) {
      // The opened product wasn't in the returned set (stale data) — keep it as
      // the selected entry so the viewer never loses the model already on screen.
      parts.insert(0, selected);
      index = 0;
    }
    emit(state.copyWith(parts: parts, selectedIndex: index));
  }

  /// Switch the visible model to [index]. A re-tap of the already-ready part is
  /// a no-op (no flicker); otherwise the new part is resolved from cache or
  /// downloaded.
  Future<void> selectPart(int index) async {
    if (index < 0 || index >= state.parts.length) return;
    if (index == state.selectedIndex && state.phase == ArViewerPhase.ready) {
      return;
    }
    await _load(index);
  }

  Future<void> _load(int index) async {
    final part = state.parts[index];
    final token = ++_loadToken;

    // No model URL → nothing to render; show the retry/error surface rather
    // than handing model-viewer an empty source.
    if (!part.hasModel) {
      emit(
        state.copyWith(
          selectedIndex: index,
          phase: ArViewerPhase.failed,
          renderToken: token,
          clearSrc: true,
        ),
      );
      return;
    }

    final cached = await _cache.peek(part.glbUrl);
    if (token != _loadToken || isClosed) return;

    if (cached != null) {
      // Already on disk → render straight from file:// with no download flash.
      emit(
        state.copyWith(
          selectedIndex: index,
          phase: ArViewerPhase.rendering,
          src: cached,
          renderToken: token,
        ),
      );
      return;
    }

    // Not cached → cover the stage with the overlay while it downloads once.
    emit(
      state.copyWith(
        selectedIndex: index,
        phase: ArViewerPhase.downloading,
        renderToken: token,
        clearSrc: true,
      ),
    );
    final resolved = await _cache.resolve(part.glbUrl);
    if (token != _loadToken || isClosed) return;
    emit(state.copyWith(phase: ArViewerPhase.rendering, src: resolved));
  }

  /// `<model-viewer>` fired `load` — the model is on screen; reveal the controls.
  void onModelRendered() {
    if (state.phase == ArViewerPhase.rendering) {
      emit(state.copyWith(phase: ArViewerPhase.ready));
    }
  }

  /// `<model-viewer>` fired `error` / the load watchdog elapsed — show the retry
  /// surface. Ignored once a model is already ready (a late stray event).
  void onModelFailed() {
    if (state.phase != ArViewerPhase.ready) {
      emit(state.copyWith(phase: ArViewerPhase.failed));
    }
  }

  /// Re-attempt the current part (the overlay's retry button).
  Future<void> retry() => _load(state.selectedIndex);
}
