import time
import os
import json
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler, FileCreatedEvent, FileMovedEvent
from upload_onedrive import upload_file_to_onedrive

# Directories (relative to project root)
SCREENSHOTS_DIR = "screenshots"
QUEUE_DIR = "upload_queue"

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".gif", ".webp"}

STABILITY_CHECK_INTERVAL = 0.5
STABILITY_CHECK_ROUNDS = 6  # ~3 seconds max


def is_image_file(path: str) -> bool:
    return Path(path).suffix.lower() in IMAGE_EXTS


def wait_for_file_stable(path: str) -> bool:
    try:
        last_size = -1
        for _ in range(STABILITY_CHECK_ROUNDS):
            if not os.path.exists(path):
                return False
            current_size = os.path.getsize(path)
            if current_size == last_size and current_size > 0:
                return True
            last_size = current_size
            time.sleep(STABILITY_CHECK_INTERVAL)
        return os.path.exists(path) and os.path.getsize(path) > 0
    except Exception:
        return False


def ensure_dir(path: str):
    if not os.path.exists(path):
        os.makedirs(path, exist_ok=True)

def enqueue_failed_upload(local_path: str, reason: str, extra: dict | None = None):
    """
    Store a small job file in QUEUE_DIR so we can retry later.
    """
    ensure_dir(QUEUE_DIR)
    job = {
        "local_path": os.path.abspath(local_path),
        "reason": reason,
        "extra": extra or {},
    }
    # Use a timestamp-based filename
    ts = int(time.time() * 1000)
    job_name = f"job_{ts}.json"
    job_path = os.path.join(QUEUE_DIR, job_name)
    try:
        with open(job_path, "w") as f:
            json.dump(job, f)
        print(f"[queue] Enqueued failed upload: {job_path}")
    except Exception as e:
        print(f"[queue] Failed to write job file: {e}")


def process_queue():
    """
    On startup, process any queued jobs.
    """
    ensure_dir(QUEUE_DIR)
    jobs = sorted(Path(QUEUE_DIR).glob("job_*.json"))
    if not jobs:
        print("[queue] No queued jobs to process.")
        return

    print(f"[queue] Processing {len(jobs)} queued job(s)...")

    for job_file in jobs:
        try:
            with open(job_file, "r") as f:
                job = json.load(f)
            local_path = job.get("local_path")
            print(f"[queue] Retrying: {local_path}")

            if not local_path or not os.path.exists(local_path):
                print(f"[queue] Local file missing, removing job: {job_file}")
                job_file.unlink(missing_ok=True)
                continue

            result = upload_file_to_onedrive(local_path)
            if isinstance(result, dict) and result.get("error"):
                print(f"[queue] Still failing: {local_path} -> {result}")
                # keep job for next run
                continue

            print(f"[queue] Success, removing job: {job_file}")
            job_file.unlink(missing_ok=True)

        except Exception as e:
            print(f"[queue] Error processing job {job_file}: {e}")
            # keep job; try again next startup

class ScreenshotHandler(FileSystemEventHandler):
    def _handle_new_file(self, src_path: str):
        src_path = os.path.abspath(src_path)

        if os.path.isdir(src_path):
            return

        if not is_image_file(src_path):
            return

        print(f"[watcher] Detected new file: {src_path}")

        stable = wait_for_file_stable(src_path)
        if not stable:
            print(f"[watcher] Warning: file did not stabilize or disappeared: {src_path}")
            enqueue_failed_upload(src_path, "unstable_or_missing")
            return

        try:
            result = upload_file_to_onedrive(src_path)
            if isinstance(result, dict):
                if result.get("skipped"):
                    print(f"[watcher] Skipped (exists): {result.get('onedrive_path')}")
                elif result.get("error"):
                    print(f"[watcher] Upload error: {result}")
                    enqueue_failed_upload(src_path, "upload_error", result)
                else:
                    name = result.get("name") or os.path.basename(src_path)
                    print(f"[watcher] Uploaded: {name}")
            else:
                print(f"[watcher] Unexpected upload result: {result}")
        except Exception as e:
            print(f"[watcher] Exception during upload: {e}")
            enqueue_failed_upload(src_path, "exception", {"exception": str(e)})

    def on_created(self, event):
        if isinstance(event, FileCreatedEvent):
            self._handle_new_file(event.src_path)

    def on_moved(self, event):
        if isinstance(event, FileMovedEvent):
            self._handle_new_file(event.dest_path)


def main():
    project_root = os.path.abspath(os.path.dirname(__file__))
    watch_path = os.path.join(project_root, SCREENSHOTS_DIR)

    ensure_dir(watch_path)
    ensure_dir(QUEUE_DIR)

    print(f"[watcher] Project root: {project_root}")
    print(f"[watcher] Watching screenshots in: {watch_path}")

    # First, process any queued jobs
    process_queue()

    observer = Observer()
    handler = ScreenshotHandler()
    observer.schedule(handler, watch_path, recursive=True)
    observer.start()

    print("[watcher] Watching for new screenshots...")

    try:
        last_retry_check = time.time()

        while True:
            time.sleep(1)

            # Every 60 seconds, try to process the retry queue
            if time.time() - last_retry_check >= 60:
                print("[queue] Periodic retry check...")
                process_queue()
                last_retry_check = time.time()
    except KeyboardInterrupt:
        print("[watcher] Stopping watcher (KeyboardInterrupt)")
        observer.stop()
    except Exception as e:
        print(f"[watcher] Stopping watcher due to error: {e}")
        observer.stop()

    observer.join()
    print("[watcher] Exited cleanly")


if __name__ == "__main__":
    main()
