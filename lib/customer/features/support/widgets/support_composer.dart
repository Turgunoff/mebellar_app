import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import '../../../../core/i18n/i18n.dart';
import '../../../../core/logging/talker.dart';
import '../../home/widgets/premium/premium_tokens.dart';

typedef SendTextCallback = Future<void> Function(String text);
typedef SendImageCallback =
    Future<void> Function(Uint8List bytes, String mimeType);
typedef SendAudioCallback =
    Future<void> Function(Uint8List bytes, String contentType, int durationMs);

/// The bottom composer bar — text field, image attach, send button, and a
/// hold-to-record microphone. When the text field is empty the trailing
/// control is the mic (hold to record a voice note); once text is typed it
/// becomes the send button (WhatsApp/Telegram pattern).
class SupportComposer extends StatefulWidget {
  const SupportComposer({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    required this.onSendAudio,
    this.sending = false,
  });

  final SendTextCallback onSendText;
  final SendImageCallback onSendImage;
  final SendAudioCallback onSendAudio;
  final bool sending;

  @override
  State<SupportComposer> createState() => _SupportComposerState();
}

class _SupportComposerState extends State<SupportComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  final _recorder = AudioRecorder();

  bool _hasText = false;
  bool _recording = false;
  bool _cancelled = false;
  String? _recordPath;
  DateTime? _recordStartedAt;
  Timer? _ticker;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    final hasText = _ctrl.text.trim().isNotEmpty;
    if (hasText != _hasText) setState(() => _hasText = hasText);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onTextChanged);
    _ctrl.dispose();
    _focus.dispose();
    _ticker?.cancel();
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _handleSendText() async {
    if (widget.sending) return;
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    await widget.onSendText(text);
  }

  Future<void> _handleAttach() async {
    final source = await _pickSource();
    if (source == null) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 78,
      );
    } catch (_) {
      file = null;
    }
    final picked = file;
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    await widget.onSendImage(bytes, _mimeFromName(picked.name));
  }

  Future<ImageSource?> _pickSource() async {
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        final pt = PremiumTokens.of(ctx);
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: pt.greyLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                _SheetItem(
                  icon: Iconsax.gallery,
                  label: tr('support.pick_from_gallery'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                _SheetItem(
                  icon: Iconsax.camera,
                  label: tr('support.pick_from_camera'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- voice recording ------------------------------------------------------

  Future<void> _startRecording() async {
    if (widget.sending || _recording) return;
    // permission_handler drives the OS prompt; the recorder's own
    // hasPermission() then confirms the platform is actually ready.
    final status = await Permission.microphone.request();
    if (!status.isGranted) {
      if (!mounted) return;
      _showSnack(tr('support.mic_permission_denied'));
      return;
    }
    final has = await _recorder.hasPermission();
    if (!has) {
      if (!mounted) return;
      _showSnack(tr('support.mic_permission_denied'));
      return;
    }
    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/support_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
    try {
      // AAC-LC in an .m4a container → content_type audio/mp4 (mobile contract).
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, numChannels: 1),
        path: path,
      );
    } catch (e, st) {
      talker.handle(e, st, 'SupportComposer: recorder.start failed');
      if (!mounted) return;
      _showSnack(tr('support.recording_failed'));
      return;
    }
    if (!mounted) return;
    setState(() {
      _recording = true;
      _cancelled = false;
      _recordPath = path;
      _recordStartedAt = DateTime.now();
      _elapsed = Duration.zero;
    });
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || _recordStartedAt == null) return;
      setState(() => _elapsed = DateTime.now().difference(_recordStartedAt!));
    });
  }

  Future<void> _stopRecording({required bool cancel}) async {
    if (!_recording) return;
    _ticker?.cancel();
    _ticker = null;
    final duration = _elapsed;
    final startPath = _recordPath;
    setState(() {
      _recording = false;
      _recordStartedAt = null;
    });
    String? resultPath;
    try {
      resultPath = await _recorder.stop();
    } catch (e, st) {
      talker.handle(e, st, 'SupportComposer: recorder.stop failed');
    }
    final filePath = resultPath ?? startPath;
    if (cancel || _cancelled || filePath == null) {
      await _deleteTemp(filePath);
      return;
    }
    // Too-short taps aren't real voice notes — discard silently.
    if (duration.inMilliseconds < 800) {
      await _deleteTemp(filePath);
      if (mounted) _showSnack(tr('support.recording_too_short'));
      return;
    }
    try {
      final file = File(filePath);
      if (!file.existsSync()) {
        await _deleteTemp(filePath);
        return;
      }
      final bytes = await file.readAsBytes();
      await widget.onSendAudio(bytes, 'audio/mp4', duration.inMilliseconds);
    } catch (e, st) {
      talker.handle(e, st, 'SupportComposer: read/send audio failed');
      if (mounted) _showSnack(tr('support.recording_failed'));
    } finally {
      await _deleteTemp(filePath);
    }
  }

  Future<void> _deleteTemp(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {
      // Best-effort temp cleanup.
    }
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Container(
      padding: EdgeInsets.fromLTRB(
        12,
        8,
        12,
        8 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: pt.background,
        border: Border(top: BorderSide(color: pt.divider, width: 0.6)),
      ),
      child: _recording
          ? _RecordingBar(
              elapsed: _elapsed,
              cancelled: _cancelled,
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _RoundButton(
                  icon: Iconsax.gallery_add,
                  tooltip: tr('support.attach_image'),
                  onTap: widget.sending ? null : _handleAttach,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 140),
                    decoration: BoxDecoration(
                      color: pt.surface,
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: PremiumTokens.softShadow,
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        inputDecorationTheme: const InputDecorationTheme(
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          disabledBorder: InputBorder.none,
                          errorBorder: InputBorder.none,
                          focusedErrorBorder: InputBorder.none,
                          filled: false,
                          fillColor: Colors.transparent,
                          contentPadding: EdgeInsets.zero,
                          isCollapsed: true,
                        ),
                      ),
                      child: TextField(
                        controller: _ctrl,
                        focusNode: _focus,
                        enabled: !widget.sending,
                        maxLines: null,
                        textInputAction: TextInputAction.newline,
                        textCapitalization: TextCapitalization.sentences,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(4000),
                        ],
                        cursorColor: Theme.of(context).colorScheme.primary,
                        style: PremiumTokens.body(size: 14.5, color: pt.dark),
                        decoration: InputDecoration(
                          hintText: tr('support.composer_hint'),
                          hintStyle:
                              PremiumTokens.body(size: 14, color: pt.grey),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (_hasText)
                  _SendButton(
                    enabled: !widget.sending,
                    onTap: _handleSendText,
                  )
                else
                  _MicButton(
                    enabled: !widget.sending,
                    onStart: _startRecording,
                    onEnd: () => _stopRecording(cancel: _cancelled),
                    onCancelChanged: (cancelled) {
                      if (_cancelled != cancelled) {
                        setState(() => _cancelled = cancelled);
                      }
                    },
                  ),
              ],
            ),
    );
  }
}

/// The in-progress recording overlay that replaces the input row: a pulsing
/// red dot, the elapsed mm:ss, and a slide-to-cancel hint.
class _RecordingBar extends StatelessWidget {
  const _RecordingBar({required this.elapsed, required this.cancelled});

  final Duration elapsed;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final m = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
              color: Color(0xFFE5484D),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$m:$s',
            style: PremiumTokens.body(
              size: 15,
              weight: FontWeight.w700,
              color: pt.dark,
            ),
          ),
          const Spacer(),
          Icon(
            cancelled ? Iconsax.trash : Iconsax.arrow_left_2_copy,
            size: 16,
            color: cancelled ? const Color(0xFFE5484D) : pt.grey,
          ),
          const SizedBox(width: 6),
          Text(
            cancelled
                ? tr('support.release_to_cancel')
                : tr('support.slide_to_cancel'),
            style: PremiumTokens.body(
              size: 12.5,
              color: cancelled ? const Color(0xFFE5484D) : pt.grey,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: pt.imageBg,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 20,
              color: enabled
                  ? Theme.of(context).colorScheme.primary
                  : pt.greyLight,
            ),
          ),
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Material(
      color: enabled ? accent : accent.withValues(alpha: 0.4),
      shape: const CircleBorder(),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: const SizedBox(
          width: 44,
          height: 44,
          child: Icon(Iconsax.send_2, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

/// Hold-to-record mic button. Long-press starts the recording; release stops +
/// sends. Dragging far enough up/left while held flips into a cancel state, so
/// releasing there discards the clip (slide-to-cancel).
class _MicButton extends StatefulWidget {
  const _MicButton({
    required this.enabled,
    required this.onStart,
    required this.onEnd,
    required this.onCancelChanged,
  });

  final bool enabled;
  final Future<void> Function() onStart;
  final Future<void> Function() onEnd;
  final ValueChanged<bool> onCancelChanged;

  @override
  State<_MicButton> createState() => _MicButtonState();
}

class _MicButtonState extends State<_MicButton> {
  bool _held = false;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final color = widget.enabled ? accent : accent.withValues(alpha: 0.4);
    return GestureDetector(
      onLongPressStart: widget.enabled
          ? (_) async {
              setState(() => _held = true);
              await widget.onStart();
            }
          : null,
      onLongPressMoveUpdate: widget.enabled
          ? (d) {
              // Slide up or to the left past the threshold to arm cancel.
              final cancel = d.offsetFromOrigin.dx < -60 ||
                  d.offsetFromOrigin.dy < -60;
              widget.onCancelChanged(cancel);
            }
          : null,
      onLongPressEnd: widget.enabled
          ? (_) async {
              setState(() => _held = false);
              await widget.onEnd();
            }
          : null,
      child: Tooltip(
        message: tr('support.hold_to_record'),
        child: AnimatedScale(
          scale: _held ? 1.25 : 1.0,
          duration: const Duration(milliseconds: 140),
          child: Material(
            color: color,
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Iconsax.microphone_2, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final accent = Theme.of(context).colorScheme.primary;
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: accent, size: 20),
      ),
      title: Text(
        label,
        style: PremiumTokens.body(
          size: 14,
          weight: FontWeight.w600,
          color: pt.dark,
        ),
      ),
      onTap: onTap,
    );
  }
}
