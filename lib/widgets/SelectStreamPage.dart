import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth.dart';
import '../services/api.dart';
import 'StreamerPage.dart';

class SelectStreamPage extends StatefulWidget {
  SelectStreamPageState createState() => SelectStreamPageState();
}

class SelectStreamPageState extends State<SelectStreamPage> {
  var streamsFuture;

  void initState() {
    super.initState();
    _loadStreams();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Stream'),
        actions: [
          IconButton(
              icon: Icon(Icons.logout),
              onPressed: () {
                Provider.of<AuthModel>(context, listen: false).setToken(null);
              }),
        ],
      ),
      body: _body(context),
    );
  }

  void _loadStreams() {
    var token = Provider.of<AuthModel>(context, listen: false).token;
    setState(() {
      streamsFuture = fetchStreams(token: token);
    });
  }

  Widget _body(context) {
    return FutureBuilder(
      future: streamsFuture,
      builder: (context, snapshot) =>
          snapshot.connectionState == ConnectionState.done
              ? RefreshIndicator(
                  child: _list(snapshot.data),
                  onRefresh: () async {
                    _loadStreams();
                  })
              : _loading(),
    );
  }

  Widget _loading() {
    return Center(child: CircularProgressIndicator());
  }

  Widget _list(List<Stream> streams) {
    return ListView(
      children: streams
          .map<Widget>(
            (Stream stream) => ListTile(
              leading: stream.latestUrl != null
                  ? Image(
                      image: NetworkImage(stream.latestUrl),
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                    )
                  : SizedBox(
                      width: 40,
                      height: 40,
                    ),
              title: Text(stream.title),
              subtitle:
                  Text(stream.latestTime != null ? '${stream.latestTime}' : ''),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (context) => StreamerPage(stream: stream)));
              },
            ),
          )
          .toList(),
    );
  }
}
