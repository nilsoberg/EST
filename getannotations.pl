#!/usr/bin/env perl

#version 0.9.2 no changes to this file
#version 0.9.4 modifications due to removing sequence and classi fields and addition of uniprot_description field

use Getopt::Long;
use List::MoreUtils qw{apply uniq any} ;
use DBD::SQLite;
use DBD::mysql;
use File::Slurp;


$configfile=read_file($ENV{'EFICFG'}) or die "could not open $ENV{'EFICFG'}\n";
eval $configfile;

$result=GetOptions ("fasta=s"		=> \$fasta,
		    "out=s"		=> \$out,
		    "userdat=s"		=> \$userdat
		    );
print "$fasta\n";

@accessions=apply {chomp $_} apply {$_=~s/:\d+:\d+//} apply {$_=~s/^>//} `grep "\>" $fasta`;

open OUT, ">$out" or die "cannot write struct.out file $out\n";


foreach $accession (@accessions){
  #print "$accession\n";
  unless($accession=~/^z/){
    $sth= $dbh->prepare("select * from annotations where accession = '$accession'");
    $sth->execute;
    $row = $sth->fetchrow_hashref;
    print OUT $row->{"accession"} . 
        "\n\tUniprot_ID\t" . $row->{"Uniprot_ID"} . 
        "\n\tSTATUS\t" . $row->{"STATUS"} . 
        "\n\tSequence_Length\t" . $row->{"Squence_Length"} . 
        "\n\tTaxonomy_ID\t" . $row->{"Taxonomy_ID"} . 
        "\n\tGDNA\t" . $row->{"GDNA"} . 
        "\n\tDescription\t" . $row->{"Description"} . 
        "\n\tSwissprot_Description\t" . $row->{"SwissProt_Description"} . 
        "\n\tOrganism\t" . $row->{"Organism"} . 
        "\n\tDomain\t" . $row->{"Domain"} . 
        "\n\tGN\t" . $row->{"GN"} . 
        "\n\tPFAM\t" . $row->{"PFAM"} . 
        "\n\tPDB\t" . $row->{"pdb"} . 
        "\n\tIPRO\t" . $row->{"IPRO"} . 
        "\n\tGO\t" . $row->{"GO"} . 
        "\n\tGI\t" . $row->{"GI"} . 
        "\n\tHMP_Body_Site\t" . $row->{"HMP_Body_Site"} . 
        "\n\tHMP_Oxygen\t" . $row->{"HMP_Oxygen"} . 
        "\n\tEFI_ID\t" . $row->{"EFI_ID"} . 
        "\n\tEC\t" . $row->{"EC"} . 
        "\n\tPHYLUM\t" . $row->{"Phylum"} . 
        "\n\tCLASS\t" . $row->{"Class"} . 
        "\n\tORDER\t" . $row->{"TaxOrder"} . 
        "\n\tFAMILY\t" . $row->{"Family"} . 
        "\n\tGENUS\t" . $row->{"Genus"} . 
        "\n\tSPECIES\t" . $row->{"Species"} . 
        "\n\tCAZY\t" . $row->{"Cazy"} . 
        "\n";
  }
}

close OUT;

if($userdat=~/\w+/ and -s $userdat){
  #add user supplied dat info tio struct.out
  system("cat $userdat >> $out");
}
