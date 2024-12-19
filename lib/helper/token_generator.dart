import 'dart:convert' as convert;
import 'package:chatfinance/helper/show_toast.dart';
import 'package:http/http.dart' as http;

void generateToken() async {
  var url = Uri.https('chatapplicationfinal.onrender.com', '/generateAgoraToken?', {
    'channelName': 'omMishra',
  });
  var response = await http.get(url);

  if (response.statusCode == 200) {
    var jsonResponse = convert.jsonDecode(response.body) as Map<String, dynamic>;
    var token = jsonResponse['token'];
    print('Token generated is: $token.');
    showToast(isError: false, message: token);
  } else {
    print('Request failed with status: ${response.statusCode}.');
    showToast(isError: true, message: 'Failed to generate token.');
  }
}
