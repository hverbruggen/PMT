# PMT: Partitioned Model Tester

Partitioned Model Tester is a Perl program that evaluates different partitioning strategies and models of sequence evolution for a given alignment. It calculates the Akaike and Bayesian information criteria (AIC, AICc, BIC) for the partitioning strategies you specify and the models of sequence evolution you specify.

PMT depends on three external programs. First, it wraps around [TreeFinder](http://www.treefinder.de/) to optimize the likelihood of the different partitioning strategies and models. Second, it uses [FastTree](http://www.microbesonline.org/fasttree/) to infer a guide tree (optional, you can also specify a pre-made guide tree). So you will have to download and install these programs before you can use PMT. Finally, PMT uses another perl script called nex2treefinder.pl to convert nexus files to the treefinder format. This is included in the repository.

I've only used the program on Linux and Mac OS X but if you're computer-savvy you should be able to get it to run on Windows, too.

More information and instructions on how to run the program are available here: [http://phycoweb.net/software/PMT/index.html](http://phycoweb.net/software/PMT/index.html)
