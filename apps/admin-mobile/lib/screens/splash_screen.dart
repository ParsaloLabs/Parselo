import 'package:flutter/material.dart';
import '../core/theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: BrandColors.creamBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'parsalo',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 48,
                fontWeight: FontWeight.w900,
                color: BrandColors.primary,
                letterSpacing: -1.5,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'OPERATIONS PORTAL',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 3.0,
                color: BrandColors.accentOrange,
              ),
            ),
            SizedBox(height: 32),
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(BrandColors.accentOrange),
            ),
          ],
        ),
      ),
    );
  }
}
