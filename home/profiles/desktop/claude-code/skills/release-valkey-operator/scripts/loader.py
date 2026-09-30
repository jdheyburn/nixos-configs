# /// script
# requires-python = ">=3.12"
# ///
# Loader for the upgrade gate. Runs inside a pod (see loader-pod.sh).
#   python loader.py write   # SET k:<n> n forever; appends each acked n to /data/acked
#   python loader.py verify  # MGET every acked key; prints acked=, missing=
# Env: VK_HOST (cluster headless Service), VK_TLS=1 for TLS (CA at /tls/ca.crt).
# Auth: ACL user app / apppass.
import os, sys, time, ssl
from valkey.cluster import ValkeyCluster, ClusterNode
host = os.environ["VK_HOST"]; tls = os.environ.get("VK_TLS") == "1"
kw = dict(username="app", password="apppass", socket_timeout=2, socket_connect_timeout=2,
          cluster_error_retry_attempts=1)
if tls:
    kw.update(ssl=True, ssl_ca_certs="/tls/ca.crt", ssl_check_hostname=False)
def client():
    while True:
        try:
            return ValkeyCluster(host=host, port=6379, **kw)
        except Exception as e:
            print("connect fail", repr(e)[:120], flush=True); time.sleep(1)
mode = sys.argv[1]
acked = "/data/acked"
if mode == "write":
    c = client(); n = int(open("/data/next").read()) if os.path.exists("/data/next") else 0
    ok = err = 0; last = time.time(); f = open(acked, "a"); errs = {}
    while True:
        try:
            c.set(f"k:{n}", str(n)); f.write(f"{n}\n"); f.flush(); ok += 1
        except Exception as e:
            err += 1; k = type(e).__name__; errs[k] = errs.get(k, 0) + 1
            try: c = client()
            except Exception: pass
        n += 1; open("/data/next", "w").write(str(n))
        if time.time() - last > 10:
            print(time.strftime("%H:%M:%S"), f"ok={ok} err={err} {errs}", flush=True); ok = err = 0; errs = {}; last = time.time()
        time.sleep(0.01)
elif mode == "verify":
    c = client(); ids = [int(x) for x in open(acked).read().split()]
    missing = []
    for i in range(0, len(ids), 500):
        chunk = ids[i:i+500]
        vals = c.mget_nonatomic([f"k:{x}" for x in chunk])
        missing += [x for x, v in zip(chunk, vals) if v is None or int(v) != x]
    print(f"acked={len(ids)} missing={len(missing)} sample={missing[:20]}", flush=True)
