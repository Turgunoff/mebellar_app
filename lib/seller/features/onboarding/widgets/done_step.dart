import 'package:flutter/material.dart';

import '../../../../customer/features/home/widgets/premium/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';
import 'onboarding_kit.dart';

class DoneStep extends StatelessWidget {
  const DoneStep({super.key});

  Widget _fadeUp(Animation<double> anim, Widget child) {
    return FadeTransition(
      opacity: anim,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(anim),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return StepActivation(
      step: OnboardingStep.done,
      duration: const Duration(milliseconds: 1400),
      builder: (context, animation) {
        final badgeScale = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.0, 0.5, curve: Curves.elasticOut),
        );
        final titleIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 0.6, curve: Curves.easeOutCubic),
        );
        final subtitleIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.42, 0.72, curve: Curves.easeOutCubic),
        );
        final buttonIn = CurvedAnimation(
          parent: animation,
          curve: const Interval(0.55, 0.85, curve: Curves.easeOutCubic),
        );
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 32),
          child: Column(
            children: [
              SizedBox(
                width: 200,
                height: 200,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    _Ripple(animation: animation, delay: 0.10, size: 200),
                    _Ripple(animation: animation, delay: 0.0, size: 156),
                    ScaleTransition(
                      scale: badgeScale,
                      child: Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              PremiumTokens.accent,
                              PremiumTokens.accentDeep,
                            ],
                          ),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: PremiumTokens.accentDeep.withValues(
                                alpha: 0.28,
                              ),
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _fadeUp(
                titleIn,
                Text(
                  'Ariza yuborildi!',
                  style: PremiumTokens.display(size: 28, letterSpacing: -0.4),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 14),
              _fadeUp(
                subtitleIn,
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
              ),
              const Spacer(),
              _fadeUp(
                buttonIn,
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
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Expanding ring that fades out behind the success badge.
class _Ripple extends StatelessWidget {
  const _Ripple({
    required this.animation,
    required this.delay,
    required this.size,
  });

  final Animation<double> animation;
  final double delay;
  final double size;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(delay, (delay + 0.6).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (context, _) {
        final t = curved.value;
        return Opacity(
          opacity: (1 - t) * 0.35,
          child: Transform.scale(
            scale: 0.5 + t * 0.7,
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: PremiumTokens.accent, width: 2),
              ),
            ),
          ),
        );
      },
    );
  }
}
