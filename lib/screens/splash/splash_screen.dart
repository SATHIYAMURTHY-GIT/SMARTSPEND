import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({required this.onComplete, super.key});

  final VoidCallback onComplete;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // Company logo animations (0.00 -> 0.46)
  late final Animation<double> _companyFadeIn;
  late final Animation<double> _companyFadeOut;
  late final Animation<double> _companyScale;

  // SmartSpend app logo animations (0.50 -> 0.96)
  late final Animation<double> _appFadeIn;
  late final Animation<double> _appFadeOut;
  late final Animation<double> _appScale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2600),
    );

    // Company logo: 0.00 to 0.48 (0ms to 1250ms)
    _companyFadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.00, 0.15, curve: Curves.easeOutCubic),
    );
    _companyFadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.36, 0.48, curve: Curves.easeInCubic),
    );
    _companyScale = Tween<double>(begin: 0.94, end: 1.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.00, 0.48, curve: Curves.easeOut),
      ),
    );

    // SmartSpend App logo: 0.48 to 1.00 (1250ms to 2600ms)
    _appFadeIn = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.48, 0.63, curve: Curves.easeOutCubic),
    );
    _appFadeOut = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.85, 0.98, curve: Curves.easeInCubic),
    );
    _appScale = Tween<double>(begin: 0.94, end: 1.02).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.48, 0.98, curve: Curves.easeOut),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    precacheImage(const AssetImage('assets/images/Company.png'), context);
    precacheImage(const AssetImage('assets/images/logo.png'), context);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0A1A),
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final progress = _controller.value;

            // Phase 1: Company Logo (0.00 to 0.48)
            if (progress < 0.48) {
              final opacity = (_companyFadeIn.value * (1.0 - _companyFadeOut.value))
                  .clamp(0.0, 1.0);
              return Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: _companyScale.value,
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    constraints: const BoxConstraints(
                      maxWidth: 240,
                      maxHeight: 240,
                    ),
                    child: Image.asset(
                      'assets/images/Company.png',
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                      gaplessPlayback: true,
                    ),
                  ),
                ),
              );
            }

            // Phase 2: SmartSpend Logo (0.48 to 1.00)
            final opacity =
                (_appFadeIn.value * (1.0 - _appFadeOut.value)).clamp(0.0, 1.0);
            return Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: _appScale.value,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  constraints: const BoxConstraints(
                    maxWidth: 240,
                    maxHeight: 240,
                  ),
                  child: Image.asset(
                    'assets/images/logo.png',
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
