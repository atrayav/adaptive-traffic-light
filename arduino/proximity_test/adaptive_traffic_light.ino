#include <Arduino.h>
#include <SPI.h>

// ============================================================
// Adaptive Crosswalk - Arduino Nano 33 BLE
// Arduino = SPI master
// Arty A7  = SPI slave
//
// Packet:
//   Byte 0 : 0xA5
//   Byte 1 : distance_mm[15:8]
//   Byte 2 : distance_mm[7:0]
//   Byte 3 : flags
//              bit 0 = pedestrian button
//              bit 1 = sensor valid
//   Byte 4 : XOR checksum of bytes 0-3
//
// FPGA response:
//   bit 7 = response marker
//   bit 6 = vehicle red
//   bit 5 = vehicle yellow
//   bit 4 = vehicle green
//   bit 3 = pedestrian walk
//   bit 2 = request pending
//   bit 1 = sensor valid
//   bit 0 = vehicle present
// ============================================================


// SPI

constexpr uint8_t FPGA_CS_PIN = 10;

constexpr uint32_t SPI_CLOCK_HZ = 1000000;

SPISettings fpgaSPI(
    SPI_CLOCK_HZ,
    MSBFIRST,
    SPI_MODE0
);


// Ultrasonic Sensor

constexpr uint8_t TRIG_PIN = 2;
constexpr uint8_t ECHO_PIN = 3;

// Echo timeout: about 5 m.
constexpr unsigned long ECHO_TIMEOUT_US = 30000;


// Pedestrian Button
// Connect D7 to GND through the button. LOW means pressed.

constexpr uint8_t PED_BUTTON_PIN = 7;


// Traffic LEDs

constexpr uint8_t RED_LED_PIN    = 4;
constexpr uint8_t YELLOW_LED_PIN = 5;
constexpr uint8_t GREEN_LED_PIN  = 6;

// Optional walk LED.
constexpr uint8_t WALK_LED_PIN   = 8;


// Protocol

constexpr uint8_t MAGIC = 0xA5;

constexpr uint8_t FLAG_PED_BUTTON   = 0x01;
constexpr uint8_t FLAG_SENSOR_VALID = 0x02;


// Timing

// Sample every 60 ms, before the FPGA's 500 ms timeout.

constexpr unsigned long SAMPLE_INTERVAL_MS = 60;

unsigned long lastSampleTime = 0;


// Structures

struct DistanceReading
{
    uint16_t distanceMm;
    bool valid;
};


struct FPGAStatus
{
    bool validResponse;

    bool vehicleRed;
    bool vehicleYellow;
    bool vehicleGreen;

    bool pedestrianWalk;

    bool requestPending;
    bool sensorValid;
    bool vehiclePresent;
};


// Function declarations for the Arduino IDE.
DistanceReading readDistance();
uint8_t sendSensorPacket(uint16_t distanceMm, bool pedestrianButton, bool sensorValid);
FPGAStatus decodeFPGAStatus(uint8_t status);
void updateTrafficLights(const FPGAStatus& status);
void printStatus(const DistanceReading& distance, bool pedestrianButton,
                 uint8_t rawStatus, const FPGAStatus& status);
void setup();
void loop();


// Ultrasonic measurement

DistanceReading readDistance()
{
    // Send a 10 us trigger pulse.
    digitalWrite(TRIG_PIN, LOW);
    delayMicroseconds(2);

    digitalWrite(TRIG_PIN, HIGH);
    delayMicroseconds(10);

    digitalWrite(TRIG_PIN, LOW);

    const unsigned long duration =
        pulseIn(ECHO_PIN, HIGH, ECHO_TIMEOUT_US);

    if (duration == 0)
    {
        return {0, false};
    }

    // Convert round-trip time to distance in mm.

    const uint32_t distance =
        (duration * 343UL) / 2000UL;

    if (distance == 0 || distance > 65535)
    {
        return {0, false};
    }

    return {
        static_cast<uint16_t>(distance),
        true
    };
}


// Build/send packet

uint8_t sendSensorPacket(
    uint16_t distanceMm,
    bool pedestrianButton,
    bool sensorValid
)
{
    uint8_t packet[5];

    packet[0] = MAGIC;

    packet[1] =
        static_cast<uint8_t>(
            (distanceMm >> 8) & 0xFF
        );

    packet[2] =
        static_cast<uint8_t>(
            distanceMm & 0xFF
        );

    uint8_t flags = 0;

    if (pedestrianButton)
    {
        flags |= FLAG_PED_BUTTON;
    }

    if (sensorValid)
    {
        flags |= FLAG_SENSOR_VALID;
    }

    packet[3] = flags;

    packet[4] =
        packet[0] ^
        packet[1] ^
        packet[2] ^
        packet[3];


    SPI.beginTransaction(fpgaSPI);

    digitalWrite(FPGA_CS_PIN, LOW);

    // Wait for the FPGA to detect CS.
    delayMicroseconds(2);


    uint8_t fpgaResponse = 0;

    for (uint8_t i = 0; i < 5; ++i)
    {
        // Keep the latest status byte.
        fpgaResponse = SPI.transfer(packet[i]);
    }


    delayMicroseconds(2);

    digitalWrite(FPGA_CS_PIN, HIGH);

    SPI.endTransaction();

    return fpgaResponse;
}


// Decode FPGA status

FPGAStatus decodeFPGAStatus(uint8_t status)
{
    FPGAStatus result;

    result.validResponse =
        status & (1 << 7);

    result.vehicleRed =
        status & (1 << 6);

    result.vehicleYellow =
        status & (1 << 5);

    result.vehicleGreen =
        status & (1 << 4);

    result.pedestrianWalk =
        status & (1 << 3);

    result.requestPending =
        status & (1 << 2);

    result.sensorValid =
        status & (1 << 1);

    result.vehiclePresent =
        status & (1 << 0);

    return result;
}


// Drive LEDs from FPGA state

void updateTrafficLights(
    const FPGAStatus& status
)
{
    if (!status.validResponse)
    {
        return;
    }

    digitalWrite(
        RED_LED_PIN,
        status.vehicleRed ? HIGH : LOW
    );

    digitalWrite(
        YELLOW_LED_PIN,
        status.vehicleYellow ? HIGH : LOW
    );

    digitalWrite(
        GREEN_LED_PIN,
        status.vehicleGreen ? HIGH : LOW
    );

    digitalWrite(
        WALK_LED_PIN,
        status.pedestrianWalk ? HIGH : LOW
    );
}


// Serial debugging

void printStatus(
    const DistanceReading& distance,
    bool pedestrianButton,
    uint8_t rawStatus,
    const FPGAStatus& status
)
{
    Serial.print("Distance: ");

    if (distance.valid)
    {
        Serial.print(distance.distanceMm);
        Serial.print(" mm");
    }
    else
    {
        Serial.print("INVALID");
    }


    Serial.print(" | Ped: ");
    Serial.print(
        pedestrianButton ? "PRESSED" : "released"
    );


    Serial.print(" | FPGA: 0x");

    if (rawStatus < 0x10)
    {
        Serial.print('0');
    }

    Serial.print(rawStatus, HEX);


    if (!status.validResponse)
    {
        Serial.println(
            " | Invalid FPGA response"
        );

        return;
    }


    Serial.print(" | Light: ");

    if (status.vehicleGreen)
    {
        Serial.print("GREEN");
    }
    else if (status.vehicleYellow)
    {
        Serial.print("YELLOW");
    }
    else if (status.vehicleRed)
    {
        Serial.print("RED");
    }
    else
    {
        Serial.print("UNKNOWN");
    }


    Serial.print(" | Walk: ");
    Serial.print(
        status.pedestrianWalk ? "YES" : "NO"
    );


    Serial.print(" | Request: ");
    Serial.print(
        status.requestPending
            ? "PENDING"
            : "none"
    );


    Serial.print(" | Vehicle: ");
    Serial.print(
        status.vehiclePresent
            ? "DETECTED"
            : "clear"
    );


    Serial.print(" | Sensor: ");
    Serial.println(
        status.sensorValid
            ? "VALID"
            : "INVALID"
    );
}


// Setup

void setup()
{
    Serial.begin(115200);

    // Sensor

    pinMode(TRIG_PIN, OUTPUT);
    digitalWrite(TRIG_PIN, LOW);

    pinMode(ECHO_PIN, INPUT);


    // Button

    pinMode(
        PED_BUTTON_PIN,
        INPUT_PULLUP
    );


    // LEDs

    pinMode(RED_LED_PIN, OUTPUT);
    pinMode(YELLOW_LED_PIN, OUTPUT);
    pinMode(GREEN_LED_PIN, OUTPUT);
    pinMode(WALK_LED_PIN, OUTPUT);

    digitalWrite(RED_LED_PIN, LOW);
    digitalWrite(YELLOW_LED_PIN, LOW);
    digitalWrite(GREEN_LED_PIN, LOW);
    digitalWrite(WALK_LED_PIN, LOW);


    // FPGA SPI

    pinMode(FPGA_CS_PIN, OUTPUT);

    // CS inactive.
    digitalWrite(FPGA_CS_PIN, HIGH);

    SPI.begin();


    delay(500);

    Serial.println();
    Serial.println(
        "Adaptive Crosswalk Controller"
    );

    Serial.println(
        "Arduino SPI master initialized."
    );
}


// Main loop

void loop()
{
    const unsigned long now = millis();

    if (
        now - lastSampleTime <
        SAMPLE_INTERVAL_MS
    )
    {
        return;
    }

    lastSampleTime = now;


    // Read vehicle sensor

    const DistanceReading distance =
        readDistance();


    // Read pedestrian button

    const bool pedestrianButton =
        digitalRead(PED_BUTTON_PIN) == LOW;


    // Send packet to FPGA

    const uint8_t rawStatus =
        sendSensorPacket(
            distance.distanceMm,
            pedestrianButton,
            distance.valid
        );


    // Decode FPGA response

    const FPGAStatus status =
        decodeFPGAStatus(rawStatus);


    // Let FPGA control traffic LEDs

    updateTrafficLights(status);


    // Debug output

    printStatus(
        distance,
        pedestrianButton,
        rawStatus,
        status
    );
}