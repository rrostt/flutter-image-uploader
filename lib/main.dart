import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'cameras.dart';
import './widgets/SignIn.dart';
import './models/auth.dart';
import './widgets/SelectStreamPage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  initCameras();

  AuthModel authModel = AuthModel();
  await authModel.init();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>(create: (context) => authModel),
    ],
    child: MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Consumer<AuthModel>(
        builder: (context, auth, child) =>
            auth.token != null ? SelectStreamPage() : SignIn(),
      ),
    ),
  ));
}
