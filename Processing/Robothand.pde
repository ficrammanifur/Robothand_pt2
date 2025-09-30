import mqtt.*;

MQTTClient client;
boolean[] fingers = {false, false, false, false, false}; // thumb, index, middle, ring, pinky

float[] targetMCP = new float[5], currMCP = new float[5]; // pangkal jari
float[] targetPIP = new float[5], currPIP = new float[5]; // sendi tengah
float[] targetDIP = new float[5], currDIP = new float[5]; // ujung jari (ibu jari DIP=0)

float servoLerp = 0.15; // kehalusan animasi servo
// Ukuran telapak & jari
float palmX = 300, palmY = 260, palmW = 160, palmH = 170, palmRadius = 28;
float[] seg1 = {38, 48, 52, 48, 40};   // panjang segmen 1 per jari (ibu jari - kelingking)
float[] seg2 = {32, 36, 40, 36, 30};
float[] seg3 = { 0, 28, 32, 26, 22};   // ibu jari tidak pakai seg3 (DIP=0)
float[] segW = {18, 16, 16, 15, 14};   // lebar segmen per jari

// Orientasi dasar jari (derajat): ibu jari agak miring ke kiri, kelingking sedikit miring
float[] baseOrientDeg = {-40, 0, 0, 2, 6};

// Posisi pangkal jari di tepi atas telapak
float[] baseX = {palmX - 58, palmX - 28, palmX + 4, palmX + 34, palmX + 62};
float[] baseY = {palmY + 10, palmY - 60, palmY - 72, palmY - 66, palmY - 56};

// Warna metalik dan detail
color metal = color(225, 229, 233);
color metalDark = color(170, 176, 184);
color accent = color(255, 184, 28);
color shadow = color(210, 214, 220);

void setup() {
  size(600, 400);
  background(255);

  // Buat listener
  MQTTListener listener = new MQTTListener() {
    void clientConnected() {
      println("Connected to MQTT");
      client.subscribe("OpenCV-IoT6601");
    }

    void messageReceived(String topic, byte[] payload) {
      String msg = new String(payload);
      println("Received: " + msg);

      // Parse string biner jadi state jari
      if (msg.length() == 5) {
        for (int i = 0; i < 5; i++) {
          fingers[i] = msg.charAt(i) == '1';
          boolean open = fingers[i];

          if (i == 0) { // ibu jari: 2 segmen saja
            if (open) {
              targetMCP[i] = 0;  targetPIP[i] = 0;  targetDIP[i] = 0;
            } else {
              targetMCP[i] = 38; targetPIP[i] = 22; targetDIP[i] = 0;
            }
          } else { // jari lainnya: 3 segmen
            if (open) {
              targetMCP[i] = 0;  targetPIP[i] = 0;  targetDIP[i] = 0;
            } else {
              targetMCP[i] = 55; targetPIP[i] = 35; targetDIP[i] = 18;
            }
          }
        }
      }
    }

    void connectionLost() {
      println("MQTT connection lost!");
    }
  };

  // Buat client dengan listener
  client = new MQTTClient(this, listener);
  client.connect("tcp://192.168.1.16:1883", "ProcessingClient"); // ganti IP broker-mu

  for (int i = 0; i < 5; i++) {
    float mcp = 0, pip = 0, dip = 0; // default buka
    targetMCP[i] = currMCP[i] = mcp;
    targetPIP[i] = currPIP[i] = pip;
    targetDIP[i] = currDIP[i] = dip;
  }
}

void drawSegment(float x, float y, float angleDeg, float length, float width, color fillCol) {
  pushMatrix();
  translate(x, y);
  rotate(radians(angleDeg));
  noStroke();
  fill(fillCol);
  rectMode(CORNER);
  // sedikit chamfer/rounded feel
  rect(-width/2, -length, width, length, 6);
  popMatrix();
}

void drawJoint(float x, float y, float r) {
  noStroke();
  fill(metalDark);
  ellipse(x, y, r+6, r+6);
  fill(metal);
  ellipse(x, y, r, r);
  // lubang skrup kecil
  fill(80, 85, 95);
  ellipse(x, y, r*0.3, r*0.3);
}

void draw() {
  background(245);

  // Telapak (palm) metalik
  noStroke();
  fill(shadow);
  rect(palmX - palmW/2, palmY - palmH/2 + 6, palmW, palmH, palmRadius); // bayangan halus
  fill(metal);
  rect(palmX - palmW/2, palmY - palmH/2, palmW, palmH, palmRadius);

  // Panel garis pada telapak
  stroke(195);
  strokeWeight(2);
  line(palmX - palmW/2 + 18, palmY - 16, palmX + palmW/2 - 18, palmY - 16);
  line(palmX - palmW/2 + 22, palmY + 8,  palmX + palmW/2 - 22, palmY + 8);
  noStroke();

  // Update sudut servo dengan lerp agar halus
  for (int i = 0; i < 5; i++) {
    currMCP[i] = lerp(currMCP[i], targetMCP[i], servoLerp);
    currPIP[i] = lerp(currPIP[i], targetPIP[i], servoLerp);
    currDIP[i] = lerp(currDIP[i], targetDIP[i], servoLerp);
  }

  // Gambar jari satu per satu
  for (int i = 0; i < 5; i++) {
    float bx = baseX[i];
    float by = baseY[i];
    float baseAng = baseOrientDeg[i];

    // Warna segmen sedikit berbeda untuk memberi kesan layer
    color c1 = metal;
    color c2 = lerpColor(metal, metalDark, 0.18);
    color c3 = lerpColor(metal, metalDark, 0.28);

    // MCP
    float a1 = baseAng + currMCP[i];
    drawSegment(bx, by, a1, seg1[i], segW[i], c1);
    drawJoint(bx, by, 14);

    // Hitung titik ujung segmen 1
    float x1 = bx + sin(radians(a1)) * (-seg1[i]);  // karena segmen digambar ke arah -length di sumbu Y lokal
    float y1 = by - cos(radians(a1)) * (-seg1[i]);

    // PIP
    float a2 = a1 + currPIP[i];
    drawSegment(x1, y1, a2, seg2[i], segW[i]*0.92, c2);
    drawJoint(x1, y1, 12);

    // Hitung titik ujung segmen 2
    float x2 = x1 + sin(radians(a2)) * (-seg2[i]);
    float y2 = y1 - cos(radians(a2)) * (-seg2[i]);

    // DIP (ibu jari seg3=0, otomatis tidak tergambar)
    if (seg3[i] > 0) {
      float a3 = a2 + currDIP[i];
      drawSegment(x2, y2, a3, seg3[i], segW[i]*0.85, c3);
      drawJoint(x2, y2, 10);
    }

    // Indikator status (buka/tutup) dan sudut dasar
    fill(40, 44, 52);
    textAlign(CENTER, TOP);
    textSize(10);
    String stateTxt = fingers[i] ? "OPEN" : "CLOSE";
    text(stateTxt, bx, by + 16);
  }

  // Label
  fill(40, 44, 52);
  textAlign(LEFT, TOP);
  textSize(12);
  text("MQTT Topic: OpenCV-IoT6601 | Payload: '11111' (semua buka), '00000' (semua tutup)", 16, 14);
  text("Tangan Robot dengan Servo (visual): MCP/PIP/DIP ber-animasi", 16, 32);
}
