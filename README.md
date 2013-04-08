## NAME
masterplanner

## SYNOPSIS
masterplanner.pl datafile.csv > linkMap.kml

## DESCRIPTION
masterplanner.pl is a simple script that will work from a list of portals 
players, and key counts to build graphical, and textual representation of what
links can be created and by whom.

Currently the CSV file is in the format.

GPS Coords, Ignore, Portal Name, Portal Nickname, P1, P2, P3, etc...
,,,,P1colour, P2colour, P2colour, etc...
"-120.123456, 50.123456", No, Sclupture, The Eagle, 3, 6, 1
etc...

The script csvbuilder.pl will take portal information from an existing KML file
and return the first 3 columns for the csv.

The program will also output a mesh.svg file and a orders.txt file.

mesh.svg is a simple svg file that shows links to be created in the player 
colour with a directional marker. No text or background map information is 
used, so familiarity with the area is required.

orders.txt is a textual representation of the data useful to print or have on
hand as field notes.
