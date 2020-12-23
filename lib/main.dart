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

List<CameraDescription> cameras;

final presignedUrlApi = YOUR_URL_HERE;

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

  @override
  void initState() {
    super.initState();
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
        repeatadlyUploadPic();
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<String> getPostUrl() async {
    var response = await http.post('$presignedUrlApi',
        headers: <String, String>{"Content-Type": "application/json"},
        body: jsonEncode({"fileType": ".png"}));
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
      setState(() {
        uploading = false;
        uploadingError = true;
      });
    }
  }

  void repeatadlyUploadPic() async {
    takeAndUploadPicture();
    await Future.delayed(Duration(minutes: 15));
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
        ],
      ),
    );
  }
}
