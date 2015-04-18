
AUTOMAKE_OPTIONS := foreign
.DELETE_ON_ERROR:

# The "m4" subdir must already exist, see autogen.sh for more information.
# Do not use ":=" here, or you will get warning:
#   libtoolize: Consider adding `-I m4' to ACLOCAL_AMFLAGS in Makefile.am.
# I have reported this issue in the Automake mailing list:
#   Title: Setting ACLOCAL_AMFLAGS with ':=' vs '='
#   URL:   http://lists.gnu.org/archive/html/automake/2014-09/msg00013.html
# With the advent of AC_CONFIG_MACRO_DIR, setting ACLOCAL_AMFLAGS here should not be
# necessary anymore, but libtoolize 2.4.2 probably does not support AC_CONFIG_MACRO_DIR yet.
ACLOCAL_AMFLAGS = -I m4

# If you update this line, please update AC_CONFIG_FILES in configure.ac too.
SUBDIRS := CmsisMakefile BareMetalSupport AsfForEmptyFirmware EmptyFirmware AsfForJtagFirmware JtagFirmware
