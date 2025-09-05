import 'package:flutter/material.dart';

class HomeScreenNavigator extends StatelessWidget {
  const HomeScreenNavigator({super.key});

  static void navigateToScreen(BuildContext context, String designation) {
    switch (designation) {
      case 'MANAGER':
        Navigator.pushReplacementNamed(context, '/home_page_manager');
        break;
      case 'SALES':
        Navigator.pushReplacementNamed(context, '/home_page_sales');
        break;
      case 'GODOWN':
        Navigator.pushReplacementNamed(context, '/home_page_godown');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    throw UnimplementedError();
  }
}
