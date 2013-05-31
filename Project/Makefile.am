
AUTOMAKE_OPTIONS = foreign

# Without the ACLOCAL_AMFLAGS line below, you get this warning:
#   libtoolize: Consider adding `-I m4' to ACLOCAL_AMFLAGS in Makefile.am.
# However, with it, autoreconf does not work if you don't manually create
# the m4 subdirectory beforehand, even if you add the --install flag here.
# I have tested with autoconf 2.65 and automake 1.11.1 .
#   ACLOCAL_AMFLAGS = -I m4

# If you update this line, please update AC_CONFIG_FILES in configure.ac too.
SUBDIRS = BareMetalSupport JtagFirmware EmptyFirmware
