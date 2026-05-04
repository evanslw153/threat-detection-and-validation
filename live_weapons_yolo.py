from picamera2 import Picamera2
from ultralytics import YOLO
import cv2
import time
import sys

# -----------------------------
# Load Models
# -----------------------------
threat_model = YOLO("threat_model.pt")   # guns, explosives, grenades
coco_model = YOLO("yolov8n.pt")          # COCO model for knife detection

print("Threat model classes:", threat_model.names)
print("COCO model classes:", coco_model.names)

# Threat model classes (ignore knife=3)
THREAT_CLASSES = [0]  # guns, explosive, grenade

# COCO knife class
COCO_KNIFE = 43

# -----------------------------
# Screenshot Cooldown Settings
# -----------------------------
last_screenshot_time = 0
screenshot_cooldown = 15  # seconds between screenshots

# -----------------------------
# Camera Setup (FPS optimized)
# -----------------------------
picam2 = Picamera2()
config = picam2.create_preview_configuration(
    main={"size": (480, 360), "format": "RGB888"}  # lower resolution = higher FPS
)
picam2.configure(config)
picam2.start()

print("Camera started. Press 'q' to quit.")

# -----------------------------
# Main Loop
# -----------------------------
while True:
    frame = picam2.capture_array()

    # Convert BGRA ? BGR if needed
    if frame.shape[2] == 4:
        frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)

    # Run both models (FPS optimized)
    threat_results = threat_model(frame, conf=0.50, classes=THREAT_CLASSES)[0]
    coco_results = coco_model(frame, conf=0.50, classes=[COCO_KNIFE])[0]

    output = frame.copy()
    detection_found = False  # used for screenshot logic

    # -----------------------------
    # Threat Model Detections
    # -----------------------------
    for box, cls, conf in zip(threat_results.boxes.xyxy,
                              threat_results.boxes.cls,
                              threat_results.boxes.conf):

        cls = int(cls)
        if cls in THREAT_CLASSES:
            detection_found = True

            x1, y1, x2, y2 = map(int, box)
            label = f"{threat_model.names[cls]} {float(conf):.2f}"

            cv2.rectangle(output, (x1, y1), (x2, y2), (0, 0, 255), 2)
            cv2.putText(output, label, (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (0, 0, 255), 2)

    # -----------------------------
    # COCO Knife Detections
    # -----------------------------
    for box, cls, conf in zip(coco_results.boxes.xyxy,
                              coco_results.boxes.cls,
                              coco_results.boxes.conf):

        cls = int(cls)
        if cls == COCO_KNIFE:
            detection_found = True

            x1, y1, x2, y2 = map(int, box)
            label = f"knife {float(conf):.2f}"

            cv2.rectangle(output, (x1, y1), (x2, y2), (255, 0, 0), 2)
            cv2.putText(output, label, (x1, y1 - 10),
                        cv2.FONT_HERSHEY_SIMPLEX, 0.7, (255, 0, 0), 2)

    # -----------------------------
    # Screenshot Logic (Cooldown)
    # -----------------------------
    if detection_found:
        current_time = time.time()
        if current_time - last_screenshot_time > screenshot_cooldown:

            # --- NEW CODE FOR OPTION 2 (date-based folders) ---
            from datetime import datetime
            import os

            date_folder = datetime.now().strftime("%Y-%m-%d")
            save_path = f"/home/joshlane/Detection/screenshots/{date_folder}"

            # Create folder if it doesn't exist
            os.makedirs(save_path, exist_ok=True)

            # Build filename inside that folder
            filename = f"{save_path}/screenshot_{int(current_time)}.jpg"
            # ---------------------------------------------------

            cv2.imwrite(filename, output)
            print("Saved screenshot:", filename)
            last_screenshot_time = current_time


    # -----------------------------
    # Display Output
    # -----------------------------
    cv2.imshow("Weapons Detector", output)

    if cv2.waitKey(1) & 0xFF == ord('q'):
        break

# -----------------------------
# CLEAN SHUTDOWN (no ENTER needed)
# -----------------------------
picam2.stop()

cv2.destroyAllWindows()
cv2.waitKey(1)
cv2.destroyAllWindows()
cv2.waitKey(1)

sys.exit(0)
