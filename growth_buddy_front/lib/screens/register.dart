import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../helpers/database_helper.dart';
import '../models/record.dart';
import 'package:http/http.dart' as http;

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({Key? key}) : super(key: key);

  @override
  // ignore: library_private_types_in_public_api
  _RegisterScreenState createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  String? dropdownValue;
  String comment = '';
  double selectedEffort = 1;
  int threshold = 1;
  String apiResponse = ''; // APIからのレスポンスを保持する
  Future<String>? apiResponseFuture;

  Future<void> _saveRecordAndAccessAPI() async {
    await _saveRecord();
    apiResponseFuture = _accessAPIIfThresholdReached();
    setState(() {
      apiResponseFuture = _accessAPIIfThresholdReached();
    });
  }

  Future<void> _saveRecord() async {
    final record = Record(
      category: dropdownValue ?? '',
      content: comment,
      effort: selectedEffort,
    );

    final helper = DatabaseHelper.instance;
    await helper.insertRecord(record);

    // レコードの保存が完了した後の処理
    _showSaveSuccessMessage();
  }

  Future<String> _accessAPIIfThresholdReached() async {
    final helper = DatabaseHelper.instance;

    // レコードの総数を確認します。
    int count = await helper.getRecordCount();
    
    // レコードの総数が一定の閾値に達しているなら、APIへアクセスします。
    if (count >= threshold) {
      final url = Uri.parse('http://127.0.0.1:8000/generate_image/');
      // final url = Uri.parse('http://127.0.0.1:8000/healthz/');

      // リクエストヘッダーの設定
      Map<String, String> headers = {'Content-Type': 'application/json'};

      // テキストの取得
      List<String> texts = await _getTextsFromDatabase();

      // 画像の読み込み
      String image = await _getImageFromAssets();

      // リクエストボディの設定
      Map<String, dynamic> requestBody = {
        'texts': texts,
        'image': image,
      };

      // POSTリクエストの送信
      // var response = await http.get(url);
      var response = await http.post(url, headers: headers, body: jsonEncode(requestBody));
      print(response.body);

      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        var image = data['image'];
    
        // return data; // return the parsed data
        var imageBytes = base64Decode(image);
        await _writeImageDataToFile(imageBytes);
        print("finish whiteImage");
        return image;
      } else {
        // If that response was not OK, throw an error.
        throw Exception('Failed to load data from API');
      }
    }
    return 'Threshold not reached';
  }

  Future<File> _writeImageDataToFile(Uint8List data) async {
    final directory = await getApplicationDocumentsDirectory(); // アプリケーションのドキュメントディレクトリを取得します。
    final path = directory.path; // ディレクトリのパスを取得します。
    // print(path);
    final filePath = '$path/myImage.png'; // 保存したい画像のパスを作成します。
    final file = File(filePath);
    print(file);
    return file.writeAsBytes(data); // ファイルにデータを書き込みます。
  }

  Future<List<String>> _getTextsFromDatabase() async {
    // データベースからテキストを取得する処理を実装する
    // 例: テキストのリストをデータベースから取得する
    final helper = DatabaseHelper.instance;
    List<String> texts = await helper.getTexts();
    return texts;
  }

  Future<String> _getImageFromAssets() async {
    // アセットから画像を読み込む処理を実装する
    // 例: assets内の画像ファイルをバイトデータに変換し、Base64エンコードする
    ByteData imageBytes = await rootBundle.load('assets/images/niwatori_hiyoko_koushin.png');
    List<int> byteList = imageBytes.buffer.asUint8List();
    String base64Image = base64Encode(byteList);
    return base64Image;
  }

  void _showSaveSuccessMessage() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('保存が完了しました'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Category:'),
            DropdownButton<String>(
              value: dropdownValue,
              onChanged: (String? newValue) {
                setState(() {
                  dropdownValue = newValue!;
                });
              },
              items: <String>['勉強', '趣味', '家事', 'サークル', '就活']
                  .map<DropdownMenuItem<String>>((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value),
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
            const Text('Comment:'),
            TextField(
              onChanged: (text) {
                setState(() {
                  comment = text;
                });
              },
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: 'Enter your comment here',
              ),
            ),
            const SizedBox(height: 20),
            Text('Effort: ${_getEffortLabel(selectedEffort)}'),
            Slider(
              value: selectedEffort,
              min: 1,
              max: 5,
              divisions: 4,
              onChanged: (double values) {
                setState(() {
                  selectedEffort = values;
                });
              },
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveRecordAndAccessAPI, // ボタンを押したときに_saveRecordAndAccessAPIを実行します
              child: const Text('Submit'),
            ),
            const SizedBox(height: 20),
            FutureBuilder<String>(
              future: apiResponseFuture,
              builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  // The future is still running, so show a loading indicator.
                  return const CircularProgressIndicator();
                } else if (snapshot.hasError) {
                  return Text('Error: ${snapshot.error}');
                } else {
                  // The future completed successfully.
                  String? base64Image = snapshot.data;

                  if (base64Image != null && base64Image != 'Threshold not reached') {
                    Uint8List imageBytes = base64Decode(base64Image);

                    return Image.memory(imageBytes, fit: BoxFit.fill);
                  } else {
                    return const Text('Threshold not reached or no image data');
                  }
                }
              },
            // FutureBuilder<String>(
            //   future: apiResponseFuture,
            //   builder: (BuildContext context, AsyncSnapshot<String> snapshot) {
            //     if (snapshot.connectionState == ConnectionState.waiting) {
            //       return const CircularProgressIndicator(); // ローディングインジケータを表示します
            //     } else if (snapshot.hasError) {
            //       return Text('Error: ${snapshot.error}'); // エラーメッセージを表示します
            //     } else {
            //       return Text('Response: ${snapshot.data}'); // レスポンスを表示します
            //     }
            //   },
          )],
      ),
    )
    );
  }

  String _getEffortLabel(double value) {
    switch (value.toInt()) {
      case 1:
        return 'ちょっと';
      case 2:
        return 'まあまあ';
      case 3:
        return '普通';
      case 4:
        return 'かなり';
      case 5:
        return 'とても';
      default:
        return '';
    }
  }
}
