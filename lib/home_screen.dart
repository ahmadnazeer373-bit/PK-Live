import 'package:flutter/material.dart';
import 'live_room_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  final List<Map<String, String>> liveUsers = const [

    {
      "name": "Ali",
      "image": "👨",
    },
    {
      "name": "Sara",
      "image": "👩",
    },
    {
      "name": "Ahmed",
      "image": "👨‍💻",
    },
    {
      "name": "Ayesha",
      "image": "👩‍🎤",
    },
    {
      "name": "Zain",
      "image": "🧑",
    },

  ];


  void openLiveRoom(BuildContext context, String name) {

    print("Opening Live Room: $name");

    Navigator.push(

      context,

      MaterialPageRoute(

        builder: (context) => LiveRoomScreen(

          userName: name,

        ),

      ),

    );

  }


  @override
  Widget build(BuildContext context) {

    return Scaffold(

      backgroundColor: Colors.black,


      body: SafeArea(

        child: Column(

          children: [


            const Padding(

              padding: EdgeInsets.all(15),

              child: Row(

                mainAxisAlignment:
                MainAxisAlignment.spaceAround,

                children: [

                  Text(
                    "Mine",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),

                  Text(
                    "Party",
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 18,
                    ),
                  ),

                  Text(
                    "Live",
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                ],

              ),

            ),


            const Divider(
              color: Colors.white24,
            ),



            SizedBox(

              height: 110,

              child: ListView.builder(

                scrollDirection: Axis.horizontal,

                itemCount: liveUsers.length,

                itemBuilder: (context,index){

                  final user = liveUsers[index];


                  return GestureDetector(

                    onTap: () {

                      openLiveRoom(
                        context,
                        user["name"]!,
                      );

                    },


                    child: Column(

                      children: [

                        CircleAvatar(

                          radius: 32,

                          backgroundColor:
                          Colors.redAccent,

                          child: Text(

                            user["image"]!,

                            style: const TextStyle(
                              fontSize: 30,
                            ),

                          ),

                        ),


                        Text(

                          user["name"]!,

                          style: const TextStyle(
                            color: Colors.white,
                          ),

                        ),

                      ],

                    ),

                  );

                },

              ),

            ),



            Expanded(

              child: GridView.builder(

                padding:
                const EdgeInsets.all(10),


                itemCount:
                liveUsers.length,


                gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(

                  crossAxisCount: 2,

                  crossAxisSpacing: 10,

                  mainAxisSpacing: 10,

                  childAspectRatio: 0.75,

                ),



                itemBuilder: (context,index){


                  final user = liveUsers[index];


                  return InkWell(

                    onTap: () {

                      openLiveRoom(

                        context,

                        user["name"]!,

                      );

                    },


                    child: Container(

                      decoration: BoxDecoration(

                        color: Colors.white12,

                        borderRadius:
                        BorderRadius.circular(15),

                      ),


                      child: Column(

                        children: [


                          Expanded(

                            child: Center(

                              child: Text(

                                user["image"]!,

                                style:
                                const TextStyle(

                                  fontSize: 80,

                                ),

                              ),

                            ),

                          ),



                          Padding(

                            padding:
                            const EdgeInsets.all(10),


                            child: Text(

                              user["name"]!,

                              style:
                              const TextStyle(

                                color: Colors.white,

                                fontSize: 18,

                                fontWeight:
                                FontWeight.bold,

                              ),

                            ),

                          ),

                        ],

                      ),

                    ),

                  );


                },

              ),

            ),


          ],

        ),

      ),

    );

  }

}
