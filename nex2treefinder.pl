#!/usr/bin/perl

use strict;
use warnings;
use Term::ANSIColor;

print color 'bold blue';
print "\n$0  --  a script to convert alignments from the nexus format to the treefinder format\n\n";
print color 'reset';

###################################################################################################################################
#   G L O B A L    V A R I A B L E S
###################################################################################################################################

my (	$infile,			# file containing the input alignment
		$outfile,			# output tree filename
        $part_conv,			# 1|0 -- specifies whether character sets need to be parsed and converted
		
		$seqs,				# sequences
		$partitions,		# partition information
		$partition_nrs,		# numbers assigned to the partitions
		$input_seq_length,	# length of the input alignment
		$nr_seqs,			# number of sequences in the input alignment
		$sequence_order,	# order in which the sequences were in the input alignment (array)
);
my $defaults = {
	'part_conv'		=>	0,
};

###################################################################################################################################
#   P A R S E    C O M M A N D    L I N E    O P T I O N S
###################################################################################################################################

	unless (	($ARGV[0]) and (substr($ARGV[0],0,1) eq "-") and
				($ARGV[1]) )
		{ usage(); }
	
	for (my $i=0; $i<scalar(@ARGV); $i+=2) {
		if    ($ARGV[$i] eq "-i")  { $infile        = $ARGV[$i+1]; }
		elsif ($ARGV[$i] eq "-o")  { $outfile       = $ARGV[$i+1]; }
		elsif ($ARGV[$i] eq "-p")  { $part_conv     = $ARGV[$i+1]; }
		else { usage(); }
	}
	unless ($infile) {usage();}
	unless (-e $infile) {fatal_error("file not found: $infile");}
	unless ($outfile) {
		if ($infile =~ /(.+)\.nexu*s*$/) {
			$outfile = $1.'.tf';
		} else {
			$outfile = $infile.'.tf';
		}
	}
	if (defined($part_conv)) {
		unless ($part_conv =~ /^[01]$/) {
			usage();
		}
	} else {
		$part_conv = $defaults->{'part_conv'};
	}

			sub usage {			# prints warning about incorrect command line usage
				print color 'bold red';
				print "\nwrong usage  --  use the following parameters\n"; 
				print color 'reset';
				print "\nnecessary parameters\n";
				print "   -i   input file\n";
				print "\noptional parameters\n";
				print "   -o   output file (if not specified, .tf will be appended to the input filename)\n";
				print "   -p   convert charset definitions: 1|0  (default: ",$defaults->{'part_conv'},")\n";
				print "\n";
				print "For the character set definitions, make sure that\n";
				print "   * definitions are in the syntax used by e.g. PAUP* and MrBayes\n";
				print "   * all characters are assigned to a character set\n";
				print "   * characters are assigned to no more than one character set\n";
				print "There is no error checking for this and the program will produce incorrect output if these requirements are not met\n";
				print "\n";
				exit;
			}

###################################################################################################################################
#   I M P O R T    S E Q U E N C E    D A T A
###################################################################################################################################

{
	print "loading alignment ...\n";
	open(FH,$infile) || fatal_error("unable to open $infile");
	my @filedump = <FH>; close FH;
	my $filestring = join('',@filedump);
	unless ($filestring =~ /begin data\;.+?matrix\s*([^\;]+)/s) {fatal_error("could not find data block in $infile");}
	my @a = split /\n/,$1;
	foreach my $line (@a) {
		my @b = split /\s+/,$line;
		if (scalar @b > 2) {fatal_error("problem with input: you probably have spaces in your taxon names or sequences");}
		if (scalar @b == 2) {
			unless ($b[0] =~ /^\w+$/) {fatal_error("only the following characters are allowed in taxon names: 0-9, a-z, A-Z and _");}
			unless ($seqs->{$b[0]}) {
				push @$sequence_order,$b[0];
			}
			$b[1] =~ s/\s//g;
			$seqs->{$b[0]} .= $b[1];
		}
	}
	my @keys = keys %$seqs;
	$input_seq_length = length($seqs->{$keys[0]});
	foreach my $id (keys %$seqs) {
		unless ($input_seq_length == length($seqs->{$id})) {fatalerror("sequences not of equal length");}
	}
	$nr_seqs = scalar keys %$seqs;
	print "  $nr_seqs sequences\n  $input_seq_length characters\n\n";
}
	
###################################################################################################################################
#   R E A D    C H A R S E T    I N F O R M A T I O N
###################################################################################################################################

	if ($part_conv) {
		print "reading character sets ...\n";
		open(FH,$infile) || fatal_error("unable to open $infile");
		my @filedump = <FH>; close FH;
		my $filestring = join('',@filedump);
		$filestring =~ s/[\n\r]//g;
		while ($filestring =~ /charset (.+?);/ig) {
			$1 =~ /^\s*(.+?)\s*\=\s*(.+?)\s*$/;
			my ($name,$def) = ($1,$2);
			$partition_nrs->{$name} = scalar(keys(%$partition_nrs)) + 1 || 1;
			print "  charset ",$partition_nrs->{$name},": $name\n";
			my @parts = split (/\s/,$def);
			foreach my $part (@parts) {
				if ($part =~ /\\/) {
					$part =~ /(\d+)-(.+?)\\(\d+)/;
					my ($start,$stop,$interval) = ($1,$2,$3);
					if ($stop eq '.') {$stop = $input_seq_length;}
					for (my $i = $start; $i <= $stop; $i += $interval) {
						my $char = 'i'.sprintf("%20d",$i);
						$partitions->{$char} = $partition_nrs->{$name};
					}
				} elsif ($part =~ /-/) {
					$part =~ /(\d+)\-(\d+)/;
					my ($start,$stop) = ($1,$2);
					if ($stop eq '.') {$stop = $input_seq_length;}
					for (my $i = $start; $i <= $stop; ++$i) {
						my $char = 'i'.sprintf("%20d",$i);
						$partitions->{$char} = $partition_nrs->{$name};
					}
				} else {
					$part =~ /(\d+)/;
					my $char = 'i'.sprintf("%20d",$1);
					$partitions->{$char} = $partition_nrs->{$name};
				}
			}	
		}
		print "\n";
	}

	
###################################################################################################################################
#   W R I T E    O U T P U T     A L I G N M E N T
###################################################################################################################################

	print "saving output to file $outfile\n";
	unless (open FH,">$outfile") {fatal_error("unable to write to $outfile");}
	my $maxlength; $maxlength = 0;
	foreach my $id (@$sequence_order) {
		if (length($id) > $maxlength) {$maxlength = length($id);}
	}
	if ($part_conv) {
		# between 1 and 9 partitions ==> one row of partition indicators
			if (scalar keys %$partition_nrs <= 9) {
				my $desc = "_parts"; 
				print FH '"',$desc,'"',get_spaces($maxlength - length($desc) + 2);
				foreach my $char (sort(keys(%$partitions))) {print FH $partitions->{$char};}
				print FH "\n";
			}
		# between 9 and 81 partitions ==> two rows of partition indicators
			elsif (scalar keys %$partition_nrs <= 81) {
				my $desc = ["_parts1","_parts2"];
				print FH '"',$desc->[0],'"',get_spaces($maxlength - length($desc->[0]) + 2);
				foreach my $char (sort(keys(%$partitions))) {
					my $part1;
					if ($partitions->{$char} % 9 == 0) {
						$part1 = int($partitions->{$char} / 9);
					} else {
						$part1 = 1 + int($partitions->{$char} / 9);
					}
					print FH $part1;
				}
				print FH "\n";
				print FH '"',$desc->[1],'"',get_spaces($maxlength - length($desc->[1]) + 2);
				foreach my $char (sort(keys(%$partitions))) {
					my $part1;
					if ($partitions->{$char} % 9 == 0) {$part1 = int($partitions->{$char} / 9);} else {$part1 = 1 + int($partitions->{$char} / 9);}
					my $part2 = $partitions->{$char} - ($part1 * 9) + 9;
					print FH $part2;
				}
				print FH "\n";
			}
		# between 81 and 729 partitions ==> three rows of partition indicators
			elsif (scalar keys %$partition_nrs <= 729) {
				my $desc = ["_parts1","_parts2","_parts3"];
				print FH $desc->[0],get_spaces($maxlength - length($desc->[0]) + 2);
				foreach my $char (sort(keys(%$partitions))) {
					my $part1;
					if ($partitions->{$char} % 81 == 0) {$part1 = int($partitions->{$char} / 81);} else {$part1 = 1 + int($partitions->{$char} / 81);}
					print FH $part1;
				}
				print FH "\n";
				print FH '"',$desc->[1],'"',get_spaces($maxlength - length($desc->[1]) + 2);
				foreach my $char (sort(keys(%$partitions))) {
					my ($part1,$part2);
					if ($partitions->{$char} % 81 == 0) {$part1 = int($partitions->{$char} / 81);} else {$part1 = 1 + int($partitions->{$char} / 81);}
					if (($partitions->{$char} - ($part1 * 81) + 81) % 9 == 0) {
						$part2 = int(($partitions->{$char} - ($part1 * 81) +81) / 9);
					} else {
						$part2 = 1 + int(($partitions->{$char} - ($part1 * 81) +81) / 9);
					}
					print FH $part2;
				}
				print FH "\n";
				print FH '"',$desc->[2],'"',get_spaces($maxlength - length($desc->[2]) + 2);
				foreach my $char (sort(keys(%$partitions))) {
					my ($part1,$part2,$part3);
					if ($partitions->{$char} % 81 == 0) {$part1 = int($partitions->{$char} / 81);} else {$part1 = 1 + int($partitions->{$char} / 81);}
					if (($partitions->{$char} - ($part1 * 81) + 81) % 9 == 0) {
						$part2 = int(($partitions->{$char} - ($part1 * 81) +81) / 9);
					} else {
						$part2 = 1 + int(($partitions->{$char} - ($part1 * 81) +81) / 9);
					}
					$part3 = $partitions->{$char} - ($part1 * 81) + 81 - ($part2 * 9) + 9;
					print FH $part3;
				}
				print FH "\n";
			}
		# more than 729 partitions ==> not implemented
			else {
				fatal_error ("the present version of the script does not allow more than 729 partitions");
			}
			print FH "\n";
	}
	foreach my $id (@$sequence_order) {
		print FH '"',$id,'"', get_spaces($maxlength - length($id) + 2), $seqs->{$id}, "\n";
	}
	close FH;
	if (-e $outfile) {print "  apparently successful\n"} else {fatal_error("output file could not be generated");}
	print color 'bold blue';
	print "\nfinished execution of $0\n\n";
	print color 'reset';

	
###################################################################################################################################
#   subroutines
###################################################################################################################################

		sub fatal_error {
			my $in = shift;
			print color 'bold red';
			print "\nfatal error  --  $in\n"; 
			print color 'reset';
			exit;
		}
		sub get_spaces {
			my $nr = shift;
			my $out; $out = "";
			for (my $i=0; $i<$nr; ++$i) {$out .= ' ';}
			return $out;
		}
