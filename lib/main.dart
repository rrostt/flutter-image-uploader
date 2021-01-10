import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:compressimage/compressimage.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

List<CameraDescription> cameras;

final presignedUrlApi =
    "https://l05c34qtnh.execute-api.eu-north-1.amazonaws.com/dev/generatePresignedUrl";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> with TickerProviderStateMixin {
  CameraController controller;
  AnimationController rotationController;
  bool uploading = false;
  bool uploadingError = false;

  TextEditingController plantIdController;

  Timer timer;

  @override
  void initState() {
    super.initState();
    plantIdController = TextEditingController();

    plantIdController.addListener(() async {
      var prefs = await SharedPreferences.getInstance();
      await prefs.setString('plantId', plantIdController.text);
    });
    initPlantId();

    rotationController = AnimationController(
      duration: Duration(milliseconds: 5000),
      vsync: this,
      upperBound: pi * 2,
    );
    rotationController.repeat();
    if (cameras.length > 0) {
      controller = CameraController(cameras[0], ResolutionPreset.veryHigh);
      controller.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        setState(() {});
        await Future.delayed(Duration(seconds: 5));
        // repeatadlyUploadPic();
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  void initPlantId() async {
    var prefs = await SharedPreferences.getInstance();
    plantIdController.text = prefs.getString('plantId');
  }

  Future<String> getPostUrl() async {
    var data = {"fileType": ".png"};
    if (plantIdController.text != null && plantIdController.text.isNotEmpty) {
      data['plantId'] = plantIdController.text;
    }
    var response = await http.post('$presignedUrlApi',
        headers: <String, String>{"Content-Type": "application/json"},
        body: jsonEncode(data));
    var obj = jsonDecode(response.body);
    return obj['uploadUrl'];
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
    await controller.takePicture(path);
    await CompressImage.compress(imageSrc: path, desiredQuality: 80);

    Uint8List bytes = File(path).readAsBytesSync();

    print('got bytes');
    try {
      var postUrl = await getPostUrl();

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
    return MaterialApp(
      title: 'Gurka',
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: Scaffold(
        appBar: AppBar(title: Text('Gurkor')),
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
    if (controller == null || !controller.value.isInitialized) {
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
          Expanded(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: CameraPreview(controller),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              timer != null
                  ? IconButton(
                      icon: Icon(Icons.pause),
                      onPressed: () {
                        stopTimer();
                      },
                    )
                  : IconButton(
                      icon: Icon(Icons.play_arrow),
                      onPressed: () {
                        startTimer();
                      },
                    ),
              RaisedButton(
                onPressed: () {
                  takeAndUploadPicture();
                },
                child: Text('take pic'),
              ),
              if (uploading) CircularProgressIndicator(),
              if (uploadingError) Icon(Icons.error),
            ],
          ),
          TextField(
            controller: plantIdController,
            decoration: InputDecoration(hintText: 'Plant ID'),
          ),
        ],
      ),
    );
  }
}
