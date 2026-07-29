import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'home_screen.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {

  final TextEditingController emailController =
      TextEditingController();

  final TextEditingController passwordController =
      TextEditingController();


  Future<void> loginUser() async {

    print("Login function started");

    try {

      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
      );


      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Login Successful"),
        ),
      );
Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (context) => const HomeScreen(),
  ),
);

    } on FirebaseAuthException catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? "Login Failed"),
        ),
      );

    }

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: Colors.black,

      body: SafeArea(

        child: Padding(
          padding: const EdgeInsets.all(24),

          child: Column(

            mainAxisAlignment: MainAxisAlignment.center,

            children: [

              const Icon(
                Icons.live_tv,
                size: 90,
                color: Colors.redAccent,
              ),


              const SizedBox(height:20),


              const Text(
                "PK Live",
                style: TextStyle(
                  color: Colors.white,
                  fontSize:36,
                  fontWeight:FontWeight.bold,
                ),
              ),


              const SizedBox(height:40),


              TextField(

                controller: emailController,

                style: const TextStyle(
                  color: Colors.white,
                ),

                decoration: InputDecoration(

                  hintText:"Email",

                  hintStyle: const TextStyle(
                    color: Colors.grey,
                  ),

                  prefixIcon: const Icon(
                    Icons.email,
                    color: Colors.redAccent,
                  ),

                  filled:true,

                  fillColor:Colors.white10,

                  border:OutlineInputBorder(
                    borderRadius:BorderRadius.circular(15),
                  ),

                ),

              ),


              const SizedBox(height:20),


              TextField(

                controller: passwordController,

                obscureText:true,

                style: const TextStyle(
                  color: Colors.white,
                ),

                decoration: InputDecoration(

                  hintText:"Password",

                  hintStyle: const TextStyle(
                    color:Colors.grey,
                  ),

                  prefixIcon: const Icon(
                    Icons.lock,
                    color:Colors.redAccent,
                  ),

                  filled:true,

                  fillColor:Colors.white10,

                  border:OutlineInputBorder(
                    borderRadius:BorderRadius.circular(15),
                  ),

                ),

              ),


              const SizedBox(height:30),


              SizedBox(

                width:double.infinity,

                height:55,

                child:ElevatedButton(

                  onPressed: loginUser,

                  style:ElevatedButton.styleFrom(

                    backgroundColor:Colors.redAccent,

                    shape:RoundedRectangleBorder(

                      borderRadius:
                      BorderRadius.circular(15),

                    ),

                  ),


                  child:const Text(

                    "Login",

                    style:TextStyle(

                      color:Colors.white,

                      fontSize:18,

                    ),

                  ),

                ),

              ),


              const SizedBox(height:20),


              TextButton(

                onPressed:(){},

                child:const Text(

                  "Create New Account",

                  style:TextStyle(

                    color:Colors.redAccent,

                    fontSize:16,

                  ),

                ),

              ),


            ],

          ),

        ),

      ),

    );

  }


  @override
  void dispose() {

    emailController.dispose();

    passwordController.dispose();

    super.dispose();

  }

}