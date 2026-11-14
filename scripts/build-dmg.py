"""Point Finder at the signed, embedded artwork without adding loose files to the volume."""
import pathlib
import sys

import dmgbuild
from ds_store import DSStore
from mac_alias import Alias

mount_point = None


def finish_layout(event):
    global mount_point
    if (event.get("command") == "hdiutil::attach" and event["type"] == "command::finished"
            and event.get("ret") == 0):
        for entity in event["output"].get("system-entities", []):
            if "mount-point" in entity:
                mount_point = pathlib.Path(entity["mount-point"])
    if event.get("operation") == "dsstore::create" and event["type"] == "operation::finished":
        assert mount_point is not None
        artwork = mount_point / "Awesome Fn Button.app/Contents/Resources/InstallerBackground.tiff"
        with DSStore.open(str(mount_point / ".DS_Store"), "r+") as store:
            view = store["."]["icvp"]
            view["backgroundType"] = 2
            view["backgroundImageAlias"] = Alias.for_file(str(artwork)).to_bytes()
            store["."]["icvp"] = view


dmgbuild.build_dmg(sys.argv[2], "Awesome Fn Button", settings_file="scripts/dmg-settings.py",
                   defines={"app": sys.argv[1]}, callback=finish_layout)
