#!/usr/bin/env python3
"""Small GTK3 window that exercises the Breeze palette states a file manager
mostly hides until you click something: row selection, links, checkboxes,
suggested/destructive buttons, headerbar. Used to compare palettes by
screenshot instead of squinting at two near-identical file managers."""
import gi
gi.require_version("Gtk", "3.0")
from gi.repository import Gtk, Gdk

win = Gtk.Window(title="GTK3 palette preview")
win.set_default_size(560, 420)
win.set_border_width(0)

# headerbar
hb = Gtk.HeaderBar()
hb.set_show_close_button(True)
hb.set_title("Palette preview")
hb.set_subtitle("selection · links · buttons")
win.set_titlebar(hb)

box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
box.set_border_width(14)
win.add(box)

# a listview with one row pre-selected so selection colours are visible
store = Gtk.ListStore(str, str)
for n, s in [("wallpapers", "deer-forest.jpg"), ("Screenshots", "12 items"),
             ("Collage", "3 items"), ("unsorted", "empty")]:
    store.append([n, s])
view = Gtk.TreeView(model=store)
r1 = Gtk.CellRendererText()
c1 = Gtk.TreeViewColumn("Name", r1, text=0)
c1.set_expand(True)
view.append_column(c1)
r2 = Gtk.CellRendererText()
c2 = Gtk.TreeViewColumn("Contents", r2, text=1)
view.append_column(c2)
view.get_selection().select_path(Gtk.TreePath.new_from_indices([1]))
sc = Gtk.ScrolledWindow()
sc.set_policy(Gtk.PolicyType.NEVER, Gtk.PolicyType.AUTOMATIC)
sc.set_shadow_type(Gtk.ShadowType.IN)
sc.add(view)
sc.set_size_request(-1, 150)
box.pack_start(sc, False, False, 0)

# link + checkbox row
row = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=14)
link = Gtk.LinkButton(uri="https://example.org", label="a link, for link_color")
cb = Gtk.CheckButton(label="checked")
cb.set_active(True)
cb2 = Gtk.CheckButton(label="unchecked")
row.pack_start(link, False, False, 0)
row.pack_start(cb, False, False, 0)
row.pack_start(cb2, False, False, 0)
box.pack_start(row, False, False, 0)

# button row
brow = Gtk.Box(orientation=Gtk.Orientation.HORIZONTAL, spacing=8)
brow.pack_start(Gtk.Button(label="normal"), False, False, 0)
sb = Gtk.Button(label="suggested")
sb.get_style_context().add_class("suggested-action")
brow.pack_start(sb, False, False, 0)
db = Gtk.Button(label="destructive")
db.get_style_context().add_class("destructive-action")
brow.pack_start(db, False, False, 0)
box.pack_start(brow, False, False, 0)

# entry
box.pack_start(Gtk.Entry(), False, False, 0)

win.connect("destroy", Gtk.main_quit)
win.show_all()
Gtk.main()
