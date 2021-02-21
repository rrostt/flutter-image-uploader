import 'package:camera/camera.dart';

List<CameraDescription> cameras;

Future initCameras() async {
  cameras = await availableCameras();
}
