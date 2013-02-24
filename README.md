IT goop for Tempe Bicycle Action Group's annual Bike Count as written for the 2013 count.

Includes a Plack app that listens on port 5000 accepting public signups.

It reads and writes count_sites.csv, volunteers.csv, and unassigned_locations.txt.
count_sites.csv gets longitude,latitude fields set from the location_W_E,location_N_S fields.
Geocoding hard-codes in "Tempe, AZ".
It's necessary to double check the map of locations to make sure that geocoding was correct
and then open count_sites.csv (with a text editor or spreadsheet program) to correct the
longitude and latitude if not.  Pinpointing a location with opencyclemap.org or Google
Maps will put the lat/lon in the "permalink" URL.
unassigned_locations.txt gets re-written after each signup to contain the list of locations
that no one has signed up for yet.
volunteers.csv gets rewritten after each signup to include the entered form data including
intersections signed up for, with one row per unique email address.
