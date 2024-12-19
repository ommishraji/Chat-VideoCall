import 'package:assets_audio_player/assets_audio_player.dart';

  void busy(){
    AssetsAudioPlayer.newPlayer().open(
      Audio("assets/busy1.mp3"));
  }

void endCall(){
  AssetsAudioPlayer.newPlayer().open(
      Audio("assets/end_call1.mp3"));
}

void messageReceived(){
  AssetsAudioPlayer.newPlayer().open(
      Audio("assets/message_send.mp3"));
}
void messageSent(){
  AssetsAudioPlayer.newPlayer().open(
      Audio("assets/message_sent1.mp3"));
}

