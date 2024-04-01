
#include <Preferences.h>

Preferences preferences;

void setup() {

  preferences.begin("MedPot", false);

  double sync = 20.f;

  preferences.putDouble("scale", sync);

  preferences.end();

  // Restart ESP
  ESP.restart();
}

void loop() {

}