#include "HX711.h"

const int LOADCELL_DOUT_PIN = 2;
const int LOADCELL_SCK_PIN = 3;
HX711 scale;

void setup() {
  // put your setup code here, to run once:
  Serial.begin(115200);
  scale.begin(LOADCELL_DOUT_PIN, LOADCELL_SCK_PIN);
  scale.set_scale();                      // this value is obtained by calibrating the scale with known weights; see the README for details
  scale.tare();
 
}

void loop() {
  // put your main code here, to run repeatedly:
  while(!scale.is_ready());
  Serial.println(scale.get_units(10));
}
