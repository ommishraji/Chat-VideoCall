import 'dart:async';
import 'package:assets_audio_player/assets_audio_player.dart';
import 'package:chatfinance/Screens/agoraCall.dart';
import 'package:chatfinance/helper/show_toast.dart';
import 'package:chatfinance/helper/audio_player.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../constants/consts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../helper/token_generator.dart';

class Homescreen extends StatefulWidget {
  const Homescreen({super.key});

  @override
  State<Homescreen> createState() => _HomescreenState();
}

class _HomescreenState extends State<Homescreen> {
  bool spin = false;
  bool isLogged = false;
  bool isSignUp = true;
  String forgotPassword = 'Forget Password?';
  String login = 'LOGIN';
  String signUpText = 'Don\'t have an Account?';
  String signup = 'Sign Up';
  String welcome = 'Welcome Back!';
  String welcomeSub = 'Login to proceed';
  String hintText = 'Enter name (optional)';
  TextEditingController controller1 = TextEditingController();
  TextEditingController controller2 = TextEditingController();
  TextEditingController controller3 = TextEditingController();
  TextEditingController controller4 = TextEditingController();
  late String name = '', email , password;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore cloud = FirebaseFirestore.instance;
  String receiverId ='';
  late String message;
  late String myEmail;
  double paddingValue = 0.0;
  final ScrollController _scrollController = ScrollController();
  final GoogleSignIn googleSignIn = GoogleSignIn();
  FocusNode focusNode = FocusNode();
  int incomingCallIndex = -1;
  bool lineBusy = false;
  String? lastMessageId;

  void loginFunction(){
    setState(() {
      forgotPassword = 'Forget Password?';
      login = 'LOGIN';
      signUpText = 'Don\'t have an Account?';
      signup = 'Sign Up';
      welcome = 'Welcome Back!';
      welcomeSub = 'Login to proceed';
      hintText = 'Enter name (optional)';
    });
    isSignUp = true;
    controller2.clear();
    controller1.clear();
    controller3.clear();
  }

  void signupFunction(){
    setState(() {
      forgotPassword = 'Verify Email via verification link';
      login = 'SIGN UP';
      signUpText = 'Already have an account?';
      signup = 'Login';
      welcome = 'Welcome!';
      welcomeSub = 'Create new account';
      hintText = 'Enter name';
    });
    isSignUp = false;
    controller2.clear();
    controller1.clear();
    controller3.clear();
  }

  Future<void> signUpProcess() async{
    setState(() {
      spin = true;
    });
    try{
      UserCredential? newUser;
      newUser = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: password);
      User user = newUser.user!;
      await user.sendEmailVerification();
      showToast(isError: false, message: 'Verification Email sent to ${user.email}. Please verify to Proceed');
      loginFunction();
      controller1.clear();
      controller2.clear();
      cloud.collection('user_list').add({
        'name': name,
        'email': user.email,
        'line': 'free'
      });
      setState(() {
        spin = false;
      });
    }
    catch(e){
      showToast(isError: false, message: 'Failed to register: $e');
      controller2.clear();
      setState(() {
        spin = false;
      });
    }
  }

  void loginProcess() async {
    setState(() {
      spin = true;
    });
    try{
      final fire = FirebaseAuth.instance;
      final user = await fire.signInWithEmailAndPassword(email: email, password: password);
      User? userdata = user.user;
      myEmail = email;
      controller1.clear();
      controller2.clear();
      if(userdata!.emailVerified){
        isLogged = true;
        setState(() {
          spin = false;
        });
        welcome = 'Hello';
        final QuerySnapshot existingUser = await cloud
            .collection('user_list')
            .where('email', isEqualTo: userdata.email)
            .get();
        await cloud.collection("user_list").doc(existingUser.docs.first.id).update(
            {
              "line": "free"
            });
      }
      else{
        throw Exception('Verification link has been sent to your email id. Please verify to proceed');
      }
    }
    catch(e){
      showToast(isError: false, message: '$e');
      controller2.clear();
      setState(() {
        spin = false;
      });
    }
  }

  Future<User?> _signInWithGoogle() async {
    setState(() {
      spin = true;
    });
    welcome = 'Welcome!';
    welcomeSub = 'Create new account';
    try {
      await googleSignIn.signOut();
      // await googleSignIn.disconnect();
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      final GoogleSignInAuthentication googleAuth = await googleUser!
          .authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final UserCredential userCredential = await _auth.signInWithCredential(
          credential);
      return userCredential.user;
    }
    catch(e){
      showToast(isError: false, message: "$e");
      spin = false;
    }
    return null;
  }

  void googleSign() async {
    User? user = await _signInWithGoogle();
    if (user != null) {
      final QuerySnapshot existingUser = await cloud
          .collection('user_list')
          .where('email', isEqualTo: user.email)
          .get();

      if (existingUser.docs.isEmpty) {
        await cloud.collection('user_list').add({
          'name': user.displayName,
          'email': user.email,
          'imageUrl': user.photoURL,
          'line': "free",
        });
        showToast(isError: false, message: "New user added: ${user.displayName}");
      } else {
        await cloud.collection("user_list").doc(existingUser.docs.first.id).update(
            {
              "line": "free"
            });
        showToast(isError: false, message: "Welcome back, ${user.displayName}!");
      }

      isLogged = true;
      welcome = 'Home';
      myEmail = user.email!;
    }
    setState(() {
      spin = false;
    });
  }

  Future<void> sendMessage(String message) async {
    if(receiverId != ''){
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('Something went wrong');
      }
      String chatId = getChatId(user.email!, receiverId);
      await cloud.collection('messages').doc(chatId).collection('chats').add({
        'senderEmail': user.email,
        'receiverEmail': receiverId,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    else{
      showToast(isError: false, message: "Please select one to chat");
    }
  }

  Future<void> initiateVideoCall() async {
    if(receiverId != ''){
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('Something went wrong');
      }
      else {
        String videoCallChannelName = getChatId(user.email!, receiverId);
        await cloud.collection('calls').doc(videoCallChannelName).set({
          'dialer': user.email,
          'dialerName': user.displayName,
          'receiver': receiverId,
          'receiverName': name,
          'token': "007eJxTYLifeOP14op//jZnssUvF/Nqqe9+4c3DepOhdmrN4eClt7kUGEwsLIySTY3STC2NjExSE5MtktOMk5ItjcxNjQ0sEpNMU3Ni0hsCGRlC9Y8zMEIhiM/EkJnCwAAAB2gdzg==",
          'channelName': videoCallChannelName,
          'callStatus': "ringing",
          'timestamp': FieldValue.serverTimestamp(),
        });
        final QuerySnapshot existingUser = await cloud
            .collection('user_list')
            .where('email', isEqualTo: myEmail)
            .get();
        await cloud.collection("user_list").doc(existingUser.docs.first.id).update(
            {
              "line": "busy"
            });
        Navigator.push(context,
            MaterialPageRoute(builder: (context) => VideoCallScreen(
              channel: videoCallChannelName,
              token: "007eJxTYLifeOP14op//jZnssUvF/Nqqe9+4c3DepOhdmrN4eClt7kUGEwsLIySTY3STC2NjExSE5MtktOMk5ItjcxNjQ0sEpNMU3Ni0hsCGRlC9Y8zMEIhiM/EkJnCwAAAB2gdzg==",
              caller: user.email.toString(),
              receiver: receiverId,
              isCaller: true,
            )));
      }
    }
    else{
      showToast(isError: false, message: "Please select one to call");
    }
  }

  String getChatId(String email1, String email2) {
    return email1.hashCode <= email2.hashCode ? '$email1-$email2' : '$email2-$email1';
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return cloud.collection('messages').doc(chatId).collection('chats').orderBy('timestamp').snapshots();
  }

  Future<void> signOut() async{
    await _auth.signOut();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        body: Container(
          height: MediaQuery.sizeOf(context).height*1-1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
              Colors.deepPurpleAccent,
              Colors.deepPurpleAccent,
              Colors.purple.shade50
            ]),
          ),
          child: isLogged == false ?  logInScreen(context): utility(context)
        ),
      ),
    );
  }

  logInScreen(BuildContext context) {
    return Stack(
        children: [
          Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height*.1,
              child: Padding(
                padding: const EdgeInsets.only(left: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      welcome,
                      style: GoogleFonts.unna(
                        textStyle: TextStyle(
                          color: Colors.purple.shade50,
                          fontSize: 30
                        )
                      ),
                    ),
                    Text(
                      welcomeSub,
                      style: GoogleFonts.unna(
                          textStyle: TextStyle(
                              color: Colors.purple.shade50,
                              fontSize: 20,
                          )
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              height: MediaQuery.of(context).size.height*.85,
              decoration: BoxDecoration(
                color: Colors.purple.shade50,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
            )
          ],
        ),
        Positioned(
          top: MediaQuery.sizeOf(context).height*.27,
          left: MediaQuery.sizeOf(context).width*.1,
          child: Column(
            children: [
              SizedBox(
                height: MediaQuery
                    .sizeOf(context)
                    .height * .5,
                width: MediaQuery
                    .sizeOf(context)
                    .width * .8,
                child: ModalProgressHUD(
                  inAsyncCall: spin,
                  child: Material(
                    elevation: 10,
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TextField(
                            controller: controller1,
                            onChanged: (value){
                              email = value;
                            },
                            decoration: boxkadecoration1.copyWith(hintText: 'Enter the Email ID'),
                          ),
                          TextField(
                            controller: controller3,
                            onChanged: (value){
                              name = value;
                            },
                            decoration: boxkadecoration1.copyWith(hintText: hintText),
                          ),
                          TextField(
                            controller: controller2,
                            obscureText: true,
                            onChanged: (value){
                              password = value;
                            },
                            decoration: boxkadecoration1.copyWith(hintText: 'Password'),
                          ),
                          TextButton(onPressed: (){
                            //Impliment forget password solution
                          }, child: Text(forgotPassword)),
                          Container(
                            height: 40,
                            width: 500,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.deepOrange,
                            ),
                            child: TextButton(onPressed: (){
                              setState(() {
                                isSignUp == true? loginProcess(): signUpProcess();
                              });
                            }, child: Text(login,
                              style: const TextStyle(
                                  color: Colors.white
                              ),)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  Text(
                    signUpText,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  TextButton(onPressed: (){
                    isSignUp == true ? signupFunction():loginFunction();
                  },
                    child: Text(signup),
                  )
                ],
              ),
              TextButton(
                  onPressed: () {
                    setState(() {
                      googleSign();
                    });
                  },
                  child: Container(
                    height: MediaQuery.of(context).size.width*.15,
                    width: MediaQuery.of(context).size.width*.7,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.deepOrange, width: 1),
                      borderRadius: BorderRadius.circular(30),
                      color: Colors.white,
                    ),
                    child: Material(
                      elevation: 10,
                      borderRadius: BorderRadius.circular(30),
                      child: const ListTile(
                        leading: CircleAvatar(
                          child: Image(image: AssetImage('images/logo.jpg'),),),
                        title: Text(
                          'Continue with Google',
                          softWrap: true,
                          style: TextStyle(
                            fontSize: 15
                          ),
                        ),
                      ),
                    ),
                  ))
            ],
          ),
        )
    ]
    );
  }

  utility(BuildContext context) {
    return ListView(
      children: [
        StreamBuilder<QuerySnapshot>(
          stream: cloud.collection('user_list').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasData) {
              List<String> emails=[];
              List<String> names = [];
              final users = snapshot.data!.docs;
              List<Widget> userWidgets = [];
              for (var user in users) {
                final userData = user.data() as Map<String, dynamic>;
                if(userData['email'] != myEmail) {
                  var userName = userData['name'] ?? 'No Name';
                  userName = userName.toString().length > 15 ? "${userName.toString().substring(0, 12)}..." : userName;
                  final userEmail = userData['email'] ?? 'No Email';
                  final userPhotoURL = userData['imageUrl'] ??
                      'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiV3gpnIGEekljD3OLn8d67SU0Qs3vZQDICKltYLyv5qhHIdcA_-ZFAgQ1szymkNNM2lgrxFbrNStMshSZr3CKSJVpdX2Fl894YO_De__XUEsZyib03OlNnJ6zYbxWvImCGfj9od9h9XO20btbsIkRo35BqbZMxV-v2gBRbyy6UFcxchxV51kTrQMy-oMU/s480/360_F_470299797_UD0eoVMMSUbHCcNJCdv2t8B2g1GVqYgs.jpg';
                  emails.add(userEmail);
                  names.add(userName);
                  userWidgets.add(
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(360),
                                border: Border.all(color: userName == name
                                    ? Colors.green
                                    : Colors.pink,
                                    width: 3),
                                color: userName == name ? Colors.green : Colors
                                    .transparent,
                              ),
                              child: CircleAvatar(
                                backgroundImage: NetworkImage(userPhotoURL,),
                                radius: 35,
                              ),
                            ),
                            Text(userName,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold
                              ),),
                          ],
                        ),
                      ));
                }
              }
              return SizedBox(
                width: double.maxFinite,
                height: MediaQuery.of(context).size.height*.15,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: userWidgets.length,
                  itemBuilder: (context, index){
                    return appUsers(
                        context,
                        userWidgets[index],
                        emails[index],
                        names[index]
                    );
                  },
                ),
              );
            }
            else {
              return const CircularProgressIndicator();
            }

          }
        ),
        Stack(
          children: [
            Container(
              // height: MediaQuery.of(context).size.height*.82,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  StreamBuilder<QuerySnapshot>(
                    stream: cloud.collection("calls").snapshots(),
                    builder: (context, snapshot) {
                      var calls = snapshot.data!.docs;
                      int newIncomingCallIndex = -1;
                      for(int a=0; a<calls.length; a++){
                        if(calls[a]['receiver'] == myEmail && calls[a]['callStatus'] == "ringing") {
                          newIncomingCallIndex = a;
                          break;
                        }
                      }
                      WidgetsBinding.instance.addPostFrameCallback((_) async {
                        if (incomingCallIndex != newIncomingCallIndex) {
                          setState(() {
                            incomingCallIndex = newIncomingCallIndex;
                          });
                         await Future.delayed(const Duration(seconds: 10));
                         setState(() {
                           incomingCallIndex = -1;
                         });
                        }
                      });
                      return Material(
                        elevation: 5,
                        borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                        child: Container(
                          decoration: BoxDecoration(
                              borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                            gradient: lineBusy ? const LinearGradient(colors: [
                              Colors.red,
                              Colors.redAccent,
                            ]) : incomingCallIndex != -1 ? const LinearGradient(colors: [
                              Color(0xFF89216B),
                              Color(0xFFDA4453),
                            ]): LinearGradient(colors: [
                              Colors.purpleAccent.shade400,
                              Colors.purpleAccent.shade400,
                            ])
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: lineBusy ? const LineBusy() : incomingCallIndex != -1 ? IncomingCall(
                              token: snapshot.data!.docs[incomingCallIndex]['token'],
                              channelName: snapshot.data?.docs[incomingCallIndex]['channelName'],
                              caller: snapshot.data?.docs[incomingCallIndex]['dialerName'],
                              callerId: snapshot.data?.docs[incomingCallIndex]['dialer'],
                              receiverId: snapshot.data?.docs[incomingCallIndex]['receiver'],
                              receiver: snapshot.data?.docs[incomingCallIndex]['receiverName'],
                            ) :
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                SizedBox(
                                  height: 35,
                                  child: IconButton(onPressed: () {
                                    signOut();
                                    setState(() {
                                      isLogged = false;
                                    });
                                  },
                                    icon: const Icon(Icons.power_settings_new,
                                      color: Colors.white,),
                                  ),
                                ),
                                Text(
                                    name!=''? 'Chatting with $name': 'Please select someone to chat',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontStyle: FontStyle.italic,
                                      fontSize: 15
                                  ),
                                ),
                                IconButton(onPressed: () async {
                                  if(receiverId == "") {
                                    showToast(isError: false, message: "Please select someone to call");
                                  }
                                  else{
                                  final QuerySnapshot receiverData = await cloud
                                      .collection('user_list')
                                      .where('email', isEqualTo: receiverId)
                                      .get();
                                  if (receiverData.docs.isNotEmpty) {
                                    if (receiverData.docs.first['line'] == "free") {
                                      generateToken();
                                      await initiateVideoCall();
                                    } else {
                                      setState((){
                                        lineBusy = true;
                                      });
                                      await Future.delayed(const Duration(seconds: 2));
                                      setState(() {
                                        lineBusy = false;
                                      });
                                    }
                                  }
                                  }


                                  // if(existingUser.docs.first['line'] == "free") {
                                  //   await initiateVideoCall();
                                  // }
                                  // else{
                                  //   showToast(isError: false, message: "Line Busy");
                                  // }
                                },
                                  icon: Material(
                                    elevation: 10,
                                    borderRadius: BorderRadius.circular(40),
                                    child: SizedBox(
                                        height: 35,
                                        width: 35,
                                        child: Image.asset('images/video_call.png')),
                                  ),
                                  // icon: Container(
                                  //   padding: const EdgeInsets.all(4),
                                  //   decoration: BoxDecoration(
                                  //       color: Colors.white,
                                  //       borderRadius: BorderRadius.circular(30)
                                  //   ),
                                  //   child: const Icon(Icons.video_call_outlined,
                                  //       color: Colors.green,
                                  //   size: 25,),
                                  // ),
                                  tooltip: "video call",
                                    ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }
                  ),
                  SizedBox(
                    height: MediaQuery.of(context).size.height*.7 - MediaQuery.of(context).viewInsets.bottom - 30,
                    child: StreamBuilder(
                        stream: getMessages(getChatId(myEmail, receiverId)),
                        builder: (context, snapshot) {
                          if(!snapshot.hasData || snapshot.data?.docs.map((doc)  => doc.data()).toList().length == 0) {
                            return const Center(
                              child: Text(
                                'Start chat',
                              ),
                            );
                          }
                          var messages = snapshot.data!.docs;
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            String currentLastMessageId = messages.last.id;

                            if (lastMessageId != currentLastMessageId) {
                              lastMessageId = currentLastMessageId;
                              messageReceived();
                            }
                            _scrollToBottom();
                          });
                          return ListView.builder(
                            controller: _scrollController,
                            itemCount: messages.length,
                            itemBuilder: (context, index){
                              var message = messages[index];
                              bool isMe = message['senderEmail'] == myEmail;
                              return ListTile(
                                title: Align(
                                  alignment: isMe? Alignment.centerRight: Alignment.centerLeft,
                                  child: Material(
                                    color: isMe? Colors.purpleAccent.shade400: Colors.purpleAccent.shade700,
                                    borderRadius: isMe? const BorderRadius.only(
                                        topRight: Radius.circular(30),
                                          topLeft: Radius.circular(30),
                                        bottomLeft: Radius.circular(30),
                                      ): const BorderRadius.only(
                                        topLeft: Radius.circular(30),
                                        topRight: Radius.circular(30),
                                        bottomRight: Radius.circular(30),
                                      ),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Text(
                                        message['message'],
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 16
                                        ),
                                        softWrap: true,
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          );
                        }
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Material(
                      borderRadius: BorderRadius.circular(30),
                      elevation: 10,
                      color: Colors.purple.shade50,
                      child: Row(
                        children: [
                          SizedBox(
                            width: MediaQuery.of(context).size.width*.8,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2),
                              child: TextField(
                                focusNode: focusNode,
                                onChanged: (value){
                                  message = value;
                                },
                                controller: controller4,
                                decoration: const InputDecoration(
                                    hintText: 'Type message',
                                    border: InputBorder.none),
                              ),
                            ),
                          ),
                          IconButton(onPressed: (){
                            if(controller4.text != '') {
                              sendMessage(controller4.text);
                              messageSent();
                              controller4.clear();
                              focusNode.unfocus();
                            }
                            else{
                              showToast(isError: false, message: "Write your message");
                            }
                          },
                              icon: const Icon(Icons.send,
                                color: Colors.deepPurpleAccent,))
                        ],
                      ),
                    ),
                  )
                ],
              ),
            ),
            // Positioned(
            //   bottom: 0,
            //     child:
            //
            // ),
          ],
        )
      ],
    );
  }

  appUsers(BuildContext context, Widget child, String email, String name1){
    return GestureDetector(
      onTap: (){
        setState(() {
          name = name1;
          receiverId = email;
        });
      },
      child: child,
    );
  }
}




class IncomingCall extends StatefulWidget {
  IncomingCall({
    super.key,
    required this.token,
    required this.channelName,
    required this.caller,
    required this.callerId,
    required this.receiverId,
    required this.receiver
  });
  final String channelName, token, caller, callerId, receiver, receiverId;

  @override
  State<IncomingCall> createState() => _IncomingCallState();
}

class _IncomingCallState extends State<IncomingCall> {
  final FirebaseFirestore cloud = FirebaseFirestore.instance;

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

  AssetsAudioPlayer audioPlayer = AssetsAudioPlayer();

  void play(){
    audioPlayer.open(
        Audio("assets/ringtone1.mp3"));
  }

  void pause(){
    audioPlayer.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
    play();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    pause();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        IconButton(onPressed: (){
          endCall();
          freeLine(widget.callerId);
          freeLine(widget.receiverId);
          cloud.collection('calls')
              .doc(widget.channelName)
              .update({"callStatus": "ended"});
          pause();
        },
          icon: SizedBox(
              height: 35,
              width: 35,
              child: Image.asset('images/reject_call.png')),
        ),
        SizedBox(
          width: MediaQuery.of(context).size.width*.5,
          child: Text("Video Call from ${widget.caller}",
            maxLines: 2,
            textAlign: TextAlign.center,
            softWrap: true,
            style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
                fontSize: 16
            ),),
        ),
        IconButton(onPressed: () async {
          final QuerySnapshot existingUser = await cloud
              .collection('user_list')
              .where('email', isEqualTo: widget.receiverId)
              .get();
          await cloud.collection("user_list").doc(existingUser.docs.first.id).update(
              {
                "line": "busy"
              });
          cloud.collection('calls')
              .doc(widget.channelName)
              .update({"callStatus": "ongoing"});
          Navigator.push(context, MaterialPageRoute(builder: (context) => VideoCallScreen(
              channel: widget.channelName,
              token: widget.token,
              caller: widget.callerId,
              receiver: widget.receiverId,
            isCaller: false,
          )));
        },
          icon: Material(
            elevation: 10,
            borderRadius: BorderRadius.circular(30),
            child: SizedBox(
                height: 35,
                width: 35,
                child: Image.asset('images/video_call.png')),
          ),
        ),
      ],
    );
  }
}






class LineBusy extends StatefulWidget {
  const LineBusy({super.key});

  @override
  _LineBusyState createState() => _LineBusyState();
}

class _LineBusyState extends State<LineBusy> {
  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    busy();
    _startBlinking();
  }

  void _startBlinking() {
    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
      } else {
        setState(() {
          _isVisible = !_isVisible;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 35,
      child: Center(
        child: Text(
          "Line Busy",
          style: TextStyle(
            color: _isVisible
                ? Colors.white : Colors.red,
            fontWeight: FontWeight.w400,
            fontSize: 25,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }
}
