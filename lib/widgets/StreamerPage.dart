import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:compressimage/compressimage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../models/auth.dart';
import '../services/api.dart';
import '../cameras.dart';

class StreamerPage extends StatefulWidget {
  final Stream stream;

  StreamerPage({this.stream});

  @override
  _StreamerPageState createState() => _StreamerPageState();
}

class _StreamerPageState extends State<StreamerPage>
    with TickerProviderStateMixin {
  CameraController cameraController;
  AnimationController rotationController;
  bool uploading = false;
  bool uploadingError = false;
  String token;

  Timer timer;

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
      cameraController = CameraController(cameras[0], ResolutionPreset.high);
      cameraController.initialize().then((_) async {
        if (!mounted) {
          return;
        }
        cameraController.setFlashMode(FlashMode.off);
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    cameraController?.dispose();
    rotationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    token = Provider.of<AuthModel>(context, listen: false).token;
    return Scaffold(
      appBar: AppBar(title: Text(widget.stream.title)),
      body: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (cameraController == null || !cameraController.value.isInitialized) {
      return Container(
        padding: EdgeInsets.all(20),
        child: Center(
          child: Text('Preparing'),
        ),
      );
    }
    return Stack(
      children: [
        CameraPreview(cameraController),
        Positioned(
          bottom: 20,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              roundedIconButton(
                color: timer != null ? Colors.red : Colors.black,
                onPressed: () {
                  if (timer != null) {
                    stopTimer();
                  } else {
                    startTimer();
                  }
                },
                icon: Icon(timer != null ? Icons.pause : Icons.play_arrow),
              ),
              SizedBox(
                width: 30,
              ),
              roundedIconButton(
                onPressed: () {
                  takeAndUploadPicture();
                },
                color: Colors.black,
                icon: Icon(Icons.camera_alt),
              ),
              if (uploading) CircularProgressIndicator(),
              if (uploadingError) Icon(Icons.error),
            ],
          ),
        )
      ],
    );
  }

  Widget roundedIconButton({icon, onPressed, color}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        color: color,
      ),
      child: IconButton(
        color: Colors.white,
        icon: icon,
        onPressed: onPressed,
      ),
    );
  }

  void takeAndUploadPicture() async {
    print('taking and posting');
    setState(() {
      uploading = true;
    });

    var file = await cameraController.takePicture();
    await CompressImage.compress(imageSrc: file.path, desiredQuality: 50);

    Uint8List bytes = File(file.path).readAsBytesSync();

    print('got bytes');
    try {
      var postUrl =
          await getUploadUrl(streamId: widget.stream.id, token: token);

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
}
