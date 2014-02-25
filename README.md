IT goop for Tempe Bicycle Action Group's annual Bike Count as written for the 2013 count.

Includes a Plack app that listens on port 5000 accepting public signups.

Run it with this command:

perl signup.pl 

This requires perl, the 'Continuty' CPAN package, 

It reads and writes count_sites.csv, volunteers.csv, and unassigned_locations.txt.
count_sites.csv gets longitude,latitude fields set from the location_W_E,location_N_S fields.
Geocoding currently hard-codes in "Tempe, AZ".
It's necessary to double check the map of locations to make sure that geocoding was correct
and then open count_sites.csv (with a text editor or spreadsheet program) to correct the
longitude and latitude if not.  Pinpointing a location with opencyclemap.org or Google
Maps will put the lat/lon in the "permalink" URL.

unassigned_locations.txt gets re-written after each signup to contain the list of locations
that no one has signed up for yet.

volunteers.csv gets rewritten after each signup to include the entered form data including
intersections signed up for, with one row per unique email address.

Admin:

XXX how to get in to it

XXX how to set the password

Functions:

Email Assignments Out -- Edit a message to send to newly signed up volunteers and then send it.
The same volunteer won't be mailed twice, only new volunteers will get the message.

Assignments by Location -- Lists all locations and shifts along with whoever (if anyone)
is assigned to them.

Assignments With Multiple People On Them -- Lists all of the locations that specify that
they need two or more counters, and lists all of the counters assigned there (which may
be zero).

People By Training Date -- Lists people expected at each training date for the purpose of
figuring out how much pizza to order.  Also lists people by shift (Tues AM, Tues PM, Wed AM,
etc).

Sketchy Assignments -- Lists assignments to people who either were not volunteers last year or
else did not produce good working data (count sheets rejected due to strangeness or not turned
ever turned in).

Thursday Sketchy Assignments -- Lists assignments for counters who didn't produce usable data
last year (didn't volunteer, didn't turn sheets in, etc) as above, but only those who have
Thursday assignments.  If a counter misses a Tues or Wed assignment, another volunteer might
be able to pick it up on Wed or Thurs, but if a counter misses a Thurs shift, it cannot be
picked up.  Ideally, no new or untrusted counters would count important intersections on
Thursday.

When Peoples First Shifts Are -- Reports email addresses by each counter's first shift.
If they only have one count shift, it lists their only shift.  If they have multiple, it
lists only their first.  This is useful for contacting counters immediately after their
shift to verify that everything went okay and that they made it there.  If a counter does
not respond, they likely missed their shift and a spare volunteer should perhaps be
asked to cover that intersection on the next day.  Usually when people count an intersection,
they're more than happy to email back and talk about it.

People By Last Name -- To quickly find people by name for the purpose of editing their assignments.

Unassigned Locations -- A list of shifts ( location + AM or PM ) that no volunteer has yet
signed up for.

