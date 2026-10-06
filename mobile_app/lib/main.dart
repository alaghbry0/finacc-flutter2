import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'ui/features/home/view_models/home_view_model.dart';

/// Application entry point.
///
/// Registers application-wide ViewModels with [MultiProvider] and boots
/// the root [MobileApp] widget.
void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HomeViewModel()),
      ],
      child: const MobileApp(),
    ),
  );
}
