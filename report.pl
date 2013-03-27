#!/usr/bin/perl

use strict;
use warnings;

use csv;
use Data::Dumper;
use String::Approx;

# XXX mail merge function for assignments
# XXX mail merge function for training date
# XXX add a column to 'count_sites.csv' for whether new counters are permitted to take it; make signup.pl honor it by cross-referrencing previous years and limiting what it shows

my $previous = csv->new('vis/2011_2012_combined.csv', 0);

my $volunteers = csv->new('offsite/volunteers.csv', 0);

my $count_sites = csv->new('offsite/count_sites.csv', 1);

#
# list of who has training on which date
# list of who has count shifts on which dates
#

my %people_by_training_date;
my %people_by_shift;

for my $volunteer ( $volunteers->rows ) {

        my $intersections = $volunteer->intersections or next;
        my @intersections = split m/,/, $intersections or next;
        my %intersection_by_date_shift;

        # $training_dates{ $volunteer->training_session }++; 
        $people_by_training_date{ $volunteer->training_session }->{ $volunteer->email_address }++;

        for my $intersection ( @intersections ) {

            my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])([A-Z][a-z]{2})/;

            push @{ $people_by_shift{"$ampm$day"} }, $volunteer;

            if( exists $intersection_by_date_shift{ "$ampm$day" } ) {
                print $volunteer->first_name, ' ', $volunteer->last_name, ' ', $volunteer->email_address, " is double booked for $ampm$day: $location_id vs ", $intersection_by_date_shift{ "$ampm$day" }, "\n";
            }

            $intersection_by_date_shift{ "$ampm$day" } = $location_id;


        }

}

for my $date (keys %people_by_training_date) {
    my $people = $people_by_training_date{$date};
    print "\n---> training date $date: @{[ scalar keys %$people ]} people registered\n";
    for my $person ( sort { $a cmp $b } keys %$people ) {
        print $person, "\n";
    }
}

for my $shift ( qw/ATue PTue AWed PWed AThu PThu/ ) {
    print "\n---> count shift $shift:\n";
    for my $volunteer ( @{ $people_by_shift{$shift} } ) {
        my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
        # print $name, ' ', $volunteer->email_address, "\n";
        print $volunteer->email_address, "\n";
    }
}

#
# find sketchy assignments where a new counter (or one who turned in no data in previous years) is on a high value intersection
#

print "\n---> sketchy assignments\n";

my %prev_volunteer_names = map { ( $_->Recorder => 1 ) } $previous->rows;

my @sketchy_assignments;

for my $volunteer ( $volunteers->rows ) {
    # first_name,last_name,phone_number,email_address,training_session,training_session_comment,intersections,comments
    my $sketchy;
    my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
    if( grep length $_, map $volunteer->{$_}, qw/first_name last_name/ ) {
        my @matches = String::Approx::amatch($name, keys %prev_volunteer_names);
        # print "$name matches: @matches\n";
        @matches or $sketchy = 1;
    } else {
        # print $volunteer->email_address . ": no name!\n";
        $sketchy = 1;
    }
    if( $sketchy ) {
        $name = $volunteer->email_address if $name eq ' ';
        # print "$name: " . $volunteer->intersections . "\n";
        my @intersections = split m/,/, $volunteer->intersections;
        for my $intersection (@intersections) {
            my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
            my $location = $count_sites->find( 'location_id', $location_id );
            push @sketchy_assignments, [ $name, $intersection, $location->priority ];
        }
    }
}

@sketchy_assignments = sort { $b->[2] <=> $a->[2] } @sketchy_assignments;

for my $sketchy_assignment ( @sketchy_assignments ) {
    print map "$_\n", join ' ', map $sketchy_assignment->[$_], 2, 1, 0;
}

print "\n---> sketchy Thursday assignments\n\n";

for my $sketchy_assignment ( @sketchy_assignments ) {
    next unless $sketchy_assignment->[1] =~ m/Thu/;
    print map "$_\n", join ' ', map $sketchy_assignment->[$_], 2, 1, 0;
}

#
# find doubled up count shifts
#

print "\n---> doubled up intersections\n\n";

my %doubled_up;

for my $volunteer ( $volunteers->rows ) {
    # first_name,last_name,phone_number,email_address,training_session,training_session_comment,intersections,comments
    my $sketchy;
    my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
    my $email = $volunteer->email_address;
    my @intersections = split m/,/, $volunteer->intersections;
    for my $intersection (@intersections) {
        my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
        push @{ $doubled_up{"$location_id$ampm"} }, "$day: $name <$email>";
    }
}

for my $doubled_up_intersection ( sort { $a cmp $b } keys %doubled_up ) {
    next unless @{ $doubled_up{ $doubled_up_intersection } } >= 2 or grep $doubled_up_intersection eq $_, qw/136A 136P 115A 115P 111A 111P 133A 133P/;
    print map "$_\n", $doubled_up_intersection . ': ' . join ', ', @{ $doubled_up{ $doubled_up_intersection } };
}


