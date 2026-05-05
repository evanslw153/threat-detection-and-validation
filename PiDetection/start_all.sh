#!/bin/bash
cd /home/joshlane/Detection/PiDetection
source ../detectionenv/bin/activate

# Start YOLO in background
python3 live_weapons_yolo.py &

# Start watcher in foreground
python3 watch_and_upload.py
