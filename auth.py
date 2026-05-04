import msal
import json
import os

print("auth.py started")

CONFIG_PATH = "config.json"
TOKEN_CACHE_PATH = "token_cache.bin"

def load_config():
    with open(CONFIG_PATH, "r") as f:
        return json.load(f)

def get_token():
    config = load_config()

    cache = msal.SerializableTokenCache()
    if os.path.exists(TOKEN_CACHE_PATH):
        cache.deserialize(open(TOKEN_CACHE_PATH, "r").read())

    app = msal.PublicClientApplication(
        client_id=config["client_id"],
        authority=config["authority"],
        token_cache=cache
    )

    # Try silent first
    accounts = app.get_accounts()
    result = None
    if accounts:
        result = app.acquire_token_silent(config["scopes"], account=accounts[0])

    if not result:
        # Device code flow
        flow = app.initiate_device_flow(scopes=config["scopes"])
        if "user_code" not in flow:
            raise RuntimeError("Failed to create device flow")

        print("Go to:", flow["verification_uri"])
        print("Enter code:", flow["user_code"])
        print("Sign in with the same Microsoft account used on iOS.")

        result = app.acquire_token_by_device_flow(flow)

    if "access_token" not in result:
        raise RuntimeError("Failed to obtain access token: %s" % result)

    # Save cache
    with open(TOKEN_CACHE_PATH, "w") as f:
        f.write(cache.serialize())

    return result["access_token"]
