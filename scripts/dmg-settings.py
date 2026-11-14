"""Finder layout for the drag-to-install disk image (coordinates are in points)."""
import os

app = os.path.abspath(defines["app"])
files = [app]
symlinks = {"Applications": "/Applications"}
background = None  # The background lives inside the signed app, not beside the install icons.
format = "UDZO"
filesystem = "HFS+"
window_rect = ((160, 160), (720, 420))
default_view = "icon-view"
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
show_icon_preview = True
arrange_by = None
icon_size = 112
text_size = 13
label_pos = "bottom"
icon_locations = {
    os.path.basename(app): (165, 220),
    "Applications": (555, 220),
}
