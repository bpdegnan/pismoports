pismoports ports tree
=====================

A minimal MacPorts port tree derived from `../macports-ports`, containing only
the ports needed to support:

- git
- subversion
- a working LaTeX install (TeX Live basic + core LaTeX + recommended
  packages/fonts, i.e. roughly TeX Live's "basic" install scheme, not the
  full `texlive` metaport)
- TeXShop

...plus the dependency closure (fetch/extract/patch/build/lib/run) those
ports need to build from source. See `ROOTS.txt` for the exact list of
top-level ports this tree exists to support.

This is the tree that ships inside the PismoPorts installer, at
`/opt/local/share/pismoports/ports` on the target. See `../base/README.md`.

## Adding a port later

1. Add the port's name to `ROOTS.txt`.
2. From the repo root, run `tools/update_pismoports_tree.py`.

This recomputes the dependency closure against `macports-ports` and copies in
whatever new portdirs are needed, then reindexes both trees. It never deletes
anything automatically — if a root is removed from `ROOTS.txt`, the script
lists portdirs that are no longer required so you can review and remove them
by hand.

Run `tools/update_pismoports_tree.py --check` to preview changes without
applying them.

## Building for a G3

`_resources/port1.0/group/pismoports_g3-1.0.tcl` carries the codegen settings
that make a binary run on a Pismo. Add one line to a port that needs it:

    PortGroup           pismoports_g3 1.0

It does two separate things, and both are needed:

- constrains codegen to `-mcpu=603 -mtune=603 -m32 -mno-altivec`, so no
  AltiVec instruction is emitted — a G3 has no vector unit, so one of those
  is an illegal instruction and the process dies with SIGILL rather than
  degrading;
- appends `-Wl,-force_cpusubtype_ALL`, so the linker does not stamp the
  Mach-O as requiring a G4. A binary can be perfectly G3-safe in its
  instructions and still refuse to load without this, which is the confusing
  failure — it looks like a corrupt file.

`-fno-lto` is on by default too, because LTO has been seen to re-stamp the
cpusubtype at link time and undo the second point.

Knobs, settable after the `PortGroup` line: `pismoports_g3.cpu` (default
`603`, the conservative subset of what a 750 implements), and
`pismoports_g3.altivec` / `pismoports_g3.lto` (both `no`). The whole group is
inert unless the build is darwin/powerpc, so it is harmless to include when
seeding a port from upstream.

Some things deliberately stayed out of it, because they are not about G3
safety and are unsafe tree-wide — `-D_DARWIN_USE_64_BIT_INODE` changes the
layout of `struct stat`, and applying it to some ports but not others is an
ABI mismatch that surfaces far from where it was introduced. See the comments
at the top of the group.

## lang/python312 is kept, but unused

Nothing depends on it — the tree builds against `python311` only, after 3.12
would not compile on the Pismo. It stays because its Portfile is where the G3
recipe above was worked out, and because its `files/` holds
`patch-no-copyfile-on-Tiger.diff`, which does not exist upstream. Treat it as
a reference for what Tiger needs: the copyfile patch, `__DARWIN_UNIX03` for
`ttyname_r` on `os.major < 9`, and `gcc-apple-4.2` as the compiler.

Note it will not install as it stands — it wants `mpdecimal`, which left the
tree with it, since CPython 3.12 dropped the bundled `libmpdec` that 3.11
still has. That difference is itself part of why 3.11 is the easier target.

## The PortIndex here is a host index, not a target index

`portindex` evaluates each Portfile with the *indexing* machine's
`os.platform`, `os.major`, and `os.arch` baked in, which is why MacPorts
publishes a separate index per platform. The `PortIndex` committed here was
built on the x86_64 host, so it describes the dependencies and variants that
a modern macOS selects — not the ones Darwin 8 on PowerPC selects.

Two consequences:

- The closure above is a starting set. Ports that only a `platform darwin 8`
  block or a powerpc-conditional dependency pulls in are missing from this
  tree until something notices. The PismoPorts installer's postflight runs
  `portindex` on the Tiger machine for exactly this reason, and that is where
  such gaps show up.
- MacPorts offers no supported way to fake the platform: `os_major` and
  friends are derived from `uname` in `macports::init` and are not among the
  options readable from `macports.conf`, and base additionally refuses to run
  when the live platform disagrees with the one it was configured for. So a
  correct target index has to be generated on a Darwin 8 machine.

## Using this tree on the build host

Add it as a local MacPorts source, before the default rsync source so it
takes precedence, in `/opt/local/etc/macports/sources.conf`:

    file:///Users/degs/private/projects/pismoports/pismoports

A `file://` source is a no-op to sync, but it has to appear in the sources
list to be consulted at all.
