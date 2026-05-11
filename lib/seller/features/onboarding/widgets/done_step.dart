import 'package:flutter/material.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';

class DoneStep extends StatefulWidget {
  const DoneStep({super.key});

  @override
  State<DoneStep> createState() => _DoneStepState();
}

class _DoneStepState extends State<DoneStep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
      child: Column(
        children: [
          ScaleTransition(
            scale: _scale,
            child: Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [PremiumTokens.accent, PremiumTokens.accentDeep],
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PremiumTokens.accentDeep.withValues(alpha: 0.28),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            'Ariza yuborildi!',
            style: PremiumTokens.display(size: 28, letterSpacing: -0.4),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          Text(
            "Sizning arizangiz qabul qilindi!\n"
            "24 soat ichida ko'rib chiqamiz.",
            style: PremiumTokens.body(
              size: 15,
              color: pt.grey,
              height: 1.55,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              style: FilledButton.styleFrom(
                backgroundColor: PremiumTokens.accent,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                'Profilga qaytish',
                style: PremiumTokens.body(
                  size: 15,
                  weight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
