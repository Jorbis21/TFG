import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class HomePage extends StatefulWidget{
  HomePage({super.key, required this.title});
  final String title;
  @override
  HomePageState createState() => HomePageState();
}

class HomePageState extends State<HomePage>{
  bool connect = false;
  String iconPath = 'assets/icons/bluetooth-slash.svg';
  List<String> RxData = [];
  List<String> TxData = [];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 67, 67, 67),
      appBar: _appBar(),
      body: ListView(
        children: [
          const SizedBox(height: 40,),
          _recieveData()
          
        ],
      )
    );
  }

  Column _recieveData() {
    return Column(
          children: [
            const Text(
          ' Recieve Data',
          style: TextStyle(
            color: Color.fromARGB(255, 210, 210, 210),
            fontSize: 20,
            fontWeight: FontWeight.bold
          ),
        ),
        Container(
          margin: const EdgeInsets.all(3.0),
          width:1400,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color.fromARGB(255, 0, 0, 0),
              width:2
            )
          ),
          height: 90,
          child: Text(
            RxData.join("\n"),
            style: const TextStyle(
              color: Color.fromARGB(255, 210, 210, 210),
            ),
          )
        )
          ],
        );
  }

  AppBar _appBar() {
    return AppBar(
      centerTitle: true,
      elevation: 0.0,
      backgroundColor: const Color.fromARGB(137, 41, 41, 41),
      title: const Text(
        'Medidor de Potencia',
        style: TextStyle(
          color: Color.fromARGB(255, 210, 210, 210),
          fontSize: 18,
          fontWeight: FontWeight.bold
        ),
      ),
      actions: [
        GestureDetector(
          onTap: () {
            connect = !connect;
            setState(() {});
            //iconPath = 'assets/icons/bluetooth-signal.svg';
            //llamada a funcion de conexion ble
            /*if(isConnect){
              iconPath = 'assets/icons/bluetooth-on.svg';
            }
            else{
              iconPath = 'assets/icons/bluetooth-slash.svg';
            }*/
          },
          child: Container(
            margin: const EdgeInsets.all(10),
            width: 37,
            decoration: BoxDecoration(
              color: const Color.fromARGB(255, 118, 180, 231),
              borderRadius: BorderRadius.circular(10),
              //border: Border.all(color: Colors.black, width: 2)
            ),
            alignment: Alignment.center,
            child: SvgPicture.asset(
              connect ? 'assets/icons/bluetooth-slash.svg' :'assets/icons/bluetooth-on.svg',
            ),
          ),
        )
      ],
    );
  }
}
  
 
  
  
