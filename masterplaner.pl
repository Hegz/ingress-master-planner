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
use Geo::KML;
use SVG;
use Getopt::Long;
Getopt::Long::Configure ("bundling");
use Pod::Usage;
use Data::Dumper;

# Flags and defaults

# Maximums
my $portal_max_links_out = 8;
my $portal_max_links_in  = 20;

# output Toggles
<<<<<<< HEAD
my $kml_out            = 'mesh.kml';
my $svg_out            = 'mesh.svg';
my $orders_out         = 'plans.txt';
my $outbound_links_out = 'portal_links.txt';
my $missing_keys_out   = 'missing_links.txt';

# output Filenames
=======
>>>>>>> refs/remotes/origin/master
# SVG Options
my $svg_line_scale = 1;
my $svg_x_scale    = 1;
my $svg_y_scale    = 1;

# Input Sources
my $source_file = undef;

# Global Variable Definitions
my %players;
my %portals;
my %orders;
my %controllers;
my %player_links;
my %missing_keys;
my $missed_links;

# Function Prototypes
sub process_input;
sub process_links;
sub compile_orders;
sub out_kml;
sub out_svg;
sub out_orders;
sub out_missing_keys;
sub out_links;


my ($help, $man);            # Help options
GetOptions ( 'kml:s'           => $kml_out,
             'svg:s'           => $svg_out,
			 'plans:s'         => $orders_out,
			 'links:s'         => $outbound_links_out,
			 'missingkeys:s'   => $missing_keys_out,
			 'svg-linescale:i' => $svg_line_scale,
			 'svg-xscale:i'    => $svg_x_scale,
			 'svg-yscale:i'    => $svg_y_scale,
			 'input:s'         => $source_file,
			 'help|?'          => \&$help,
			 'man'             => \&$man,
			 ) or pod2usage(2);
pod2usage(1) if $help;
pod2usage(-exitstatus => 0, -verbose =>2) if $man;

# Main Program :

process_input;

# Build points array
my @points;
for my $portal ( keys %portals ) {
	push @points, [ $portals{$portal}->{x_cord}, $portals{$portal}->{y_cord} ];
}

#Triangleificate
my $tri = new->Math::Geometry::Delaunay();
$tri->addPoints( \@points );
$tri->doEdges(1);
$tri->doVoronoi(1);
$tri->triangulate();

my $links = $tri->edges();

my $stats =
    "Total Number of Portals: "
  . scalar @points . "\n"
  . "Total Number of fields: "
  . scalar @{ $tri->vnodes } . "\n"
  . "Total Number of Links: "
  . scalar @{ $tri->edges } . "\n";

process_links;

# Outputs:
if ($missing_keys_out) {
	out_missing_keys($missing_keys_out_file);
}
if ($kml_out) {
	out_kml($kml_out_file);
}
if ($orders_out) {
	out_orders($orders_out_file);
}
if ($outbound_links_out) {
	out_links($outbound_links_out_file);
}
if ($svg_out) {
	out_svg($svg_out_file);
}

exit 0;

sub process_input {

	# Read in the defined source file, or stdin if undefined.
	my @file;
	if ( defined $source_file ) {
		open my $src_file, '<', $source_file
		  or die "Unable to open file $source_file: $!\n";
		@file = <$src_file>;
		close $src_file;
	} else {
		@file = <>;
	}

	# Read names and colours from the datafile and store in the %players hash
	my $players = shift(@file);
	my $colours = shift(@file);
	chomp $players;
	chomp $colours;
	$colours =~ s/#//g;

	my @names   = split( /,/, $players );
	my @colours = split( /,/, $colours );
	for ( my $count = 6 ; $count >= 1 ; $count-- ) {
		shift @names;
		shift @colours;
	}
	for ( my $count = scalar(@names) - 1 ; $count >= 0 ; $count-- ) {
		$players{ $names[$count] }->{'colour'} = $colours[$count];
	}

#portal hash.  Format $portals{Portal_name}->{nick=>Nickname, x_cord=>x, y_cord=>y, {player}=>{keys}}
#Read in Datafile
	for (@file) {
		chomp;
		s/"//g;
		my ( $x, $y, $ignore, $controller, $name, $nick, $total, @keys ) =
		  split(/,/);
		unless ( $ignore =~ m/yes/i ) {
			$portals{$name} =
			  { nick => $nick, x_cord => $x, y_cord => $y, ignore => $ignore };
			for ( my $count = scalar(@names) - 1 ; $count >= 0 ; $count-- ) {
				$portals{$name}->{ $names[$count] } = $keys[$count];
				unless ( $controller = '' ) {
					$controllers{$name} = $controller;
					push \@{ $players{$controller}->{'portals'} }, $name;
				}
			}
		}
	}
	return;
}    ## --- end sub process_input

sub process_links {
	my ($par1) = @_;

	# Number of Links per player
	for ( keys %players ) {
		$player_links{$_} = 0;
	}

	my %portalkeys;

	for my $portal ( keys %portals ) {
		my $keys = 0;
		for my $player ( keys %players ) {
			if ( looks_like_number( $portals{$portal}->{$player} ) ) {
				$keys += $portals{$portal}->{$player};
			}
		}
		$portalkeys{$portal} = $keys;
	}
	for
	  my $key ( sort { $portalkeys{$b} <=> $portalkeys{$a} } keys %portalkeys )
	{
	  LINK: for my $link ( @{$links} ) {
			next LINK unless ( defined $link );
			if (    ${ ${$link}[0] }[0] == $portals{$key}->{'x_cord'}
				 && ${ ${$link}[0] }[1] == $portals{$key}->{'y_cord'}
				 && $portalkeys{$key} > 0 )
			{
				if ( keylink( ${$link}[1], $key, \%portalkeys ) ) {
					$link = undef;
					next LINK;
				}
			} elsif (    ${ ${$link}[1] }[0] == $portals{$key}->{'x_cord'}
					  && ${ ${$link}[1] }[1] == $portals{$key}->{'y_cord'}
					  && $portalkeys{$key} > 0 )
			{
				if ( keylink( ${$link}[0], $key, \%portalkeys ) ) {
					$link = undef;
					next LINK;
				}
			}
		}
	}

	#Load on any remainders

  LINK: for my $link ( @{$links} ) {
		next unless ( defined $link );
		$missed_links++;
		for my $key ( keys %portals ) {
			if (    ${ ${$link}[0] }[0] == $portals{$key}->{'x_cord'}
				 && ${ ${$link}[0] }[1] == $portals{$key}->{'y_cord'} )
			{
				for ( keys %portals ) {
					if (    $portals{$_}->{'x_cord'} == ${ ${$link}[1] }[0]
						 && $portals{$_}->{'y_cord'} == ${ ${$link}[1] }[1] )
					{
						$missing_keys{$key}++;
						$missing_keys{$_}++;
						push @{ $orders{$_} }, { target => $key };
						$link = undef;
						next LINK;
					}
				}
			}
		}
	}

	return;
}    ## --- end sub process_links

sub keylink {

# Add a link from a source portal($key) to the target, along with a player that has the key.
	my ( $link, $key, $portalkeys, $player ) = @_;
	unless ( defined $player ) {

# Give this link to the player with the least links, unless we're told what player to use.
	  CHOOSER:
		for my $p (
					sort { $player_links{$a} <=> $player_links{$b} }
					keys %player_links
				  )
		{
			if ( defined $portals{$key}->{$p} && $portals{$key}->{$p} > 0 ) {
				$player = $p;
				last CHOOSER;
			}
		}
	}

  FINDER: for ( keys %portals ) {

		# Find the Target portal, and add it all to the hash
		if (    $portals{$_}->{'x_cord'} == ${$link}[0]
			 && $portals{$_}->{'y_cord'} == ${$link}[1]
			 && $key ne $_ )
		{

# Check if the source portal is being controlled by a player, give it to them if possible
			if (    defined $controllers{$_}
				 && defined $portals{$_}->{ $controllers{$_} }
				 && $portals{$key}->{ $controllers{$_} } > 0 )
			{
				$player = $controllers{$_};
			}
			push @{ $orders{$_} }, { target => $key, player => $player };
			$portalkeys->{$key}--;
			$player_links{$player} += 1;
			$portals{$key}->{$player} -= 1;
			return 1;
		}
	}
	return 0;
}    ## --- end sub keylink

sub get_output {

	# Open the file name provided for output, or return stdout instead.
	my ($filename) = @_;
	if ($filename) {
		open my $file, '>', $filename
		  or die "unable to open file $filename: $!\n";
		return $file;
	} else {
		my $file = \*STDOUT;
		return $file;
	}
}

sub out_missing_keys {
	my ($filename) = @_;
	my $file = get_output($filename);
	for ( sort keys %missing_keys ) {
		print $file "$_, " . $missing_keys{$_} . "\n";
	}
	if ($filename) {
		close $file;
	}
	return;
}    ## --- end sub out_missing_keys

sub out_kml {

	# KML link mesh output
	my ($filename) = @_;
	my $file = get_output($filename);

	# Begin Document
	print $file "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
	print $file "<kml xmlns=\"http://earth.google.com/kml/2.2\">\n";
	print $file "<Document>\n";
	print $file "  <name>Kamloops Portals - Max Links</name>\n";
	print $file "  <description><![CDATA[Autogenerated Max links.\n";
	print $file "";
	print $file "$stats";
	print $file "currently $missed_links links short of a full wipe\n\n"
	  if defined($missed_links);

	for ( keys %player_links ) {
		print $file "$_ $player_links{$_}\n";
	}
	print $file "]]></description>\n";

	# Set default link colour for no Keys
	print $file "  <Style id=\"linknokey\">\n";
	print $file "    <LineStyle>\n";
	print $file "      <color>FF000000</color>\n";
	print $file "      <width>2</width>\n";
	print $file "    </LineStyle>\n";
	print $file "  </Style>\n";

	# Set default link colour for links with Keys but no controller
	print $file "  <Style id=\"linknocontroller\">\n";
	print $file "    <LineStyle>\n";
	print $file "      <color>FFFF00FF</color>\n";
	print $file "      <width>2</width>\n";
	print $file "    </LineStyle>\n";
	print $file "  </Style>\n";

	# Set link colours for players with matching keys
	for ( keys %players ) {
		print $file "  <Style id=\"link$_\">\n";
		print $file "    <LineStyle>\n";
		print $file "      <color>FF" . scalar
		  reverse( $players{$_}->{'colour'} ) . "</color>\n";
		print $file "      <width>5</width>\n";
		print $file "    </LineStyle>\n";
		print $file "  </Style>\n";
	}

	#Set Default Portal Style
	print $file "   <Style id=\"Portal\">\n";
	print $file "     <LabelStyle>\n";
	print $file "       <color>FFAA0000</color>\n";
	print $file "     </LabelStyle>\n";
	print $file "   </Style>\n";

	# Load all portal markers.
	for ( sort keys %portals ) {
		print $file "   <Placemark>\n";
		print $file "     <name>$_</name>\n";
		print $file "     <styleUrl>#Portal</styleUrl>\n";
		print $file "     <Point>\n";
		print $file "       <coordinates>"
		  . $portals{$_}->{'x_cord'} . ","
		  . $portals{$_}->{'y_cord'}
		  . ",0</coordinates>\n";
		print $file "     </Point>\n";
		print $file "   </Placemark>\n";
	}

	for my $source ( sort keys %orders ) {
		for ( @{ $orders{$source} } ) {
			print $file "  <Placemark>\n";
			print $file "    <Snippet></Snippet>\n";
			print $file "    <description><![CDATA[]]></description>\n";

			if ( defined $_->{'player'} && defined $controllers{$source} ) {
				print $file "    <styleUrl>#link"
				  . $controllers{$source}
				  . "</styleUrl>\n";
				print $file "    <name>"
				  . $_->{'player'}
				  . " key link to "
				  . $_->{'target'}
				  . "</name>\n";
			} elsif ( defined $_->{'player'} ) {
				print $file "    <styleUrl>#linknocontroller</styleUrl>\n";
				print $file "    <name>"
				  . $_->{'player'}
				  . " key link to "
				  . $_->{'target'}
				  . "</name>\n";
			} else {
				print $file "    <styleUrl>#linknokey</styleUrl>\n";
				print $file "    <name>Link</name>\n";
			}
			print $file "    <LineString>\n";
			print $file "      <tessellate>1</tessellate>\n";
			print $file "      <coordinates>\n";
			print $file "        "
			  . $portals{$source}->{x_cord} . ","
			  . $portals{$source}->{y_cord} . ",0\n";
			print $file "        "
			  . $portals{ $_->{target} }->{x_cord} . ","
			  . $portals{ $_->{target} }->{y_cord} . ",0\n";
			print $file "      </coordinates>\n";
			print $file "    </LineString>\n";
			print $file "  </Placemark>\n";
		}
	}

	# Close Document
	print $file "</Document>\n";
	print $file "</kml>\n";
	if ($filename) {
		close $file;
	}
	return;
}    ## --- end sub out_kml

sub out_orders {

	# Textual Marching orders output
	my ($filename) = @_;
	my $file = get_output($filename);
	for my $player ( sort keys %players ) {
		print $file "Attack Plan for $player\n";
		print $file "==================================\n\n";
		my $total_links = 0;
		if ( defined( @{ $players{$player}->{'portals'} } ) ) {
			for ( sort @{ $players{$player}->{'portals'} } ) {
				chomp;
				print $file "$_";
				print $file " (" . $portals{$_}->{nick} . ")"
				  if defined $portals{$_}->{nick} && $portals{$_}->{nick} ne "";
				print $file "\n";
				if ( defined( @{ $orders{$_} } ) ) {
					for ( @{ $orders{$_} } ) {
						next unless defined $_->{'player'};
						print $file "  -> " . $_->{'target'};
						print $file " ("
						  . $portals{ $_->{target} }->{nick} . ")"
						  if $portals{ $_->{target} }->{nick} ne "";
						print $file "\n";
						$total_links++;
					}
				} else {
					print $file "  ! No Outgoing Links !\n";
				}
				print $file "\n";
			}
		}
		print $file $total_links . " Total Links\n";
		print $file "Your Key Transfers\n\n";
		for my $reciptient ( sort keys %players ) {
			next if $reciptient eq $player;
			print $file "Keys to transfer to $reciptient\n";
			my %transfers;
			for my $portal ( sort keys %portals ) {
				if ( defined $orders{$portal} ) {
					for ( @{ $orders{$portal} } ) {
						next unless defined $_->{'player'};
						next
						  unless defined $controllers{$portal}
							  && $controllers{$portal} eq $reciptient;
						if ( $player eq $_->{'player'} ) {
							$transfers{ $_->{'target'} } += 1;
						}
					}
				}
			}
			for ( sort keys %transfers ) {
				print $file $transfers{$_} . " X " . $_ . "\n";
			}
			print $file "\n";
		}
	}
	if ($filename) {
		close $file;
	}
	return;
}    ## --- end sub out_orders

sub out_links {

	# Print out the portal names, and the number of outgoing links for each.
	my ($filename) = @_;
	my $file = get_output($filename);
	for ( sort keys %portals ) {
		print $file "$_";
		print $file " (" . $portals{$_}->{nick} . ")"
		  if $portals{$_}->{nick} ne "";
		print $file ",";
		if ( defined( @{ $orders{$_} } ) ) {
			print $file scalar @{ $orders{$_} } . "\n";
		} else {
			print $file "0 \n";
		}
	}
	if ($filename) {
		close $file;
	}
	return;
}    ## --- end sub out_links

sub out_svg {

	# Print the SVG Output
	my ($filename) = @_;
	my $file = get_output($filename);

	my $northmost = 0;
	my $westmost  = 360;
	my $southmost = 100;
	my $eastmost  = -360;
	my $imagesize = 1000;
	my $imgwidth;
	my $imgheight;

	# Calculate the image bounds.
	for my $portal ( keys %portals ) {
		$northmost = $portals{$portal}->{y_cord}
		  if $portals{$portal}->{y_cord} > $northmost;
		$southmost = $portals{$portal}->{y_cord}
		  if $portals{$portal}->{y_cord} < $southmost;
		$eastmost = $portals{$portal}->{x_cord}
		  if $portals{$portal}->{x_cord} > $eastmost;
		$westmost = $portals{$portal}->{x_cord}
		  if $portals{$portal}->{x_cord} < $westmost;
	}

	# Calculate Image size and scaling.
	my $scaley = $imagesize / ( $eastmost - $westmost ) * 1;
	my $scalex = $imagesize / ( $southmost - $northmost ) * -1;
	$imgheight = $scaley * ( $southmost - $northmost ) * -1.02;
	$imgwidth  = $scalex * ( $eastmost - $westmost ) * 1.02;
	my $xoffset = $scalex * ( $eastmost - $westmost ) * 0.01;
	my $yoffset = $scaley * ( $southmost - $northmost ) * -0.01;

	my $svg = SVG->new(
						width  => $imgwidth,
						height => $imgheight,
						style  => { background => 'white' }
					  );

	my $bg = $svg->rectangle(
							  width  => $imgwidth,
							  height => $imgheight,
							  fill   => 'white',
							  id     => 'rect_1'
							);

	# Insert Directional Marker
	my $m = $svg->marker(
						  id           => 'Tri',
						  viewBox      => "0 0 20 20",
						  refX         => "0",
						  refY         => "10",
						  markerUnits  => "strokeWidth",
						  markerWidth  => $imagesize / 300,
						  markerHeight => $imagesize / 300,
						  orient       => "auto",
						);
	$m->tag( 'path', d => "M 0 0 L 20 10 L 0 20 z" );

	# Add a group for each player
	my %groups;
	for my $player ( keys %players ) {
		$groups{$player} = $svg->group(
										id    => "group_$player",
										style => {
											  stroke => '#' . $players{$player},
											  'stroke-width' => '0.5',
											  'marker-mid'   => 'url(#Tri)'
										}
									  );
	}

	# Portals Group
	my $svg_ports = $svg->group(
			id => 'group_y',
			style =>
			  { stroke => 'purple', fill => 'Purple', 'stroke-width' => '0.05' }
	);

	# Add in all the lines with a midpoint for the directional Marker
	my $lineid = 1;
	for my $source ( sort keys %portals ) {
		if ( defined( @{ $orders{$source} } ) ) {
			for ( @{ $orders{$source} } ) {
				next unless defined $_->{'player'};

				my $x1 =
				  ( ( -1 * $westmost ) + $portals{$source}->{x_cord} ) *
				  $scalex + $xoffset;
				my $y1 =
				  ( $northmost - $portals{$source}->{y_cord} ) * $scaley +
				  $yoffset;

				my $x3 =
				  ( ( -1 * $westmost ) + $portals{ $_->{'target'} }->{x_cord} )
				  * $scalex + $xoffset;
				my $y3 =
				  ( $northmost - $portals{ $_->{'target'} }->{y_cord} ) *
				  $scaley + $yoffset;

				my $x2 = $x1 + 0.5 * ( $x3 - $x1 );
				my $y2 = $y1 + 0.5 * ( $y3 - $y1 );

				my $xv = [ $x1, $x2, $x3 ];
				my $yv = [ $y1, $y2, $y3 ];

				my $points =
				  $svg->get_path(
								  x       => $xv,
								  y       => $yv,
								  -type   => 'polyline',
								  -closed => 'true'
								);

				$groups{ $_->{'player'} }->polyline( %$points, id => $lineid, );
				$lineid++;
			}
		}
	}

	# Add in all the portals
	for my $portal ( sort keys %portals ) {
		my $x =
		  ( ( -1 * $westmost ) + $portals{$portal}->{x_cord} ) * $scalex +
		  $xoffset;
		my $y =
		  ( $northmost - $portals{$portal}->{y_cord} ) * $scaley + $yoffset;

		$svg_ports->circle( cx => $x, cy => $y, r => 1, id => $portal );
	}

<<<<<<< HEAD
exit 0;

__END__

=head1 NAME

masterplanner.pl - simplified optimal AP Collecting

=head1 SYNOPSIS

masterplanner.pl [options]

 Options:
   
   -help             Brief help message
   -man              Full Documentation
 
   Output Options:
   -kml              Filename for KML output
   -svg              Filename for SVG output
   -plan             Filename for the Attack Plans report
   -links            Filename for portals and outgoing links report
   -missinglinks     Filename for portals with missing links report
 
  svg options:
   -svg-linescale    Scale factor for link lines
   -svg-xscale       Scale factor for Width
   -svg-yscale       scale factor for height

=head1 OPTIONS

=head2 OUTPUT OPTIONS

One output option must be chosen.

=item B<-kml>

Activates the KML and sets the filename to save it in.  If No filename is provided STDOUT is used instead.  
KML files can be uploaded to Google maps to visually show the link structure, verify the plan and share it with the team.

=item B<-svg>

Activates the svg output and sets the filename to save it in.  If No filename is provided STDOUT is used instead.
SVG files show link directionality, but do not show the map, or portal names.

=item B<-plan>

Activates the attack plan report and sets the filename to save it in.  If No filename is provided STDOUT is used instead.
Plans are the textual easy to follow data output.  It will be individualized per team member and show the source portal,
outgoing links, and all keys the need to be given away, and to whom.

=item B<-links>

Activates the portal links report and sets the filename to save it in.  If No filename is provided STDOUT is used instead.
This shows Each portal and the number of outgoing links from each portal.  Useful for deciding on controllers.

=item B<-missinglinks>

Activates the missing links report and sets the filename to save it in.  If No filename is provided STDOUT is used instead.
This report shows the portals and the number of links that are unfilled.  It's a useful list to help obtain the necessary keys
to maximize available links


=cut
=======
	print $file $svg->xmlify;
	if ($filename) {
	}
	return;
}    ## --- end sub out_svg
>>>>>>> refs/remotes/origin/master
