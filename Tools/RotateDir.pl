#!/usr/bin/perl

# The following POD section contains placeholders, so it has to be preprocessed by this script first.
#
# HelpBeginMarker

=head1 OVERVIEW

PROGRAM_NAME version SCRIPT_VERSION

This tool makes room for a new slot, deleting older slots if necessary. Each slot is just a directory on disk.

An example where such a directory rotation is useful would be a daily build server, where build results
from the last 10 days should be available at any point in time.

If RotateDir is used from a script, the caller must parse this tool's output in order to recover
the new directory name. Option "--output-only-new-dir-name" helps simplify the parsing, see below.

The top-level containing directory must already exist.

It's best not to place unrelated content in the top-level directory containing the slots,
as any foreign contents are always at risk of being elected
for automatic deletion during rotation. Even if that could never happen in a given configuration,
a future human error modifiying that configuration might lead to unpleasant surprises.

If you are using this script to do rotating backups, and you have a monitoring system,
see script CheckIfAnyFilesModifiedRecently/SanityCheckRotatingBackup.sh for an example
on how to check that backups are still being performed regularly
and the number of slots falls within expectation.

=head1 HOW SLOTS ARE ROTATED

This is what a rotating directory set looks like, in slot age order:

  basedir/rotated-dir-9
  basedir/rotated-dir-10-optional-comment
  basedir/rotated-dir-11 some manual comment
  basedir/rotated-dir-200

If the maximum slot count is 4, then the next time around directory 'rotated-dir-9' will
be deleted and directory "rotated-dir-201" will be created.

Alternatively, directory names can be made of timestamps like this:

  basedir/rotated-dir-2010-12-31
  basedir/rotated-dir-2011-01-01
  basedir/rotated-dir-2011-01-01~2
  basedir/rotated-dir-2011-01-01~3-optional-comment
  basedir/rotated-dir-2011-01-01~4 some manual comment
  basedir/rotated-dir-2011-05-10

Note that, because date "2011-01-01" is duplicated, a sequence number has been automatically appended.

The naming scheme must be based on either plain sequence numbers or timestamps; mixing both
schemes in a single containing directory is not allowed.

The directory's creation date, as recorded in the filesystem, is not considered when determining a slot's age.
Only the slot squence number or timestamp, as recovered from the directory's filename, is taken into account.

This tool does not look at the amount of disk space each slot occupies, it only looks at the number of slots.
The slot size could be taken into account in a future version, but note that the only safe way to limit
disk size on a daily build scenario would be to set a size quota on each separate slot directory
at a file system level. Otherwise, a single run can generate a slot bigger than the combined size limit
for all slots together.

=head1 USAGE

S<perl PROGRAM_NAME [options] E<lt>containing directory nameE<gt>>

=head1 OPTIONS

=over

=item *

B<-h, --OPT_NAME_HELP>

Print this help text.

=item *

B<--version>

Print this tool's name and version number (SCRIPT_VERSION).

=item *

B<--license>

Print the license.

=item *

B<< --OPT_NAME_SELF_TEST >>

Run the built-in self-tests.

=item *

B<-->

Terminate options processing. Useful to avoid confusion between options and a directory name
that begins with a hyphen ('-'). Recommended when calling this script from another script,
where the directory name comes from a variable or from user input.

=item *

B<--slot-count n>

Maximum number of rotating directores on disk. The default is 3.

This option is incompatible with --no-slot-deletion .

=item *

B<--dir-name-prefix E<lt>prefixE<gt>>

Prefix for the rotated directory names. The default is "rotated-dir-".

Warning: all directories whose names have the given prefix are candidates
for automatic deletion when the maximum slot count is reached.

=item *

B<--dir-naming-scheme E<lt>typeE<gt>>

Naming scheme for the rotated directory names. Possible types are:

=over

=item *

sequence

The default. This is a monotonically-increasing integer number
calculated as "the highest value I see on disk at the moment + 1".

On an empty containing directory, the first sequence number will be 1,
but it's best not to rely on this and always look at RotateDir's output.

=item *

date

A timestamp in the form "yyyy-mm-dd", like "2010-12-31". See option
--timestamp for more information.

=back

=item *

B<--timestamp E<lt>yyyy-mm-ddE<gt>>

This option is only allowed when the naming scheme has been set to a timestamp-based type.

The given timestamp will be used to name the new slot directory. An example
timestamp would be "2010-12-31". In order to avoid surprises, it's best to
zero-fill the date fields, therefore "2010-01-02" is better than "2010-1-2".

The new timestamp must be the equal to or greater than the ones already present in the containing directory.
If that is not the case, an error will be generated.

If the same timestamp is already on disk, a sequence number is appended, like "2010-12-31~2".
The first sequence number for timestamp-based naming is 2, but it's best not to
rely on this and always look at RotateDir's output. Further sequence numbers
are calculated as "the highest value I see on disk at the moment + 1".

A standard epoch-based integer timestamp would have been easier to handle,
but there are still unresolved year 2038 issues in perl, see this tool's source code for details.

The default is to take the current local time. An error will be generated
if the perl environment cannot handle years after 2038,
even if that date has not been reached yet.

This option is incompatible with --no-slot-creation .

=item *

B<--dir-name-suffix E<lt>suffixE<gt>>

An optional suffix for the newly-created directory name. This is intended to be used
as a reminder of why the slot was created, that is, it is only a comment.
A hyphen is always inserted before the given suffix.

The following illustrates why such a suffix can be useful:

  basedir/rotated-dir-22-KnownToFail
  basedir/rotated-dir-23-FirstWithGccVersion10
  basedir/rotated-dir-24
  basedir/rotated-dir-25-SameAsBefore

You can manually add or change the suffix after the directory has been created.
In this case, you can use a space as a separator (instead of a hyphen).

=item *

B<< --no-slot-deletion >>

Create a new slot but do not delete any old ones.

This option is incompatible with --slot-count, --no-slot-creation and --deletion-delay.

=item *

B<< --no-slot-creation >>

Make room for a new slot, deleting older slots if necessary,
but do not create a new slot. Therefore, assuming --slot-count is set to 10,
this option will leave a maximum of 9 slots behind.

This option is incompatible with --no-slot-deletion and with --output-only-new-dir-name .

=item *

B<--output-only-new-dir-name>

Print only the new slot's directory name and no other messages.
Useful when running this tool from automated scripts, so that there is no other text output
to parse and discard.
The output includes the containing directory name and a new-line character at the end.

This option is incompatible with --no-slot-creation .

=item *

B<--deletion-delay E<lt>secondsE<gt>>

On Microsoft Windows, sometimes it takes a few seconds for a deleted directory
to actually go away, especially if the user is looking at it
with Windows Explorer. If the delete operation succeeds but the directory
is still visible on the filesystem, RotateDir will wait the given number of seconds
and check again whether the directory continues to exist. If the directory is still there
after the wait, an error will be generated.

The default is 5 seconds. A value of 0 disables the waiting and the second check.

This option is incompatible with --no-slot-deletion .

=back

=head1 EXIT CODE

Exit code: 0 on success, some other value on error.

=head1 FEEDBACK

Please send feedback to rdiezmail-tools at yahoo.de

=head1 LICENSE

Copyright (C) 2011-2022 R. Diez

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License version 3 as published by
the Free Software Foundation.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License version 3 for more details.

You should have received a copy of the GNU Affero General Public License version 3
along with this program.  If not, see L<http://www.gnu.org/licenses/>.

=cut

# HelpEndMarker

use strict;
use warnings;

use FindBin qw( $Bin $Script );
use Getopt::Long qw( GetOptionsFromString );
use File::Glob;
use File::Spec qw();
use File::Path;
use IO::Handle;
use Pod::Usage qw();
use Class::Struct qw();

use constant PROGRAM_NAME => "RotateDir.pl";

use constant SCRIPT_VERSION => "2.15";

use constant EXIT_CODE_SUCCESS       => 0;
use constant EXIT_CODE_FAILURE_ARGS  => 1;
use constant EXIT_CODE_FAILURE_ERROR => 2;

use constant TRUE  => 1;
use constant FALSE => 0;

use constant NS_SEQUENCE => "sequence";
use constant NS_DATE     => "date";

use constant FIRST_SEQUENCE_SEQUENCE_NUMBER  => 1;
use constant FIRST_TIMESTAMP_SEQUENCE_NUMBER => 2;

use constant DATE_SEPARATOR => "-";

# Up until version 2.14 this script used a hyphen ('-'), but from version 2.15 it changed
# to a tilde ('~'), in order to accomodate an optional suffix.
use constant SEQUENCE_NUMBER_SEPARATOR_FOR_DATES     => "~";
use constant SEQUENCE_NUMBER_SEPARATOR_FOR_DATES_OLD => "-";

use constant OPT_NAME_HELP =>'help';
use constant OPT_NAME_SELF_TEST => "self-test";


# This is important: if the sequence numbers overflow, we don't want Perl
# to resort to floating-point numbers.
use integer;


Class::Struct::struct( CSlotInfo =>
        {
          dirName        => '$',
          slotSubdirName => '$',
          afterPrefix    => '$',  # slotSubdirName minus the prefix

          year           => '$',
          month          => '$',
          day            => '$',

          sequenceNumber => '$'
        }
      );


# ----------- main routine, the script entry point is at the bottom -----------

sub main ()
{
  my $arg_help             = FALSE;
  my $arg_h                = FALSE;
  my $arg_help_pod         = FALSE;
  my $arg_version          = FALSE;
  my $arg_license          = FALSE;
  my $arg_self_test        = FALSE;

  my $arg_slotCount;
  my $arg_deletionDelay;
  my $arg_dirNamePrefix    = "rotated-dir-";
  my $arg_dirNameSuffix;
  my $arg_dirNamingScheme  = NS_SEQUENCE;
  my $arg_timestamp;
  my $arg_outputOnlyNewDir = FALSE;
  my $arg_noSlotDeletion   = FALSE;
  my $arg_noSlotCreation   = FALSE;

  Getopt::Long::Configure( "no_auto_abbrev", "prefix_pattern=(--|-)", "no_ignore_case", "require_order" );

  my $result = GetOptions(
                 OPT_NAME_HELP()       => \$arg_help,
                 'h'                   => \$arg_h,
                 'help-pod'            => \$arg_help_pod,
                 'version'             => \$arg_version,
                 'license'             => \$arg_license,
                 OPT_NAME_SELF_TEST()  => \$arg_self_test,

                 'slot-count=s'        =>  \$arg_slotCount,
                 'deletion-delay=s'    =>  \$arg_deletionDelay,
                 'dir-name-prefix=s'   =>  \$arg_dirNamePrefix,
                 'dir-name-suffix=s'   =>  \$arg_dirNameSuffix,
                 'dir-naming-scheme=s' =>  \$arg_dirNamingScheme,
                 'timestamp=s'         =>  \$arg_timestamp,
                 'no-slot-deletion'    =>  \$arg_noSlotDeletion,
                 'no-slot-creation'    =>  \$arg_noSlotCreation,
                 'output-only-new-dir-name' => \$arg_outputOnlyNewDir
                );

  if ( not $result )
  {
    # GetOptions has already printed an error message.
    return EXIT_CODE_FAILURE_ARGS;
  }

  if ( $arg_help || $arg_h )
  {
    print_help_text();
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_help_pod )
  {
    write_stdout( "This file is written in Perl's Plain Old Documentation (POD) format\n" );
    write_stdout( "and has been generated with option --help-pod .\n" );
    write_stdout( "Run the following Perl commands to convert it to HTML or to plain text for easy reading:\n" );
    write_stdout( "\n" );
    write_stdout( "  pod2html README.pod >README.html\n" );
    write_stdout( "  pod2text README.pod >README.txt\n" );
    write_stdout( "\n\n" );
    write_stdout( get_pod_from_this_script() );
    write_stdout( "\n" );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_version )
  {
    write_stdout( "RotateDir version " . SCRIPT_VERSION . "\n" );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_license )
  {
    write_stdout( get_license_text() );
    return EXIT_CODE_SUCCESS;
  }

  if ( $arg_self_test )
  {
    write_stdout( "Running the self-tests...\n" );
    self_test();
    write_stdout( "\nSelf-tests finished.\n" );
    exit EXIT_CODE_SUCCESS;
  }


  if ( $arg_noSlotDeletion && ( defined( $arg_slotCount ) || $arg_noSlotCreation || defined( $arg_deletionDelay ) ) )
  {
    die "Option --no-slot-deletion is incompatible with options --slot-count, --no-slot-creation and --deletion-delay .\n";
  }

  if ( $arg_noSlotCreation && $arg_outputOnlyNewDir )
  {
    die "Option --no-slot-creation is incompatible with option --output-only-new-dir-name.\n";
  }

  if ( not defined $arg_slotCount )
  {
    $arg_slotCount = 3;  # Default value.
  }

  if ( has_non_digits( $arg_slotCount ) )
  {
    die qq<Invalid slot count "$arg_slotCount".\n>;
  }


  if ( not defined $arg_deletionDelay )
  {
    $arg_deletionDelay = 5;  # Default value.
  }

  if ( has_non_digits( $arg_deletionDelay ) )
  {
    die qq<Invalid deletion delay "$arg_deletionDelay".\n>;
  }

  if ( $arg_slotCount < 1 )
  {
    die "The slot count must be at least 1.\n";
  }

  if ( $arg_dirNamingScheme ne NS_SEQUENCE and
       $arg_dirNamingScheme ne NS_DATE )
  {
    die qq<Invalid naming scheme "$arg_dirNamingScheme".\n>;
  }

  if ( defined( $arg_timestamp ) )
  {
    if ( $arg_dirNamingScheme ne NS_DATE )
    {
      die "Option --timestamp is only allowed together with a timestamp-based naming scheme.\n";
    }

    if ( $arg_noSlotCreation )
    {
      die "Option --timestamp is incompatible with option --no-slot-creation.\n";
    }
  }

  if ( 1 != scalar @ARGV )
  {
    die "Invalid number of arguments. Run this tool with the --help option for usage information.\n";
  }

  my $baseDir = shift @ARGV;

  my @allSlots = scan_slots( $baseDir, $arg_dirNamePrefix );

  my $newSlotName;

  if ( $arg_dirNamingScheme eq NS_SEQUENCE )
  {
    $newSlotName = process_sequence_slots( \@allSlots );
  }
  elsif ( $arg_dirNamingScheme eq NS_DATE )
  {
    if ( $arg_noSlotCreation )
    {
      process_timestamp_slots( \@allSlots, undef );
      $newSlotName = undef;
    }
    else
    {
      my $nextTimestamp = get_next_timestamp( $arg_timestamp );

      $newSlotName = process_timestamp_slots( \@allSlots, $nextTimestamp );
    }
  }
  else
  {
    # This should have been checked before.
    die qq<Invalid naming scheme "$arg_dirNamingScheme".\n>;
  }

  if ( not $arg_noSlotDeletion )
  {
    delete_old_slots( \@allSlots,
                      $arg_slotCount,
                      $arg_outputOnlyNewDir,
                      $arg_deletionDelay );
  }

  if ( not $arg_noSlotCreation )
  {
    my $newSubdirname = $arg_dirNamePrefix . $newSlotName;

    if ( defined( $arg_dirNameSuffix ) )
    {
      $newSubdirname .= "-" . $arg_dirNameSuffix;
    }

    create_new_slot( $baseDir,
                     $newSubdirname,
                     $arg_outputOnlyNewDir );
  }

  return EXIT_CODE_SUCCESS;
}


sub replace_script_specific_help_placeholders ( $ )
{
  my $podAsStr = shift;

  $podAsStr =~ s/OPT_NAME_SELF_TEST/@{[ OPT_NAME_SELF_TEST ]}/gs;

  return $podAsStr;
}


sub self_test ()
{
  self_test_parse_timestamp();
}


sub scan_slots ( $ $ )
{
  my $baseDir = shift;
  my $prefix  = shift;

  validate_dir_name_prefix( $prefix );

  if ( not -d $baseDir )
  {
    die qq<The containing directory "$baseDir" does not exist.\n>;
  }

  my $globPattern = cat_path( $baseDir, "$prefix*" );

  my @matchedDirs = File::Glob::bsd_glob( $globPattern, &File::Glob::GLOB_ERR | &File::Glob::GLOB_NOSORT );

  if ( &File::Glob::GLOB_ERROR )
  {
    die "Error listing existing directories: $!\n";
  }

  if ( FALSE )
  {
    write_stderr( scalar(@matchedDirs) . " matched dirs:\n" . join( "\n", @matchedDirs ) . "\n" );
  }

  my @allSlots;

  foreach my $dirName ( @matchedDirs )
  {
    next if not -d $dirName;

    my ( $volume, $directories, $fileName ) = File::Spec->splitpath( $dirName );

    next if !str_starts_with( $fileName, $prefix );

    my $afterPrefix = substr( $fileName, length $prefix );

    my $slotFound = CSlotInfo->new( dirName        => $dirName ,
                                    slotSubdirName => $fileName,
                                    afterPrefix    => $afterPrefix );

    if ( FALSE )
    {
      write_stderr( "Dirname: $dirName, slot subdir name: $fileName, after prefix: $afterPrefix\n" );
    }

    push @allSlots, $slotFound;
  }

  return @allSlots;
}


sub validate_dir_name_prefix ( $ )
{
  my $prefix = shift;

  # Do not allow any special bsd_glob meta characters in the directory name prefix,
  # as it could be dangerous.

  for ( my $i = 0; $i < length( $prefix ); ++$i )
  {
    my $c = substr( $prefix, $i, 1 );

    if ( $c eq "\\" or
         $c eq "["  or
         $c eq "]"  or
         $c eq "{"  or
         $c eq "}"  or
         $c eq "*"  or
         $c eq "?"  or
         $c eq "~" )
    {
      die "Character '$c' is not allowed in directory name prefix \"$prefix\".";
    }
  }
}


sub process_sequence_slots ( $ )
{
  my $allSlots = shift;


  my $parseSeqNumRegex  =  "\\A";        # Start of string.
     $parseSeqNumRegex .=  "(\\d+)";     # Capture the sequence number.
     $parseSeqNumRegex .=  "([- ].*)?";  # An optional suffix that begins with a '-' or a space and extends until the end of the string.
                                         # The suffix can be empty, but that probably does not make much sense.
                                         # We do not actually need to capture the suffix, but I could not find a way to
                                         # specify a non-capturing group in Perl.
     $parseSeqNumRegex .=  "\\z";        # End of string.

  my $compiledParseSeqNumRegex = qr/$parseSeqNumRegex/as;


  my $nextSequenceNumber = FIRST_SEQUENCE_SEQUENCE_NUMBER;

  foreach my $slotFound ( @$allSlots )
  {
    my @seqNumParts = $slotFound->afterPrefix =~ m/$compiledParseSeqNumRegex/;

    if ( scalar( @seqNumParts ) < 1 )
    {
      die "Cannot extract the slot number from directory name \"" . $slotFound->slotSubdirName . "\".\n";
    }

    my $sequenceNumber = $seqNumParts[ 0 ];

    if ( FALSE )
    {
      write_stdout( "After prefix: <" . $slotFound->afterPrefix . ">\n" );
      write_stdout( "Seq number  : <" . $sequenceNumber . ">\n" );
    }

    # If the number is too big, apparently it gets internally converted to zero,
    # which will make this test fail.
    if ( $sequenceNumber < FIRST_SEQUENCE_SEQUENCE_NUMBER )
    {
      die "Invalid sequence number \"" . $sequenceNumber . "\".\n";
    }

    $slotFound->sequenceNumber( $sequenceNumber );

    if ( $sequenceNumber >= $nextSequenceNumber )
    {
      $nextSequenceNumber = $sequenceNumber + 1;
      check_valid_sequence_number( $nextSequenceNumber );
    }
  }

  return "$nextSequenceNumber";
}


sub process_timestamp_slots ( $ $ )
{
  my $allSlots      = shift;
  my $nextTimestamp = shift;  # If undef, there will be no next slot.

  my $nextSequenceNumber = FIRST_TIMESTAMP_SEQUENCE_NUMBER - 1;

  foreach my $slotFound ( @$allSlots )
  {
    eval
    {
      parse_timestamp( $slotFound->afterPrefix, TRUE, $slotFound );
    };

    my $errorMessage = $@;

    if ( $errorMessage )
    {
      die "Error extracting the timestamp from slot \"" . $slotFound->slotSubdirName . "\": $errorMessage\n";
    }

    if ( defined $nextTimestamp )
    {
      my $cmp = compare_timestamps( $slotFound, $nextTimestamp );

      if ( $cmp >= 1 )
      {
        die "The given or current timestamp \"" .
            format_timestamp( $nextTimestamp->year,
                              $nextTimestamp->month,
                              $nextTimestamp->day ) .
            "\" is less than the timestamp extracted from existing slot \"" .
            $slotFound->slotSubdirName . "\".\n";
      }

      if ( $cmp == 0 )
      {
        if ( $slotFound->sequenceNumber >= $nextSequenceNumber )
        {
          $nextSequenceNumber = $slotFound->sequenceNumber + 1;
          check_valid_sequence_number( $nextSequenceNumber );
        }
      }
    }
  }

  if ( defined $nextTimestamp )
  {
    my $suffix = $nextSequenceNumber < FIRST_TIMESTAMP_SEQUENCE_NUMBER
                     ? ""
                     : SEQUENCE_NUMBER_SEPARATOR_FOR_DATES . "$nextSequenceNumber";

    return format_timestamp( $nextTimestamp->year,
                             $nextTimestamp->month,
                             $nextTimestamp->day ) .
           $suffix;
  }
  else
  {
    return undef;
  }
}


# If the integer number overflows, we want to find out straight away.

sub check_valid_sequence_number ( $ )
{
  my $val = shift;

  if ( has_non_digits( "$val" ) )
  {
    die "Integer overflow calculating the sequence number.\n";
  }
}


sub delete_old_slots ( $ $ $ )
{
  my $allSlots         = shift;
  my $slotCount        = shift;
  my $outputOnlyNewDir = shift;
  my $deletionDelay    = shift;

  my $currentSlotCount = scalar @$allSlots;

  if ( FALSE )
  {
    write_stderr( $currentSlotCount . " slots:\n" . join( "\n", @$allSlots ) . "\n" );
  }

  return if ( $currentSlotCount < $slotCount );

  my @toDelete = sort compare_slots @$allSlots;

  # Shorten the array, leave only the slots to delete.
  $#toDelete -= $slotCount - 1;

  foreach my $del ( @toDelete )
  {
    if ( !$outputOnlyNewDir )
    {
      write_stdout( "Deleting old slot \"" . $del->slotSubdirName . "\" ... ");
    }

    # Under Linux, rmtree has the bad habit of printing error messages to stderr
    # when it cannot delete a directory due to insufficient permissions.
    # If we don't flush stdout at this point, the error message may
    # come before the progress message.
    flush_stdout();

    delete_folder( $del->dirName, FALSE, $deletionDelay );

    if ( !$outputOnlyNewDir )
    {
      write_stdout( "\n" );
    }
  }
}


sub create_new_slot ( $ $ $ )
{
  my $baseDir          = shift;
  my $newSubdirName    = shift;
  my $outputOnlyNewDir = shift;

  if ( ! $outputOnlyNewDir )
  {
    write_stdout( "Creating new slot \"" . $newSubdirName . "\" ... " );
  }

  my $fullpath = cat_path( $baseDir, $newSubdirName );

  if ( -e $fullpath )
  {
    die "Unexpected error: filename \"$fullpath\" already exists.\n";
  }

  mkdir( $fullpath ) or
    die "Error creating directory \"$fullpath\": $!\n";

  if ( ! $outputOnlyNewDir )
  {
    write_stdout( "\n" );
  }

  if ( $outputOnlyNewDir )
  {
    write_stdout( $fullpath . "\n" );
  }
}


sub format_timestamp ( $ $ $ )
{
  my $year  = shift;
  my $month = shift;
  my $day   = shift;

  return sprintf( "%04d" . DATE_SEPARATOR . "%02d" . DATE_SEPARATOR . "%02d",
                  $year,
                  $month,
                  $day );
}


sub get_next_timestamp ( $ )
{
  my $timestampStr = shift;

  my $nextTimestamp = CSlotInfo->new();

  if ( defined $timestampStr )
  {
    eval
    {
      parse_timestamp( $timestampStr, FALSE, $nextTimestamp );
    };

    my $errorMessage = $@;

    if ( $errorMessage )
    {
      die qq<Error parsing timestamp "$timestampStr": $errorMessage\n>;
    }
  }
  else
  {
    use constant MORE_THAN_32BITS => 2247483650;

    my ($sec2,$min2,$hour2,$mday2,$mon2,$year2,$wday2,$yday2,$isdst2) = localtime( MORE_THAN_32BITS );
    $mon2 += 1;
    $year2 += 1900;

    if ( $year2 != 2041 )
    {
      # Fixing this script (see the error message below) is not so easy.
      # There are CPAN modules that can help, but they are not available
      # by default on all platforms.

      die "This perl environment cannot handle dates greater than 2038. " .
          "You can either fix this script or provide the current date with the --timestamp option.\n";
    }

    eval
    {
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime( time() );
      $mon  += 1;
      $year += 1900;
      my $timestampStr = format_timestamp( $year, $mon, $mday );
      parse_timestamp( $timestampStr, FALSE, $nextTimestamp );
    };

    my $errorMessage = $@;

    if ( $errorMessage )
    {
      die qq<Error retrieving the current date: $errorMessage\n>;
    }
  }

  return $nextTimestamp;
}


sub compare_timestamps ( $ $ )
{
  my $left  = shift;
  my $right = shift;

  if ( FALSE )
  {
    write_stderr( "Comparing timestamps (" .
                  format_timestamp( $left->year,
                                    $left->month,
                                    $left->day ) .
                  ", " .
                  $left->sequenceNumber .
                  ") and (" .
                  format_timestamp( $right->year,
                                    $right->month,
                                    $right->day ) .
                  ", " .
                  $right->sequenceNumber .
                  ").\n" );
  }


  my $yearCmp = $left->year <=> $right->year;

  return $yearCmp if ( $yearCmp != 0 );

  my $monthCmp = $left->month <=> $right->month;

  return $monthCmp if ( $monthCmp != 0 );

  return $left->day <=> $right->day;
}


# Do not add a space between or around the two $$ in the function prototype below.
# Perl version v5.22.1 on my system does not tolerate spaces there anymore.

sub compare_slots ($$)
{
  if ( FALSE )
  {
    write_stderr( "compare_slots() received " . scalar @_ . " arguments:\n" . join( "\n", @_ ) . "\n" );
  }

  my $left  = shift;
  my $right = shift;

  if ( FALSE )
  {
    write_stderr( "Comparing slots \"$left->dirname\" and \"$right->dirname\".\n" );
  }

  if ( defined( $left->year ) )
  {
    my $dateCmp = compare_timestamps( $left, $right );

    return $dateCmp if ( $dateCmp != 0 );
  }

  my $result = $left->sequenceNumber <=> $right->sequenceNumber;

  if ( $result == 0 )
  {
    my $errMsg = "Duplicate sequence number " . $left->sequenceNumber . " in " .
                 format_str_for_message( $left ->slotSubdirName ) . " and " .
                 format_str_for_message( $right->slotSubdirName ) . ".";

    if ( $left->sequenceNumber eq FIRST_TIMESTAMP_SEQUENCE_NUMBER - 1 )
    {
      $errMsg .= " Are the directory names using the old separator ('@{[ SEQUENCE_NUMBER_SEPARATOR_FOR_DATES_OLD ]}') " .
                 "instead of ('@{[ SEQUENCE_NUMBER_SEPARATOR_FOR_DATES ]}') for the sequence number?";
    }

    die $errMsg . "\n";
  }

  return $result;
}


my $timestampRegex  =  "\\A";           # Start of string.
   $timestampRegex .=  "(\\d+)";        # Match the year as a number.
   $timestampRegex .=  DATE_SEPARATOR;
   $timestampRegex .=  "(\\d+)";        # Match the month as a number.
   $timestampRegex .=  DATE_SEPARATOR;
   $timestampRegex .=  "(\\d+)";        # Match the day as a number.

   $timestampRegex .=  "(" . SEQUENCE_NUMBER_SEPARATOR_FOR_DATES . "\\d+" . ")?";  # An optional sequence number.

   $timestampRegex .=  "([- ].*)?";     # An optional suffix that begins with a '-' or a space and extends until the end of the string.
                                        # The suffix can be empty, but that probably does not make much sense.

   $timestampRegex .=  "\\z";           # End of string.

my $compiledTimestampRegex = qr/$timestampRegex/as;

sub parse_timestamp ( $ $ $ )
{
  my $str                 = shift;
  my $allowSequenceNumber = shift;  # This allows the optional suffix too.
  my $slotInfo            = shift;

  # Examples of strings to parse:
  #   2011-10-24           (without sequence number)
  #   2011-10-24~3         (with    sequence number)
  #   2011-10-24~3-comment (with    sequence number and suffix)
  #   2011-10-24~3 comment (with    sequence number and suffix)
  # See the self-test code for more such strings.

  my @dateParts = $str =~ m/$compiledTimestampRegex/;

  if ( scalar( @dateParts ) < 3 )
  {
    die "Invalid date format.\n";
  }

  $slotInfo->year ( $dateParts[ 0 ] );
  $slotInfo->month( $dateParts[ 1 ] );
  $slotInfo->day  ( $dateParts[ 2 ] );

  my $seqNum;

  if ( scalar( @dateParts ) >= 4 )
  {
    $seqNum = $dateParts[ 3 ];
  }

  if ( scalar( @dateParts ) >= 5 )
  {
    my $suffix = $dateParts[ 4 ];

    if ( defined( $suffix ) and not $allowSequenceNumber )
    {
      die "Invalid suffix after date: " . format_str_for_message( $suffix ) . "\n";
    }
  }


  # I'm paranoid with the year 2038 problem. If the year is too low, generate an error right away.
  if ( $slotInfo->year < 2010 )
  {
    die "Year \"" . $slotInfo->year . "\" is invalid.\n";
  }

  if ( $slotInfo->month < 1 or $slotInfo->month > 12 )
  {
    die "Month \"" . $slotInfo->month . "\" is invalid.\n";
  }

  if ( $slotInfo->day < 1 or $slotInfo->day > 31 )
  {
    die "Day \"" . $slotInfo->day . "\" is invalid.\n";
  }

  if ( ! defined( $seqNum ) )
  {
    $slotInfo->sequenceNumber( FIRST_TIMESTAMP_SEQUENCE_NUMBER - 1 );
  }
  else
  {
    if ( not $allowSequenceNumber )
    {
      die "Invalid sequence number after date.\n";
    }

    # The captured sequence number includes the SEQUENCE_NUMBER_SEPARATOR_FOR_DATES prefix.
    my $sequenceStr = substr( $seqNum, length( SEQUENCE_NUMBER_SEPARATOR_FOR_DATES ) );

    # If the number is too big, apparently it gets internally converted to zero,
    # which will make this test fail.
    if ( $sequenceStr < FIRST_TIMESTAMP_SEQUENCE_NUMBER )
    {
      die "Invalid sequence number \"$sequenceStr\".\n";
    }

    $slotInfo->sequenceNumber( $sequenceStr );
  }

  if ( FALSE )
  {
    write_stderr( "Parsed timestamp: \"$str\" -> " .
                  format_timestamp( $slotInfo->year,
                                    $slotInfo->month,
                                    $slotInfo->day ) .
                  ", " .
                  $slotInfo->sequenceNumber .
                  ".\n" );
  }
}


sub pts_test_case ( $ $ $ $ $ )
{
  my $strToParse             = shift;
  my $expectedYear           = shift;
  my $expectedMonth          = shift;
  my $expectedDay            = shift;
  my $expectedSequenceNumber = shift;

  my $slotInfo = CSlotInfo->new();

  eval
  {
    parse_timestamp( $strToParse,
                     defined( $expectedSequenceNumber ) ? TRUE : FALSE,
                     $slotInfo );

    my $seqNo = defined( $expectedSequenceNumber ) ? $expectedSequenceNumber : FIRST_TIMESTAMP_SEQUENCE_NUMBER - 1;

    if ( $slotInfo->year           != $expectedYear  ||
         $slotInfo->month          != $expectedMonth ||
         $slotInfo->day            != $expectedDay   ||
         $slotInfo->sequenceNumber != $seqNo          )
    {
      die "The information parsed does not match expectations.\n";
    }
  };

  my $errorMessage = $@;

  if ( $errorMessage )
  {
    die "Test case for parse_timestamp() failed for " . format_str_for_message( $strToParse ) . ": " . $errorMessage;
  }
}


sub self_test_parse_timestamp ()
{
  write_stdout( "Testing parse_timestamp()...\n" );

  pts_test_case( "2020-06-29"               , 2020, 06, 29, undef );
  pts_test_case( "2020-06-29"               , 2020, 06, 29,     1 );
  pts_test_case( "2020-06-29-comment"       , 2020, 06, 29,     1 );
  pts_test_case( "2020-06-29 comment"       , 2020, 06, 29,     1 );
  pts_test_case( "2020-06-29~123"           , 2020, 06, 29,   123 );
  pts_test_case( "2020-06-29~123 my comment", 2020, 06, 29,   123 );
  pts_test_case( "2020-06-29~123-my-comment", 2020, 06, 29,   123 );
  pts_test_case( "2020-06-29~123-my comment", 2020, 06, 29,   123 );
}


#------------------------------------------------------------------------

sub write_stdout ( $ )
{
  my $str = shift;

  ( print STDOUT $str ) or
     die "Error writing to standard output: $!\n";
}

sub write_stderr ( $ )
{
  my $str = shift;

  ( print STDERR $str ) or
     die "Error writing to standard error: $!\n";
}


sub flush_stdout ()
{
  if ( ! defined( STDOUT->flush() ) )
  {
    # The documentation does not say whether $! is set. I am hoping that it does,
    # because otherwise there is no telling what went wrong.
    die "Error flushing standard output: $!\n";
  }
}


sub close_or_die ( $ $ )
{
  close ( $_[0] ) or die "Internal error: Cannot close file handle of file " . format_str_for_message( $_[1] ) . ": $!\n";
}


# Say you have the following logic:
# - Open a file.
# - Do something that might fail.
# - Close the file.
#
# If an error occurs between opening and closing the file, you need to
# make sure that you close the file handle before propagating the error upwards.
#
# You should not die() from an eventual error from close(), because we would
# otherwise be hiding the first error that happened. But you should
# generate at least warning, because it is very rare that closing a file handle fails.
# This is usually only the case if it has already been closed (or if there is some
# serious memory corruption).
#
# Writing the warning to stderr may also fail, but you should ignore any such eventual
# error for the same reason.

sub close_file_handle_or_warn ( $ $ )
{
  my $fileHandle = shift;
  my $filename   = shift;

  close( $fileHandle )
    or print STDERR "Warning: Internal error in '$Script': Cannot close file handle of " . format_str_for_message( $filename ) . ": $!\n";
}


sub if_error_close_file_handle_and_rethrow ( $ $ $ )
{
  my $fileHandle       = shift;
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if ( $errorMsgFromEval )
  {
    close_file_handle_or_warn( $fileHandle, $filename );

    die $errorMsgFromEval;
  }
}


sub close_file_handle_and_rethrow_eventual_error ( $ $ $ )
{
  my $fileHandle       = shift;
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if_error_close_file_handle_and_rethrow( $fileHandle, $filename, $errorMsgFromEval );

  close_or_die( $fileHandle, $filename );
}


sub rethrow_eventual_error_with_filename ( $ $ )
{
  my $filename         = shift;
  my $errorMsgFromEval = shift;

  if ( $errorMsgFromEval )
  {
    # Do not say "file" here, because it could be a directory.
    die "Error accessing " . format_str_for_message( $filename ) . ": $errorMsgFromEval";
  }
}


# This routine does not include the filename in an eventual error message.

sub open_file_for_binary_reading ( $ )
{
  my $filename = shift;

  open( my $fileHandle, "<", "$filename" )
    or die "Cannot open the file: $!\n";

  binmode( $fileHandle )  # Avoids CRLF conversion.
    or die "Cannot access the file in binary mode: $!\n";

  return $fileHandle;
}


#------------------------------------------------------------------------
#
# Returns a true value if the string starts with the given 'beginning' argument.
#

sub str_starts_with ( $ $ )
{
  my $str       = shift;
  my $beginning = shift;

  if ( length($str) < length($beginning) )
  {
    return 0;
  }

  return substr($str, 0, length($beginning)) eq $beginning;
}


#------------------------------------------------------------------------
#
# Returns a true value if the string ends in the given 'ending'.
#

sub str_ends_with ( $ $ )
{
  my $str    = shift;
  my $ending = shift;

  if ( length($str) < length($ending) )
  {
    return 0;
  }

  return substr($str, -length($ending), length($ending)) eq $ending;
}


#------------------------------------------------------------------------
#
# Useful to parse integer numbers.
#

sub has_non_digits ( $ )
{
  my $str = shift;

  # \D and \d would match anything that Unicode says it is a number somewhere in the world,
  # which could even introduce a security issue. So specifically ask for ASCII numbers only.

  my $scalar = $str =~ m/[^0-9]/;

  return $scalar;
}


#------------------------------------------------------------------------
#
# Sometimes we want to generate an error message meant for humans which contains the string
# that caused the error. However, the string that we want to embed in the error message may be problematic:
# 1) It may be too long, rendering the error message unreadable.
# 2) It may have characters that make it difficult to know where the embedded string begins
#    and ends inside the error message.
# 3) It may have ASCII control characters that will cause visualisation problems depending
#    on the terminal or editor.
#
# This routine escapes away any problematic characters, shortens the string if necessary
# and surrounds it in double quotation marks. The resulting string can be safely embedded
# in a larger text.
#
# Examples of such quoted strings:
#   "abc"
#   " abc "
#   "a<TAB>b<CR>c"
#   "a<QUOT>b"
#
# The quoted string is designed for maximum readability, so there is a trade-off:
# it cannot be reliably unquoted, because some encodings are ambiguous. For example,
# a string like 'a<TAB>b' will pass through without any quoting. The receiver will
# have no way to know whether the original string had a single tab character,
# or the 5 characters '<TAB>'.
#
# I have decided to use this ambiguous quoting rules because any other escaping mechanisms
# I know are hard to read or pose more questions, and the focus here is readability in
# informational messages for humans who cannot be bother to read the encodind specification.
#
# Example of hard-to-read or ugly quotation mechanisms:
#   URL encoding: a%30%40%40b
#   Shell: "\"Spaces\ get\ quoted\""
#   Perl Unicode literals: \x{1234}x\x{4567}
#   Perl Unicode literals: \N{U+1234}N\N{U+4567}
#
# Because all quoted characters are <= 127, this routine is safe to use before or after
# converting a string to or from UTF-8.

my %escapeTable =
(
   0  => "NUL",
   1  => "SOH",
   2  => "STX",
   3  => "ETX",
   4  => "EOT",
   5  => "ENQ",
   6  => "ACK",
   7  => "BEL",
   8  => "BS",
   9  => "TAB",  # The ASCII name is actually HT for Horizontal Tab.
  10  => "LF",
  11  => "VT",
  12  => "FF",
  13  => "CR",
  14  => "SO",
  15  => "SI",
  16  => "DLE",
  17  => "DC1",
  18  => "DC2",
  19  => "DC3",
  20  => "DC4",
  21  => "NAK",
  22  => "SYN",
  23  => "ETB",
  24  => "CAN",
  25  => "EM",
  26  => "SUB",
  27  => "ESC",
  28  => "FS",
  29  => "GS",
  30  => "RS",
  31  => "US",  # In octal: 037

  34  => "QUOT", # Double quotation mark, in octal: 042

 127  => "DEL", # In octal: 0177

 # Anything above 127 may display as rubbish in a terminal or in a text editor, depending on the encoding,
 # but it will probably cause no big problems like a line break.
);

sub format_str_for_message ( $ )
{
  my $str = shift;

  $str =~ s/([\000-\037\042\177])/ '<' . $escapeTable{ ord $1 } . '>' /eg;

  # This is some arbitrary length limit. Some people would like to see more text, some less.
  use constant FSFM_MAX_LEN => 300;

  use constant FSFM_SUFFIX => "[...]";

  if ( length( $str ) > FSFM_MAX_LEN )
  {
    my $lenToPreserve = FSFM_MAX_LEN - length( FSFM_SUFFIX );

    if ( FALSE )
    {
      # substr() can turn a Perl string marked as UTF-8 to a native/byte string,
      # so avoid it because we want to support the assertion strategy enabled by ENABLE_UTF8_RESEARCH_CHECKS.
      $str = substr( $str, 0, FSFM_MAX_LEN - length( FSFM_SUFFIX ) ) . FSFM_SUFFIX;
    }
    else
    {
      my @capture = $str =~ m/\A(.{$lenToPreserve})/;

      $str = $capture[ 0 ] . FSFM_SUFFIX;
    }
  }

  return '"' . $str . '"';
}


#------------------------------------------------------------------------
#
# Returns a true value if the Operating System is Microsoft Windows.
#

sub is_windows ()
{
  return $^O eq 'MSWin32';
}


#------------------------------------------------------------------------
#
# Helpers to run a process.
#

sub reason_died_from_wait_code ( $ )
{
  my $wait_code = shift;

  my $exit_code   = $wait_code >> 8;
  my $signal_num  = $wait_code & 127;
  my $dumped_core = $wait_code & 128;

  if ( $signal_num != 0 )
  {
    return "Indication of signal $signal_num.";
  }

  if ( $dumped_core != 0 )
  {
    return "Indication of core dump.";
  }

  return "Exit code $exit_code.";
}


sub run_process
{
  my $ret = system( @_ );

  if ( $ret == -1 )
  {
    # system() has probably already printed an error message, but you cannot be sure.
    # In any case, the error message does not contain the whole failed command.
    die "Failed to execute external command \"" . join( ' ', @_ ) . "\", ".
        "the error returned was: $!" . "\n";
  }

  my $exit_code   = $ret >> 8;
  my $signal_num  = $ret & 127;
  my $dumped_core = $ret & 128;

  if ( $signal_num != 0 || $dumped_core != 0 )
  {
    die "Error: Child process \"" . join( ' ', @_ ) . "\" died: ".
        reason_died_from_wait_code( $ret ) . "\n";
  }

  return $exit_code;
}


sub run_process_exit_code_0
{
  my $exitCode = run_process( @_ );

  if ( $exitCode != 0 )
  {
    die "The following external command signalled an error with exit code $exitCode: " . join( ' ', @_ ) . "\n";
  }
}


#------------------------------------------------------------------------
#
# Deletes the given folder.
#
# On Microsoft Windows, sometimes it takes a few seconds for a deleted directory
# to actually go away, especially if the user is looking at it
# with Windows Explorer. If the delete operation succeeds but the directory
# is still visible on the filesystem, this routine will wait the given number of seconds
# and check again whether the directory continues to exist. If the directory is still there
# after the wait, an error will be generated.
#
# Security note: If it fails, the error message will contain the folder it couldn't delete.
#

sub delete_folder ( $ $ $ )
{
  my $folder_path    = shift;
  my $print_progress = shift;
  my $deletionDelay  = shift;

  if ( $print_progress )
  {
    write_stdout( qq<Deleting existing folder "$folder_path"... > );
  }

  # If you believe that Perl's File::Path::rmtree is too slow, you can switch to "rm -rf" under Unix:
  use constant USE_RM_RF_UNDER_UNIX => FALSE;

  # Always trace the deletion operation, so that you can see how long File::Path::rmtree or "rm -rf" takes
  # to delete the files, even if $print_progress is disabled:
  use constant DEBUG_TRACE_TO_STDERR => FALSE;

  if ( is_windows() || ! USE_RM_RF_UNDER_UNIX )
  {
    if ( DEBUG_TRACE_TO_STDERR )
    {
      write_stderr( qq<Deleting existing folder "$folder_path" with File::Path::rmtree() ... > );
    }

    my $deleteCount = File::Path::rmtree( $folder_path );

    if ( $deleteCount < 1 )
    {
      die "deleteCount: $deleteCount --- Cannot delete folder \"$folder_path\".\n";
    }
  }
  else
  {
    if ( DEBUG_TRACE_TO_STDERR )
    {
      write_stderr( qq<Deleting existing folder "$folder_path" with rm -rf ... > );
    }

    run_process_exit_code_0( "rm", "-rf", "--", $folder_path );
  }

  if ( $print_progress )
  {
    write_stdout( qq<done\n> );
  }

  if ( DEBUG_TRACE_TO_STDERR )
  {
    write_stderr( qq<done\n> );
  }

  # Double-check the folder is not there any more.
  # If it's not, we are done.

  if ( not -d $folder_path )
  {
    return;
  }


  if ( $deletionDelay > 0 )
  {
    # Give it a few seconds, so that Windows Explorer realises
    # and stops showing the deleted folder. After that,
    # or maybe just after a short time, the folder usually
    # disappears and we can be confident it has been deleted.

    if ( $print_progress )
    {
      write_stdout( "WARNING: The just-deleted folder is still visible. Waiting to see if it goes away..." );
      flush_stdout();
    }

    sleep_seconds( $deletionDelay );

    if ( not -d $folder_path )
    {
      if ( $print_progress )
      {
        write_stdout( " done\n" );
      }
      return;
    }
  }

  die qq(The deleted folder tree "$folder_path" is still present, ) .
      qq(this usually happens under Windows if an Explorer window ) .
      qq(is open on that folder, a second attempt usually succeeds.\n);
}


#------------------------------------------------------------------------
#
# Concatenates different path components together,
# adding dir slashes where necessary.
#
# Normally, the last element to concatenate is the file name.
#
# Example:  cat_path( "dir", "subdir", "file.txt" )
#           returns "dir/subdir/file.txt".
#
# If a component is empty or undef, it ignores it.
# For example, the following are equivalent:
#    cat_path( "a", "b" )
#    cat_path( "", "a", "", "b", "" )
#    cat_path( undef, "a", undef, "b", undef )
# This helps when joining the results of File::Spec->splitpath().
#
# Never returns undef, the smallest thing it ever returns
# is the empty string "".
#
# An alternative to consider would be File::Spec->catpath().
#

sub cat_path
{
  my $slash = "/";
  my $res = "";

  for ( my $i = 0; $i < scalar(@_); $i++ )
  {
    if ( not defined($_[$i]) or $_[$i] eq "" )
    {
      next;
    }

    if ( $res eq "" or str_ends_with( $res, $slash ) )
    {
      $res .= $_[$i];
    }
    else
    {
      $res .= $slash . $_[$i];
    }
  }

  return $res;
}


#------------------------------------------------------------------------
#
# Waits at least for the given number of seconds.
#
# Note that it can actually wait longer than specified if the call to wait()
# gets interrupted by a signal and it has to sleep again.
#

sub sleep_seconds ( $ )
{
  my $to_wait = shift;

  for ( my $total_waited = 0 ; $total_waited < $to_wait ; )
  {
    $total_waited += sleep( $to_wait - $total_waited );
  }
}


# Reads a whole binary file, returns it as a scalar.
#
# Security warning: Any eventual error message will contain the file path.
#
# Alternative: use Perl module File::Slurp

sub read_whole_binary_file ( $ )
{
  my $filename = shift;

  # I believe that standard tool 'cat' uses a 128 KiB buffer size under Linux.
  use constant SOME_ARBITRARY_BLOCK_SIZE_RWBF => 128 * 1024;

  my $fileContent;

  eval
  {
    my $fileHandle = open_file_for_binary_reading( $filename );

    eval
    {
      my $pos = 0;

      for ( ; ; )
      {
        my $readByteCount = sysread( $fileHandle, $fileContent, SOME_ARBITRARY_BLOCK_SIZE_RWBF, $pos );

        if ( not defined $readByteCount )
        {
          die "Error reading from file: $!\n";
        }

        if ( $readByteCount == 0 )
        {
          last;
        }

        $pos += $readByteCount;
      }
    };

    close_file_handle_and_rethrow_eventual_error( $fileHandle, $filename, $@ );
  };

  rethrow_eventual_error_with_filename( $filename, $@ );

  return $fileContent;
}


sub print_help_text ()
{
  my $podAsStr = get_pod_from_this_script();


  # Prepare an in-memory file with the POD contents.

  my $memFileWithPodContents;

  open( my $memFileWithPod, '+>', \$memFileWithPodContents )
    or die "Cannot create in-memory file: $!\n";

  binmode( $memFileWithPod )  # Avoids CRLF conversion.
    or die "Cannot access in-memory file in binary mode: $!\n";

  ( print $memFileWithPod $podAsStr ) or
    die "Error writing to in-memory file: $!\n";

  seek $memFileWithPod, 0, 0
    or die "Cannot seek inside in-memory file: $!\n";


  write_stdout( "\n" );

  # Unfortunately, pod2usage does not return any error indication.
  # However, if the POD text has syntax errors, the user will see
  # error messages in a "POD ERRORS" section at the end of the output.

  Pod::Usage::pod2usage( -exitval    => "NOEXIT",
                         -verbose    => 2,
                         -noperldoc  => 1,  # Perl does not come with the perl-doc package as standard (at least on Debian 4.0).
                         -input      => $memFileWithPod,
                         -output     => \*STDOUT );

  $memFileWithPod->close()
    or die "Cannot close in-memory file: $!\n";
}


sub get_pod_from_this_script ()
{
  # POSSIBLE OPTIMISATION:
  #   We do not actually need to read the whole file. We could read line-by-line,
  #   discard everything before HelpBeginMarker and stop as soon as HelpEndMarker is found.

  my $sourceCodeOfThisScriptAsString = read_whole_binary_file( "$Bin/$Script" );

  # We do not actually need to isolate the POD section, but it is cleaner this way.

  my $regex = "# HelpBeginMarker[\\s]+(.*?)[\\s]+# HelpEndMarker";

  my @podParts = $sourceCodeOfThisScriptAsString =~ m/$regex/s;

  if ( scalar( @podParts ) != 1 )
  {
    die "Internal error isolating the POD documentation.\n";
  }

  my $podAsStr = $podParts[0];


  # Replace the known placeholders. This is the only practical way to make sure
  # that things like the script name and version number in the help text are always right.
  # If you duplicate name and version in the source code and in the help text,
  # they will inevitably get out of sync at some point in time.

  # There are faster ways to replace multiple placeholders, but optimising this
  # is not worth the effort.

  $podAsStr =~ s/PROGRAM_NAME/@{[ PROGRAM_NAME ]}/gs;
  $podAsStr =~ s/SCRIPT_NAME/$Script/gs;
  $podAsStr =~ s/SCRIPT_VERSION/@{[ SCRIPT_VERSION ]}/gs;
  $podAsStr =~ s/OPT_NAME_HELP/@{[ OPT_NAME_HELP ]}/gs;

  return replace_script_specific_help_placeholders( $podAsStr );
}


sub get_license_text ()
{
  return ( <<EOL

                    GNU AFFERO GENERAL PUBLIC LICENSE
                       Version 3, 19 November 2007

 Copyright (C) 2007 Free Software Foundation, Inc. <http://fsf.org/>
 Everyone is permitted to copy and distribute verbatim copies
 of this license document, but changing it is not allowed.

                            Preamble

  The GNU Affero General Public License is a free, copyleft license for
software and other kinds of works, specifically designed to ensure
cooperation with the community in the case of network server software.

  The licenses for most software and other practical works are designed
to take away your freedom to share and change the works.  By contrast,
our General Public Licenses are intended to guarantee your freedom to
share and change all versions of a program--to make sure it remains free
software for all its users.

  When we speak of free software, we are referring to freedom, not
price.  Our General Public Licenses are designed to make sure that you
have the freedom to distribute copies of free software (and charge for
them if you wish), that you receive source code or can get it if you
want it, that you can change the software or use pieces of it in new
free programs, and that you know you can do these things.

  Developers that use our General Public Licenses protect your rights
with two steps: (1) assert copyright on the software, and (2) offer
you this License which gives you legal permission to copy, distribute
and/or modify the software.

  A secondary benefit of defending all users' freedom is that
improvements made in alternate versions of the program, if they
receive widespread use, become available for other developers to
incorporate.  Many developers of free software are heartened and
encouraged by the resulting cooperation.  However, in the case of
software used on network servers, this result may fail to come about.
The GNU General Public License permits making a modified version and
letting the public access it on a server without ever releasing its
source code to the public.

  The GNU Affero General Public License is designed specifically to
ensure that, in such cases, the modified source code becomes available
to the community.  It requires the operator of a network server to
provide the source code of the modified version running there to the
users of that server.  Therefore, public use of a modified version, on
a publicly accessible server, gives the public access to the source
code of the modified version.

  An older license, called the Affero General Public License and
published by Affero, was designed to accomplish similar goals.  This is
a different license, not a version of the Affero GPL, but Affero has
released a new version of the Affero GPL which permits relicensing under
this license.

  The precise terms and conditions for copying, distribution and
modification follow.

                       TERMS AND CONDITIONS

  0. Definitions.

  "This License" refers to version 3 of the GNU Affero General Public License.

  "Copyright" also means copyright-like laws that apply to other kinds of
works, such as semiconductor masks.

  "The Program" refers to any copyrightable work licensed under this
License.  Each licensee is addressed as "you".  "Licensees" and
"recipients" may be individuals or organizations.

  To "modify" a work means to copy from or adapt all or part of the work
in a fashion requiring copyright permission, other than the making of an
exact copy.  The resulting work is called a "modified version" of the
earlier work or a work "based on" the earlier work.

  A "covered work" means either the unmodified Program or a work based
on the Program.

  To "propagate" a work means to do anything with it that, without
permission, would make you directly or secondarily liable for
infringement under applicable copyright law, except executing it on a
computer or modifying a private copy.  Propagation includes copying,
distribution (with or without modification), making available to the
public, and in some countries other activities as well.

  To "convey" a work means any kind of propagation that enables other
parties to make or receive copies.  Mere interaction with a user through
a computer network, with no transfer of a copy, is not conveying.

  An interactive user interface displays "Appropriate Legal Notices"
to the extent that it includes a convenient and prominently visible
feature that (1) displays an appropriate copyright notice, and (2)
tells the user that there is no warranty for the work (except to the
extent that warranties are provided), that licensees may convey the
work under this License, and how to view a copy of this License.  If
the interface presents a list of user commands or options, such as a
menu, a prominent item in the list meets this criterion.

  1. Source Code.

  The "source code" for a work means the preferred form of the work
for making modifications to it.  "Object code" means any non-source
form of a work.

  A "Standard Interface" means an interface that either is an official
standard defined by a recognized standards body, or, in the case of
interfaces specified for a particular programming language, one that
is widely used among developers working in that language.

  The "System Libraries" of an executable work include anything, other
than the work as a whole, that (a) is included in the normal form of
packaging a Major Component, but which is not part of that Major
Component, and (b) serves only to enable use of the work with that
Major Component, or to implement a Standard Interface for which an
implementation is available to the public in source code form.  A
"Major Component", in this context, means a major essential component
(kernel, window system, and so on) of the specific operating system
(if any) on which the executable work runs, or a compiler used to
produce the work, or an object code interpreter used to run it.

  The "Corresponding Source" for a work in object code form means all
the source code needed to generate, install, and (for an executable
work) run the object code and to modify the work, including scripts to
control those activities.  However, it does not include the work's
System Libraries, or general-purpose tools or generally available free
programs which are used unmodified in performing those activities but
which are not part of the work.  For example, Corresponding Source
includes interface definition files associated with source files for
the work, and the source code for shared libraries and dynamically
linked subprograms that the work is specifically designed to require,
such as by intimate data communication or control flow between those
subprograms and other parts of the work.

  The Corresponding Source need not include anything that users
can regenerate automatically from other parts of the Corresponding
Source.

  The Corresponding Source for a work in source code form is that
same work.

  2. Basic Permissions.

  All rights granted under this License are granted for the term of
copyright on the Program, and are irrevocable provided the stated
conditions are met.  This License explicitly affirms your unlimited
permission to run the unmodified Program.  The output from running a
covered work is covered by this License only if the output, given its
content, constitutes a covered work.  This License acknowledges your
rights of fair use or other equivalent, as provided by copyright law.

  You may make, run and propagate covered works that you do not
convey, without conditions so long as your license otherwise remains
in force.  You may convey covered works to others for the sole purpose
of having them make modifications exclusively for you, or provide you
with facilities for running those works, provided that you comply with
the terms of this License in conveying all material for which you do
not control copyright.  Those thus making or running the covered works
for you must do so exclusively on your behalf, under your direction
and control, on terms that prohibit them from making any copies of
your copyrighted material outside their relationship with you.

  Conveying under any other circumstances is permitted solely under
the conditions stated below.  Sublicensing is not allowed; section 10
makes it unnecessary.

  3. Protecting Users' Legal Rights From Anti-Circumvention Law.

  No covered work shall be deemed part of an effective technological
measure under any applicable law fulfilling obligations under article
11 of the WIPO copyright treaty adopted on 20 December 1996, or
similar laws prohibiting or restricting circumvention of such
measures.

  When you convey a covered work, you waive any legal power to forbid
circumvention of technological measures to the extent such circumvention
is effected by exercising rights under this License with respect to
the covered work, and you disclaim any intention to limit operation or
modification of the work as a means of enforcing, against the work's
users, your or third parties' legal rights to forbid circumvention of
technological measures.

  4. Conveying Verbatim Copies.

  You may convey verbatim copies of the Program's source code as you
receive it, in any medium, provided that you conspicuously and
appropriately publish on each copy an appropriate copyright notice;
keep intact all notices stating that this License and any
non-permissive terms added in accord with section 7 apply to the code;
keep intact all notices of the absence of any warranty; and give all
recipients a copy of this License along with the Program.

  You may charge any price or no price for each copy that you convey,
and you may offer support or warranty protection for a fee.

  5. Conveying Modified Source Versions.

  You may convey a work based on the Program, or the modifications to
produce it from the Program, in the form of source code under the
terms of section 4, provided that you also meet all of these conditions:

    a) The work must carry prominent notices stating that you modified
    it, and giving a relevant date.

    b) The work must carry prominent notices stating that it is
    released under this License and any conditions added under section
    7.  This requirement modifies the requirement in section 4 to
    "keep intact all notices".

    c) You must license the entire work, as a whole, under this
    License to anyone who comes into possession of a copy.  This
    License will therefore apply, along with any applicable section 7
    additional terms, to the whole of the work, and all its parts,
    regardless of how they are packaged.  This License gives no
    permission to license the work in any other way, but it does not
    invalidate such permission if you have separately received it.

    d) If the work has interactive user interfaces, each must display
    Appropriate Legal Notices; however, if the Program has interactive
    interfaces that do not display Appropriate Legal Notices, your
    work need not make them do so.

  A compilation of a covered work with other separate and independent
works, which are not by their nature extensions of the covered work,
and which are not combined with it such as to form a larger program,
in or on a volume of a storage or distribution medium, is called an
"aggregate" if the compilation and its resulting copyright are not
used to limit the access or legal rights of the compilation's users
beyond what the individual works permit.  Inclusion of a covered work
in an aggregate does not cause this License to apply to the other
parts of the aggregate.

  6. Conveying Non-Source Forms.

  You may convey a covered work in object code form under the terms
of sections 4 and 5, provided that you also convey the
machine-readable Corresponding Source under the terms of this License,
in one of these ways:

    a) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by the
    Corresponding Source fixed on a durable physical medium
    customarily used for software interchange.

    b) Convey the object code in, or embodied in, a physical product
    (including a physical distribution medium), accompanied by a
    written offer, valid for at least three years and valid for as
    long as you offer spare parts or customer support for that product
    model, to give anyone who possesses the object code either (1) a
    copy of the Corresponding Source for all the software in the
    product that is covered by this License, on a durable physical
    medium customarily used for software interchange, for a price no
    more than your reasonable cost of physically performing this
    conveying of source, or (2) access to copy the
    Corresponding Source from a network server at no charge.

    c) Convey individual copies of the object code with a copy of the
    written offer to provide the Corresponding Source.  This
    alternative is allowed only occasionally and noncommercially, and
    only if you received the object code with such an offer, in accord
    with subsection 6b.

    d) Convey the object code by offering access from a designated
    place (gratis or for a charge), and offer equivalent access to the
    Corresponding Source in the same way through the same place at no
    further charge.  You need not require recipients to copy the
    Corresponding Source along with the object code.  If the place to
    copy the object code is a network server, the Corresponding Source
    may be on a different server (operated by you or a third party)
    that supports equivalent copying facilities, provided you maintain
    clear directions next to the object code saying where to find the
    Corresponding Source.  Regardless of what server hosts the
    Corresponding Source, you remain obligated to ensure that it is
    available for as long as needed to satisfy these requirements.

    e) Convey the object code using peer-to-peer transmission, provided
    you inform other peers where the object code and Corresponding
    Source of the work are being offered to the general public at no
    charge under subsection 6d.

  A separable portion of the object code, whose source code is excluded
from the Corresponding Source as a System Library, need not be
included in conveying the object code work.

  A "User Product" is either (1) a "consumer product", which means any
tangible personal property which is normally used for personal, family,
or household purposes, or (2) anything designed or sold for incorporation
into a dwelling.  In determining whether a product is a consumer product,
doubtful cases shall be resolved in favor of coverage.  For a particular
product received by a particular user, "normally used" refers to a
typical or common use of that class of product, regardless of the status
of the particular user or of the way in which the particular user
actually uses, or expects or is expected to use, the product.  A product
is a consumer product regardless of whether the product has substantial
commercial, industrial or non-consumer uses, unless such uses represent
the only significant mode of use of the product.

  "Installation Information" for a User Product means any methods,
procedures, authorization keys, or other information required to install
and execute modified versions of a covered work in that User Product from
a modified version of its Corresponding Source.  The information must
suffice to ensure that the continued functioning of the modified object
code is in no case prevented or interfered with solely because
modification has been made.

  If you convey an object code work under this section in, or with, or
specifically for use in, a User Product, and the conveying occurs as
part of a transaction in which the right of possession and use of the
User Product is transferred to the recipient in perpetuity or for a
fixed term (regardless of how the transaction is characterized), the
Corresponding Source conveyed under this section must be accompanied
by the Installation Information.  But this requirement does not apply
if neither you nor any third party retains the ability to install
modified object code on the User Product (for example, the work has
been installed in ROM).

  The requirement to provide Installation Information does not include a
requirement to continue to provide support service, warranty, or updates
for a work that has been modified or installed by the recipient, or for
the User Product in which it has been modified or installed.  Access to a
network may be denied when the modification itself materially and
adversely affects the operation of the network or violates the rules and
protocols for communication across the network.

  Corresponding Source conveyed, and Installation Information provided,
in accord with this section must be in a format that is publicly
documented (and with an implementation available to the public in
source code form), and must require no special password or key for
unpacking, reading or copying.

  7. Additional Terms.

  "Additional permissions" are terms that supplement the terms of this
License by making exceptions from one or more of its conditions.
Additional permissions that are applicable to the entire Program shall
be treated as though they were included in this License, to the extent
that they are valid under applicable law.  If additional permissions
apply only to part of the Program, that part may be used separately
under those permissions, but the entire Program remains governed by
this License without regard to the additional permissions.

  When you convey a copy of a covered work, you may at your option
remove any additional permissions from that copy, or from any part of
it.  (Additional permissions may be written to require their own
removal in certain cases when you modify the work.)  You may place
additional permissions on material, added by you to a covered work,
for which you have or can give appropriate copyright permission.

  Notwithstanding any other provision of this License, for material you
add to a covered work, you may (if authorized by the copyright holders of
that material) supplement the terms of this License with terms:

    a) Disclaiming warranty or limiting liability differently from the
    terms of sections 15 and 16 of this License; or

    b) Requiring preservation of specified reasonable legal notices or
    author attributions in that material or in the Appropriate Legal
    Notices displayed by works containing it; or

    c) Prohibiting misrepresentation of the origin of that material, or
    requiring that modified versions of such material be marked in
    reasonable ways as different from the original version; or

    d) Limiting the use for publicity purposes of names of licensors or
    authors of the material; or

    e) Declining to grant rights under trademark law for use of some
    trade names, trademarks, or service marks; or

    f) Requiring indemnification of licensors and authors of that
    material by anyone who conveys the material (or modified versions of
    it) with contractual assumptions of liability to the recipient, for
    any liability that these contractual assumptions directly impose on
    those licensors and authors.

  All other non-permissive additional terms are considered "further
restrictions" within the meaning of section 10.  If the Program as you
received it, or any part of it, contains a notice stating that it is
governed by this License along with a term that is a further
restriction, you may remove that term.  If a license document contains
a further restriction but permits relicensing or conveying under this
License, you may add to a covered work material governed by the terms
of that license document, provided that the further restriction does
not survive such relicensing or conveying.

  If you add terms to a covered work in accord with this section, you
must place, in the relevant source files, a statement of the
additional terms that apply to those files, or a notice indicating
where to find the applicable terms.

  Additional terms, permissive or non-permissive, may be stated in the
form of a separately written license, or stated as exceptions;
the above requirements apply either way.

  8. Termination.

  You may not propagate or modify a covered work except as expressly
provided under this License.  Any attempt otherwise to propagate or
modify it is void, and will automatically terminate your rights under
this License (including any patent licenses granted under the third
paragraph of section 11).

  However, if you cease all violation of this License, then your
license from a particular copyright holder is reinstated (a)
provisionally, unless and until the copyright holder explicitly and
finally terminates your license, and (b) permanently, if the copyright
holder fails to notify you of the violation by some reasonable means
prior to 60 days after the cessation.

  Moreover, your license from a particular copyright holder is
reinstated permanently if the copyright holder notifies you of the
violation by some reasonable means, this is the first time you have
received notice of violation of this License (for any work) from that
copyright holder, and you cure the violation prior to 30 days after
your receipt of the notice.

  Termination of your rights under this section does not terminate the
licenses of parties who have received copies or rights from you under
this License.  If your rights have been terminated and not permanently
reinstated, you do not qualify to receive new licenses for the same
material under section 10.

  9. Acceptance Not Required for Having Copies.

  You are not required to accept this License in order to receive or
run a copy of the Program.  Ancillary propagation of a covered work
occurring solely as a consequence of using peer-to-peer transmission
to receive a copy likewise does not require acceptance.  However,
nothing other than this License grants you permission to propagate or
modify any covered work.  These actions infringe copyright if you do
not accept this License.  Therefore, by modifying or propagating a
covered work, you indicate your acceptance of this License to do so.

  10. Automatic Licensing of Downstream Recipients.

  Each time you convey a covered work, the recipient automatically
receives a license from the original licensors, to run, modify and
propagate that work, subject to this License.  You are not responsible
for enforcing compliance by third parties with this License.

  An "entity transaction" is a transaction transferring control of an
organization, or substantially all assets of one, or subdividing an
organization, or merging organizations.  If propagation of a covered
work results from an entity transaction, each party to that
transaction who receives a copy of the work also receives whatever
licenses to the work the party's predecessor in interest had or could
give under the previous paragraph, plus a right to possession of the
Corresponding Source of the work from the predecessor in interest, if
the predecessor has it or can get it with reasonable efforts.

  You may not impose any further restrictions on the exercise of the
rights granted or affirmed under this License.  For example, you may
not impose a license fee, royalty, or other charge for exercise of
rights granted under this License, and you may not initiate litigation
(including a cross-claim or counterclaim in a lawsuit) alleging that
any patent claim is infringed by making, using, selling, offering for
sale, or importing the Program or any portion of it.

  11. Patents.

  A "contributor" is a copyright holder who authorizes use under this
License of the Program or a work on which the Program is based.  The
work thus licensed is called the contributor's "contributor version".

  A contributor's "essential patent claims" are all patent claims
owned or controlled by the contributor, whether already acquired or
hereafter acquired, that would be infringed by some manner, permitted
by this License, of making, using, or selling its contributor version,
but do not include claims that would be infringed only as a
consequence of further modification of the contributor version.  For
purposes of this definition, "control" includes the right to grant
patent sublicenses in a manner consistent with the requirements of
this License.

  Each contributor grants you a non-exclusive, worldwide, royalty-free
patent license under the contributor's essential patent claims, to
make, use, sell, offer for sale, import and otherwise run, modify and
propagate the contents of its contributor version.

  In the following three paragraphs, a "patent license" is any express
agreement or commitment, however denominated, not to enforce a patent
(such as an express permission to practice a patent or covenant not to
sue for patent infringement).  To "grant" such a patent license to a
party means to make such an agreement or commitment not to enforce a
patent against the party.

  If you convey a covered work, knowingly relying on a patent license,
and the Corresponding Source of the work is not available for anyone
to copy, free of charge and under the terms of this License, through a
publicly available network server or other readily accessible means,
then you must either (1) cause the Corresponding Source to be so
available, or (2) arrange to deprive yourself of the benefit of the
patent license for this particular work, or (3) arrange, in a manner
consistent with the requirements of this License, to extend the patent
license to downstream recipients.  "Knowingly relying" means you have
actual knowledge that, but for the patent license, your conveying the
covered work in a country, or your recipient's use of the covered work
in a country, would infringe one or more identifiable patents in that
country that you have reason to believe are valid.

  If, pursuant to or in connection with a single transaction or
arrangement, you convey, or propagate by procuring conveyance of, a
covered work, and grant a patent license to some of the parties
receiving the covered work authorizing them to use, propagate, modify
or convey a specific copy of the covered work, then the patent license
you grant is automatically extended to all recipients of the covered
work and works based on it.

  A patent license is "discriminatory" if it does not include within
the scope of its coverage, prohibits the exercise of, or is
conditioned on the non-exercise of one or more of the rights that are
specifically granted under this License.  You may not convey a covered
work if you are a party to an arrangement with a third party that is
in the business of distributing software, under which you make payment
to the third party based on the extent of your activity of conveying
the work, and under which the third party grants, to any of the
parties who would receive the covered work from you, a discriminatory
patent license (a) in connection with copies of the covered work
conveyed by you (or copies made from those copies), or (b) primarily
for and in connection with specific products or compilations that
contain the covered work, unless you entered into that arrangement,
or that patent license was granted, prior to 28 March 2007.

  Nothing in this License shall be construed as excluding or limiting
any implied license or other defenses to infringement that may
otherwise be available to you under applicable patent law.

  12. No Surrender of Others' Freedom.

  If conditions are imposed on you (whether by court order, agreement or
otherwise) that contradict the conditions of this License, they do not
excuse you from the conditions of this License.  If you cannot convey a
covered work so as to satisfy simultaneously your obligations under this
License and any other pertinent obligations, then as a consequence you may
not convey it at all.  For example, if you agree to terms that obligate you
to collect a royalty for further conveying from those to whom you convey
the Program, the only way you could satisfy both those terms and this
License would be to refrain entirely from conveying the Program.

  13. Remote Network Interaction; Use with the GNU General Public License.

  Notwithstanding any other provision of this License, if you modify the
Program, your modified version must prominently offer all users
interacting with it remotely through a computer network (if your version
supports such interaction) an opportunity to receive the Corresponding
Source of your version by providing access to the Corresponding Source
from a network server at no charge, through some standard or customary
means of facilitating copying of software.  This Corresponding Source
shall include the Corresponding Source for any work covered by version 3
of the GNU General Public License that is incorporated pursuant to the
following paragraph.

  Notwithstanding any other provision of this License, you have
permission to link or combine any covered work with a work licensed
under version 3 of the GNU General Public License into a single
combined work, and to convey the resulting work.  The terms of this
License will continue to apply to the part which is the covered work,
but the work with which it is combined will remain governed by version
3 of the GNU General Public License.

  14. Revised Versions of this License.

  The Free Software Foundation may publish revised and/or new versions of
the GNU Affero General Public License from time to time.  Such new versions
will be similar in spirit to the present version, but may differ in detail to
address new problems or concerns.

  Each version is given a distinguishing version number.  If the
Program specifies that a certain numbered version of the GNU Affero General
Public License "or any later version" applies to it, you have the
option of following the terms and conditions either of that numbered
version or of any later version published by the Free Software
Foundation.  If the Program does not specify a version number of the
GNU Affero General Public License, you may choose any version ever published
by the Free Software Foundation.

  If the Program specifies that a proxy can decide which future
versions of the GNU Affero General Public License can be used, that proxy's
public statement of acceptance of a version permanently authorizes you
to choose that version for the Program.

  Later license versions may give you additional or different
permissions.  However, no additional obligations are imposed on any
author or copyright holder as a result of your choosing to follow a
later version.

  15. Disclaimer of Warranty.

  THERE IS NO WARRANTY FOR THE PROGRAM, TO THE EXTENT PERMITTED BY
APPLICABLE LAW.  EXCEPT WHEN OTHERWISE STATED IN WRITING THE COPYRIGHT
HOLDERS AND/OR OTHER PARTIES PROVIDE THE PROGRAM "AS IS" WITHOUT WARRANTY
OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO,
THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
PURPOSE.  THE ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE PROGRAM
IS WITH YOU.  SHOULD THE PROGRAM PROVE DEFECTIVE, YOU ASSUME THE COST OF
ALL NECESSARY SERVICING, REPAIR OR CORRECTION.

  16. Limitation of Liability.

  IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MODIFIES AND/OR CONVEYS
THE PROGRAM AS PERMITTED ABOVE, BE LIABLE TO YOU FOR DAMAGES, INCLUDING ANY
GENERAL, SPECIAL, INCIDENTAL OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE
USE OR INABILITY TO USE THE PROGRAM (INCLUDING BUT NOT LIMITED TO LOSS OF
DATA OR DATA BEING RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD
PARTIES OR A FAILURE OF THE PROGRAM TO OPERATE WITH ANY OTHER PROGRAMS),
EVEN IF SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.

  17. Interpretation of Sections 15 and 16.

  If the disclaimer of warranty and limitation of liability provided
above cannot be given local legal effect according to their terms,
reviewing courts shall apply local law that most closely approximates
an absolute waiver of all civil liability in connection with the
Program, unless a warranty or assumption of liability accompanies a
copy of the Program in return for a fee.

                     END OF TERMS AND CONDITIONS

            How to Apply These Terms to Your New Programs

  If you develop a new program, and you want it to be of the greatest
possible use to the public, the best way to achieve this is to make it
free software which everyone can redistribute and change under these terms.

  To do so, attach the following notices to the program.  It is safest
to attach them to the start of each source file to most effectively
state the exclusion of warranty; and each file should have at least
the "copyright" line and a pointer to where the full notice is found.

    <one line to give the program's name and a brief idea of what it does.>
    Copyright (C) <year>  <name of author>

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU Affero General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU Affero General Public License for more details.

    You should have received a copy of the GNU Affero General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.

Also add information on how to contact you by electronic and paper mail.

  If your software can interact with users remotely through a computer
network, you should also make sure that it provides a way for users to
get its source.  For example, if your program is a web application, its
interface could display a "Source" link that leads users to an archive
of the code.  There are many ways you could offer source, and different
solutions will be better for different programs; see section 13 for the
specific requirements.

  You should also get your employer (if you work as a programmer) or school,
if any, to sign a "copyright disclaimer" for the program, if necessary.
For more information on this, and how to apply and follow the GNU AGPL, see
<http://www.gnu.org/licenses/>.

EOL
  );
}


# ------------ Script entry point ------------

eval
{
  my $exitCode = main();
  exit $exitCode;
};

my $errorMessage = $@;

# We want the error message to be the last thing on the screen,
# so we need to flush the standard output first.
STDOUT->flush();

print STDERR "\nError running \"$Bin/$Script\": $errorMessage";

exit EXIT_CODE_FAILURE_ERROR;
