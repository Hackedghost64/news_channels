import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:provider/provider.dart';
import 'providers/channel_provider.dart';
import 'screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FLUTTER_FRAMEWORK_ERROR: ${details.exceptionAsString()}');
    debugPrintStack(stackTrace: details.stack);
  };
  PlatformDispatcher.instance.onError = (error, stackTrace) {
    debugPrint('UNCAUGHT_PLATFORM_ERROR: $error');
    debugPrintStack(stackTrace: stackTrace);
    return true;
  };
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.channelProvider});

  final ChannelProvider? channelProvider;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'News TV',
      theme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFE53935),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.black,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );

    if (channelProvider != null) {
      return ChangeNotifierProvider<ChannelProvider>.value(
        value: channelProvider!,
        child: app,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => ChannelProvider()..loadChannels(),
      child: app,
    );
  }
}
