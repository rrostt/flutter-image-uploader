import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:compressimage/compressimage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:gurkapp/models/auth.dart';
import 'package:gurkapp/services/api.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

import 'package:google_sign_in/google_sign_in.dart';

GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId:
      '804478743579-a5999sgljs52e98i57p1i7u2v889nt8b.apps.googleusercontent.com',
  scopes: [
    'email',
  ],
);

List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();

  AuthModel authModel = AuthModel();

  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthModel>(create: (context) => authModel),
    ],
    child: Consumer<AuthModel>(
      builder: (context, auth, child) =>
          auth.token != null ? CameraApp() : SignIn(),
    ),
  ));
}

class SignIn extends StatelessWidget {
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            RaisedButton(
              onPressed: () async {
                try {
                  var x = await _googleSignIn.signIn();
                  var auth = await x.authentication;

                  var token = await fetchToken(auth.idToken);

                  Provider.of<AuthModel>(context, listen: false)
                      .setToken(token);
                } catch (e) {
                  print(e);
                  print('unable to signin');
                }
              },
              child: Text('login'),
            )
          ]),
        ),
      ),
    );
  }
}

class SelectStream extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;
  SelectStream({this.value, @required this.onChanged});

  Widget build(context) {
    return Consumer<AuthModel>(
      builder: (context, auth, _) => FutureBuilder(
        future: fetchStreams(token: auth.token),
        builder: (context, snapshot) =>
            snapshot.hasData ? _streamSelect(snapshot.data) : Text('loading'),
      ),
    );
  }

  Widget _streamSelect(List<Stream> streams) {
    return DropdownButton(
      items: streams
          .map((stream) =>
              DropdownMenuItem(child: Text(stream.title), value: stream.id))
          .toList(),
      onChanged: onChanged,
      value: value,
    );
  }
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> with TickerProviderStateMixin {
  CameraController cameraController;
  AnimationController rotationController;
  bool uploading = false;
  bool uploadingError = false;
  String streamId;
  String token;

  // TextEditingController plantIdController;

  Timer timer;

  @override
  void initState() {
    super.initState();
    initStreamId();

    rotationController = AnimationController(
      duration: Duration(milliseconds: 5000),
      vsync: this,
      upperBound: pi * 2,
    );
    rotationController.repeat();
    if (cameras.length > 0) {
      cameraController =
          CameraController(cameras[0], ResolutionPreset.veryHigh);
      cameraController.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        setState(() {});
        await Future.delayed(Duration(seconds: 5));
      });
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    super.dispose();
  }

  void initStreamId() async {
    var prefs = await SharedPreferences.getInstance();
    streamId = prefs.getString('streamId');
  }

  void setStreamId(String value) async {
    setState(() {
      streamId = value;
    });
    var prefs = await SharedPreferences.getInstance();
    await prefs.setString('streamId', streamId);
  }

  void takeAndUploadPicture() async {
    print('taking and posting');
    setState(() {
      uploading = true;
    });

    String path = join(
      (await getTemporaryDirectory()).path,
      '${DateTime.now()}.png',
    );
    await cameraController.takePicture(path);
    await CompressImage.compress(imageSrc: path, desiredQuality: 80);

    Uint8List bytes = File(path).readAsBytesSync();

    print('got bytes');
    try {
      var postUrl = await getUploadUrl(streamId: streamId, token: token);

      print(postUrl);

      try {
        var response = await http.put(
          postUrl,
          headers: <String, String>{
            'Content-Type': 'image/png',
          },
          body: bytes,
        );
        print(response);
        if (response.statusCode == 200) {
          print('Uploaded successfully');
        }
        setState(() {
          uploading = false;
          uploadingError = response.statusCode != 200;
        });
      } catch (e) {
        print(e);
        setState(() {
          uploading = false;
          uploadingError = true;
        });
      }
    } catch (e) {
      print(e);
      setState(() {
        uploading = false;
        uploadingError = true;
      });
    }
  }

  void repeatadlyUploadPic() async {
    takeAndUploadPicture();
    await Future.delayed(Duration(minutes: 15));
    repeatadlyUploadPic();
  }

  @override
  Widget build(BuildContext context) {
    token = Provider.of<AuthModel>(context, listen: false).token;
    return MaterialApp(
      title: 'Gurka',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Gurkor'), actions: [
          FlatButton(
            child: Text('logout'),
            onPressed: () {
              Provider.of<AuthModel>(context, listen: false).setToken(null);
              setStreamId(null);
            },
          ),
        ]),
        body: _body(context),
      ),
    );
  }

  void startTimer() {
    timer = Timer.periodic(Duration(minutes: 15), (timer) {
      takeAndUploadPicture();
    });
    setState(() {});
    takeAndUploadPicture();
  }

  void stopTimer() {
    if (timer != null) timer.cancel();
    timer = null;
    setState(() {});
  }

  Widget _body(BuildContext context) {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Center(
              child: Text('aGurk'),
            )
          ],
        ),
      );
    }
    return Container(
      // height: 400,
      width: 400,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Select stream'),
              SizedBox(width: 20),
              SelectStream(
                value: streamId,
                onChanged: (value) {
                  setStreamId(value);
                },
              ),
            ],
          ),
          Expanded(
            child: AspectRatio(
              aspectRatio: cameraController.value.aspectRatio,
              child: CameraPreview(cameraController),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              timer != null
                  ? IconButton(
                      icon: Icon(Icons.pause),
                      onPressed: streamId == null
                          ? null
                          : () {
                              stopTimer();
                            },
                    )
                  : IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: streamId == null
                          ? null
                          : () {
                              startTimer();
                            },
                    ),
              RaisedButton(
                onPressed: streamId == null
                    ? null
                    : () {
                        takeAndUploadPicture();
                      },
                child: Text('take pic'),
              ),
              if (uploading) CircularProgressIndicator(),
              if (uploadingError) Icon(Icons.error),
            ],
          ),
        ],
      ),
    );
  }
}
