import 'package:chatfinance/Screens/agoraCall.dart';
import 'package:chatfinance/helper/show_toast.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:modal_progress_hud_nsn/modal_progress_hud_nsn.dart';
import '../constants/consts.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
        });
        showToast(isError: false, message: "New user added: ${user.displayName}");
      } else {
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
                if(userData['email'] == myEmail)
                  continue;
                final userName = userData['name'] ?? 'No Name';
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
                          border: Border.all(color: userName == name ? Colors.green: Colors.pink,
                          width: 3),
                          color: userName == name ? Colors.green: Colors.transparent,
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
            Expanded(
              child: Container(
                // height: MediaQuery.of(context).size.height*.82,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Material(
                      elevation: 5,
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(25), topRight: Radius.circular(25)),
                      color: Colors.purpleAccent.shade400,
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
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
                            IconButton(onPressed: () {
                              Navigator.push(context,
                              MaterialPageRoute(builder: (context) => VideoCallScreen(
                                channel: "chatChannel",
                              )));
                            },
                              icon: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30)
                                ),
                                child: const Icon(Icons.video_call_outlined,
                                    color: Colors.green,
                                size: 25,),
                              ),
                              tooltip: "video call",
                                ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(
                      height: MediaQuery.of(context).size.height*.7 - MediaQuery.of(context).viewInsets.bottom - 30,
                      child: StreamBuilder(
                          stream: getMessages(getChatId(myEmail, receiverId)),
                          builder: (context, snapshot) {
                            if(!snapshot.hasData) {
                              return const Center(
                                child: Text(
                                  'Start chat',
                                ),
                              );
                            }
                            var messages = snapshot.data!.docs;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
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
                              sendMessage(controller4.text);
                              controller4.clear();
                              focusNode.unfocus();
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
