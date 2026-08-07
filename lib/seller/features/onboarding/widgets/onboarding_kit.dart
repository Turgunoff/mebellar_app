import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/theme/premium_tokens.dart';
import '../bloc/onboarding_bloc.dart';

/// Shared design kit for the seller onboarding wizard. Every step builds on
/// the same three primitives so the whole flow reads as one product:
/// [StepActivation] (replays an entrance animation each time its step becomes
/// the active wizard page), [StepReveal] (staggered list reveal on top of it),
/// and [StepHeader] + [onboardingFieldDecoration] for consistent type & forms.

/// Drives an entrance [Animation] that (re)plays whenever [step] becomes the
/// active wizard step. All pages of the wizard's PageView are alive from the
/// first frame, so a plain one-shot animation would finish long before the
/// user ever reaches the page — this listens to the bloc instead.
class StepActivation extends StatefulWidget {
  const StepActivation({
    super.key,
    required this.step,
    required this.builder,
    this.duration = const Duration(milliseconds: 700),
  });

  final OnboardingStep step;
  final Duration duration;
  final Widget Function(BuildContext context, Animation<double> animation)
  builder;

  @override
  State<StepActivation> createState() => _StepActivationState();
}

class _StepActivationState extends State<StepActivation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  StreamSubscription<OnboardingState>? _sub;
  late OnboardingStep _lastStep;

  @override
  void initState() {
    super.initState();
    final bloc = context.read<OnboardingBloc>();
    _lastStep = bloc.state.step;
    if (_lastStep == widget.step) _ctrl.forward();
    _sub = bloc.stream.listen((s) {
      if (s.step == widget.step && _lastStep != widget.step) {
        _ctrl.forward(from: 0);
      }
      _lastStep = s.step;
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, _ctrl.view);
}

/// Staggered fade + slide-up reveal for list-shaped steps.
class StepReveal extends StatelessWidget {
  const StepReveal({
    super.key,
    required this.step,
    required this.children,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 32),
  });

  final OnboardingStep step;
  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return StepActivation(
      step: step,
      builder: (context, animation) {
        return ListView(
          padding: padding,
          children: [
            for (var i = 0; i < children.length; i++)
              RevealItem(animation: animation, index: i, child: children[i]),
          ],
        );
      },
    );
  }
}

/// One staggered entry of a [StepReveal]/[StepActivation] sequence.
class RevealItem extends StatelessWidget {
  const RevealItem({
    super.key,
    required this.animation,
    required this.index,
    required this.child,
  });

  final Animation<double> animation;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.5);
    final curved = CurvedAnimation(
      parent: animation,
      curve: Interval(start, (start + 0.45).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.06),
          end: Offset.zero,
        ).animate(curved),
        child: child,
      ),
    );
  }
}

/// Display title + muted subtitle, identical across every wizard step.
class StepHeader extends StatelessWidget {
  const StepHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final pt = PremiumTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: PremiumTokens.display(size: 26, letterSpacing: -0.3),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: PremiumTokens.body(size: 14, color: pt.grey, height: 1.5),
        ),
      ],
    );
  }
}

/// Filled, softly-rounded field style shared by all onboarding forms.
InputDecoration onboardingFieldDecoration(
  BuildContext context, {
  required String label,
  String? hint,
  IconData? icon,
}) {
  final pt = PremiumTokens.of(context);
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecoration(
    labelText: label,
    hintText: hint,
    prefixIcon: icon == null ? null : Icon(icon, size: 20, color: pt.grey),
    filled: true,
    fillColor: pt.surface,
    labelStyle: PremiumTokens.body(size: 14, color: pt.grey),
    floatingLabelStyle:
        PremiumTokens.body(size: 13, color: PremiumTokens.accent),
    hintStyle: PremiumTokens.body(size: 14, color: pt.greyLight),
    border: border(pt.divider),
    enabledBorder: border(pt.divider),
    focusedBorder: border(PremiumTokens.accent, 1.6),
    errorBorder: border(scheme.error),
    focusedErrorBorder: border(scheme.error, 1.6),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
  );
}

/// Tinted rounded-square leading icon used on cards across the wizard.
class TintedIcon extends StatelessWidget {
  const TintedIcon({super.key, required this.icon, this.size = 44});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: PremiumTokens.accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: PremiumTokens.accent, size: size * 0.5),
    );
  }
}
