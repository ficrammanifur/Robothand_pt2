import cv2
import mediapipe as mp
import paho.mqtt.client as mqtt
import time

# -------------------------------
# MQTT Setup
# -------------------------------
MQTT_BROKER = "192.168.1.16"  # Ganti sesuai IP PC/Server MQTT
MQTT_PORT = 1883
MQTT_TOPIC = "OpenCV-IoT6601"
MQTT_CLIENT_ID = "PythonClient"

client = mqtt.Client(client_id=MQTT_CLIENT_ID)

def on_connect(client, userdata, flags, rc):
    if rc == 0:
        print("Connected to MQTT broker")
        client.subscribe(MQTT_TOPIC)
    else:
        print(f"Failed to connect to MQTT broker, return code: {rc}")

def on_disconnect(client, userdata, rc):
    print(f"Disconnected from MQTT broker, return code: {rc}")

client.on_connect = on_connect
client.on_disconnect = on_disconnect

# -------------------------------
# MediaPipe Setup
# -------------------------------
mp_hands = mp.solutions.hands
hands = mp_hands.Hands(
    max_num_hands=1,
    min_detection_confidence=0.7,
    min_tracking_confidence=0.5
)
mp_draw = mp.solutions.drawing_utils

# -------------------------------
# Webcam Setup
# -------------------------------
cap = cv2.VideoCapture(0)
if not cap.isOpened():
    print("Error: Could not open webcam")
    exit()

# Landmark IDs
FINGER_TIPS = [4, 8, 12, 16, 20]  # Thumb, Index, Middle, Ring, Pinky
FINGER_PIPS = [3, 6, 10, 14, 18]

# -------------------------------
# Helper Functions
# -------------------------------
def is_thumb_open(landmarks):
    tip_x = landmarks[4].x
    mcp_x = landmarks[2].x
    wrist_x = landmarks[0].x
    # Deteksi tangan kanan/kiri
    if wrist_x < landmarks[5].x:  # tangan kanan
        return tip_x > mcp_x
    else:  # tangan kiri
        return tip_x < mcp_x

def is_finger_open(landmarks, tip_id, pip_id):
    if tip_id == 4:
        return is_thumb_open(landmarks)
    return landmarks[tip_id].y < landmarks[pip_id].y

# -------------------------------
# Connect to MQTT
# -------------------------------
try:
    client.connect(MQTT_BROKER, MQTT_PORT, keepalive=60)
    client.loop_start()
except Exception as e:
    print(f"Failed to connect to MQTT broker: {e}")
    cap.release()
    exit()

# -------------------------------
# Main Loop
# -------------------------------
try:
    while cap.isOpened():
        ret, frame = cap.read()
        if not ret:
            print("Failed to read frame from camera")
            break

        frame = cv2.flip(frame, 1)
        frame_rgb = cv2.cvtColor(frame, cv2.COLOR_BGR2RGB)
        results = hands.process(frame_rgb)

        finger_states = ['0'] * 5  # Default: semua jari tertutup

        if results.multi_hand_landmarks:
            for hand_landmarks in results.multi_hand_landmarks:
                mp_draw.draw_landmarks(frame, hand_landmarks, mp_hands.HAND_CONNECTIONS)
                for i, (tip, pip) in enumerate(zip(FINGER_TIPS, FINGER_PIPS)):
                    if is_finger_open(hand_landmarks.landmark, tip, pip):
                        finger_states[i] = '1'

                binary_string = ''.join(finger_states)
                client.publish(MQTT_TOPIC, binary_string, qos=1)
                print(f"Sending: {binary_string}")
                cv2.putText(frame, binary_string, (10, 30),
                            cv2.FONT_HERSHEY_SIMPLEX, 1, (0, 255, 0), 2)
        else:
            # Kirim 00000 jika tangan tidak terdeteksi
            client.publish(MQTT_TOPIC, "00000", qos=1)
            print("Sending: 00000 (No hand detected)")

        cv2.imshow('Hand Gesture Control', frame)

        if cv2.waitKey(1) & 0xFF == ord('q'):
            break

        time.sleep(0.1)

except KeyboardInterrupt:
    print("Program terminated by user")
except Exception as e:
    print(f"An error occurred: {e}")

finally:
    cap.release()
    cv2.destroyAllWindows()
    client.loop_stop()
    client.disconnect()
    print("Cleaned up resources")
