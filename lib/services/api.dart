import 'package:http/http.dart' as http;
import 'dart:convert';

final apiBase = 'https://l05c34qtnh.execute-api.eu-north-1.amazonaws.com/dev';
// final presignedUrlApi = "$apiBase/generatePresignedUrl";
final uploadUrl = '$apiBase/uploadUrl';
final fetchAuthTokenUrl = '$apiBase/token';
final fetchStreamsUrl = '$apiBase/streams';

Future<String> fetchToken(String idToken) async {
  var response = await http.post(fetchAuthTokenUrl,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'tokenId': idToken}));

  var result = jsonDecode(response.body);
  return result['token'];
}

class Stream {
  final String id;
  final String title;
  final String description;

  Stream({this.id, this.title, this.description});

  factory Stream.fromJson(Map<String, dynamic> json) {
    return Stream(
      id: json['id'],
      title: json['title'],
      description: json['description'],
    );
  }
}

Future<List<Stream>> fetchStreams({token}) async {
  var response = await http.get(
    fetchStreamsUrl,
    headers: {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token'
    },
  );
  var array = jsonDecode(response.body);
  print(array);
  return array.map<Stream>((obj) => Stream.fromJson(obj)).toList();
}

Future<String> getUploadUrl({token, streamId}) async {
  var data = {"fileType": ".png"};
  if (streamId != null && streamId.isNotEmpty) {
    data['streamId'] = streamId;
  }
  var response = await http.post('$uploadUrl',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token'
      },
      body: jsonEncode(data));
  var obj = jsonDecode(response.body);
  return obj['uploadUrl'];
}
