# PMT: Partitioned Model Tester

Note: Partitioned Model Tester is obsolete and is no longer supported. Better implementations are available in IQ-Tree or PartitionFinder.

Partitioned Model Tester is a Perl program that evaluates different partitioning strategies and models of sequence evolution for a given alignment. It calculates the Akaike and Bayesian information criteria (AIC, AICc, BIC) for the partitioning strategies you specify and the models of sequence evolution you specify.

PMT depends on three external programs. First, it wraps around [TreeFinder](http://www.treefinder.de/) to optimize the likelihood of the different partitioning strategies and models. Second, it uses [FastTree](http://www.microbesonline.org/fasttree/) to infer a guide tree (optional, you can also specify a pre-made guide tree). So you will have to download and install these programs before you can use PMT. Finally, PMT uses another perl script called nex2treefinder.pl to convert nexus files to the treefinder format. This is included in the repository.

I've only used the program on Linux and Mac OS X but if you're computer-savvy you should be able to get it to run on Windows, too.

### User guide
PMT is very simple to use. I suggest you start by downloading the example alignment and running it by running `PMT.pl -i concatenated.nex`.

When you start with your own data, the most important thing is getting your alignment in shape. PMT takes an alignment in NEXUS format with a PMT block at the end. The NEXUS parser is not very advanced, so please clean up your alignment, make sure not to have spaces or out-of-the-ordinary characters in your taxon names, and take all the comments out of the file. The alignment should not be interleaved. Please look at the example file and try to format your alignment accordingly.

Below your alignment you can add a PMT block. This defines the various partitioning strategies that PMT will evaluate. It is very simple and intuitive to do this, as is shown in this example:


```
begin PMT.pl;

  PMTstrategy 01_onepart;
	charset all = 1-4852;
  end;

  PMTstrategy 02_genes;
	charset 18S = 1-1706;
	charset LSU = 1707-2089;
	charset cox1 = 2090-2704;
	charset psbA = 2705-3466;
	charset rbcL = 3467-4852;
  end;

  PMTstrategy 03_functional;
	charset rDNA = 1-2089;
	charset protcod = 2090-4852;
  end;

  PMTstrategy 04_genomes;
	charset nucl = 1-2089;
	charset mito = 2090-2704;
	charset plas = 2705-4852;
  end;

  PMTstrategy 05_genomes_codpos;
	charset nucl = 1-2089;
	charset mitocp1 = 2090-2704\3;
	charset mitocp2 = 2091-2704\3;
	charset mitocp3 = 2092-2704\3;
	charset plascp1 = 2705-4852\3;
	charset plascp2 = 2706-4852\3;
	charset plascp3 = 2707-4852\3;
  end;
  
end;
```

A list of substitution models and rates across sites model extensions can be specified at the command-line. See the list of command-line flags below for instructions on this.

If you have a cluster at your disposal, you can run the different optimizations in parallel. In this case, use the -m flag to subdivide the execution in two parts. For the job launching part, use the -c flag to submit jobs to the Sun Grid Engine (option 2) or the PBS (option 3). After the jobs have been executed, run the PMT script again with -m 2 to summarize the results.

Here is a complete list of command-line flags you can use.

```
mandatory parameters
   -i  input alignment (nexus format)

optional parameters
   -o  output file (plain text)
		 default: results.txt
   -g  guide tree (newick format)
		 if unspecified, will run PhyML with HKY+IG4 to get one
   -s  substitution models
		 comma-separated list of substitution models
		 default: JC,F81,K80,HKY,SYM,GTR
   -r  rates across sites
		 comma-separated list of Gamma and Pinvar options
		 default: G4,G8,IG4,I
   -c  computer you're working with
		 1: local workstation (default)
		 2: KERMIT (parallel execution)
		 3: UGent HPC (parallel execution)
   -m  running mode
		 1: job launching mode (default)
		 2: summarize results mode
```

### Citation
If you find this software useful, please cite it in your work. I recommend citing it as follows:
Verbruggen H. (2012) PMT: Partitioned Model Tester version 1.01. https://github.com/hverbruggen/PMT

### Notes and disclaimer
PMT is in development and has not been tested extensively. It is quite plausible that incorrectly formatted input could lead to nonsensical output. In such cases, you should double-check your input, compare it to the example files and try again. If this still doesn't work, please feel free to write me an email (heroen.verbruggen@gmail.com).

