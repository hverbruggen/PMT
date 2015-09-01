#!/usr/bin/perl

my $version = 1.02;

#	PMT.pl     version 1.02
#
#   heroen.verbruggen@gmail.com
#
#
#   Version history:
#   1.01  initial release
#   1.02  uses FastTree to build guide tree instead of phyml

use strict;
use warnings;


### global variables #################################################################################################################################################

my (
	$infile,
	$outfile,
	$tflink,
	$n2tflink,
	$fasttree_link,
	$nchar,
	$PMTstrategies,
	$system,
	$substmodels,
	$RAStypes,
	$guide_tree,
	$runmode,
);

my $defaults = {
	'system' => '1',
	'test_for_previous_run' => 0,
	'RAStypes' => 'G4,G8,IG4,I',
	'substmodels' => 'JC,F81,K80,HKY,SYM,GTR',
	'outfile' => 'results.txt',
	'runmode' => 1,
	'guide_tree' => 'guide_tree.nwk',
};

my $system_definitions = {
	'1' => 'local workstation',
	'2' => 'KERMIT (parallel execution)',
	'3' => 'UGent HPC (parallel execution)',
};

my $runmode_definitions = {
	'1' => 'job launching',
	'2' => 'summarize',
};

my $recognized = {
	'substmodels' => {
		'JC' => 1,
		'F81' => 1,
		'K80' => 1,
		'HKY' => 1,
		'SYM' => 1,
		'GTR' => 1,
	},
};

### parsing command line arguments ###############################################################################################################################

unless (($ARGV[0]) and (substr($ARGV[0],0,1) eq "-") and
		($ARGV[1]))
	{usage()}

for (my $i=0; $i<scalar(@ARGV); $i+=2) {
	if    ($ARGV[$i] eq "-i") {$infile = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-o") {$outfile = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-c") {$system = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-s") {$substmodels = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-r") {$RAStypes = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-g") {$guide_tree = $ARGV[$i+1]}
	elsif ($ARGV[$i] eq "-m") {$runmode = $ARGV[$i+1]}
	else {usage()}
}

unless (defined $infile) {usage()}
unless (-e $infile) {die "\n#### FATAL ERROR ####\nfile not found: $infile\n"}
unless (defined $outfile) {$outfile = $defaults->{'outfile'}}
if (not defined $system)  {$system  = $defaults->{'system'}}  else {unless ($system_definitions->{$system}) {die "\n#### FATAL ERROR ####\noption specified with -s flag must be 1, 2 or 3\n"}}
if (not defined $runmode) {$runmode = $defaults->{'runmode'}} else {unless ($runmode_definitions->{$runmode}) {die "\n#### FATAL ERROR ####\nrun mode (flag -m) must be 1 or 2\n"}}
if (defined $substmodels) {check_substmodels($substmodels)} else {$substmodels = $defaults->{'substmodels'}}
if (defined $RAStypes) {check_RAStypes($RAStypes)} else {$RAStypes = $defaults->{'RAStypes'}}
$RAStypes .= ',0';  # this adds a search without any RAS options activated
if (defined $guide_tree) {unless (-e $guide_tree) {die "\n#### FATAL ERROR ####\nfile not found: $guide_tree\n"}}
if ($runmode == 2) {$defaults->{'test_for_previous_run'} = 0}

sub usage {
	print "\nusage:\n";
	print "\nmandatory parameters\n";
	print "   -i  input alignment (nexus format)\n";
	print "\noptional parameters\n";
	print "   -o  output file (plain text)\n";
	print "         default: ",$defaults->{'outfile'},"\n";
	print "   -g  guide tree (newick format)\n";
	print "         if unspecified, will run FastTree to get one\n";
	print "   -s  substitution models\n";
	print "         comma-separated list of substitution models\n";
	print "         default: ",$defaults->{'substmodels'},"\n";
	print "   -r  rates across sites\n";
	print "         comma-separated list of Gamma and Pinvar options\n";
	print "         default: ",$defaults->{'RAStypes'},"\n";
	print "   -c  computer you're working with\n";
	foreach my $key (sort keys %$system_definitions) {
		print "         $key\: ",$system_definitions->{$key};
		if ($key eq $defaults->{'system'}) {print " (default)"}
		print "\n";
	}
	print "   -m  running mode\n";
	print "         1: job launching mode (default)\n";
	print "         2: summarize results mode\n";
	print "\n";
	exit;
}


### printing list of options ###############################################################################################################################

print "\nPMT.pl - version $version\n";
print "\nlist of options used\n";
print "   input file    $infile\n";
print "   output file   $outfile\n";
print "   guide tree    "; if (defined $guide_tree) {print $guide_tree} else {print $defaults->{'guide_tree'}," (to be inferred)"} print "\n";
print "   comp system   ",$system_definitions->{$system},"\n";
print "   run mode      ",$runmode_definitions->{$runmode},"\n";
print "   subst models  $substmodels\n";
print "   RAS types     $RAStypes\n";

### checking dependencies ###############################################################################################################################

{
	print "\nchecking for presence of programs needed\n";
	my $tempfile = "temp".randdig(10);
	my $a;
	$a = system("which tf > $tempfile");
	if ($a eq '256') {
		die "\n#### FATAL ERROR ####\nTreeFinder must be installed, be in the path, and be reachable with 'tf' command\n"
	} else {
		open FH,$tempfile; $tflink = <FH>; $tflink =~ s/[\r\n]//g;
		if (-e $tflink) {
			print "   $tflink -- found\n";
		} else {
			die "\n#### FATAL ERROR ####\nTreeFinder must be installed, be in the path, and be reachable with 'tf' command\n"
		}
	}
	$a = system("which nex2treefinder.pl > $tempfile");
	if ($a eq '256') {
		die "\n#### FATAL ERROR ####\nnex2treefinder.pl must be installed, be in the path, and be reachable with 'nex2treefinder.pl' command\n"
	} else {
		open FH,$tempfile; $n2tflink = <FH>; $n2tflink =~ s/[\r\n]//g;
		if (-e $n2tflink) {
			print "   $n2tflink -- found\n";
		} else {
			die "\n#### FATAL ERROR ####\nnex2treefinder.pl must be installed, be in the path, and be reachable with 'nex2treefinder.pl' command\n"
		}
	}
	unless (defined $guide_tree) {
		$a = system("which fasttree > $tempfile");
		if ($a eq '256') {
			die "\n#### FATAL ERROR ####\nFastTree must be installed, be in the path, and be reachable with 'fasttree' command\n"
		} else {
			open FH,$tempfile; $fasttree_link = <FH>; $fasttree_link =~ s/[\r\n]//g;
			if (-e $fasttree_link) {
				print "   $fasttree_link -- found\n";
			} else {
				die "\n#### FATAL ERROR ####\nFastTree must be installed, be in the path, and be reachable with 'fasttree' command\n"
			}
		}
	}
	system("rm $tempfile");
}


### inferring guide tree ###############################################################################################################################

unless (defined $guide_tree) {
	print "\ninferring guide tree with FastTree\n";
	$guide_tree = $defaults->{'guide_tree'};
	print "   converting alignment to fasta format\n";
	my ($seq_order,$seqs) = read_nexus_data($infile);
	my $aln = 'temp'.randdig(10);
	open FH,">$aln";
	my @keys = keys %$seqs;
	my $ml; $ml = 0; foreach my $sn (@$seq_order) {if (length $sn > $ml) {$ml = length $sn}}
	for (my $i = 0; $i < scalar(@$seq_order); ++$i) {
		my $seqname = $seq_order->[$i];
		my $seq = $seqs->{$seqname};
		print FH ">",$seqname,"\n",$seq,"\n";
	}
	close FH;
	print "   running FastTree -- please be patient...\n";
	my $c = "$fasttree_link -nosupport $aln > $guide_tree";
	print "   command: $c\n";
	system($c." 2> deleteme");
	system("rm $aln");
	if (-e $guide_tree) {
		print "   guide tree inferred: $guide_tree\n"; system("rm deleteme");
	} else {
		print "ERROR -- inference of guide tree appears to have failed\nPlease check your alignment and whether you can identify the problem in the screen output of FastTree (file called \"deleteme\")\n";
		exit;
	}
}

### parsing input nexus file ###############################################################################################################################

{
	print "\ngetting PMTstrategies from nexus file\n";
	unless (open FH,$infile) {die "\n#### FATAL ERROR ####\ncannot read from file: $infile\n"}
	my $filedata;
	while (my $line = <FH>) {$line =~ s/[\r\n]/__new__line__/g; $filedata .= $line;}
	if ($filedata =~ /nchar\s*=\s*(\d+)/i) {
		$nchar = $1
	} else {
		die "\n#### FATAL ERROR ####\ninput file ill-formatted: no nchar statement\n"
	}
	print "   total characters: $nchar\n";
	unless ($filedata =~ /begin\s+pmt\.pl/i) {die "\n#### FATAL ERROR ####\ninput nexus file does not contain PMT.pl block\n"}
	$filedata =~ s/PMTstrategy(.*?)end\s*;/PMTstrategy$1ennd;/gi;
	$filedata =~ /begin\s+pmt\.pl\s*;(.*?)end\s*;/i;
	$filedata = $1; $filedata =~ s/__new__line__//g;
	while ($filedata =~ /pmtstrategy\s+(.*?)\s*;(.*?)ennd\s*;/ig) {
		my ($name,$def) = ($1,$2);
		$def =~ s/;\s*$//; $def =~ s/^\s*charset\s+//i;
		my @a = split /\s*;\s*charset\s+/,$def;
		foreach my $el (@a) {
			unless ($el =~ /^.*\s+=\s+.*$/) {
				die "\n#### FATAL ERROR ####\ninput file ill-formatted: this is not a good charset definition\n$el\n"
			}
		}
		push @$PMTstrategies,{name => $name, def => \@a};
	}
	print "   partitioning strategies: ",scalar(@$PMTstrategies),"\n";
	foreach my $PMTstrategy (@$PMTstrategies) {
		print "      ",$PMTstrategy->{name},": ",scalar(@{$PMTstrategy->{def}})," parts\n";
	}
	foreach my $PMTstrategy (@$PMTstrategies) {
		check_strategy($PMTstrategy)
	}
	print "   all strategies contain the expected number of characters\n";
}


### generating directory structure and preparing analyses ###############################################################################################################################

if ($runmode == 1) {
	print "\npreparing data for model testing\n";
	print "   generating directory structure and nexus files\n";
	foreach my $PMTstrategy (@$PMTstrategies) {
		if (-e $PMTstrategy->{name} && $defaults->{'test_for_previous_run'}) {die "\n#### FATAL ERROR ####\nprevious PMT.pl run detected\nit is not considered safe to run an analysis from a directory in which another PMT.pl run was executed\n"}
	}
	my $nexdata;
	unless (open FH,$infile) {die "\n#### FATAL ERROR ####\ncannot read from file: $infile\n"}
	my $filedata;
	while (my $line = <FH>) {$line =~ s/[\r\n]/__new__line__/g; $filedata .= $line;}
	unless ($filedata =~ /^(.*)matrix(.*?)end\s*;/i) {die "\n#### FATAL ERROR ####\ncannot find data matrix in input nexus file\n"}
	my $nexseq; $nexseq = $1.'matrix'.$2.'end;'; $nexseq =~ s/__new__line__/\n/g;
	foreach my $PMTstrategy (@$PMTstrategies) {
		my $dir = $PMTstrategy->{name};
		mkdir $dir;
		open FH,">".$dir."/aln.nex";
		print FH $nexseq,"\n\nbegin sets;\n";
		if (scalar @{$PMTstrategy->{def}} > 1) {
			foreach my $part (@{$PMTstrategy->{def}}) {
				print FH "\tcharset $part\;\n";
			}
		}
		print FH "end;\n";
		close FH;
	}
	print "   converting nexus files to treefinder format\n";
	my $tempfile = 'temp'.randdig(10);
	foreach my $PMTstrategy (@$PMTstrategies) {
		my $dir = $PMTstrategy->{name};
		chdir($dir);
		if (scalar @{$PMTstrategy->{def}} > 1) {
			system("$n2tflink -i aln.nex -o aln.tf -p 1 > $tempfile");
		} else {
			system("$n2tflink -i aln.nex -o aln.tf -p 0 > $tempfile");
		}
		unless (-e 'aln.tf' && -s $tempfile > 200) {die "\n#### FATAL ERROR ####\nan error occurred converting alignment for PMTstrategy $dir to TreeFinder format\n"}
		system("rm $tempfile");
		chdir('..');
	}
	print "   generating TL scripts\n";
	foreach my $PMTstrategy (@$PMTstrategies) {
		my $dir = $PMTstrategy->{name};
		chdir($dir);
		foreach my $substmodel (split ',',$substmodels) {
			foreach my $RAStype (split ',',$RAStypes) {
				my $modelTL = get_TL_model($substmodel,$RAStype);
				open FH,">opt_".$substmodel."_".$RAStype.".tl";
				print FH 'ReconstructPhylogeny[',"\n";
				print FH '  "aln.tf",',"\n";
				if (scalar @{$PMTstrategy->{def}} > 1) {
					print FH '  SubstitutionModel->{',"\n";
					for (my $i=1; $i < scalar @{$PMTstrategy->{def}}; ++$i) {
						print FH '    ',$modelTL,',',"\n";
					}
					print FH '    ',$modelTL,"\n";
					print FH '  },',"\n";
					print FH '  PartitionRates->Optimum,',"\n";
				} else {
					print FH '  SubstitutionModel->',$modelTL,',',"\n";
				}
				print FH '  WithEdgeSupport->False,',"\n";
				print FH '  Tree->"../',$guide_tree,'"',"\n";
				print FH '],',"\n";
				print FH '"opt_',$substmodel,'_',$RAStype,'.out",',"\n";
				print FH 'SaveReport',"\n";
				close FH;
			}
		}
		chdir('..');
	}
	open SH,">run_all_jobs.sh";
	print SH '#!/bin/bash',"\n";
	if ($system > 1) {
		print "   generating job submission scripts\n";
	}
	foreach my $PMTstrategy (@$PMTstrategies) {
		my $dir = $PMTstrategy->{name};
		chdir($dir);
		print SH "cd $dir\n";
		foreach my $substmodel (split ',',$substmodels) {
			foreach my $RAStype (split ',',$RAStypes) {
				if ($system > 1) {
					open FH,">opt_".$substmodel."_".$RAStype.".sh";
					if ($system == 2) {
						print FH '#!/bin/sh',"\n";
						print FH '#$ -S /bin/sh',"\n";
						print FH '#$ -cwd',"\n\n";
						print FH "$tflink opt_",$substmodel,"_",$RAStype,".tl\n";
					} elsif ($system == 3) {
						print FH '#!/bin/sh',"\n";
						print FH '#PBS -N normal',"\n";
						print FH '#PBS -o $0.out',"\n";
						print FH '#PBS -e $0.err',"\n";
						print FH '#PBS -l walltime=6:00:00',"\n";
						print FH 'cd $PBS_O_WORKDIR',"\n";
						print FH "$tflink opt_",$substmodel,"_",$RAStype,".tl\n";
					}
					close FH;
					print SH "qsub opt_",$substmodel,"_",$RAStype,".sh\n"
				} else {
					print SH "$tflink opt_",$substmodel,"_",$RAStype,".tl\n"
				}
			}
		}
		print SH "cd ..\n";
		chdir("..");
	}
	close SH;
	print "   all files ready\n";
}


### launching analyses ###############################################################################################################################

if ($runmode == 1) {
	print "\nlaunching analyses\n";
	if ($system > 1) {
		print "   submitting jobs to cluster -- please be patient...\n";
		system("sh run_all_jobs.sh > deleteme");
		system("rm deleteme");
		system("rm run_all_jobs.sh");
		print "   jobs have been submitted to the cluster\n";
		print "   when they have finished, run the script again in \"summarize\" mode\n";
		print "\n\n"; exit;
	} else {
		print "   running analyses locally -- please be patient...\n";
		system("sh run_all_jobs.sh");
		summarize_results();
	}
}

### summarizing results ###############################################################################################################################

if ($runmode == 2) {
	summarize_results();
}
sub summarize_results {
	print "\nsummarizing results\n";
	unless (open FH,">$outfile") {die "\n#### FATAL ERROR ####\ncannot write to file: $outfile\n"}
	print FH "PMTstrategy\tsubstmodel\tRAStype\tlikelihood\tparameters\tAIC\tAICc\tHQ\tBIC\n";
	my $best;
	foreach my $PMTstrategy (@$PMTstrategies) {
		my $dir = $PMTstrategy->{name};
		foreach my $substmodel (split ',',$substmodels) {
			foreach my $RAStype (split ',',$RAStypes) {
				print FH "$dir\t$substmodel\t$RAStype\t";
				my $file = $dir.'/'.'opt_'.$substmodel.'_'.$RAStype.'.out';
				unless (-e $file) {die "\n#### FATAL ERROR ####\nfile not found: $file\n"}
				open IN,$file; my @a = <IN>; close IN;
				my $results = join '',@a; $results =~ s/[\n\r]//g;
				my ($lnL,$npar,$AIC,$AICc,$HQ,$BIC);
				if ($results =~ /Likelihood\-\>([\-\.\d]+)\,/) {$lnL = $1; print FH $lnL,"\t"} else {print FH "\t"}
				if ($results =~ /NParameters\-\>(\d+)\,/) {$npar = $1; print FH $npar,"\t"} else {print FH "\t"}
				if ($results =~ /AIC\-\>([\.\d]+)\,/) {$AIC = $1; print FH $AIC,"\t"} else {print FH "\t"}
				if ($results =~ /AICc\-\>([\.\d]+)\,/) {$AICc = $1; print FH $AICc,"\t"} else {print FH "\t"}
				if ($results =~ /HQ\-\>([\.\d]+)\,/) {$HQ = $1; print FH $HQ,"\t"} else {print FH "\t"}
				if ($results =~ /BIC\-\>([\.\d]+)\,/) {$BIC = $1; print FH $BIC,"\n"} else {print FH "\n"}
				if ($best->{AIC}->{val}) {
					if ($best->{AIC}->{val} > $AIC) {
						$best->{AIC}->{val} = $AIC;
						$best->{AIC}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
					}
				} else {
					$best->{AIC}->{val} = $AIC;
					$best->{AIC}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
				}
				if ($best->{AICc}->{val}) {
					if ($best->{AICc}->{val} > $AICc) {
						$best->{AICc}->{val} = $AICc;
						$best->{AICc}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
					}
				} else {
					$best->{AICc}->{val} = $AICc;
					$best->{AICc}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
				}
				if ($best->{BIC}->{val}) {
					if ($best->{BIC}->{val} > $BIC) {
						$best->{BIC}->{val} = $BIC;
						$best->{BIC}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
					}
				} else {
					$best->{BIC}->{val} = $BIC;
					$best->{BIC}->{name} = $PMTstrategy->{name}.' '.$substmodel.'+'.$RAStype;
				}
			}
		}
	}
	print "   all files found and parsed\n";
	print "   results table written to $outfile\n";
	print "   selected models:\n";
	print "      AIC:  ",$best->{AIC}->{name},"\n";
	print "      AICc: ",$best->{AICc}->{name},"\n";
	print "      BIC:  ",$best->{BIC}->{name},"\n";
	print "\n\n";
	close FH;
}


### various subroutines ###############################################################################################################################

sub randdig {
	my $nr = shift;
	my $out;
	for (my $i = 0; $i < $nr; ++$i) {
		$out .= int rand 10
	}
	return $out
}

sub spaces {
	my $nr = shift;
	my $out;
	for (my $i = 0; $i < $nr; ++$i) {
		$out .= ' '
	}
	return $out
}

sub get_TL_model {
	my $substmodel = shift;
	my $RAStype = shift;
	my $out;
	if ($substmodel =~ /^GTR$/i) {
		$out = 'GTR[Optimum,Empirical]'
	} elsif ($substmodel =~ /^HKY$/i) {
		$out = 'HKY[Optimum,Empirical]'
	} elsif ($substmodel =~ /^F81$/i) {
		$out = 'GTR[{1,1,1,1,1,1},Empirical]'
	} elsif ($substmodel =~ /^SYM$/i) {
		$out = 'GTR[Optimum,{1,1,1,1}]'
	} elsif ($substmodel =~ /^K80$/i) {
		$out = 'HKY[Optimum,{1,1,1,1}]'
	} elsif ($substmodel =~ /^JC$/i) {
		$out = 'GTR[{1,1,1,1,1,1},{1,1,1,1}]'
	}
	if ($RAStype =~ /^G(\d+)$/i) {
		$out .= ':G[Optimum]:'.$1;
	} elsif ($RAStype =~ /^IG(\d+)$/i) {
		$out .= ':GI[Optimum]:'.$1;
	} elsif ($RAStype =~ /^I$/i) {
		$out .= ':I[Optimum]';
	}
	return $out;
}

sub check_strategy {
	my $strat = shift;
	my ($ar,$ha);
	foreach my $partdef (@{$strat->{def}}) {
		$partdef =~ /^(.*)\s+=\s+(.*)$/;
		my ($name,$def) = ($1,$2);
		$name =~ s/\s//g;
		foreach my $part (split /\s/,$def) {
			if ($part =~ /\\/) {
				$part =~ /(\d+)-(.+?)\\(\d+)/;
				my ($start,$stop,$interval) = ($1,$2,$3);
				if ($stop eq '.') {$stop = $nchar;}
				for (my $i = $start; $i <= $stop; $i += $interval) {
					push @$ar,1;
					$ha->{$i} = 1;
				}
			} elsif ($part =~ /-/) {
				$part =~ /(\d+)\-(\d+)/;
				my ($start,$stop) = ($1,$2);
				if ($stop eq '.') {$stop = $nchar;}
				for (my $i = $start; $i <= $stop; ++$i) {
					push @$ar,1;
					$ha->{$i} = 1;
				}
			} else {
				$part =~ /(\d+)/;
				$ha->{$1} = 1;
				push @$ar,1;
			}
		}
	}
	unless (scalar @$ar == $nchar) {
		die "\n#### FATAL ERROR ####\nPMTstrategy ",$strat->{name}," does not contain $nchar characters (nchar = ",scalar(@$ar),")\n";
	}
	unless (scalar keys %$ha == $nchar) {
		die "\n#### FATAL ERROR ####\nnot all characters assigned to a partition in PMTstrategy ",$strat->{name}," (nchar = ",scalar(keys %$ha),")\n";
	}
}

sub check_substmodels {
	my $in = shift;
	my @a = split ',',$in;
	foreach my $el (@a) {
		unless ($recognized->{'substmodels'}->{$el}) {die "\n#### FATAL ERROR ####\nsubstitution model $el is not recognized or supported\n";}
	}
}

sub check_RAStypes {
	my $in = shift;
	my @a = split ',',$in;
	foreach my $el (@a) {
		unless (($el =~ /^I$/i) or ($el =~ /^G(\d+)$/i) or ($el =~ /^IG(\d+)$/i)) {die "\n#### FATAL ERROR ####\nrates across sites type $el is not recognized or supported\nuse I for Pinvar, Gx for Gamma with x categories, IGx for combination\nseparate different RAS types with commas, without spaces between\n";}
	}
}

sub read_nexus_data {
	my $infile = shift;
	my ($sequence_order,$seqs);
#	print "\nreading alignment ...\n";
	open(FH,$infile) || die "\n#### FATAL ERROR ####\nunable to open $infile";
	my @filedump = <FH>; close FH;
	my $filestring = join('',@filedump);
	unless ($filestring =~ /begin data\;.+?matrix\s*([^\;]+)/si) {die "\n#### FATAL ERROR ####\ncould not find data block in $infile"}
	my @a = split /\n/,$1;
	foreach my $line (@a) {
		my @b = split /\s+/,$line;
		if (scalar @b > 2) {die "\n#### FATAL ERROR ####\nproblem with input: you probably have spaces in your taxon names or sequences";}
		if (scalar @b == 2) {
			unless ($seqs->{$b[0]}) {
				push @$sequence_order,$b[0];
			}
			$b[1] =~ s/\s//g;
			$seqs->{$b[0]} .= $b[1];
		}
	}
	my @keys = keys %$seqs;
	my $seq_length = length($seqs->{$keys[0]});
	foreach my $id (keys %$seqs) {
		unless ($seq_length == length($seqs->{$id})) {die "\n#### FATAL ERROR ####\nsequences not of equal length"}
	}
	my $nr_seqs = scalar keys %$seqs;
#	print "  $nr_seqs sequences\n  $seq_length characters\n";
	return ($sequence_order,$seqs);
}
