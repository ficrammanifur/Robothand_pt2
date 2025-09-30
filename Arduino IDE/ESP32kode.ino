#include <WiFi.h>
#include <PubSubClient.h>
#include <ESP32Servo.h>

// WiFi & MQTT Settings
const char* ssid = "FRISS";
const char* password = "mamahfris";
const char* mqtt_server = "192.168.1.16"; // IP PC / broker MQTT
const char* topic = "OpenCV-IoT6601";

WiFiClient espClient;
PubSubClient client(espClient);

// Servo setup
Servo servos[5];
int servoPins[5] = {13, 12, 14, 27, 26}; // Pin untuk tiap jari

void setup() {
  Serial.begin(115200);

  // Attach servos
  for (int i = 0; i < 5; i++) {
    servos[i].attach(servoPins[i]);
    servos[i].write(90); // Awal tertutup
  }

  // Connect WiFi
  WiFi.begin(ssid, password);
  while (WiFi.status() != WL_CONNECTED) {
    delay(1000);
    Serial.println("Connecting to WiFi...");
  }
  Serial.println("Connected to WiFi");

  // Setup MQTT
  client.setServer(mqtt_server, 1883);
  client.setCallback(callback);

  // Connect MQTT
  while (!client.connected()) {
    Serial.println("Connecting to MQTT...");
    if (client.connect("ESP32Client")) {
      Serial.println("Connected to MQTT");
      client.subscribe(topic);
    } else {
      Serial.print("Failed, rc=");
      Serial.print(client.state());
      delay(5000);
    }
  }
}

void loop() {
  client.loop(); // MQTT loop
}

// Callback saat menerima pesan MQTT
void callback(char* topic, byte* payload, unsigned int length) {
  String msg = "";
  for (int i = 0; i < length; i++) {
    msg += (char)payload[i];
  }
  Serial.println("Received: " + msg);

  // Parse string biner (misal "10000")
  if (msg.length() == 5) {
    for (int i = 0; i < 5; i++) {
      if (msg[i] == '1') {
        servos[i].write(0);   // jari terbuka
      } else {
        servos[i].write(90);  // jari tertutup
      }
    }
  }
}
