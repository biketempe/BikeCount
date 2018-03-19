IT goop for Tempe Bicycle Action Group's annual Bike Count online signup form
as written for the 2013 count and modified for the 2014 count (and then
2015, 2016, and 2017).

# Background

This software is licensed under the GNU GPL v2 license; see below for details.

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

Admin functions are available for sending emails to groups of volunteers by
shift time, used to follow-up after their shift, and groups of volunteers
by training count date (useful to remind them to go to training).

This software is not easily configurable.  Significant work is needed to
make it generally useful for bike counts in other cities.

# File Overview

The signup app reads and writes `count_sites.csv` and `volunteers.csv`.
It also reads `min_priority.txt` and `signup2.html`.
It writes `unassigned_locations.txt` on each access.

# Output Files

`unassigned_locations.txt` gets re-written after each signup to contain the list of locations
that no one has signed up for yet.  This is redundant with one of the management interface
reports but is useful for linking directly to without needing an admin signin.

`volunteers.csv` gets rewritten after each signup to include the entered form data including
intersections signed up for, with one row per unique email address.

# Configuration

The admin sets `min_priority.txt` to control the lowest number for
`priority` to make available to people.  As high priority intersections fill (perhaps in
pre-registration events sent to count alumni who have previously turned in good data),
more can be made available.

Higher number of `priority` are higher priority.  Eg, 178 is higher priority than 3.
Cliff's worksheet does the opposite, so I reverse them with a formula:  `=max(E2:E65535)-E2`.
Saving a csv file should save the result of the formula, not the formula itself.

To make changes for each year, edit the `signup2.html` template and change
wording in the HTML.  The training dates have HTML inputs that look like
`<input value="">`.  The value fields get recorded and shown
in the admin, so make sure to edit those when editing the text of the
training date.

Each year, you'll need to edit `volunteers.csv` and delete all of the
previous year's data, which is everything except for the very first line
of the file.  The very first line is the header line.

## count_sites.csv

`count_sites.csv` powers the signup app.

Each year, you'll want to review `count_sites.csv`.  Before signup can
show them on the map, the `latitude` and `longitude` columns need to be filled in.
The `geocode_count_sites.pl` can help with that but double-check
the results as they are often wrong.  Geocoding is done based on
`location_W_E,location_N_S` columns which should give intersecting
streets.
Geocoding currently hard-codes in "Tempe, AZ".

All of the geocoder services are
horrible, including Google, which attempts to find businesses with "Broadway" or
"McClintock" in their name when you look for "Broadway Rd and McClintock Rd", finding
many.  Other geocoders fail and return a default location (their idea of the center of
Tempe) rather than an error code.

If geocoding was incorrect,
then open `count_sites.csv` (with a text editor or spreadsheet program) to correct the
longitude and latitude.  Pinpointing a location with opencyclemap.org or Google
Maps will put the lat/lon in the "permalink" URL.  

`num_volunteers` is how many
people the signup app will try to assign to an intersection.  They
will always be assigned on the same day.  Whoever first signs up
for that shift sets the day that subsequent volunteers can sign up
for it when there are more than one volunteers needed.  The ID must
be numeric and three digits.

# Installation

It runs as a CGI script against perl 5.20 or newer.

To install, it requires perl and these CPAN packages:

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

# Admin

The admin is `admin.cgi`.  The password is hard-coded.  Change it for your deployment.

Admin Functions:

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
This requires files beyond what are outlined above.
Sorry, the process of processing count sheets and managing lists of volunteers isn't documented,
but we were doing String::Aprox matching on name against the previous year's count data.

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

"Assignments With Multiple People On Them" is keyed off of a vols_needed field
in the count_sites.csv, by the way.  It lists things that should have multiple
people on them regardless of whether they actually do.

# License

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
