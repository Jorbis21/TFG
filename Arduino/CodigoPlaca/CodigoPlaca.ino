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

void envioMensaje(std::string msg){
  pTxCharacteristic->setValue(msg);
  pTxCharacteristic->notify();
}

class MyCallbacks: public BLECharacteristicCallbacks {
    void onWrite(BLECharacteristic *pCharacteristic) {
      std::string rxValue = pCharacteristic->getValue();
        switch(rxValue.at(0)){
          case 't':
            scale.read();
            scale.read_average(20);
            scale.get_value(5);
            scale.get_units(5);	
            scale.set_scale(2280.f);
            scale.tare();			
            envioMensaje("Tara realizada");
            break;
          case 's':
            //hay que ver si se le envia una variable para para la calibracion
            //o no, y si no ver que poner en el set_scale
            scale.set_scale(2280.f);
            envioMensaje("Sincronizacion realizada");
            break;
          default:
          break;
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

void ADCInit(){
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);

  envioMensaje("Antes de la escala");
  envioMensaje("Lectura:");
  envioMensaje(String(scale.read()).c_str());	// print a raw reading from the ADC

  envioMensaje("Lectura media:");
  envioMensaje(String(scale.read_average(20)).c_str());  	// print the average of 20 readings from the ADC

  envioMensaje("Toma valor:");
  envioMensaje(String(scale.get_value(5)).c_str());		// print the average of 5 readings from the ADC minus the tare weight (not set yet)

  envioMensaje("Toma unidades:");
  envioMensaje(String(scale.get_units(5)).c_str());	// print the average of 5 readings from the ADC minus tare weight (not set) divided
						// by the SCALE parameter (not set yet)

  scale.set_scale(2280.f);                      // this value is obtained by calibrating the scale with known weights; see the README for details
  scale.tare();				        // reset the scale to 0

  envioMensaje("Despues de la escala");

  envioMensaje("Lectura:");
  envioMensaje(String(scale.read()).c_str());                 // print a raw reading from the ADC

  envioMensaje("Lectura media:");
  envioMensaje(String(scale.read_average(20)).c_str());       // print the average of 20 readings from the ADC

  envioMensaje("Toma valor:");
  envioMensaje(String(scale.get_value(5)).c_str());		// print the average of 5 readings from the ADC minus the tare weight, set with tare()

  envioMensaje("Toma unidades:");
  envioMensaje(String(scale.get_units(5)).c_str());        // print the average of 5 readings from the ADC minus tare weight, divided
						// by the SCALE parameter set with set_scale

  envioMensaje("Readings:");
}
void setup() {
  //Serial.begin(115200);
  BLEInit();
  ADCInit();
}

void loop() {
  if (deviceConnected) {
    envioMensaje("Una lectura:");
    txValue = String(scale.get_units(), 3);
    envioMensaje(txValue.c_str());

    envioMensaje("Media:");
    txValue = String(scale.get_units(10), 3);
    envioMensaje(txValue.c_str());

    scale.power_down();			        // put the ADC in sleep mode
    delay(5000);
    scale.power_up();

		delay(1000); // bluetooth stack will go into congestion, if too many packets are sent
	}

    // disconnecting
  if (!deviceConnected && oldDeviceConnected) {
    delay(500); // give the bluetooth stack the chance to get things ready
    pServer->startAdvertising(); // restart advertising
    //Serial.println("start advertising");
    oldDeviceConnected = deviceConnected;
  }
  // connecting
  if (deviceConnected && !oldDeviceConnected) {
	// do stuff here on connecting
    oldDeviceConnected = deviceConnected;
  }
}
