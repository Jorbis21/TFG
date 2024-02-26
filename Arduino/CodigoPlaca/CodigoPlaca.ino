#include "HX711.h"
#include <BLEDevice.h>
#include <BLEServer.h>
#include <BLEUtils.h>
#include <BLE2902.h>

//HX711 definitions
const int LOADCELL_DOUT_PIN = 2;
const int LOADCELL_SCK_PIN = 3;
HX711 scale;

//BLE Service definitions
BLEServer *pServer = NULL;
BLECharacteristic * pTxCharacteristic;
bool deviceConnected = false;
bool oldDeviceConnected = false;
String txValue;//this is the data send

#define SERVICE_UUID           "6E400001-B5A3-F393-E0A9-E50E24DCCA9E" // UART service UUID
#define CHARACTERISTIC_UUID_RX "6E400002-B5A3-F393-E0A9-E50E24DCCA9E"
#define CHARACTERISTIC_UUID_TX "6E400003-B5A3-F393-E0A9-E50E24DCCA9E"

class MyServerCallbacks: public BLEServerCallbacks {
    void onConnect(BLEServer* pServer) {
      deviceConnected = true;
    };

    void onDisconnect(BLEServer* pServer) {
      deviceConnected = false;
    }
};


//Esta clase ha que modificarla para que cuando reciba cierto caracter
//haga la tara y lo de la sincronizacion
class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue();
      if(rxValue.size() == 1){
        switch(rxValue.at(0)){
          case 't':
            scale.tare();
            pTxCharacteristic->setValue("Tara realizada");
            pTxCharacteristic->notify();
            break;
          case 's':
            //hay que ver si se le envia una variable para para la calibracion
            //o no, y si no ver que poner en el set_scale
            scale.set_scale(2280.f);
            pTxCharacteristic->setValue("Sincronizacion realizada");
            pTxCharacteristic->notify();
            break;
          default:
          break;
        }
      }
    }
};

void BLEInit(){
  // Create the BLE Device
  BLEDevice::init("Medidor de Potencia");

  // Create the BLE Server
  pServer = BLEDevice::createServer();
  pServer->setCallbacks(new MyServerCallbacks());

  // Create the BLE Service
  BLEService *pService = pServer->createService(SERVICE_UUID);

  // Create a BLE Characteristic
  pTxCharacteristic = pService->createCharacteristic(
										CHARACTERISTIC_UUID_TX,
										BLECharacteristic::PROPERTY_NOTIFY
									);
                      
  pTxCharacteristic->addDescriptor(new BLE2902());

  BLECharacteristic * pRxCharacteristic = pService->createCharacteristic(
											 CHARACTERISTIC_UUID_RX,
											BLECharacteristic::PROPERTY_WRITE
										);

  pRxCharacteristic->setCallbacks(new MyCallbacks());

  // Start the service
  pService->start();

  // Start advertising
  pServer->getAdvertising()->start();
}
void envioMensaje(std::string msg){
  pTxCharacteristic->setValue(msg);
  pTxCharacteristic->notify();
}
void ADCInit(){
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);

  envioMensaje("Antes de la escala");
  envioMensaje("Lectura: \t\t");
  envioMensaje(String(scale.read()).c_str());	// print a raw reading from the ADC

  envioMensaje("Lectura media: \t\t");
  envioMensaje(String(scale.read_average(20)).c_str());  	// print the average of 20 readings from the ADC

  envioMensaje("Toma valor: \t\t");
  envioMensaje(String(scale.get_value(5)).c_str());		// print the average of 5 readings from the ADC minus the tare weight (not set yet)

  Serial.print("Toma unidades: \t\t");
  Serial.println(scale.get_units(5), 1);	// print the average of 5 readings from the ADC minus tare weight (not set) divided
						// by the SCALE parameter (not set yet)

  scale.set_scale(2280.f);                      // this value is obtained by calibrating the scale with known weights; see the README for details
  scale.tare();				        // reset the scale to 0

  Serial.println("After setting up the scale:");

  Serial.print("read: \t\t");
  Serial.println(scale.read());                 // print a raw reading from the ADC

  Serial.print("read average: \t\t");
  Serial.println(scale.read_average(20));       // print the average of 20 readings from the ADC

  Serial.print("get value: \t\t");
  Serial.println(scale.get_value(5));		// print the average of 5 readings from the ADC minus the tare weight, set with tare()

  Serial.print("get units: \t\t");
  Serial.println(scale.get_units(5), 1);        // print the average of 5 readings from the ADC minus tare weight, divided
						// by the SCALE parameter set with set_scale

  Serial.println("Readings:");
}
void setup() {
  Serial.begin(115200);

  
  
 

}

void loop() {
  if (deviceConnected) {
    Serial.print("one reading:\t");
    txValue = String(scale.get_units(), 3);
    Serial.print(txValue);
    pTxCharacteristic->setValue(txValue.c_str());
    pTxCharacteristic->notify();



    Serial.print("\t| average:\t");
    txValue = String(scale.get_units(10), 3);
    Serial.println(txValue);
    pTxCharacteristic->setValue(txValue.c_str());
    pTxCharacteristic->notify();

    scale.power_down();			        // put the ADC in sleep mode
    delay(5000);
    scale.power_up();

		delay(1000); // bluetooth stack will go into congestion, if too many packets are sent
	}

    // disconnecting
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    Serial.println("start advertising");
    oldDeviceConnected = deviceConnected;
  }
  // connecting
  if (deviceConnected && !oldDeviceConnected) {
	// do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }
}
