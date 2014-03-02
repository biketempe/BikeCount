IT goop for Tempe Bicycle Action Group's annual Bike Count online signup form
as written for the 2013 count and modified for the 2014 count.

We conduct a bike count during the middle of a week in late March or early April
each year.  Volunteers pick up to six possible shifts:  AM and/or PM shifts
from Tuesday through Thursday.  They also pick the locations to count at.

This software records volunteers basic information as well as their shift
and location selections.  It attempts to keep them from picking conflicting
shifts (for example, they can only pick one Tuesday AM shift).  In cases where
two people are needed to work as a team to count a busy intersection, it
allows two people to sign up, and the second person is restricted to only
singing up on the same day that the first person already chose.

Also included is a management user interface for re-assigning shifts,
sending out assignment confirmations, and viewing various reports.

It also now sends an email to the bikecount@ mailbox every time someone adds
an intersection, including with any comments and other fields they've filled
in.

This software is not easily configurable.  Significant work is needed to
make it generally useful for bike counts in other cities.

Run it with this command:

    perl signup.pl 

Then connect to http://hostname:5000.

Ideally, you would run nginx or something similar to proxy requests from a URL at 
http://hostname to http://hostname:5000.

This requires perl and these CPAN packages:

Continuty  (currently the development version from http://github.com/scrottie/continuity)
String::Approx
Email::Send::SMTP::Gmail
Geo::Coder::Geocoder::US
Geo::Coder::Google
Geo::Coder::RandMcnally
Geo::Coder::TomTom
HTML::Scrubber
JSON::PP
Pod::Usage
Spreadsheet::ParseExcel
String::Approx
Text::CSV
XXX

It reads and writes count_sites.csv, volunteers.csv, and unassigned_locations.txt.
count_sites.csv gets longitude,latitude fields set from the location_W_E,location_N_S fields.
Geocoding currently hard-codes in "Tempe, AZ".

It's necessary to double check the map of locations to make sure that geocoding was correct
and then open count_sites.csv (with a text editor or spreadsheet program) to correct the
longitude and latitude if not.  Pinpointing a location with opencyclemap.org or Google
Maps will put the lat/lon in the "permalink" URL.  All of the geocoder services are
horrible, including Google, which attempts to find businesses with "Broadway" or
"McClintock" in their name when you look for "Broadway Rd and McClintock Rd", finding
many.  Other geocoders fail and return a default location (their idea of the center of
Tempe) rather than an error code.

unassigned_locations.txt gets re-written after each signup to contain the list of locations
that no one has signed up for yet.  This is redundant with one of the management interface
reports.

volunteers.csv gets rewritten after each signup to include the entered form data including
intersections signed up for, with one row per unique email address.

Admin:

Run this:

    perl report.pl

Then connect to hostname:16000.  The password is current hard-coded into the app.

Functions:

Email Assignments Out -- Edit a message to send to newly signed up volunteers and then send it.
The same volunteer won't be mailed twice, only new volunteers will get the message.

Assignments by Location -- Lists all locations and shifts along with whoever (if anyone)
is assigned to them.

Assignments With Multiple People On Them -- Lists all of the locations that specify that
they need two or more counters, and lists all of the counters assigned there (which may
be zero).  It lists things that should have multiple people on them regardless of whether
they actually do.

People By Training Date -- Lists people expected at each training date for the purpose of
figuring out how much pizza to order.  Also lists people by shift (Tues AM, Tues PM, Wed AM,
etc).

Sketchy Assignments -- Lists assignments to people who either were not volunteers last year or
else did not produce good working data (count sheets rejected due to strangeness or not turned
ever turned in).  This references the data from the previous year after it is entered.  The
logic is that if someone turned in their sheet last year and it was good enough to use, then
we can trust them this year with the higest priority intersections.  "Sketchy" (new) people
on high priority intersections perhaps should be contacted and re-assigned elsewhere.

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

People By Last Name -- To quickly find people by name for the purpose of
editing their assignments.

Unassigned Locations -- A list of shifts ( location + AM or PM ) that no volunteer has yet
signed up for.

Emailing assignments won't send assignments to the same person twice.  There's
a new field in volunteers.csv that keeps track of when/if their assignments
were mailed to them.  Clear out the was_mailed_assignment field in volunteers.csv
to re-send the confirmation email.

Emailing assignments also lets you edit the wording before it goes out now. 
It's a two step process now.

The "extra sketchy" report is still on my todo list.

"Assignments With Multiple People On Them" is keyed off of a vols_needed field
in the count_sites.csv, by the way.  It lists things that should have multiple
people on them regardless of whether they actually do.

There's now a report by priority: 
http://slowass.net:16000/?action=by_priority
