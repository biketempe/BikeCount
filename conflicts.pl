#!/usr/bin/perl

use strict;
use warnings;

use csv;
use Data::Dumper;

my $volunteers = csv->new('volunteers.csv', 0);

my %training_dates;
my %people_by_training_date;

for my $volunteer ( $volunteers->rows ) {

        my $intersections = $volunteer->intersections or next;
        my @intersections = split m/,/, $intersections or next;
        my %intersection_by_date_shift;

        $training_dates{ $volunteer->training_session }++; 
        $people_by_training_date{ $volunteer->training_session }->{ $volunteer->email_address }++;

        for my $intersection ( @intersections ) {
            my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])([A-Z][a-z]{2})/;
            if( exists $intersection_by_date_shift{ "$ampm$day" } ) {
                print $volunteer->first_name, ' ', $volunteer->last_name, ' ', $volunteer->email_address, " is double booked for $ampm$day: $location_id vs ", $intersection_by_date_shift{ "$ampm$day" }, "\n";
            }
            $intersection_by_date_shift{ "$ampm$day" } = $location_id;
        }

}

print Dumper \%training_dates;

for my $date (keys %people_by_training_date) {
    print "\n---> training date $date\n";
    for my $person ( sort { $a cmp $b } keys %{ $people_by_training_date{$date} } ) {
        print $person, "\n";
    }
}

