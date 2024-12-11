import 'package:chatfinance/Screens/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
      options: const FirebaseOptions(
          apiKey: 'AIzaSyA1w2WRcMlf63ZAMcKh3WuAZeINhMwQ4AA',
          appId: '1:759422759332:android:e52fd06c95471092cd1131',
          messagingSenderId: '759422759332',
          projectId: 'kudoswareassignment-c5d97'
      )
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Flutter Demo',
      home: Homescreen(),
    );
  }
}
