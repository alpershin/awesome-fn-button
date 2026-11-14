"""Check the actual mounted installer, including its Finder layout and app signature."""
import pathlib
import plistlib
import subprocess
import sys
import tempfile

from ds_store import DSStore

image = pathlib.Path(sys.argv[1]).resolve()
with tempfile.TemporaryDirectory(prefix="awesome-fn-dmg-check-") as mount:
    subprocess.run(["hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", mount, str(image)],
                   check=True, stdout=subprocess.DEVNULL)
    try:
        root = pathlib.Path(mount)
        visible = {item.name for item in root.iterdir() if not item.name.startswith(".")}
        assert visible == {"Awesome Fn Button.app", "Applications"}, visible
        assert (root / "Applications").is_symlink()
        assert (root / "Applications").readlink() == pathlib.Path("/Applications")
        assert not (root / ".background.tiff").exists()
        assert not (root / ".VolumeIcon.icns").exists()
        with DSStore.open(str(root / ".DS_Store"), "r") as store:
            assert store["Awesome Fn Button.app"]["Iloc"] == (165, 220)
            assert store["Applications"]["Iloc"] == (555, 220)
            assert store["."]["icvp"]["backgroundType"] == 2
            assert store["."]["icvp"]["backgroundImageAlias"]
            assert store["."]["icvp"]["iconSize"] == 112
            window = store["."]["bwsp"]
            assert window["WindowBounds"] == "{{160, 160}, {720, 420}}"
            assert not window["ShowToolbar"] and not window["ShowSidebar"]
        app = root / "Awesome Fn Button.app"
        for resource in ["INSTALL.txt", "LICENSE.txt", "AppIcon.icns", "InstallerBackground.tiff"]:
            assert (app / "Contents" / "Resources" / resource).is_file(), resource
        with (app / "Contents" / "Info.plist").open("rb") as file:
            packaged = plistlib.load(file)
        with pathlib.Path("Resources/Info.plist").open("rb") as file:
            expected = plistlib.load(file)
        assert packaged["CFBundleShortVersionString"] == expected["CFBundleShortVersionString"]
        subprocess.run(["codesign", "--verify", "--deep", "--strict", str(app)], check=True)
    finally:
        subprocess.run(["hdiutil", "detach", mount], check=True, stdout=subprocess.DEVNULL)
print("DMG verified: two visible items, Applications link, Finder layout, background, and app signature.")
