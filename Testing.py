import requests
import time
import threading

URL = "http://localhost:9090"
TOTAL_REQUESTS = 0
HOT_REQUESTS = 0
STANDBY_REQUESTS = 0
FAILOVER_TIME = None
START_TIME = time.time()

lock = threading.Lock()

def send_requests():
    global TOTAL_REQUESTS, HOT_REQUESTS, STANDBY_REQUESTS, FAILOVER_TIME

    while True:
        try:
            r = requests.get(URL, timeout=2)
            data = r.json()

            with lock:
                TOTAL_REQUESTS += 1

                if data.get("role") == "hot":
                    HOT_REQUESTS += 1
                elif data.get("role") == "standby":
                    STANDBY_REQUESTS += 1
                    if FAILOVER_TIME is None:
                        FAILOVER_TIME = time.time() - START_TIME
                        print("\n🔥 FAILOVER DETECTED 🔥")

        except Exception:
            pass


# Start multiple threads to increase pressure
THREADS = 20
for _ in range(THREADS):
    t = threading.Thread(target=send_requests, daemon=True)
    t.start()

try:
    while True:
        with lock:
            print(
                f"Total={TOTAL_REQUESTS} | "
                f"Hot={HOT_REQUESTS} | "
                f"Standby={STANDBY_REQUESTS} | "
                f"FailoverTime={FAILOVER_TIME}"
            )
        time.sleep(1)

except KeyboardInterrupt:
    print("\nStopped.")
