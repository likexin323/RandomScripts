#!/usr/bin/env perl

use warnings;
use strict;
use Pod::Usage;
use Getopt::Long qw(GetOptions);
Getopt::Long::Configure qw(gnu_getopt);

################################################################
#                                                              #
################################################################

#First-pass script to label barcodes in an index read histogram
# based on a barcode file, and incorporating mismatches if no
# perfectly matching barcode is found.

=pod

=head1 NAME

labelIndexReadHistogram.pl - Label an index read histogram with sample IDs

=head1 SYNOPSIS

labelIndexReadHistogram.pl [options]

 Options:
  --help,-h,-?         Display this documentation
  --input_histogram,-i Path to input index read histogram TSV file (default: STDIN)
  --barcode_file,-b    Path to barcode file

=head1 DESCRIPTION

Using the information found in the barcode file, this script adds a third
column to the index read histogram that indicates the sample ID and how
many mismatches were required for the barcode sequence to match.

=cut

my $help = 0;
my $man = 0;
my $histogram_path = "STDIN";
my $bcfile_path = "";
GetOptions('input_histogram|i=s' => \$histogram_path, 'barcode_file|b=s' => \$bcfile_path, 'help|h|?' => \$help, man => \$man) or pod2usage(2);
pod2usage(-exitval => 1, -output => \*STDERR) if $help;
pod2usage(-exitval => 0, -verbose => 2, -output => \*STDERR) if $man;

#Open the index read histogram file, or set it up to be read from STDIN:
if ($histogram_path ne "STDIN") {
   unless(open(HISTFILE, "<", $histogram_path)) {
      print STDERR "Error opening index read histogram TSV file.\n";
      exit 2;
   }
} else {
   open(HISTFILE, "<&", "STDIN"); #Duplicate the file handle for STDIN to HISTFILE so we can seamlessly handle piping
}

#Open the barcode file:
unless(open(INDEXFILE, "<", $bcfile_path)) {
   print STDERR "Error opening barcode file.\n";
   exit 3;
}

my @bases = ("A", "C", "G", "T");
my %FCmap = ();
while (my $line = <INDEXFILE>) {
   chomp $line;
   my ($id, $bc) = split /\t/, $line, 2;
   #Should do some case checking to make sure it's a valid barcode file in the future
   $FCmap{$bc} = $id;
}
close(INDEXFILE);

while (my $line = <HISTFILE>) {
   chomp $line;
   $line =~ s/^\s+//;
   my ($count, $bc) = split /\s+/, $line, 2;
   print $count, "\t", $bc, "\t";
   if (exists($FCmap{$bc})) {
      print $FCmap{$bc}, " (0 mismatches)";
   } else {
      for (my $pos = 0; $pos < length($bc); $pos++) {
         for my $base (@bases) {
            my $altbc = $bc;
            substr($altbc, $pos, 1) = $base;
            next if $altbc eq $bc;
            if (exists($FCmap{$altbc})) {
               print $FCmap{$altbc}, " (1 mismatch)";
               last;
            }
            for (my $postwo = $pos+1; $postwo < length($bc); $postwo++) {
               for my $basetwo (@bases) {
                  my $twoaltbc = $altbc;
                  substr($twoaltbc, $postwo, 1) = $basetwo;
                  next if $twoaltbc eq $bc or $twoaltbc eq $altbc;
                  if (exists($FCmap{$twoaltbc})) {
                     print $FCmap{$twoaltbc}, " (2 mismatches)\t";
                  }
               }
            }
         }
      }
   }
   print "\n";
}
close(HISTFILE) if $histogram_path ne "STDIN";