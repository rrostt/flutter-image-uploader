import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/auth.dart';
import '../services/api.dart';
import 'StreamerPage.dart';

class SelectStreamPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Streams'), actions: [
        FlatButton(
          child: Text('logout'),
          onPressed: () {
            Provider.of<AuthModel>(context, listen: false).setToken(null);
          },
        ),
      ]),
      body: _body(context),
    );
  }

  Widget _body(context) {
    var token = Provider.of<AuthModel>(context, listen: false).token;
    return FutureBuilder(
      future: fetchStreams(token: token),
      builder: (context, snapshot) => snapshot.hasData
          ? ListView(
              children: snapshot.data
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
                      subtitle: Text(stream.latestTime != null
                          ? '${stream.latestTime}'
                          : ''),
                      onTap: () {
                        Navigator.of(context).push(MaterialPageRoute(
                            builder: (context) =>
                                StreamerPage(stream: stream)));
                      },
                    ),
                  )
                  .toList(),
            )
          : Text('loading'),
    );
  }
}
