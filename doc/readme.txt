ProPhylo 1.02 release (09/14/11)
================================

What's new in this version:

A new program that can create a profile from BLAST result file.

ProPhylo 1.01 release (07/25/11)
================================

What's new in this version:

1. A new program that score a profile with HMMER3 result has been added.





ProPhylo 1.0 release (02/14/11)
===============================

What's new in this version:
===========================
1. The name of the software is changed to ProPhylo. There is already a
   separate software with this name.
2. The software no longer requires separate download of
   SeqToolBox. The library is already included with the distribution.
3. The BLAST databases and the taxonomy database have been updated.
4. Several bugfixes and enhancement. 
5. The software is now supported on MacOSX and Linux.
5. This is a version 1 release of the software.



PhyloProf 0.01 beta release (01/21/10) 

*** The software is supported on Linux only ***

This is a quick and dirty release of phylogenetic profile comparison
program using Partial Phylogenetic Profile algorithm.

Installation
============

The software is written using Perl. You need to install the following
Perl modules to correctly use this software.

1. Math::Cephes
2. Term::ProgressBar
3. DBD::SQLite
4. Bio::Perl (though not strictly needed for partial phylogenetic profile)

You can download and install these modules using standard perl installation.


== Update 02/14/11: No longer needed ==
>Once you have installed these modules, download SeqToolBox from this
>location.  ftp://ftp.jcvi.org/pub/data/ppp/software/seqtoolbox. Unzip
>it in any directory of your choice. Add the SeqToolBox/lib directory
>to your PERL5LIB paths.
========================================


To use properly SeqToolBox, you need to create another directory where
you will store the SeqToolBox databases. This directory should have
atleast 1GB of space. Once you have created your directory, add it to
an environment variable SEQTOOLBOXDB. If you are using bash, you can
add this line to your .bash_profile export
SEQTOOLBOXDB=/the_directory_I_have_created/. Now you should download
the file,
ftp://ftp.jcvi.org/pub/data/ppp/seqtoolboxdb/seqtoolboxdb.tar.bz2
to this directory and unzip it:

cd /the_directory_i_have_created
wget ftp://ftp.jcvi.org/pub/data/ppp/seqtoolboxdb/seqtoolboxdb.tar.bz2
tar -xvjf seqtoolboxdb.tar.bz2

Now you have to download the PPP databases and set it up. You should
create another directory of your choice. The space required varies
depending on how many genomes you'd like to search. Once you have
created your directory create two subdirectories under it, desc and blast. 
The directory structure will be like this:

ppp_dir
	desc
	blast

cd ppp_dir/desc
wget ftp://ftp.jcvi.org/pub/data/ppp/pppdb/desc/gi_desc.sqlite3.bz2
bunzip2 gi_desc.sqlite3.bz2

The last but one step of the PPP search is to find the genome you are
interested in. The database with the software comes with ~1400
complete or partial genomes. If you have the taxon id you can download the specific genomes by,

cd ppp_dir/blast
wget ftp://ftp.jcvi.org/pub/data/ppp/pppdb/blast/taxon_id.tar.bz2 (replace the taxon_id of your choice)
tar -xvjf taxon_id.tar.bz2

The last step of the installation process in to download the ppp
software itself. Create a directory of your choice. Download the
latest version of the software from
ftp://ftp.jcvi.org/pub/data/ppp/software/phyloprof/ in this
directory. Unzip it and put the lib directory in your PERL5LIB path.

Now you have completed the installation.


Running PPP search
==================
The main scrip is ppp.pl in the bin direcotry of PhyloProf distribution.

The software has many options but the main options are:

-t taxon_id 
This is the genome to search. Be sure that the directory exists in your ppp_dir/blast location.

-w dir 
This is a path where the temporary files will be written. If
not given the temporary files are written in your current directory.

-d ppp_dir
This is the path of the ppp database directory

-p profile_file
This is the profile file that will searched against the genome. The file has the following format:

taxon_id_1  <tab> 1
taxon_id_2 <tab> 0
...

This is a tab-delimited file where the first column is NCBI taxon id
and the second column is 1 or 0, indicating presence and absence,
respectively.

--threads num
This is to run the software in parellel.


Example run
===========

perl -w ~/projects/PhyloProf/bin/ppp.pl \
     -d /usr/local/scratch/malay/phyloprof/stand_alone/db/ \
     -t 146891 -p /usr/local/scratch/malay/phyloprof/tmp/ppp/TOMM_PELO.PROFILE \
     --threads 4 >result.txt



Some notes about the result 
========================== 

The software takes the profile and iterates through the blast result
of each gene in the genome. For each blast result it goes down the
list and finds the depth at which the best probabilty score found
using binomial probablity. If the gi comes from a taxonomic group that
is present in the given profile, it is taken as 'yes'. The total
number of experiment is the number of comparison made.

The result of a ppp run is is a text file containing list of all the
genes in the genome sorted by closest match to the given profile. The
output file has the following columns from left to right:

1. The gene gi number
2. The number of matches to the profile (number of yes)
3. The total number genes compared (number of experiments)
4. The depth of the blast result where the best match found
5. The probability value of the match
6. The score of the match in log.
7. The description of gene.


Author
=======

Malay K Basu (mbasu@jcvi.org)


Contact
=======

For comments and further help contact mbasu@jcvi.org.




 



