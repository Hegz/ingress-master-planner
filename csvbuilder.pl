#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: csvbuilder.pl
#
#        USAGE: ./csvbuilder.pl <KML Datafile>
#
#  DESCRIPTION: Turns a KML export of portals into a cvs list consumable by 
#               masterplaner.pl
#
#       AUTHOR: Adam Fairbrother (Hegz), afairbrother@sd73.bc.ca
# ORGANIZATION: School District No. 73
#      VERSION: 1.0
#      CREATED: 13-04-05 12:40:52 PM
#     REVISION: ---
#===============================================================================

use strict;
use warnings;
use utf8;
use XML::Twig;

my $outfile = 'portals.csv';

my $raw_kml = <>;

my $twig = XML::Twig->new();
$twig->parse($raw_kml);
my $root = $twig->root;
my @children = $root->first_child->children('Placemark');

my @sorted = sort { $a->first_child()->text 
                    cmp $b->first_child()->text} @children;

open my $output, '>', $outfile;
print $output "GPS Cord,Key Name\n";
for (@sorted){
	my $gps = $_->first_child('Point')->text;
	$gps =~ s/,0$//;
	print $output '"' . $gps . '",';
	print $output $_->first_child->text . "\n";
}
