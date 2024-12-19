import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:chatfinance/helper/app_constants.dart';
import 'package:chatfinance/helper/audio_player.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:permission_handler/permission_handler.dart';
class VideoCallScreen extends StatefulWidget {
  const VideoCallScreen({super.key, required this.channel, required this.token, required this.caller, required this.receiver, required this.isCaller});
  final String channel, token, caller, receiver;
  final bool isCaller;
  @override
  _VideoCallScreenState createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends State<VideoCallScreen> {
  int? _remoteUid;
  bool _localUserJoined = false;
  late RtcEngine _engine;
  bool _isMuted = false;
  bool _isCameraOn = true;
  bool showOptions = true;
  final FirebaseFirestore cloud = FirebaseFirestore.instance;
  @override
  void initState() {
    super.initState();
    initAgora();
    if(widget.isCaller) {
      play();
    }
  }

  AssetsAudioPlayer audioPlayer = AssetsAudioPlayer();

  void play(){
    audioPlayer.open(
        Audio("assets/ringing_outgoing1.mp3"));
  }

  void pause(){
    audioPlayer.dispose();
  }

  Future<void> initAgora() async {
    await [Permission.microphone, Permission.camera].request();

    _engine = createAgoraRtcEngine();
    await _engine.initialize(RtcEngineContext(
      appId: AppConstants.appId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint("local user ${connection.localUid} joined");
          setState(() {
            _localUserJoined = true;
          });
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("remote user $remoteUid joined");
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("remote user $remoteUid left channel");
          setState(() {
            _remoteUid = null;
          });
        },
        onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
          debugPrint(
              '[onTokenPrivilegeWillExpire] connection: ${connection.toJson()}, token: $token');
        },
      ),
    );

    await _engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    await _engine.enableVideo();
    await _engine.startPreview();
    await _engine.joinChannel(
      token: widget.token,
      channelId: "id",
      uid: 0,
      options: const ChannelMediaOptions(),
    );
  }

  Future<void> freeLine(String email) async {
    final QuerySnapshot existingUser = await cloud
        .collection('user_list')
        .where('email', isEqualTo: email)
        .get();
    await cloud.collection("user_list").doc(existingUser.docs.first.id).update(
        {
          "line": "free"
        });
  }

  @override
  void dispose() {
    super.dispose();

    _dispose();
  }

  Future<void> _dispose() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  Widget _controlButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.black.withOpacity(0.7),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          IconButton(
            onPressed: () {
              _engine.leaveChannel();
              FirebaseFirestore.instance
                  .collection('calls')
                  .doc(widget.channel)
                  .update({"callStatus": "ended"});
              freeLine(widget.caller);
              freeLine(widget.receiver);
            },
            icon: const Icon(Icons.call_end, color: Colors.red),
            tooltip: 'End Call',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isMuted = !_isMuted;
              });
              _engine.muteLocalAudioStream(_isMuted);
            },
            icon: Icon(
              _isMuted ? Icons.mic_off : Icons.mic,
              color: Colors.white,
            ),
            tooltip: _isMuted ? 'Unmute' : 'Mute',
          ),
          IconButton(
            onPressed: () {
              _engine.switchCamera();
            },
            icon: const Icon(Icons.cameraswitch, color: Colors.white),
            tooltip: 'Switch Camera',
          ),
          IconButton(
            onPressed: () {
              setState(() {
                _isCameraOn = !_isCameraOn;
              });
              _engine.muteLocalVideoStream(!_isCameraOn);
            },
            icon: Icon(
              _isCameraOn ? Icons.videocam : Icons.videocam_off,
              color: Colors.white,
            ),
            tooltip: _isCameraOn ? 'Stop Camera' : 'Start Camera',
          ),
        ],
      ),
    );
  }

  Widget _remoteVideo() {
    if (_remoteUid != null) {
      return AgoraVideoView(
        controller: VideoViewController.remote(
          rtcEngine: _engine,
          canvas: VideoCanvas(uid: _remoteUid),
          connection: RtcConnection(channelId: 'id'),
        ),
      );
    } else {
      return const Center(
        child: Text(
          'ringing...',
          style: TextStyle(color: Colors.white),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: cloud.collection("calls").snapshots(),
            builder: (context, snapshot) {
              var calls = snapshot.data!.docs;
              for(int a=0; a<calls.length; a++){
                if(calls[a]['channelName'] == widget.channel && calls[a]['callStatus'] == "ended") {
                  pause();
                  endCall();
                  _engine.leaveChannel();
                  Navigator.pop(context);
                }
                if(calls[a]['channelName'] == widget.channel && calls[a]['callStatus'] == "ongoing"){
                  pause();
                }
              }
              return GestureDetector(
                onTap: (){
                  setState(() {
                    showOptions = !showOptions;
                  });
                },
                child: Center(
                  child: _remoteVideo(),
                ),
              );
            }
          ),
          Align(
            alignment: Alignment.topLeft,
            child: _isCameraOn ? SizedBox(
              width: 100,
              height: 150,
              child: Center(
                child: _localUserJoined
                    ? AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                )
                    : const CircularProgressIndicator(),
              ),
            ) : Container(),
          ),
          showOptions == true ? Align(
            alignment: Alignment.bottomCenter,
            child: _controlButtons(),
          ) : Container(),
        ],
      ),
    );
  }
}
