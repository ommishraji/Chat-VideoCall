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
  bool issignup = true;
  String forgotpassword = 'Forget Password?';
  String login = 'LOGIN';
  String signuptext = 'Don\'t have an Account?';
  String signup = 'Sign Up';
  String welcome = 'Welcome Back!';
  String welcomsub = 'Login to proceed';
  String hinttext = 'Enter name (optional)';
  TextEditingController controller1 = TextEditingController();
  TextEditingController controller2 = TextEditingController();
  TextEditingController controller3 = TextEditingController();
  TextEditingController controller4 = TextEditingController();
  late String name = '', email , password;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();
  final FirebaseFirestore cloud = FirebaseFirestore.instance;
  String reciverid ='';
  late String message;
  late String myemail;
  double paddingValue = 0.0;

  void loginfunction(){
    setState(() {
      forgotpassword = 'Forget Password?';
      login = 'LOGIN';
      signuptext = 'Don\'t have an Account?';
      signup = 'Sign Up';
      welcome = 'Welcome Back!';
      welcomsub = 'Login to proceed';
      hinttext = 'Enter name (optional)';
    });
    issignup = true;
    controller2.clear();
    controller1.clear();
    controller3.clear();
  }

  void signupfunction(){
    setState(() {
      forgotpassword = 'Verify Email via verification link';
      login = 'SIGN UP';
      signuptext = 'Already have an account?';
      signup = 'Login';
      welcome = 'Welcome!';
      welcomsub = 'Create new account';
      hinttext = 'Enter name';
    });
    issignup = false;
    controller2.clear();
    controller1.clear();
    controller3.clear();
  }

  Future<void> signupprocess() async{
    setState(() {
      spin = true;
    });
    try{
      UserCredential? newuser;
      newuser = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: email, password: password);
      User user = newuser.user!;
      await user.sendEmailVerification();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Verification Email sent to ${user.email}. Please verify to Proceed')));
      loginfunction();
      controller1.clear();
      controller2.clear();
      cloud.collection('userlist').add({
        'name': name,
        'email': user.email,
      });
      setState(() {
        spin = false;
      });
    }
    catch(e){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to register: $e')),
      );
      controller2.clear();
      setState(() {
        spin = false;
      });
    }
  }

  void loginprocess() async {
    setState(() {
      spin = true;
    });
    try{
      final fire = FirebaseAuth.instance;
      final user = await fire.signInWithEmailAndPassword(email: email, password: password);
      User? userdata = user.user;
      myemail = email;
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$e')),
      );
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
    welcomsub = 'Create new account';
    try {
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      spin = false;
    }
  }

  void googelsign() async {
    User? user = await _signInWithGoogle();
    if (user != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sign in successful: ${user.displayName}')));
      isLogged = true;
      welcome = 'Home';
      myemail = user.email!;
      cloud.collection('userlist').add({
        'name': user.displayName,
        'email' : user.email,
        'imageurl': user.photoURL,
      });
    }
    setState(() {
      spin = false;
    });
  }

  Future<void> sendMessage(String message) async {
    if(reciverid != ''){
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('Something went wrong');
      }
      String chatId = getChatId(user.email!, reciverid);
      await cloud.collection('messages').doc(chatId).collection('chats').add({
        'senderEmail': user.email,
        'receiverEmail': reciverid,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
      });
    }
    else{
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(
          'Please select someone to chat',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        backgroundColor: Colors.deepPurpleAccent,)
      );
    }
  }
  String getChatId(String email1, String email2) {
    return email1.hashCode <= email2.hashCode ? '$email1-$email2' : '$email2-$email1';
  }

  Stream<QuerySnapshot> getMessages(String chatId) {
    return cloud.collection('messages').doc(chatId).collection('chats').orderBy('timestamp').snapshots();
  }

  Future<void> signout() async{
    await _auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.deepPurpleAccent,
      body: SizedBox(
        height: MediaQuery.sizeOf(context).height*1,
        child: ListView.builder(
          itemCount: 1,
          itemBuilder: (BuildContext context, int index) {
            return  isLogged == false ?  logginscreen(context): utility(context);
          },
        ),
      ),
    );
  }

  logginscreen(BuildContext context) {
    return Stack(
        children: [Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: MediaQuery.of(context).size.height*.15,
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
                      welcomsub,
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
                            decoration: boxkadecoration1.copyWith(hintText: hinttext),
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
                          }, child: Text(forgotpassword)),
                          Container(
                            height: 40,
                            width: 500,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              color: Colors.deepOrange,
                            ),
                            child: TextButton(onPressed: (){
                              setState(() {
                                issignup == true? loginprocess(): signupprocess();
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
                    signuptext,
                    style: const TextStyle(
                      color: Colors.grey,
                    ),
                  ),
                  TextButton(onPressed: (){
                    issignup == true ? signupfunction():loginfunction();
                  },
                    child: Text(signup),
                  )
                ],
              ),
              TextButton(
                  onPressed: () {
                    setState(() {
                      googelsign();
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
                          'Continue with Google'
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
    return Column(
      children: [
        SizedBox(
          height: MediaQuery.of(context).size.height*.16,
          child: Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: cloud.collection('userlist').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasData) {
                  List<String> emails=[];
                  List<String> names = [];
                  final users = snapshot.data!.docs;
                  List<Widget> userWidgets = [];
                  for (var user in users) {
                    final userData = user.data() as Map<String, dynamic>;
                    final userName = userData['name'] ?? 'No Name';
                    final userEmail = userData['email'] ?? 'No Email';
                    final userPhotoURL = userData['imageurl'] ??
                        'https://blogger.googleusercontent.com/img/b/R29vZ2xl/AVvXsEiV3gpnIGEekljD3OLn8d67SU0Qs3vZQDICKltYLyv5qhHIdcA_-ZFAgQ1szymkNNM2lgrxFbrNStMshSZr3CKSJVpdX2Fl894YO_De__XUEsZyib03OlNnJ6zYbxWvImCGfj9od9h9XO20btbsIkRo35BqbZMxV-v2gBRbyy6UFcxchxV51kTrQMy-oMU/s480/360_F_470299797_UD0eoVMMSUbHCcNJCdv2t8B2g1GVqYgs.jpg';
                    emails.add(userEmail);
                    names.add(userName);
                    userWidgets.add(Row(
                      children: [
                        Column(
                          children: [
                            CircleAvatar(
                              backgroundImage: NetworkImage(userPhotoURL),
                              radius: 35,
                            ),
                            Text(userName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold
                            ),),
                          ],
                        ),
                      ],
                    ));
                  }
                  return ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: userWidgets.length,
                    itemBuilder: (context, index){
                      return PaddingItem(
                          context,
                          userWidgets[index],
                          emails[index],
                          names[index]
                      );
                    },
                  );
                }
                else {
                  return const CircularProgressIndicator();
                }

              }
            ),
          ),
        ),
        Container(
          height: MediaQuery.of(context).size.height*.82,
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
                          signout();
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
                      SizedBox(
                        height: 35,
                        child: FloatingActionButton.extended(onPressed: () {
                        },
                          label: const Text('Pay',
                          style: TextStyle(
                            color: Colors.white
                          ),),
                          icon: const Icon(Icons.currency_rupee,
                            color: Colors.white,),
                          backgroundColor: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: StreamBuilder(
                    stream: getMessages(getChatId(myemail, reciverid)),
                    builder: (context, snapshot) {
                      if(!snapshot.hasData) {
                        return const Center(
                          child: Text(
                            'Start chat',
                          ),
                        );
                      }
                      var messages = snapshot.data!.docs;
                      return ListView.builder(
                        itemCount: messages.length,
                        itemBuilder: (context, index){
                          var message = messages[index];
                          bool isme = message['senderEmail'] == myemail;
                          return ListTile(
                            title: Align(
                              alignment: isme? Alignment.centerRight: Alignment.centerLeft,
                              child: Material(
                                color: isme? Colors.purpleAccent.shade400: Colors.purpleAccent.shade700,
                                borderRadius: isme? const BorderRadius.only(
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
                        width: MediaQuery.of(context).size.width*.83,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 2),
                          child: TextField(
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
                      },
                          icon: const Icon(Icons.send,
                            color: Colors.deepPurpleAccent,))
                    ],
                  ),
                ),
              )
            ],
          ),
        )
      ],
    );
  }

  PaddingItem(BuildContext context, Widget child, String email, String name1){
    return GestureDetector(
      onTap: (){
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:
        Text(
          'Press & hold a second to chat with $name',
        ),
          backgroundColor: Colors.deepPurpleAccent,
          duration: const Duration(milliseconds: 200),));
      },
      onTapDown: (TapDownDetails details) {
        setState(() {
          paddingValue = 5.0;
          reciverid = email;
          name = name1;
        });
      },
      onTapUp: (TapUpDetails details) {
        setState(() {
          paddingValue = 0.0;
        });
      },
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 100),
        padding: EdgeInsets.only(top: 24+paddingValue, left: 10+paddingValue, right: 10+paddingValue, bottom: 10+paddingValue),
        child: child,
      ),
    );
  }
}
