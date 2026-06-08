import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/auth_provider.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onComplete;

  const WelcomeScreen({
    super.key,
    required this.onComplete,
  });

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _bgFade;
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _textFade;
  late Animation<double> _letterSpacing;
  late Animation<double> _lineWidth;
  late Animation<double> _screenExit;

  // Onboarding phase tracking
  // 0 = Splash/Intro animation
  // 1 = Name input query
  // 2 = Exit transition
  int _phase = 0;
  bool _showGetStartedButton = false;
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();

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
    _letterSpacing = Tween<double>(begin: 2.0, end: 6.0).animate(
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

    // Trigger showing the "Get Started" button once intro animations settle
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _showGetStartedButton = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitNameOnboarding() async {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController.text.trim();
      
      // Perform local sign in with the name
      final success = await ref.read(authProvider.notifier).signInWithLocalName(name);
      
      if (success) {
        // Transition to Phase 2 (Exit)
        setState(() {
          _phase = 2;
        });
        
        // Let the phase exit animations play out briefly then complete
        Future.delayed(const Duration(milliseconds: 500), () {
          widget.onComplete();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to initialize local profile.')),
        );
      }
    }
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
          // If we are in Phase 2 (Exit), we animate opacity down
          final double currentOpacity = _phase == 2 ? 0.0 : _screenExit.value;

          return Opacity(
            opacity: currentOpacity,
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
                    
                    // Main Content Cross-Fade between Intro and Form Onboarding
                    AnimatedCrossFade(
                      firstChild: _buildIntroPhase(context, primaryTextColor, secondaryTextColor, accentColor),
                      secondChild: _buildFormPhase(context, primaryTextColor, secondaryTextColor),
                      crossFadeState: _phase == 0 ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                      duration: const Duration(milliseconds: 600),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildIntroPhase(BuildContext context, Color primaryTextColor, Color secondaryTextColor, Color accentColor) {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aesthetic Minimal Logo/Compass Icon
            Opacity(
              opacity: _logoOpacity.value,
              child: Transform.scale(
                scale: _logoScale.value,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(
                    'assets/images/nova_study_logo.png',
                    width: 100,
                    height: 100,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // Subtitle "WELCOME TO"
            Opacity(
              opacity: _textFade.value,
              child: Text(
                'WELCOME TO',
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
            
            // Main name "NOVA STUDY"
            Opacity(
              opacity: _textFade.value,
              child: Text(
                'NOVA STUDY',
                style: GoogleFonts.outfit(
                  textStyle: TextStyle(
                    color: primaryTextColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: _letterSpacing.value,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Description
            Opacity(
              opacity: _textFade.value,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40.0),
                child: Text(
                  'Monitor your academics here.\nAll-in-one app.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    textStyle: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Elegant horizontal center line expanding
            Opacity(
              opacity: _textFade.value,
              child: Container(
                width: 120 * _lineWidth.value,
                height: 1.5,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
            
            const SizedBox(height: 40),
            
            // Animated Start Button
            AnimatedOpacity(
              opacity: _showGetStartedButton ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 500),
              child: _showGetStartedButton
                  ? ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _phase = 1;
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                        elevation: 4,
                      ),
                      child: Text(
                        'Get Started',
                        style: GoogleFonts.outfit(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(height: 54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormPhase(BuildContext context, Color primaryTextColor, Color secondaryTextColor) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Welcome header
              Center(
                child: Text(
                  'Before we begin...',
                  style: GoogleFonts.outfit(
                    textStyle: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'What should we call you?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    textStyle: TextStyle(
                      color: primaryTextColor,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'We\'ll use this to customize your briefings, morning reminders, and logs.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    textStyle: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 13,
                      height: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 36),

              // Name Input Field
              TextFormField(
                controller: _nameController,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                style: GoogleFonts.outfit(
                  textStyle: TextStyle(color: primaryTextColor, fontSize: 16),
                ),
                decoration: InputDecoration(
                  labelText: 'Your Name',
                  hintText: 'Enter your name or nickname',
                  labelStyle: GoogleFonts.outfit(textStyle: TextStyle(color: secondaryTextColor)),
                  hintStyle: GoogleFonts.outfit(textStyle: TextStyle(color: secondaryTextColor.withOpacity(0.6))),
                  prefixIcon: Icon(Icons.person_outline, color: Theme.of(context).primaryColor),
                  filled: true,
                  fillColor: Theme.of(context).cardColor,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a name to continue';
                  }
                  if (value.trim().length < 2) {
                    return 'Name must be at least 2 characters';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 32),

              // Let's Begin Button
              ElevatedButton(
                onPressed: _submitNameOnboarding,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                ),
                child: Text(
                  'Let\'s Begin',
                  style: GoogleFonts.outfit(
                    textStyle: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
