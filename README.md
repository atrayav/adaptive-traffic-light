# adaptive-traffic-light

Smart Crosswalks

## Arduino proximity sensing milestone

This milestone uses an Arduino Nano 33 BLE Sense Rev2 and the onboard APDS9960 proximity sensor. Install the `Arduino_APDS9960` library through the Arduino IDE Library Manager before compiling or uploading.

Sketch path:

```text
arduino/proximity_test/proximity_test.ino
```

To upload with the Arduino IDE:

1. Open `arduino/proximity_test/proximity_test.ino`.
2. Select **Tools > Board > Arduino Mbed OS Nano Boards > Arduino Nano 33 BLE Sense Rev2**.
3. Select the connected board port from **Tools > Port**.
4. Click **Upload**.

To view readings, open **Tools > Serial Monitor**, set the baud rate to `115200`, and confirm output in this CSV format:

```text
time_ms,proximity
```

Collect at least five clear readings with the sensing area unobstructed, then at least five occupied readings with an object or hand held steadily in front of the APDS9960 sensor. Record the raw proximity values as printed; do not convert them to distance and do not choose a detection threshold yet.
