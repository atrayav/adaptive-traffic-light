#include <Arduino.h>

constexpr uint8_t TRIG_PIN = 2;
constexpr uint8_t ECHO_PIN = 3;
constexpr unsigned long ECHO_TIMEOUT_US = 30000;
constexpr unsigned long SAMPLE_INTERVAL_MS = 60;

unsigned long lastSampleMs = 0;

void setup() {
  Serial.begin(115200);
  pinMode(TRIG_PIN, OUTPUT);
  digitalWrite(TRIG_PIN, LOW);
  pinMode(ECHO_PIN, INPUT);

  while (!Serial) {
    ;
  }

  Serial.println("time_ms,distance_mm,valid");
}

void loop() {
  const unsigned long now = millis();

  if (now - lastSampleMs < SAMPLE_INTERVAL_MS) {
    return;
  }

  lastSampleMs = now;

  // Send a 10 us trigger pulse.
  digitalWrite(TRIG_PIN, LOW);
  delayMicroseconds(2);
  digitalWrite(TRIG_PIN, HIGH);
  delayMicroseconds(10);
  digitalWrite(TRIG_PIN, LOW);

  const unsigned long duration = pulseIn(ECHO_PIN, HIGH, ECHO_TIMEOUT_US);

  // Convert round-trip time to distance in mm.
  const uint32_t distanceMm = (duration * 343UL) / 2000UL;
  const bool valid = duration != 0 && distanceMm > 0 && distanceMm <= 65535;

  Serial.print(now);
  Serial.print(',');
  Serial.print(valid ? distanceMm : 0);
  Serial.print(',');
  Serial.println(valid ? 1 : 0);
}
