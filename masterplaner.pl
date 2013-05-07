#!/usr/bin/env perl 
#===============================================================================
#
#         FILE: masterplaner.pl
#
#        USAGE: ./masterplaner.pl sourcefile.csv
#
#  DESCRIPTION: Produce a KML file showing the Maximum links for a given area.
#               -Show links that can be created given current keys.
#               -Give preference to a specific player.
#               -textual output of links
#               -report of consumed keys
#               -SVG output of link mesh
#
# REQUIREMENTS: Math::Geometry::Delaunay
#       AUTHOR: Adam Fairbrother (Hegz), adam.fairbrother@gmail.com
#      VERSION: 1.0
#      CREATED: 13-03-11 01:08:57 PM
#===============================================================================

use strict;
use warnings;
use Math::Geometry::Delaunay qw(TRI_CCDT);
use Scalar::Util qw(looks_like_number);
use SVG;
use Getopt::Long;
use Data::Dumper;

# Flags and defaults

# Maximums
my $portal_max_links_out = 8;
my $portal_max_links_in  = 20;

# output Toggles
my $kml_out            = 1;
my $svg_out            = 1;
my $orders_out         = 1;
my $outbound_links_out = 1;
my $missing_keys_out   = 1;

# output Filenames
my $kml_out_file            = 'mesh.kml';
my $svg_out_file            = 'mesh.svg';
my $orders_out_file         = 'orders.txt';
my $outbound_links_out_file = 'portal_links.txt';
my $missing_keys_out_file   = 'missing_links.txt';
# SVG Options
my $svg_line_scale = 1;
my $svg_x_scale    = 1;
my $svg_y_scale    = 1;

# Input Sources
my $source_file = undef;

# Global Variable Definitions
my @file;                    # Raw data in
my %players;                 # Players, Colours and controlled portals, keyed by name
my %portals;                 # Portals, Cords, Nickname and player key counts, keyed by portal name
my %orders;                  # Hash of source portals to targets with name of linker, and key owner
my %controllers;             # Hash to define the portal controllers, keyed by portal

# Function Prototypes
sub process_input;           # Process the raw input file into the various hashes and arrays
sub compile_orders;          # Use the Delaunay grid and key counts to create the orders.
sub output_kml;
sub output_svg;
sub output_orders;

# Main Program :

process_input;

# Build points array
my @points;
for my $portal (keys %portals) {
	push @points, [ $portals{$portal}->{x_cord}, $portals{$portal}->{y_cord} ];
}

#Triangleificate
my $tri = new Math::Geometry::Delaunay();
$tri->addPoints(\@points);
$tri->doEdges(1);
$tri->doVoronoi(1);
$tri->triangulate();

my $links = $tri->edges();

my $stats = "Total Number of Portals: " . scalar @points . "\n" .
"Total Number of fields: " . scalar @{$tri->vnodes} . "\n" . 
"Total Number of Links: " . scalar @{$tri->edges} . "\n";

sub process_input {
# Read in the defined source file, or stdin if undefined.
	if (defined $source_file) {
		open my $src_file, '<', $source_file;
		@file = <$src_file>;
		close $src_file;
	}
	else {
		my @file = <>;
	}

# Read names and colours from the datafile and store in the %players hash
	my $players = shift(@file);
	my $colours = shift(@file);
	chomp $players;
	chomp $colours;
	$colours =~ s/#//g;

	my @names = split(/,/,$players);
	my @colours = split(/,/,$colours);
	for (my $count = 4; $count >= 1; $count--) {
		shift @names;
		shift @colours;
	}
	for (my $count = scalar(@names) - 1 ; $count >= 0; $count--) {
		$players{$names[$count]}->{'colour'} = $colours[$count];
	}

#portal hash.  Format $portals{Portal_name}->{nick=>Nickname, x_cord=>x, y_cord=>y, {player}=>{keys}}
#Read in Datafile
	for (@file) {
		chomp;
		s/"//g;
		my ($x,$y,$ignore,$controller,$name,$nick,$total,@keys) = split(/,/);
		unless ($ignore =~ m/yes/i ) { 
			$portals{$name} = {nick => $nick, x_cord => $x, y_cord => $y, ignore => $ignore};
			for (my $count = scalar(@names)-1; $count >= 0; $count--) {
				$portals{$name}->{$names[$count]} = $keys[$count];
				unless ( $controller = '' ) {
					$controllers{$name} = $controller;
					push \@{$players{$controller}->{'portals'}}, $name;
				}
			}
		}
	}
} ## --- end sub process_input

# Number of Links per player
my %player_links;
for (keys %players) {
	$player_links{$_} = 0;
}

my %portalkeys;

for my $portal (keys %portals){
	my $keys = 0;
	for my $player (keys %players) {
		if (looks_like_number($portals{$portal}->{$player})) {
			$keys += $portals{$portal}->{$player};
		}
	}
	$portalkeys{$portal} = $keys;
}
for my $key ( sort { $portalkeys{$b} <=> $portalkeys{$a} } keys %portalkeys ){
LINK: for my $link ( @{$links} ) {
		  next LINK unless ( defined $link );
		  if ( ${${$link}[0]}[0] == $portals{$key}->{'x_cord'} && ${${$link}[0]}[1] == $portals{$key}->{'y_cord'} && $portalkeys{$key} gt 0) {
			  if (keylink(${$link}[1], $key, \%portalkeys)){
				  $link = undef;
				  next LINK;
			  }
		  }
		  elsif ( ${${$link}[1]}[0] == $portals{$key}->{'x_cord'} && ${${$link}[1]}[1] == $portals{$key}->{'y_cord'} && $portalkeys{$key} gt 0) {
			  if (keylink(${$link}[0], $key, \%portalkeys)){
				  $link = undef;
				  next LINK;
			  }
		  }
	  }
}

sub keylink {
# Add a link from a source portal($key) to the target, along with a player that has the key.
	my	( $link, $key, $portalkeys, $player )	= @_;
	unless (defined $player) {

# Give this link to the player with the least links, unless we're told what player to use.
CHOOSER: for my $p ( sort { $player_links{$a} <=> $player_links{$b} } keys %player_links ) {
			 if (defined $portals{$key}->{$p} &&  $portals{$key}->{$p} gt 0) {
				 $player = $p;
				 last CHOOSER;
		 }
		}
	}

FINDER: for (keys %portals) {
# Find the Target portal, and add it all to the hash
			if ($portals{$_}->{'x_cord'} == ${$link}[0] && $portals{$_}->{'y_cord'} == ${$link}[1] && $key ne $_) {
# Check if the source portal is being controlled by a player, give it to them if possible
				if (defined $controllers{$_} && defined $portals{$_}->{$controllers{$_}} &&  $portals{$key}->{$controllers{$_}} gt 0) {
					$player = $controllers{$_};
				}
				push @{$orders{$_}}, {target => $key, player => $player};
				$portalkeys->{$key}--;
				$player_links{$player} += 1;
				$portals{$key}->{$player} -= 1;
				return 1;
			}
		}
		return 0;
} ## --- end sub keylink

my %missing_keys;
my $missed_links;
#Load on any remainders

LINK: for my $link ( @{$links} ) {
		  next unless ( defined $link );
		  $missed_links++;
		  for my $key (keys %portals) {
			  if (${${$link}[0]}[0] == $portals{$key}->{'x_cord'} && ${${$link}[0]}[1] == $portals{$key}->{'y_cord'}) {
				  for (keys %portals) {
					  if ($portals{$_}->{'x_cord'} == ${${$link}[1]}[0] && $portals{$_}->{'y_cord'} == ${${$link}[1]}[1]) {
						  $missing_keys{$key}++;
						#  $missing_keys{$_}++;
						  push @{$orders{$_}}, {target => $key};
						  $link = undef;
						  next LINK;
					  }
				  }
			  }
		  }
	  }


if ($missing_keys_out ) {
	#missing keys output
	open my $file, '>', $missing_keys_out_file;
		for (sort keys %missing_keys) {
			print $file "$_ " . "\n";
		}
	close $file;
}
#Print output

if ($kml_out) {
# Begin Document
	print "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print "<kml xmlns=\"http://earth.google.com/kml/2.2\">\n";
	print "<Document>\n";
	print "  <name>Kamloops Portals - Max Links</name>\n";
	print "  <description><![CDATA[Autogenerated Max links.\n";
	print "";
	print "$stats";
	print "currently $missed_links links short of a full wipe\n\n" if defined ($missed_links);
	for (keys %player_links) {
		print "$_ $player_links{$_}\n";
	}
	print "]]></description>\n";

# Set default link colour for no Keys
	print "  <Style id=\"linknokey\">\n";
	print "    <LineStyle>\n";
	print "      <color>FF000000</color>\n";
	print "      <width>2</width>\n";
	print "    </LineStyle>\n";
	print "  </Style>\n";

# Set default link colour for links with Keys but no controller
	print "  <Style id=\"linknocontroller\">\n";
	print "    <LineStyle>\n";
	print "      <color>FFFF00FF</color>\n";
	print "      <width>2</width>\n";
	print "    </LineStyle>\n";
	print "  </Style>\n";

# Set link colours for players with matching keys
	for (keys %players){
		print "  <Style id=\"link$_\">\n";
		print "    <LineStyle>\n";
		print "      <color>FF" .  scalar reverse($players{$_}->{'colour'}) . "</color>\n";
		print "      <width>5</width>\n";
		print "    </LineStyle>\n";
		print "  </Style>\n";
	}

#Set Default Portal Style
	print "   <Style id=\"Portal\">\n";
	print "     <LabelStyle>\n";
	print "       <color>FFAA0000</color>\n";
	print "     </LabelStyle>\n";
	print "   </Style>\n";

# Load all portal markers.
	for (sort keys %portals) {
		print "   <Placemark>\n";
		print "     <name>$_</name>\n";
		print "     <styleUrl>#Portal</styleUrl>\n";
		print "     <Point>\n";
		print "       <coordinates>" . $portals{$_}->{'x_cord'} . "," . $portals{$_}->{'y_cord'} .",0</coordinates>\n";
		print "     </Point>\n";
		print "   </Placemark>\n";
	}

	for my $source (sort keys %orders){
		for (@{$orders{$source}}) {
			print "  <Placemark>\n";
			print "    <Snippet></Snippet>\n";
			print "    <description><![CDATA[]]></description>\n";

			if (defined $_->{'player'} && defined $controllers{$source}){
				print "    <styleUrl>#link" . $controllers{$source} . "</styleUrl>\n";
				print "    <name>" . $_->{'player'} . " key link to " . $_->{'target'} . "</name>\n";
			}
			elsif (defined $_->{'player'}) {
				print "    <styleUrl>#linknocontroller</styleUrl>\n";
				print "    <name>" . $_->{'player'} . " key link to " . $_->{'target'} . "</name>\n";
			}
			else {
				print "    <styleUrl>#linknokey</styleUrl>\n";
				print "    <name>Link</name>\n";
			}
			print "    <LineString>\n";
			print "      <tessellate>1</tessellate>\n";
			print "      <coordinates>\n";
			print "        " . $portals{$source}->{x_cord} . "," . $portals{$source}->{y_cord} . ",0\n";
			print "        " . $portals{$_->{target}}->{x_cord} . "," . $portals{$_->{target}}->{y_cord} . ",0\n";
			print "      </coordinates>\n";
			print "    </LineString>\n";
		 	print "  </Placemark>\n";
		} 
	}

# Close Document
	print "</Document>\n";
	print "</kml>\n";
}

#Textual Description output
open my $marching_orders, '>', 'orders.txt';
for my $player (sort keys %players) {
	print $marching_orders "Attack Plan for $player\n";
	print $marching_orders "==================================\n\n";
	my $total_links = 0;
	if (defined (@{$players{$player}->{'portals'}})) {
		for (sort @{$players{$player}->{'portals'}}) {
			chomp;
			print $marching_orders "$_";
			print $marching_orders " (" . $portals{$_}->{nick} . ")" if defined $portals{$_}->{nick} && $portals{$_}->{nick} ne "";
			print $marching_orders "\n";
			if (defined (@{$orders{$_}})) {
				for (@{$orders{$_}}) {
					next unless defined $_->{'player'};
					print $marching_orders "  -> " . $_->{'target'} ;
					print $marching_orders " (" . $portals{$_->{target}}->{nick} . ")" if $portals{$_->{target}}->{nick} ne "";
					print $marching_orders "\n";
					$total_links++
				}
			}
			else {
				print $marching_orders "  ! No Outgoing Links !\n";
			}
			print $marching_orders "\n";
		}
	}
	print $marching_orders $total_links . " Total Links\n";
	print $marching_orders "Your Key Transfers\n\n";
	for my $reciptient (sort keys %players) {
		next if $reciptient eq $player;
		print $marching_orders "Keys to transfer to $reciptient\n";
		my %transfers;
		for my $portal (sort keys %portals) {
			if (defined $orders{$portal}){
				for (@{$orders{$portal}}) {
					next unless defined $_->{'player'};
					next unless defined $controllers{$portal} && $controllers{$portal} eq $reciptient;
					if ($player eq $_->{'player'}) {
						$transfers{$_->{'target'}} +=1; 
					}
				}
			}
		}
		for (sort keys %transfers) {
			print $marching_orders $transfers{$_} . " X " . $_ . "\n";
		}
		print $marching_orders "\n";

	}

	for (@{$players{$player}->{'portals'}}) {
		print $marching_orders $portals{$_}->{'y_cord'} . "," . $portals{$_}->{'x_cord'} . "\n";
	}
}

open my $portal_links, '>', 'portal_links.txt';
for (sort keys %portals) {
	print $portal_links "$_";
	print $portal_links " (" . $portals{$_}->{nick} . ")" if $portals{$_}->{nick} ne "";
	print $portal_links ",";
	if (defined (@{$orders{$_}})) {
		print $portal_links scalar @{$orders{$_}} . "\n";
	}
	else {
		print $portal_links "0 \n";
	}
}

exit 0;

#SVG Output

my $northmost =0;
my $westmost=360;
my $southmost=100;
my $eastmost=-360;
my $imagesize = 1000;
my $imgwidth;
my $imgheight;

# Calculate the image bounds.
for my $portal (keys %portals) {
	$northmost = $portals{$portal}->{y_cord} if $portals{$portal}->{y_cord} > $northmost;
	$southmost = $portals{$portal}->{y_cord} if $portals{$portal}->{y_cord} < $southmost;
	$eastmost = $portals{$portal}->{x_cord} if $portals{$portal}->{x_cord} > $eastmost;
	$westmost = $portals{$portal}->{x_cord} if $portals{$portal}->{x_cord} < $westmost;
}

# Calculate Image size and scaling.
my $scaley = $imagesize / ($eastmost - $westmost) * 1;
my $scalex = $imagesize / ($southmost - $northmost) * -1;
$imgheight = $scaley * ($southmost - $northmost) *-1.02;
$imgwidth = $scalex * ($eastmost - $westmost) * 1.02;
my $xoffset = $scalex * ($eastmost - $westmost) * 0.01;
my $yoffset = $scaley * ($southmost - $northmost) *-0.01;

my $svg= SVG->new(width=>$imgwidth,height=>$imgheight, style=>{background=>'white'});

my $bg = $svg->rectangle(
		width=>$imgwidth, height=>$imgheight,
		fill => 'white',
		id=>'rect_1'
		);


# Insert Directional Marker
my $m = $svg->marker(
		id => 'Tri',
		viewBox => "0 0 20 20", 
		refX => "0", 
		refY => "10", 
		markerUnits => "strokeWidth",
		markerWidth => $imagesize / 300, 
		markerHeight => $imagesize / 300, 
		orient => "auto",
		);
$m->tag(
		'path',
		d => "M 0 0 L 20 10 L 0 20 z"
	   );

# Add a group for each player
my %groups;
for my $player (keys %players) {
	$groups{$player} = $svg->group (
			id => "group_$player",
			style => { stroke=> '#'.$players{$player}, 'stroke-width'=>'0.5', 'marker-mid' => 'url(#Tri)'});
}

# Portals Group
my $svg_ports=$svg->group(
		id    => 'group_y',
		style => { stroke=>'purple', fill=> 'Purple', 'stroke-width'=>'0.05'}
		);


# Add in all the lines with a midpoint for the directional Marker
my $lineid = 1;
for my $source (sort keys %portals) {
	if (defined (@{$orders{$source}})) {
 		for (@{$orders{$source}}) {
 			next unless defined $_->{'player'};

			my $x1 = ((-1 * $westmost) + $portals{$source}->{x_cord}) * $scalex + $xoffset;
			my $y1 = ($northmost - $portals{$source}->{y_cord}) * $scaley + $yoffset;

			my $x3 = ((-1 * $westmost) + $portals{$_->{'target'}}->{x_cord}) * $scalex +$xoffset;
			my $y3 = ($northmost - $portals{$_->{'target'}}->{y_cord}) * $scaley +$yoffset;

			my $x2 = $x1 + 0.5 * ($x3 - $x1);
			my $y2 = $y1 + 0.5 * ($y3 - $y1);

			my $xv = [$x1,$x2,$x3];
			my $yv = [$y1,$y2,$y3];

			my $points = $svg->get_path(
					x=>$xv, y=>$yv,
					-type=>'polyline',
					-closed=>'true');

			$groups{$_->{'player'}}->polyline (
					%$points,
					id => $lineid,
					); 
			$lineid ++;
		}
	}
}

# Add in all the portals
for my $portal (sort keys %portals) {
	my $x = ((-1 * $westmost) + $portals{$portal}->{x_cord}) * $scalex +$xoffset;
	my $y = ($northmost - $portals{$portal}->{y_cord}) * $scaley +$yoffset;

	$svg_ports->circle(cx=>$x, cy=>$y, r=>1, id=>$portal)
}

open my $pic, '>', 'mesh.svg';
print $pic $svg->xmlify;
close $pic;

exit 0;
