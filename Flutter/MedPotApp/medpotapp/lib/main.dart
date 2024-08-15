import 'package:flutter/material.dart';
import 'package:medpotapp/pages/home.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
              seedColor: const Color.fromARGB(255, 3, 32, 128)),
          useMaterial3: true,
        ),
        home: const HomePage(title: 'Medidor de Potencia'));
  }
}
