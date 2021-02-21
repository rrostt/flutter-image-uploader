import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../models/auth.dart';
import '../services/api.dart';

GoogleSignIn _googleSignIn = GoogleSignIn(
  clientId:
      '804478743579-a5999sgljs52e98i57p1i7u2v889nt8b.apps.googleusercontent.com',
  scopes: [
    'email',
  ],
);

class SignIn extends StatelessWidget {
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          RaisedButton(
            onPressed: () async {
              try {
                var x = await _googleSignIn.signIn();
                var auth = await x.authentication;

                var token = await fetchToken(auth.idToken);

                Provider.of<AuthModel>(context, listen: false).setToken(token);
              } catch (e) {
                print(e);
                print('unable to signin');
              }
            },
            child: Text('login'),
          )
        ]),
      ),
    );
  }
}
