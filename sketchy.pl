#!/usr/bin/perl

# just report on email addresses of users who generated good data; these volunteers are invited to register early for the high priority intersections

use strict;
use warnings;

use csv;
use Data::Dumper;
use String::Approx;

use lib 'continuity/lib'; # dev version
use Continuity;
use Continuity::Adapt::PSGI;

use Data::Dumper;
use IO::Handle;
use Carp;  
use Cwd;

use csv;
use geo;


my $previous = csv->new('count_data_2013_post_cliff_fixes_extra_data_prune.csv', 0);
# my $previous = csv->new('2011_2012_combined.csv', 0);

my $volunteers = csv->new('volunteers.csv', 0);

#
# find sketchy assignments where a new counter (or one who turned in no data in previous years) is on a high value intersection
#

my %prev_volunteer_names = map { ( $_->Recorder => 1 ) } $previous->rows;

my @sketchy_assignments;

for my $volunteer ( $volunteers->rows ) {
    # first_name,last_name,phone_number,email_address,training_session,training_session_comment,intersections,comments
    my $sketchy;
    my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
    if( grep length $_, map $volunteer->{$_}, qw/first_name last_name/ ) {
        my @matches = String::Approx::amatch($name, keys %prev_volunteer_names);
        if( @matches ) {
            print $volunteer->email_address, "\n";
        }
    }
}


# test
