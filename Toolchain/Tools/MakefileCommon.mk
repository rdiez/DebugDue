.DELETE_ON_ERROR:


# Setting option '--no-builtin-variables' inside the makefile has no effect, at least when expanding
# the top-level makefile expressions with GNU Make versions 4.3 and 4.4.1 . I guess it is too late to set
# the option at this point. That means that option '--no-builtin-rules' does not get automatically enabled either.
# Incidentally, '--no-builtin-variables' does seem to have an effect later on when executing the recipes, which
# means its behaviour is then inconsistent and confusing if set here.
# I recommend that you call this makefile with option '--no-builtin-variables' passed in the command-line. This makes
# the makefile more robust, because this makefile is designed to define all variables it needs.
#   MAKEFLAGS += --no-builtin-variables

# Disable all implicit rules, in case the user did not specify '--no-builtin-variables' in the command line.
# This makefile defines all rules it needs because it is then easier to debug.
# Besides, if implicit rules are active, GNU Make seems to look for many different possible source file types
# when trying to find a suitable rule for each target file. That can trigger many stat syscalls per target file,
# dramatically slowing down makefiles for large projects.
# Turning implicit rules off at this point is actually a little late. If you run the makefile with option '--debug=a',
# you will see messages like this:
#   Considering target file 'Makefile'.
#    Looking for an implicit rule for 'Makefile'.
#    No implicit rule found for 'Makefile'.
# But that only happens for the Makefile itself and it does not really matter.
MAKEFLAGS += --no-builtin-rules

# This makefile defines all variables that it needs. Turning on the following warning
# makes the makefile easier to debug.
# Unfortunately, setting this flag inside the makefile is not enough, as of GNU Make version 4.3.
# It does work for undefined variables inside recipies, but not inside prerequisites or globally,
# like "$(info $(UNDEFINED_VARIABLE))" at top level.
# Later note: This option seems to work now globally too with GNU Make version 4.4.1 .
MAKEFLAGS += --warn-undefined-variables

# Unfortunately, option "--output-sync" leads to long periods of time with no output, followed by large bursts of output.
# It is annoying, but it is actually the only sane way of generating a build log when building in parallel.
# And you want to build in parallel on today's multicore computers.
#
# Option "--output-sync" is only available in GNU Make version 4.0 (released in 2013) or later.
# I have noticed that this option seems to be ignored by the GNU Make version 4.2.1 that comes with Ubuntu 20.04.2,
# even if explicitly passed on the command line (not with MAKEFLAGS inside the makefile).
# I tested on the same system with a self-compiled GNU Make 4.3, and "--output-sync" worked fine.
#
# I am no longer unconditionally enabling this option inside the makefile, because then
# "make download-tarballs-from-internet" will not show the download progress messages in a timely manner.
# The user will probably want to pass option "--output-sync=recurse" if building in parallel.
#
# We could add this flag conditionally by looking at MAKECMDGOALS, but it gets complicated and
# would not be completely reliable. After all, the user can specify several targets at the same time.
#
# I tried to add this flag only if the user requested a parallel build, but I could not find
# a way to achieve that. Option "-j" is not reflected in MAKEFLAGS at this point, it gets added later
# when executing a rule.
#
#  MAKEFLAGS += --output-sync=recurse


# This makefile has only been tested with Bash.
# Option 'pipefail' is necessary. Otherwise, piping to 'tee' would mask any errors on the left side of the pipeline.
# Option 'nounset' helps us debug this makefile.
# Option 'errexit' makes it pretty hard to ignore errors. For example, a recipe like "false; true" would now fail.
# GNU Make appends option '-c' and a single argument with the command to execute.
SHELL := bash  -o nounset  -o pipefail  -o errexit
# This way of passing shell options is only available in modern GNU Make versions,
# and not in version 3.81 shipped with Ubuntu 14.04. Option -e is equivalent to "-o errexit":
#   .SHELLFLAGS := -o nounset  -o pipefail  -e  -c


# Check file or directory paths for whitespace.
#
# This alternative implementation does not need 'eval', but it does not detect leading or trailing whitespace.
# Adding 'pre' and 'post' to the string would help, but then we would need to check for an empty string beforehand:
#   $(if $(filter-out 1,$(words $($(1)))),$(error Variable $(1) is empty or contains whitespace. Its value is: "$($(1))"))

define check_variable_non_empty_and_contains_no_whitespace_needs_eval =

  ifeq ($($1),)
    $$(error Variable '$(1)' is empty, but it must have a value)
  else
    # GNU Make does not support spaces inside filenames, but I keep forgetting, so check.
    # Adding 'pre' and 'post' checks for leading and trailing whitespace too,
    # because otherwise it is automatically removed.
    # It is hard to pass leading whitespace on the 'make' command line, as it tends to be discarded.
    # Use the escape character ('\') to test leading whitespace.
    ifneq (1,$(words pre$($(1))post))
      $$(error Variable '$(1)' contains whitespace, but that is disallowed)
    endif
  endif

endef

check_variable_non_empty_and_contains_no_whitespace = $(eval $(call check_variable_non_empty_and_contains_no_whitespace_needs_eval,$(1)))


# Kept in case I need this again:
#  verify_variable_is_defined = $(if $(filter undefined,$(origin $(1))),$(error "The variable '$(1)' is not defined, but it should be at this point."))

# If a variable is needed, it usually must be defined and non-empty.
# However, we cannot always check upfront, because not all targets need all variables.
# For example, the "help" target needs less variables than most other targets.
# The idea of "poisoning" is to make a variable fail only if it is needed
# and it does not fulfil those conditions.
#
# Note 1) If a variable may be poisoned, all variables using it must be "recursively expanded".
#         Variables of type "simply expanded" will fail straight away (or maybe defer expansion of the poisoned variable).
# Note 2) If the variable's value consists of only space characters, it will be considered empty too.
#
# If we only needed the "is defined" condition (and not the "is empty" too), we could use VAR ?= ... below.

define poison_variable_if_empty_or_contains_whitespace_needs_eval =

  ifeq ($($1),)
    override $(1)=$$(error Variable '$(1)' is empty, but it should not be at this point)
  else
    # GNU Make does not support spaces inside filenames, but I keep forgetting, so check.
    # Adding 'pre' and 'post' checks for leading and trailing whitespace too,
    # because otherwise it is automatically removed.
    # It is hard to pass leading whitespace on the 'make' command line, as it tends to be discarded.
    # Use the escape character ('\') to test leading whitespace.
    ifneq (1,$(words pre$($(1))post))
      override $(1)=$$(error Variable '$(1)' contains whitespace, but that is disallowed)
    endif
  endif

endef

poison_variable_if_empty_or_contains_whitespace = $(eval $(call poison_variable_if_empty_or_contains_whitespace_needs_eval,$(1)))

sentinel_filename = ToolchainBuilder-sentinel-$(1)


# Request and store the configuration help text for each component we are building.
#
# Storing these help texts is not actually required to build a toolchain, but it is often useful
# if you want to troubleshoot the build later on, just look up what an option means,
# or what other options are available.
#
# Many toolchain components have subcomponents with their own 'configure' script.
# The top-level 'configure' script automatically passes all configuration options down.
# This means that the help text for a particular configuration option may be in a subcomponent,
# and that is the reason why we request all help texts in a recursively manner.
#
# We request and store the help texts in parallel across different components because it can take quite some time.
# For example, GCC 11.2's configure script needs more a full second just to print all recursive help texts.
#
# Avoid running the same 'configure' script in parallel. The easiest way to prevent that
# is to make each configuration target depend on its help target.

store_recursive_help = \
	echo && \
	echo "Help text from the $(2) 'configure' script:" && \
	$($(1))/configure --help=recursive | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(2)ConfigHelp.txt" && \
	echo "The $(2) help generation has finished." >"$@" && \
	echo "The $(2) help generation has finished."

# Option --help=recursive failed partially with Newlib versions before 2022.
store_recursive_help_ignore_error = \
	echo && \
	echo "Help text from the $(2) 'configure' script:" && \
	{ $($(1))/configure --help=recursive | tee "$(CROSS_TOOLCHAIN_BUILD_DIR_HELP_FILES)/$(2)ConfigHelp.txt"; true; } && \
	echo "The $(2) help generation has finished." >"$@" && \
	echo "The $(2) help generation has finished."
