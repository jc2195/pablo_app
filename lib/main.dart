import 'package:drawing_app/drawing_page.dart';
import 'package:drawing_app/menu_page.dart';
import 'package:flutter/material.dart';
import 'package:splashscreen/splashscreen.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Drawing App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => MyAppSplash(),
      },
    );
  }
}

class MyAppSplash extends StatefulWidget {
  @override
  _MyAppState createState() => new _MyAppState();
}

class _MyAppState extends State<MyAppSplash> {
  @override
  Widget build(BuildContext context) {
    return new SplashScreen(
      seconds: 4,
      navigateAfterSeconds: new MenuPage(),
      title: new Text(
        'Art, reinvented',
        style: new TextStyle(fontWeight: FontWeight.bold, fontSize: 40.0),
      ),
      image: new Image.asset(
          'assets/pablo_logo_all_with_brush.png',
      ),
      photoSize: 300,
      backgroundColor: Colors.white,
      loaderColor: Colors.blue,
    );
  }
}
