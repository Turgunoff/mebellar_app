import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/i18n.dart';
import '../../../customer/features/home/widgets/premium/premium_tokens.dart';

typedef SendTextCallback = Future<void> Function(String body);
typedef SendImageCallback = Future<void> Function(
  Uint8List bytes,
  String mimeType,
  String? caption,
);

/// The bottom composer bar — text field, attach button, send button.
/// Disables itself while [sending] is true to avoid double-submits.
class ChatComposer extends StatefulWidget {
  const ChatComposer({
    super.key,
    required this.onSendText,
    required this.onSendImage,
    this.sending = false,
  });

  final SendTextCallback onSendText;
  final SendImageCallback onSendImage;
  final bool sending;

  @override
  State<ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<ChatComposer> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _hasText = false;

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
    super.dispose();
  }

  Future<void> _handleSend() async {
    final body = _ctrl.text.trim();
    if (body.isEmpty || widget.sending) return;
    _ctrl.clear();
    setState(() => _hasText = false);
    await widget.onSendText(body);
  }

  Future<void> _handleAttach() async {
    final source = await _pickSource();
    if (source == null) return;
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        // Cap dimensions + quality so we don't ship 12-MP camera shots
        // over the wire; chat images don't need print resolution.
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 78,
      );
    } catch (_) {
      file = null;
    }
    if (file == null) return;
    final bytes = await file.readAsBytes();
    final mime = _mimeFromName(file.name);
    await widget.onSendImage(bytes, mime, null);
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
                  label: tr('chat.pick_from_gallery'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
                ),
                _SheetItem(
                  icon: Iconsax.camera,
                  label: tr('chat.pick_from_camera'),
                  onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _mimeFromName(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.gif')) return 'image/gif';
    return 'image/jpeg';
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    final canSend = _hasText && !widget.sending;
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RoundButton(
            icon: Iconsax.gallery_add,
            tooltip: tr('chat.attach_image'),
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
                  cursorColor: PremiumTokens.accent,
                  style: PremiumTokens.body(
                    size: 14.5,
                    color: pt.dark,
                  ),
                  decoration: InputDecoration(
                    hintText: tr('chat.composer_hint'),
                    hintStyle: PremiumTokens.body(size: 14, color: pt.grey),
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
          _SendButton(enabled: canSend, onTap: _handleSend),
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
              color: enabled ? PremiumTokens.accent : pt.greyLight,
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      child: Material(
        color: enabled
            ? PremiumTokens.accent
            : PremiumTokens.accent.withValues(alpha: 0.4),
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
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: PremiumTokens.accent.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: PremiumTokens.accent, size: 20),
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
