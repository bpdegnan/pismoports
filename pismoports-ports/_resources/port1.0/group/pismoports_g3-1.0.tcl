# -*- coding: utf-8; mode: tcl; tab-width: 4; indent-tabs-mode: nil; c-basic-offset: 4 -*- vim:fenc=utf-8:ft=tcl:et:sw=4:ts=4:sts=4
#
# This portgroup makes a port produce binaries that actually run on a
# PowerBook G3. It does two separate jobs:
#
#    * constrains code generation to the 750/G3 instruction set, so no
#      AltiVec instruction is ever emitted
#    * forces the Mach-O cpusubtype to ALL, so the resulting binary is not
#      tagged as requiring a G4 or better
#
# Both matter. A G3 has no AltiVec unit, so a G4-targeted instruction is an
# illegal instruction: the process dies with SIGILL rather than degrading.
# And a binary can be perfectly G3-safe in its instructions yet still refuse
# to load, because the linker stamped a cpusubtype the loader rejects. The
# second failure is the confusing one -- it looks like file corruption.
#
# Usage:
#
#   PortGroup pismoports_g3 1.0
#
#   pismoports_g3.cpu:      target CPU passed to -mcpu/-mtune. Default 603,
#                           which is the conservative choice: it is a strict
#                           subset of what a 750 (G3) implements, so it also
#                           runs on the earlier PowerPC machines. Set to 750
#                           if a port genuinely benefits and you only care
#                           about the Pismo.
#   pismoports_g3.altivec:  set to yes to allow AltiVec. Only do this for a
#                           port that will never be installed on a G3.
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
        set gen [list -mcpu=${cpu} -mtune=${cpu} -m32]

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
