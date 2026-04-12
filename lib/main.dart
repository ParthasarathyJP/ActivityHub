import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'auth_gate.dart';
import 'services/firestore_seed_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Seed TypeMaster reference data once (no-op on subsequent launches)
  try {
    await FirestoreSeedService.seedTypeMaster();
  } catch (e) {
    debugPrint('TypeMaster seed skipped: $e');
  }

  runApp(const ActivityHubApp());
}

class ActivityHubApp extends StatelessWidget {
  const ActivityHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ActivityHub',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF0D1B2A),
      ),
      home: const AuthGate(),
    );
  }
}