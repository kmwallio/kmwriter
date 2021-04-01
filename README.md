# Sharing Bite-Sized Knowledge of how ThiefMD Works

This repo is just for showing how some of the core stuff in [ThiefMD](https://github.com/kmwallio/ThiefMD) works. It's mostly stuff that I think is cool or would be useful for other people to use that I can't easily package into a new library (yet).

## Blog Posts

 - [Playing with Gtk.TextTag's](https://1.6km.me//blog/2021/03/06/playing-with-gtk-texttags/) - Covers how we perform URL hiding.
 - [The Poor Man's Grammar Checker](https://1.6km.me/blog/2021/03/30/the-poor-mans-grammar-checker/) - Covers how we perform grammar checking.
 - [Speeding KMWriter Up](https://1.6km.me/blog/2021/03/31/speeding-kmwriter-up/) - Real time (or non-disruptive) grammar checking.

## Building

### Ubuntu

```bash
sudo apt install meson ninja-build valac cmake libgtk-3-dev libgee-0.8-dev libgtksourceview-4-dev link-grammar
```

### Fedora

```bash
sudo dnf install vala meson ninja-build cmake gtk3-devel gtksourceview4-devel libgee-devel link-grammar
```

### Building & Running

```bash
git clone https://github.com/kmwallio/kmwriter.git
cd kmwriter
meson build
cd build
ninja
./kmwriter
```
