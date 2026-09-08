# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This portgroup makes a port produce binaries that actually run on a
# PowerBook G3. It does two separate jobs:
#
#    * keeps AltiVec out of the generated code
#    * forces the Mach-O cpusubtype to ALL, so the resulting binary is not
#      tagged as requiring a G4 or better
#
# The second is the one that does the real work here. gcc14 targeting
# powerpc-apple-darwin8 already defaults to generic 32-bit PowerPC with
# __ALTIVEC__ undefined, so there is no ISA to restrict -- -mno-altivec below
# is insurance against a port turning it on, not the mechanism.
#
# The cpusubtype tag is the live hazard. A binary can be perfectly G3-safe in
# its instructions and still refuse to load because the linker stamped a
# subtype the loader rejects, and that failure looks like file corruption
# rather than an architecture problem.
#
# Usage:
#
#   PortGroup pismoports_g3 1.0
#
#   pismoports_g3.cpu:      target CPU passed to -mtune. Default 603,
#                           which is the conservative choice: it is a strict
#                           subset of what a 750 (G3) implements, so it also
#                           runs on the earlier PowerPC machines. Set to 750
#                           if a port genuinely benefits and you only care
#                           about the Pismo.
#   pismoports_g3.altivec:  set to yes to allow AltiVec. Verified that gcc14
#                           leaves __ALTIVEC__ undefined by default, so
#                           -mno-altivec is belt-and-braces, not the thing
#                           actually keeping vector code out.
#   pismoports_g3.lto:      set to yes to leave LTO alone. Off by default:
#                           GCC's LTO has been observed to re-stamp the
#                           cpusubtype at link time, undoing the work above.
#
# Everything here is a no-op unless the build is actually darwin/powerpc, so
# the group is harmless to include when seeding a port from upstream.
#
# Deliberately NOT included, though the python312 Portfile this was lifted
# from carries them, because they are not about G3 safety and are unsafe to
# apply tree-wide:
#
#   -D_DARWIN_USE_64_BIT_INODE -D_FILE_OFFSET_BITS=64
#       Changes the layout of struct stat. Applying it to some ports and not
#       others is an ABI mismatch that shows up as garbage stat results far
#       from where it was introduced.
#   -D__DARWIN_UNIX03=1
#       Selects UNIX03 semantics, which changes the return type of
#       ttyname_r among other things. Correct for CPython on Tiger, wrong
#       as a blanket setting.
#   configure.compiler gcc-apple-4.2
#       Compiler choice belongs to the port, not to this group.
#
# Set those per-port where they are needed.

options pismoports_g3.cpu
default pismoports_g3.cpu               603

options pismoports_g3.altivec
default pismoports_g3.altivec           no

options pismoports_g3.lto
default pismoports_g3.lto               no

# Only darwin/powerpc gets any of this. os.arch is already normalised by base
# ("Power Macintosh" becomes powerpc), so this is the whole test.
if {${os.platform} eq "darwin" && ${os.arch} eq "powerpc"} {

    # Applied in pre-configure rather than at Portfile-eval time so that a
    # Portfile can override the options above after including the group.
    pre-configure {
        set cpu [option pismoports_g3.cpu]

        # -mtune, deliberately NOT -mcpu. Verified against gcc14 14.3.0 on
        # Darwin 8 / ppc750:
        #
        #   -mcpu=603 ...              ld: unknown/unsupported architecture
        #                              name for: -arch ppc603
        #   -mcpu=603 ... -arch ppc    same failure; the explicit -arch does
        #                              not override it
        #   -mcpu=750 ... -arch ppc    links, but stamps cpusubtype ppc750 --
        #                              which defeats force_cpusubtype_ALL below
        #   -mtune=603 ...             links, cpusubtype ALL
        #
        # gcc turns -mcpu= into an -arch ppcNNN for the linker, and ld has no
        # such architecture name. -mtune changes instruction scheduling only,
        # leaves the ISA and the arch tag alone, and is what we actually want:
        # the default ISA for powerpc-apple-darwin8 is already generic 32-bit
        # PowerPC, so there is nothing to restrict.
        set gen [list -mtune=${cpu} -m32]

        if {![tbool pismoports_g3.altivec]} {
            lappend gen -mno-altivec
        }
        if {![tbool pismoports_g3.lto]} {
            lappend gen -fno-lto
        }

        configure.cflags-append     {*}${gen}
        configure.cxxflags-append   {*}${gen}
        configure.objcflags-append  {*}${gen}

        # -Wl, so it survives being passed through the compiler driver, which
        # is how MacPorts invokes the linker for almost every port.
        configure.ldflags-append    -Wl,-force_cpusubtype_ALL

        ui_debug "pismoports_g3: targeting ${cpu}, altivec=[tbool pismoports_g3.altivec], forcing cpusubtype ALL"
    }
}
