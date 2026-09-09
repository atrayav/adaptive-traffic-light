#include <Arduino_APDS9960.h>

const unsigned long SAMPLE_INTERVAL_MS = 100;
unsigned long lastSampleMs = 0;

void setup() {
  Serial.begin(115200);
  while (!Serial) {
    ;
  }

  if (!APDS.begin()) {
    Serial.println("ERROR: APDS9960 initialization failed. Check board and Arduino_APDS9960 library.");
    while (true) {
      delay(1000);
    }
  }

  Serial.println("time_ms,proximity");
}

void loop() {
  const unsigned long now = millis();

  if (now - lastSampleMs < SAMPLE_INTERVAL_MS) {
    return;
  }

  lastSampleMs = now;

  if (APDS.proximityAvailable()) {
    const int proximity = APDS.readProximity();

    Serial.print(now);
    Serial.print(',');
    Serial.println(proximity);
  }
}
