#!/usr/bin/perl

# run with:   /usr/local/bin/corona --E development signup.pl 

# TODO:
# XXX every hit, reload the csv files if they've changed since the last time we've read them -- test this
# XXX detect conflicting assignments (same day, same am/pm) -- run a report at some point to make sure none of these raced in
# XXX let people come back and just view their assignments
# XXX hosting
# XXX notes section with a prompt for food requests
# XXX double check geolocation results

use strict;

use lib 'continuity/lib'; # dev version
use Continuity;
use Continuity::Adapt::PSGI;

use Data::Dumper;
use IO::Handle;
use Text::CSV;
use List::MoreUtils 'zip';
use Cwd;
use JSON::PP;
# use Geo::Coder::RandMcnally; # overlaps most of the intersections
# use Geo::Coder::Geocoder::US;
use Geo::Coder::TomTom;
use XXX;
use Carp;
use HTML::Scrubber;

use repop 'repop';
use csv;
use geo;

$SIG{USR1} = sub {
    Carp::confess $@;
};

open my $log, '>>', 'signup.log' or die $!;
$log->autoflush(1);

sub read_signupform {
    my $fn = shift;
    open my $fh, '<', $fn or die "$fn: $!";
    read $fh, my $signupform, -s $fh;
    close $fh;
    return $signupform;
}

# init volunteers

my $volunteers = csv->new('volunteers.csv', 0);

# init count sites

my $count_sites = csv->new('count_sites.csv', 1);

geo::geocode( $count_sites );

#

my $am_shifts = qq{
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="ATue">Tuesday AM</label></li>
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="AWed">Wednesday AM</label></li>
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="AThu">Thursday AM</label></li>
};

my $pm_shifts = qq{
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="PTue">Tuesday PM</label></li>
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="PWed">Wednesday PM</label></li>
    <li class="ss-choice-item"><label class="ss-choice-label"><input name="shift" class="ss-q-radio" type="radio" value="PThu">Thursday PM</label></li>
};

sub get_pois {

    my $all_flag = shift;

    # get points of interest that haven't yet been (completely) allocated

    my $pending_sites;

    if( $all_flag ) {
        for my $site ( $count_sites->rows ) {
            $pending_sites->{ $site->location_id . 'A' } = $site;
            $pending_sites->{ $site->location_id . 'P' } = $site;
        }
    } else {
        # normal case:  only show what's still available
        $pending_sites = get_pending_sites();
    }


    my @pois = sort { $a->{desc} cmp $b->{desc} } grep { $_->{lat} and $_->{lon} and $_->{desc} } map { 
        {
            lat  => $_->latitude,
            lon  => $_->longitude,
            desc => $_->location_id . ': ' . $_->location_N_S . ' and ' . $_->location_W_E,
            id   => $_->location_id,
        }
    } values %$pending_sites; # $count_sites->rows;
    # warn Data::Dumper::Dumper \@pois;

    return \@pois;
}


sub get_pending_sites {

    # returns a hash of 101A style codes to site records from $count_sites
    # takes an optional location_id argument to restrict results

    my $loc_id = shift;

    my %sites;

    for my $site ( $count_sites->rows ) {
        next if $loc_id and $loc_id ne $site->location_id;
        $sites{ $site->location_id . 'A' } = $site;  # available until found otherwise
        $sites{ $site->location_id . 'P' } = $site;
    }

    # XXX generalize this to use the 'vols_needed' of $count_sites

    my %double_up = (
#        '133A' => 1,
#        '133P' => 1,
#        '111A' => 1,
#        '111P' => 1,
        # '118A' => 1,
        # '118P' => 1,
    );

    for my $volunteer ( $volunteers->rows ) {
        my $intersections = $volunteer->intersections or next;
        my @intersections = split m/,/, $intersections or next;
        for my $intersection ( @intersections ) {
            my( $location_id_ampm ) = $intersection =~ m/(\d+[AP])/;  # ignore any trailing day of the week information
            if( $double_up{ $location_id_ampm } ) {
                $double_up{ $location_id_ampm }--;
             } else {
                delete $sites{ $location_id_ampm };  # taken
            }
        }
    }

    # update unassigned_sites

    if( ! $loc_id ) {
        open my $fh, '>', 'unassigned_locations.txt' or warn $!;

        for my $id (sort { $a cmp $b } keys %sites) {
            my $site = $sites{$id};
            $fh and $fh->print($id, ': ', $site->location_N_S, ' and ', $site->location_W_E, "\n");
        }
    }

    return \%sites;

}

sub get_assignments {

    # returns a textual list of assignments for a given user

    my $email_address = shift or return;

    my $volunteer = $volunteers->find('email_address', $email_address, sub { lc $_[0] } ) or return;

    my $parsed_assignments = '';

    my $intersections = $volunteer->intersections or return;
warn "have intersections: ``$intersections''";
    my @assignments = split m/,/, $intersections or return;
    for my $intersection (@assignments) {
warn "have assignment ``$intersection''";
        my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
warn "searching for location_id ``$location_id''";
        my $site = $count_sites->find('location_id', $location_id);
        $parsed_assignments .= "$day $ampm" .'M ' . $site->location_N_S . ' and ' . $site->location_W_E . " ($location_id)<br>\n";
    }

    return $parsed_assignments;

}

sub update_volunteer_data {

    # save user entered form data

    # XXX should subclass the volunteer records and add this logic there

    my $signup_data = shift;

    my $error;

    my $volunteer = $volunteers->find('email_address', $signup_data->{email_address} );

    if( ! $volunteer ) {
        $volunteer = $volunteers->add;
warn "adding a new volunteer record";
        $volunteer->email_address = $signup_data->{email_address};
    }

    for my $key ( qw/first_name last_name phone_number training_session training_session_comment comments/ ) {
        if( $signup_data->{ $key } ) {
            $volunteer->{ $key } = $signup_data->{ $key };
            $log->print("setting $key = $signup_data->{$key} for user $signup_data->{email}\n");
        }
    }

    if( $signup_data->{location_id} ) {

        # record assignment

        my $assignment = $signup_data->{location_id};
        $log->print("location_id = $assignment for user $signup_data->{email}\n");
        $assignment =~ s{:.*}{};  # comes in the form of eg "101: Hardy and Southern"
        $assignment .= $signup_data->{'shift'};  # of the format 'ATue'
        $log->print("shift = $signup_data->{'shift'} for user $signup_data->{email}\n");
        $assignment =~ m/^\d{3}[AP][A-Z][a-z][a-z]$/ or do {
            warn "bad assignment: ``$assignment''";
            $log->print("ERROR --> bad assignement: ``$assignment''\n");
            return "<br><br>Error:  Pick a location and a shift";
        };
        $log->print("new assignment: $assignment\n");

        my $intersections = $volunteer->intersections;
        $intersections .= ',' if $intersections;
        $intersections .= $assignment;
        $volunteer->intersections = $intersections;

        $error = '<br><br>Count shift recorded -- thanks!';


    }

    $volunteers->write;
    chmod 0640, "volunteers.csv";

    return $error;

}

# start server

my $server = Continuity->new(
    adapter => Continuity::Adapt::PSGI->new( docroot => Cwd::getcwd() ),
    port => 16000,
    path_session => 1,
    debug => 3,
);

my $scrubber = HTML::Scrubber->new;

sub main {
    my $req = shift;

    my $signup_data = { };

    while(1) {

        $count_sites->reload;
        $volunteers->reload;

        my $action = $req->param('action') || 'default';

        my %new_params = $req->params;
        # warn "new params: " . Data::Dumper::Dumper \%new_params;
        for my $new_param (keys %new_params) {
            next if $new_param eq 'action';
            $signup_data->{ $new_param } = $scrubber->scrub( $new_params{ $new_param } );
        }
        $log->print("signup_data: " . Data::Dumper::Dumper $signup_data );

        my $error = update_volunteer_data( $signup_data ) || '' if $signup_data->{email_address} and $action eq 'register';

        if( $action eq 'get_times_for_intersection' ) {
            
            my $location_id = $scrubber->scrub( $req->param('location_id') );
            $location_id =~ s{:.*}{};  # comes in the form of eg "101: Hardy and Southern"

            my $sites = get_pending_sites( $location_id );

            # $req->print(qq{<form id="shift_form">\n});

            exists $sites->{ $location_id . 'A' } and $req->print($am_shifts);

            exists $sites->{ $location_id . 'P' } and $req->print($pm_shifts);

            # $req->print(qq{</form>\n});

        } elsif( $action eq 'get_assignments' ) {

            my $assignments = get_assignments( $signup_data->{email_address} );
            $req->print( $assignments || 'No current assignments for that email address' );

        } else {
  
            my $all = $req->param('all');  # show all intersections, even those that are full?

            my $signupform = read_signupform('signup1.html'); # every time, during dev

            my $html = repop( $signupform, $signup_data );

            my $pois = get_pois( $all );
            my $json_pois = encode_json $pois;
            $html =~ s/POIS/$json_pois/;

# XXX
# convert $pois to $available_intersections
            my $available_intersections = '';
            for my $poi (@$pois) {
                $available_intersections .= qq{
                    <option value="@{[ $poi->{desc} ]}">@{[ $poi->{desc} ]}</option>
                };
            }
            $html =~ s/AVAILABLEINTERSECTIONS/$available_intersections/;

            my $assignments = get_assignments( $signup_data->{email_address} );
            $html =~ s/CURRENT_ASSIGNMENTS/$assignments/;

            my $comments = $signup_data->{comments} || '';
            $html =~ s/COMMENTS/$comments/;

            $html =~ s/ERROR/$error/;

            $req->print( $html );

        }
   
        $req->next; # Get their response to that

    }
}

$server->loop; # has to be last for plack


