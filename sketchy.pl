#!/usr/bin/perl

# report on email addresses of users who generated good data
# these volunteers are invited to register early for the high priority intersections

# the output of this can be imported into the Mailchimp list of count Alumni at https://us4.admin.mailchimp.com/lists/members/?id=181049

use strict;
use warnings;

use csv;
use Data::Dumper;
use String::Approx;

use Data::Dumper;
use IO::Handle;
use Carp;  

use csv;

my $previous = csv->new('2014_post_turk_post_volunteer_entry_checking_post_scotts_sanity_checks_post_cliff_conversion.csv', 0);  # this is the output of the Mechanical Turk process
# my $previous = csv->new('count_data_2013_post_cliff_fixes_extra_data_prune.csv', 0);
# my $previous = csv->new('2011_2012_combined.csv', 0);

my $volunteers = csv->new('volunteers-last-cp.csv', 0);

my %prev_volunteer_names = map { ( $_->Recorder => 1 ) } $previous->rows;

my @sketchy_assignments;

for my $volunteer ( $volunteers->rows ) {
    my @name_parts = grep { defined $_ and length $_ } map $volunteer->{$_}, qw/first_name last_name/;
    if( 2 == @name_parts and $volunteer->email_address ) {
        my $name = join ' ', @name_parts;
        my @matches = String::Approx::amatch($name, keys %prev_volunteer_names);
        if( @matches ) {
            # print "$name matches @matches: email: ", $volunteer->email_address, "\n"; # debug
            # print "$name <" . $volunteer->email_address . ">\n"; # Mailchimp considers this to be a "syntax error" but GMail wants 822 style email addresses except *without* commas seperating them (FFS, get it together people, this is why we invented RFCs)
            print $volunteer->email_address, "\n";   # this is what Mailchimp wants for import
        }
    }
}

