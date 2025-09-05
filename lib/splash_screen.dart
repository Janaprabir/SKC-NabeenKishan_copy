import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nabeenkishan/login_page.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  double _opacity = 0.0;
  double _scale = 1.0;

  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    // Initialize the slide animation
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0.0, 0.0),
      end: const Offset(-1.0, 0.0), // Slide to the left
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    // Start the fade-in animation
    Timer(const Duration(milliseconds: 500), () {
      setState(() {
        _opacity = 1.0;
      });
    });

    // Start the "pop up" scale animation after the fade-in
    Timer(const Duration(seconds: 2), () {
      setState(() {
        _scale = 1.1; // Scale up slightly
      });

      // Reset the scale to normal after the pop-up effect
      Timer(const Duration(milliseconds: 300), () {
        setState(() {
          _scale = 1.0; // Return to normal scale
        });
      });
    });

    // Start the slide animation and navigate to the next page
Timer(const Duration(milliseconds: 3900), () {
  _slideController.forward().then((value) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500), // Smooth and quick
        pageBuilder: (context, animation, secondaryAnimation) => const LoginPage(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, -1.0); // Start from the top
          const end = Offset.zero;

          var slideAnimation = Tween(begin: begin, end: end)
              .chain(CurveTween(curve: Curves.easeInOut));

          return SlideTransition(
            position: animation.drive(slideAnimation),
            child: child,
          );
        },
      ),
    );
  });
});

  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SlideTransition(
        position: _slideAnimation,
        child: Center(
          child: AnimatedOpacity(
            duration: const Duration(seconds: 2),
            curve: Curves.easeInOut,
            opacity: _opacity,
            child: AnimatedScale(
              scale: _scale,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
              child: Image.asset(
                'assets/splashscreen.gif',
                fit: BoxFit.contain,
                width: 400,
                height: 400,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
