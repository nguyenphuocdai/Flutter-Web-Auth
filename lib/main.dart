import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:io' show HttpServer;
import 'package:http/http.dart' as http;
import 'package:flutter_web_auth/flutter_web_auth.dart';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'package:uuid/uuid.dart';

const html = """
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>Grant Access to Flutter</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    html, body { margin: 0; padding: 0; }
    main {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      font-family: -apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif,Apple Color Emoji,Segoe UI Emoji,Segoe UI Symbol;
    }
    #icon {
      font-size: 96pt;
    }
    #text {
      padding: 2em;
      max-width: 260px;
      text-align: center;
    }
    #button a {
      display: inline-block;
      padding: 6px 12px;
      color: white;
      border: 1px solid rgba(27,31,35,.2);
      border-radius: 3px;
      background-image: linear-gradient(-180deg, #34d058 0%, #22863a 90%);
      text-decoration: none;
      font-size: 14px;
      font-weight: 600;
    }
    #button a:active {
      background-color: #279f43;
      background-image: none;
    }
  </style>
</head>
<body>
  <main>
    <div id="icon">&#x1F3C7;</div>
    <div id="text">Press the button below to sign in using your Localtest.me account.</div>
    <div id="button"><a href="foobar://success?code=1337">Sign in</a></div>
  </main>
</body>
</html>
""";

void main() => runApp(MyApp());

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = '';

  @override
  void initState() {
    super.initState();
    startServer();
  }

  Future<void> startServer() async {
    final server = await HttpServer.bind('127.0.0.1', 43823);

    server.listen((req) async {
      setState(() {
        _status = 'Received request!';
      });

      req.response.headers.add('Content-Type', 'text/html');
      req.response.write(html);
      req.response.close();
    });
  }

  String _randomString(int length) {
    var rand = new Random();
    var codeUnits = new List.generate(length, (index) {
      return rand.nextInt(33) + 89;
    });

    return new String.fromCharCodes(codeUnits);
  }

  void authenticate() async {
    // final url = 'http://localtest.me:43823/';
    Codec<String, String> stringToBase64Url = utf8.fuse(base64Url);
    var verifier = new Uuid().v4() + "a673b49ba7f7b04a";
    // var verifier = "c775e7b757ede630cd0aa1113bd102661ab38829ca52a6422ab782862f268646";

    List<int> bytes_verifier = utf8.encode(verifier);
    // var sha256_verifier = sha256.convert(bytes_verifier);
    Digest digest = sha256.convert(bytes_verifier);
    // String code_challenge = "51FaJvQFsiNdiFWIq2EMWUKeAqD47dqU_cHzJpfHl-Q";
    String code_challenge = base64Url.encode(digest.bytes).replaceAll("=", "");
    print(base64Url.encode(digest.bytes));
    final url =
        'http://192.168.137.1:5000/connect/authorize?client_id=mobile_spa&response_type=code&scope=openid api.read&redirect_uri=foobarmobile://success?code=1337&code_challenge=$code_challenge&code_challenge_method=S256';

    final callbackUrlScheme = 'foobarmobile';

    final result = await FlutterWebAuth.authenticate(url: url, callbackUrlScheme: callbackUrlScheme);
    final code = Uri.parse(result).queryParameters['code'];
    final urlGetAccessToken = 'http://192.168.137.1:5000/connect/token';

    print(url);
    print(code);

    var map = new Map<String, dynamic>();
    map['grant_type'] = 'authorization_code';
    map['client_id'] = 'mobile_spa';
    map['code'] = code;
    map['code_verifier'] = verifier;
    map['redirect_uri'] = 'foobarmobile://success?code=1337';

    var result_token = await http.post(urlGetAccessToken,
        // body: json.encode(map),
        body: map,
        headers: {'content-type': 'application/x-www-form-urlencoded'});

    setState(() {
      _status = 'Got result: $result \r\n Token: ${result_token.toString()}';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Web Auth example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('Status: $_status\n'),
              const SizedBox(height: 80),
              RaisedButton(
                child: Text('Authenticate'),
                onPressed: () {
                  this.authenticate();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
