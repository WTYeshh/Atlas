import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class WelcomeScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const WelcomeScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textFade;
  late Animation<double> _letterSpacing;
  late Animation<double> _lineWidth;
  late Animation<double> _screenExit;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2500),
    );

    // 1. Background fade-in (0.0 to 0.3 of duration)
    _bgFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
      ),
    );

    // 2. Logo opacity and scale (0.1 to 0.6 of duration)
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.5, curve: Curves.easeOut),
      ),
    );
    _logoScale = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.1, 0.6, curve: Curves.easeOutBack),
      ),
    );

    // 3. Text fade and letter-spacing (0.3 to 0.8 of duration)
    _textFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.7, curve: Curves.easeIn),
      ),
    );
    _letterSpacing = Tween<double>(begin: 2.0, end: 8.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.3, 0.8, curve: Curves.easeOutCubic),
      ),
    );

    // 4. Horizontal line width drawing (0.4 to 0.9 of duration)
    _lineWidth = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.85, curve: Curves.easeInOutQuad),
      ),
    );

    // 5. Exit transition fade/slide (0.85 to 1.0 of duration)
    _screenExit = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.85, 1.0, curve: Curves.fastOutSlowIn),
      ),
    );

    // Start the animation sequence
    _controller.forward();

    // Trigger complete callback when the animation finishes
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Define elegant colors
    final Color bgColorStart = isDark ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
    final Color bgColorEnd = isDark ? const Color(0xFF0A0A0C) : const Color(0xFFF4F4F6);
    final Color primaryTextColor = isDark ? Colors.white : Colors.black;
    final Color accentColor = isDark ? const Color(0xFFE5E5EA) : const Color(0xFF1C1C1E);
    final Color secondaryTextColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    final Color glowColor = isDark ? const Color(0x33FFFFFF) : const Color(0x11000000);

    return Scaffold(
      body: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return Opacity(
            opacity: _screenExit.value,
            child: Transform.translate(
              offset: Offset(0, -20 * (1.0 - _screenExit.value)),
              child: Container(
                width: double.infinity,
                height: double.infinity,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color.lerp(bgColorStart, bgColorStart, _bgFade.value)!,
                      Color.lerp(bgColorStart, bgColorEnd, _bgFade.value)!,
                    ],
                  ),
                ),
                child: SafeArea(
                  child: Stack(
                    children: [
                      // Background ambient glow
                      Center(
                        child: Opacity(
                          opacity: _logoOpacity.value * 0.4,
                          child: Container(
                            width: 250,
                            height: 250,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor,
                                  blurRadius: 100,
                                  spreadRadius: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Central content
                      Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Aesthetic Minimal Logo/Compass Icon
                            Opacity(
                              opacity: _logoOpacity.value,
                              child: Transform.scale(
                                scale: _logoScale.value,
                                child: Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: primaryTextColor.withOpacity(0.15),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Center(
                                    child: Container(
                                      width: 50,
                                      height: 50,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryTextColor.withOpacity(0.3),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Icon(
                                          Icons.explore_outlined,
                                          size: 24,
                                          color: primaryTextColor.withOpacity(0.8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 40),
                            // Subtitle "WELCOME"
                            Opacity(
                              opacity: _textFade.value,
                              child: Text(
                                'WELCOME',
                                style: GoogleFonts.outfit(
                                  textStyle: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            // Main name "YESHWANTH"
                            Opacity(
                              opacity: _textFade.value,
                              child: Text(
                                'YESHWANTH',
                                style: GoogleFonts.outfit(
                                  textStyle: TextStyle(
                                    color: primaryTextColor,
                                    fontSize: 26,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: _letterSpacing.value,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 24),
                            // Elegant horizontal center line expanding
                            Opacity(
                              opacity: _textFade.value,
                              child: Container(
                                width: 100 * _lineWidth.value,
                                height: 1.5,
                                decoration: BoxDecoration(
                                  color: accentColor.withOpacity(0.5),
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
