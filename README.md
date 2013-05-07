## NAME
masterplanner

## SYNOPSIS
masterplanner.pl datafile.csv > linkMap.kml

## DESCRIPTION

masterplanner.pl is a simple script that will work from a list of portals 
players, and key counts to build graphical, and textual representation of what
links can be created and by whom.

Currently the CSV file is in the format.

    GPS Coords, Ignore, Controler, Portal Name, Nick Name, Total, Player 1, Player 2, etc...
    ,,,,,,P1colour, P2colour, P2colour, etc...
    "-120.123456, 50.123456", No, Hegz, Sclupture, The Eagle, 10, 3, 6, 1
    etc...

The script csvbuilder.pl will take portal information from an existing KML file
and return the first 3 columns for the csv.

The program will output :
 * KML to STDOUT -- a map that can be viewed in google earth of the best links, and who should make those links.
 * mesh.svg      -- a svg output of the links, colour coded, and with directional arrows.
 * orders.txt    -- per player breakdown of what should be linked to where, and who to transfer keys to.
 * missing\_links.txt  -- Portals and the number of missing keys.
 * portal\_links.txt  -- The number of outgoing links per portal.

mesh.svg is a simple svg file that shows links to be created in the player 
colour with a directional marker. No text or background map information is 
used, so familiarity with the area is required.

orders.txt is a textual representation of the data useful to print or have on
hand as field notes.
