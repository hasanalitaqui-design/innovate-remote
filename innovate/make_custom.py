"""Innovate Remote - makes the signed custom-client settings (name, our server, our server key, locked server settings) for the RustDesk fork.
The SIGNING key (private) stays in C:/Innovate/remote_build/signing/ and is never committed; the fork only gets the PUBLIC verify key and the signed settings text.
Run:  python make_custom.py        -> writes <fork>/innovate/innovate_custom.txt and prints the public verify key (base64)."""
import os, json, base64
from nacl.signing import SigningKey

BASE = "C:/Innovate/remote_build"
FORK = BASE + "/innovate-remote"
KEYDIR = BASE + "/signing"
os.makedirs(KEYDIR, exist_ok=True)
os.makedirs(FORK + "/innovate", exist_ok=True)
seed_path = KEYDIR + "/innovate_signing_seed.hex"
if os.path.exists(seed_path):
    sk = SigningKey(bytes.fromhex(open(seed_path).read().strip()))
else:
    sk = SigningKey.generate()
    open(seed_path, "w").write(sk.encode().hex())
pub_b64 = base64.b64encode(bytes(sk.verify_key)).decode()
open(KEYDIR + "/innovate_verify_key.b64", "w").write(pub_b64)

SERVER = "remote.taquiai.ai"      # a NAME, not an IP: moving the relay later is only a DNS change (was 192.236.183.198 on RackNerd)
SERVER_KEY = "4Wpe27z5xf+OtgRrVuXjsaInjoQmZgYia1Xwl9UKSA0="        # the Innovate Remote server's PUBLIC key
settings = {
    "app-name": "InnovateRemote",
    "override-settings": {                                         # cannot be changed by the user
        "custom-rendezvous-server": SERVER,
        "relay-server": SERVER,
        "key": SERVER_KEY,
        "hide-server-settings": "Y",
        "hide-proxy-settings": "Y",
        "hide-websocket-settings": "Y",
        "verification-method": "use-permanent-password",       # only the unattended password, no random one-time password
    },
    "default-settings": {                                          # changeable per PC
        "allow-auto-disconnect": "Y",
        "auto-disconnect-timeout": "15",                           # minutes idle -> session closes
    },
}
raw = json.dumps(settings, separators=(",", ":")).encode()
signed = bytes(sk.sign(raw))                                       # signature + message: the format sodiumoxide's sign::verify reads
open(FORK + "/innovate/innovate_custom.txt", "w").write(base64.b64encode(signed).decode())
print("verify key (public):", pub_b64)
print("settings text written:", len(signed), "bytes")
