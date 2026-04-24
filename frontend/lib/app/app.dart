import 'package:flutter/material.dart';
import 'router.dart';
import 'theme.dart';

class ShelfScanApp extends StatelessWidget {
  const ShelfScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'ShelfScan-AI',
      theme: AppTheme.light(),
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}