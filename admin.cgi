#!/home/biketempe/bin/perl

#!/usr/bin/perl

use strict;
use warnings;

use CGI;
use CGI::Carp 'fatalsToBrowser';

use lib '/home/biketempe/perl5/lib/perl5/';

use csv;
use Data::Dumper;
use String::Approx;
use Email::Send::SMTP::Gmail;

my @email_config = (
    -smtp=>   'smtp.gmail.com',
    -login=>  'bikecount@biketempe.org',
    -pass => `/home/biketempe/bin/bikecountgmail`,
    'port' =>  25,   # ports 485 (SMTP+SSL) and 587 (SMTP+TSL) are blocked, but 25 is apparently open
    -layer => 'ssl',
);

my $password = 'jennguzy1';

# XXX do an extra sketchy where people sign up and bail on the sign up
# test -- track who signed up since the last assignments email went out

use Data::Dumper;
use IO::Handle;
use Carp;  
use Cwd;

use csv;
use geo;

# my $previous = csv->new('count_data_2013_post_cliff_fixes_extra_data_prune.csv', 0);
my $previous = csv->new('2014_post_turk_post_volunteer_entry_checking_post_scotts_sanity_checks_post_cliff_conversion.csv', 0);

my $volunteers;
my $count_sites;

my %people_by_shift;     # indexed by eg ATue
my %people_by_location;  # indexed by location_id; eg 101A
my %prev_volunteer_names;
my @sketchy_assignments;


sub recompute_stuff {

    %people_by_shift = ();
    %people_by_location = ();
    %prev_volunteer_names = ();
    @sketchy_assignments = ();

    #
    # list of who has count shifts on which dates
    #
    
    for my $volunteer ( $volunteers->rows ) {
    
        my $intersections = $volunteer->intersections or next;
        my @intersections = split m/,/, $intersections or next;
        # my %intersection_by_date_shift;
    
        for my $intersection ( @intersections ) {
    
            my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])([A-Z][a-z]{2})/ or do { warn "bad intersection: $intersection"; next; };
    
            push @{ $people_by_shift{"$ampm$day"} }, $volunteer;
    
            # $intersection_by_date_shift{ "$ampm$day" } = $location_id;
    
        }
    
    }
    
    #
    # find doubled up count shifts
    #
    
    for my $volunteer ( $volunteers->rows ) {
        # first_name,last_name,phone_number,email_address,training_session,training_session_comment,intersections,was_mailed_assignment,comments
        my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
        my $email = $volunteer->email_address;
        $name = $email if $name eq ' ';
        my @intersections = split m/,/, $volunteer->intersections;
        for my $intersection (@intersections) {
            my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
            push @{ $people_by_location{"$location_id$ampm"} }, [ "$day: $name", $email ];
        }
    }
    
    #
    # find sketchy assignments where a new counter (or one who turned in no data in previous years) is on a high value intersection
    #
 
    %prev_volunteer_names = map { ( $_->Recorder => 1 ) } $previous->rows;

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
            my $email = $volunteer->email_address;
            $name = $email if $name eq ' ';
            # print "$name: " . $volunteer->intersections . "\n";
            my @intersections = split m/,/, $volunteer->intersections;
            for my $intersection (@intersections) {
                my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
                my $location = $count_sites->find( 'location_id', $location_id );
                push @sketchy_assignments, [ $name, $intersection, $location->priority, $email ];
            }
        }
    }
    
    @sketchy_assignments = sort { $a->[2] <=> $b->[2] } @sketchy_assignments;

}
    
#
# main
#

do {

    my $given_password = CGI::cookie('password');

    if( $given_password and $given_password eq $password ) {

        if( CGI::param('action') eq 'download_volunteers' ) {
            print "Content-type: text/csv\r\n";
            print "Content-Disposition: attachment; filename=volunteers.csv\r\n";
            print "\r\n";
            system '/bin/cat', 'volunteers.csv';
            exit;
        }

        print "Content-type: text/html\r\n\r\n";
        # fall-through

    } else {

        if( CGI::param('password') eq $password ) {
            print "Content-type: text/html\r\n";
            print "Set-Cookie: " . CGI::cookie( -name => 'password', -value => $password ) . "\r\n";
            print "\r\n";
            # fall-through
        } else {
            print "Content-type: text/html\r\n\r\n";
            print(qq{<form method="post">Password: <input type="text" name="password"><input type="submit"></form>});
            exit;
        }

    }
            
    $volunteers = csv->new('volunteers.csv', 0);
    $count_sites = csv->new('count_sites.csv', 0);

    recompute_stuff();

    my $action = CGI::param('action') || 'default';
    $action = 'person' if CGI::param('person');

    # show a menu
    print( qq{
        <a href="?action=mail_assignments">Email Assignments Out</a><br>
        <a href="?action=assignments_by_location">Assignments by Location</a><br>
        <a href="?action=doubled_up">Assignments With Multiple People On Them</a><br>
        <a href="?action=people_by_training_date">People By Training Date</a><br>
        <a href="?action=sketchy">Sketchy Assignments</a><br>
        <a href="?action=thursday_sketchy">Thursday Sketchy Assignments</a><br>
        <a href="?action=finished_first_shift">When Peoples First Shifts Are</a><br>
        <a href="?action=by_last_name">People By Last Name</a><br>
        <a href="?action=unassigned_locations">Unassigned Locations</a><br>
        <a href="?action=by_priority">Locations By Priority</a><br>
        <a href="?action=download_volunteers">Download volunteers.csv</a><br>
        <hr>
    } );

    # do any actions

    if ( $action eq 'assignments_by_location' ) {

        # assignments by location id

        for my $count_site ( sort { $a->location_id cmp $b->location_id } $count_sites->rows ) {
            next unless $count_site->vols_needed;
            for my $ampm ('A', 'P') {
                my $location_id = $count_site->location_id . $ampm;
                print( map "$_\n", $location_id . ': ' . join ', ', map qq{<a href="?person=$_->[1]">$_->[0]</a>}, @{ $people_by_location{ $location_id } } );
                print("<br>\n");
            }
        }

    } elsif ( $action eq 'unassigned_locations' ) {

        my @pending_shifts = get_pending_shifts();  # we do this after we possibily delete an assignment
        for my $shift ( @pending_shifts ) {
            my( $location_id, $ampm ) = $shift =~ m/(\d+)([AP])/;
            my $loc = $count_sites->find('location_id', $location_id);
            print( $shift, ' ', $loc->location_W_E, ' and ', $loc->location_N_S, "<br>\n" ); 
        }

    } elsif ( $action eq 'by_priority' ) {

        for my $count_site ( sort { $a->priority <=> $b->priority } $count_sites->rows ) {
            next unless $count_site->vols_needed;
            for my $ampm ('A', 'P') {
                my $location_id = $count_site->location_id . $ampm;
                print( map "$_\n", $count_site->priority . ': ' . $location_id . ': ' . join ', ', map qq{<a href="?person=$_->[1]">$_->[0]</a>}, @{ $people_by_location{ $location_id } } );
                print("<br>\n");
            }
        }

    } elsif ( $action eq 'by_last_name' ) {

        for my $volunteer ( sort { $a->last_name cmp $b->last_name } $volunteers->rows ) {
            my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
            my $email = $volunteer->email_address;
            print( qq{<a href="?person=$email">$name $email</a><br>\n} );
                print( qq{<a href="?person=$email">$name &lt;$email&gt;</a><br>\n} );
        }

    } elsif ( $action eq 'person' ) {

        my $email = CGI::param('person');
        my $action2 = CGI::param('action2') || '';
        my $volunteer = $volunteers->find('email_address', $email, sub { lc $_[0] } ) or do { print "utterly failed"; next; }; # for updating

        my @assignments = assignments_per_user( $email );
        my @updated_assignments;

        if ( $action2 eq 'delete_assignment' ) {
            my $assignment = CGI::param('assignment');
            @updated_assignments = grep $_ ne $assignment, @assignments;
            @updated_assignments < @assignments or do {
                print("failed to find the assignment in their list of assignments to remove: $assignment not in @assignments");
                 goto skip_the_subaction;
            };
        } elsif( $action2 eq 'add_assignment' ) {
            my $new_assignment = CGI::param('new_assignment') . CGI::param('day');
            if( ! check_compat_shift( \@assignments, $new_assignment ) ) {
                print("new assignment $new_assignment conflicts with an existing assignment<br>\n");
                goto skip_the_subaction;
            }
            @updated_assignments = ( @assignments, $new_assignment );
        }

        if( $action2 ) {
            $volunteer->intersections = join ',', @updated_assignments;
            $volunteers->write;
            $volunteers->reload;
            # @assignments = assignments_per_user( $email );
            @assignments = @updated_assignments;
        }

        skip_the_subaction:

        my @pending_shifts = get_pending_shifts();  # we do this after we possibily delete an assignment
        print( qq{<form method="post"><input type="hidden" name="action2" value="add_assignment"><select name="new_assignment">} . join('', map qq{<option value="$_">$_</option>}, @pending_shifts) . qq{</select><select name="day"><option>Tue</option><option>Wed</option><option>Thu</Option></select><input type="submit" value="Add"></form><br>\n} );

        for my $field ( split m/,/, "first_name,last_name,phone_number,email_address,training_session,training_session_comment,intersections,was_mailed_assignment,comments" ) {
            print( "$field: ", $volunteer->$field, "<br>\n" );
        }
        print("<br>\n");

        for my $assignment ( @assignments ) {
            # my( $location_id, $ampm, $day, $location_N_S, $location_W_E ) = @$assignment;
            print(qq{<nobr>$assignment&nbsp;<form method="post"><input type="hidden" name="action2" value="delete_assignment"><input type="hidden" name="person" value="$email"><input type="hidden" name="assignment" value="$assignment"><input type="submit" value="delete"></form></nobr><br>\n});
        }


    } elsif ( $action eq 'finished_first_shift' ) {

        # the first shift for each user used to figure out when to contact them and ask them how everything went

        # XXX this should generate and send the "how did it go?" emails

        my %also_had_previous_shift;

        for my $shift ( qw/ATue PTue AWed PWed AThu PThu/ ) {

            print("<br><br>\ncount shift $shift (didn't have a previous shift):<br>\n");
            for my $volunteer ( @{ $people_by_shift{$shift} } ) {
                next if $also_had_previous_shift{ $volunteer->email_address };
                my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
                my $email = $volunteer->email_address;
                print( qq{<a href="?person=$email">$name &lt;$email&gt;</a><br>\n} );
            }

            # print("\n---> count shift $shift (all):<br>\n");
            for my $volunteer ( @{ $people_by_shift{$shift} } ) {
                my $name = join ' ', map $volunteer->{$_}, qw/first_name last_name/;
                # print( $volunteer->email_address, "<br>\n");
                $also_had_previous_shift{ $volunteer->email_address }++;
            }
        
        }

    } elsif ( $action eq 'doubled_up' ) {

#            for my $people_by_location_intersection ( sort { $a cmp $b } keys %people_by_location ) {
#                next unless @{ $people_by_location{ $people_by_location_intersection } } >= 2;
#                # print( map "$_<br>\n", $people_by_location_intersection . ': ' . join ', ', @{ $people_by_location{ $people_by_location_intersection } } );
#                print( map "$people_by_location_intersection: $_<br>\n", join ', ', map qq{<a href="?person=$_->[1]">$_->[0]</a>}, @{ $people_by_location{ $people_by_location_intersection } } );
#            }

        for my $count_site ( sort { $a->location_id cmp $b->location_id } $count_sites->rows ) {
            next unless $count_site->vols_needed;
            for my $ampm ('A', 'P') {
                my $location_id = $count_site->location_id . $ampm;
                next unless $count_site->vols_needed >= 2 or @{ $people_by_location{ $location_id } || [] } >= 2;
                print( map "$_\n", $location_id . ': volunteers needed: ' . $count_site->vols_needed . ': ' . join ', ', map qq{<a href="?person=$_->[1]">$_->[0]</a>}, @{ $people_by_location{ $location_id } } );
                print("<br>\n");
            }
        }

    } elsif ( $action eq 'sketchy' ) {

        for my $sketchy_assignment ( @sketchy_assignments ) {
            # print( map "$_<br>\n", join ' ', map $sketchy_assignment->[$_], 2, 1, 0);
            my( $name, $intersection, $priority, $email ) = @$sketchy_assignment;
            # print( qq{<a href="?person=$email">$name $email $intersection $priority</a><br>\n} );
            print( qq{<a href="?person=$email">$intersection (priority $priority) $name</a><br>\n} );
        }

    } elsif ( $action eq 'thursday_sketchy' ) {

        for my $sketchy_assignment ( @sketchy_assignments ) {
            next unless $sketchy_assignment->[1] =~ m/Thu/;
            my( $name, $intersection, $priority, $email ) = @$sketchy_assignment;
            print( qq{<a href="?person=$email">$intersection (priority $priority) $name</a><br>\n} );
        }

    } elsif ( $action eq 'people_by_training_date' ) {

        my %people_by_training_date;

        for my $volunteer ( $volunteers->rows ) {
            $people_by_training_date{ $volunteer->training_session }->{ $volunteer->email_address } = $volunteer;
        }

        for my $date (keys %people_by_training_date) {
            my $people = $people_by_training_date{$date};
            print( "<br><br>\ntraining date $date: @{[ scalar keys %$people ]} people registered<br>\n");
            for my $person ( sort { $a cmp $b } keys %$people ) {
                my $notes = $people_by_training_date{$date}{$person}->training_session_comment || '';
                $notes = " Comment: $notes" if $notes;
                print( qq{<a href="?person=$person">$person</a>$notes<br>\n} );
            }
        }

    } elsif ( $action eq 'mail_assignments' ) {

        my $action2 = CGI::param('action2') || '';

        if( $action2 eq 'send') {

             my $wording = CGI::param('wording');

             my $mail = Email::Send::SMTP::Gmail->new( @email_config ) or die;

             for my $volunteer ( $volunteers->rows ) {

# unless( lc($volunteer->email_address) eq 'scott@slowass.net' or lc($volunteer->email_address) eq 'jenn@biketempe.org' ) { print("skipping " . $volunteer->email_address ."<br>\n"); next; }; # 

                 next if $volunteer->was_mailed_assignment;

                 my $name = join ' ', $volunteer->first_name, $volunteer->last_name;

                 my $intersections = $volunteer->intersections or next;
                 my @intersections = split m/,/, $intersections or next;

                 my $all_descs = '';


                 for my $intersection ( @intersections ) {

                     my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])([A-Z][a-z]{2})/ or do { warn "bad assignment $intersection for volunteer " . $volunteer->email_address; next; };

                     my $location = $count_sites->find( 'location_id', $location_id ) or do { warn "failed to get a location_id for volunteer " . $volunteer->email_address; next; };

                     $all_descs .= $location->location_id . ': ' . $location->location_N_S . ' and ' . $location->location_W_E . " ${ampm}M shift, $day\n";


                 }

                 print("emailing " . $volunteer->email_address . "...<br>\n");

                 my $body = $wording;
                 $body =~ s{%NAME%}{$name};
                 $body =~ s{%SHIFTS%}{$all_descs};

                 $mail->send( 
                     -to => $volunteer->email_address,
                     -subject => "Your Bike Count shift details",
                     -body => $body,
                 ); # or die; # always dies

                 $volunteer->was_mailed_assignment = scalar time;
                 $volunteers->write;

             }

             print("done.<br>\n");
             $mail->bye;

        } else {

            print(qq{
                 <form method="post">
                 <input type="hidden" name="action" value="mail_assignments">
                 <input type="hidden" name="action2" value="send">
                 <textarea cols="80" rows="30" name="wording">
Dear %NAME%,

This is a form email with your bike count shift information.  Please double 
check it and if it isn't what you expect, please contact us to sort it out.

You may download and print out the count sheet from here:

http://azcrap.org/bikecount/2013_count_sheet.pdf XXX

You need two copies for each shift you have (one sheet per hour, and all shifts
are two hours).  Let me know if you need sheets but can't print them.

The volunteer appreciation party is at XXX.

Here are your shifts:

%SHIFTS%

AM shifts are 7-9am.  PM shifts are 4-6pm.

Thanks for being part of the count!
                 </textarea>
                 <br>
                 <input type="submit" value="Send">  &lt; -- this is the last step before email goes out
                 </form>
             });

        }

    }

};


sub get_pending_shifts {

    # returns a hash of 101A style codes to site records from $count_sites

    my %shifts;

    my %volunteers_needed;

    for my $site ( $count_sites->rows ) {
        next unless $site->vols_needed;
        $shifts{ $site->location_id . 'A' } = $site;  # available until found otherwise
        $shifts{ $site->location_id . 'P' } = $site;
        $volunteers_needed{ $site->location_id . 'A' } = $site->vols_needed;
        $volunteers_needed{ $site->location_id . 'P' } = $site->vols_needed;
    }

    for my $volunteer ( $volunteers->rows ) {
        my $intersections = $volunteer->intersections or next;
        my @intersections = split m/,/, $intersections or next;
        for my $intersection ( @intersections ) {
            my( $location_id_ampm ) = $intersection =~ m/(\d+[AP])/;  # ignore any trailing day of the week information
             delete $shifts{ $location_id_ampm } if $volunteers_needed{ $location_id_ampm }-- <= 1;
        }
    }

    my @shifts = sort { $a cmp $b } keys %shifts;

    return @shifts;

}

sub check_compat_shift {
    my $intersections = shift;
    my $pending_shift = shift;

    my %intersection_by_date_shift;

    for my $intersection ( @$intersections ) {
        my( $location_id, $ampm, $day ) = $intersection =~ m/^(\d+)([AP])([A-Z][a-z]{2})$/ or die $intersection;
        $intersection_by_date_shift{ "$ampm$day" } = $location_id; # not checking here for double booked
    }

    my( $location_id, $ampm, $day ) = $pending_shift =~ m/^(\d+)([AP])([A-Z][a-z]{2})$/ or die $pending_shift;
    return ! $intersection_by_date_shift{ "$ampm$day" };

}

sub assignments_per_user {

    my $email_address = shift or return ();

    my $volunteer = $volunteers->find('email_address', $email_address, sub { lc $_[0] } ) or return ();

    my @assignments;

    my $intersections = $volunteer->intersections or return ();
    for my $intersection ( split m/,/, $intersections ) {
        my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])(.*)/;
        my $site = $count_sites->find('location_id', $location_id);
        # $parsed_assignments .= "$day $ampm" .'M ' . $site->location_N_S . ' and ' . $site->location_W_E . " ($location_id)<br>\n";
        # push @assignments, [ $location_id, $ampm, $day,  $site->location_N_S, $site->location_W_E ];
        push @assignments, "$location_id$ampm$day"; # 128AThu
    }

    @assignments = sort { $a cmp $b } @assignments;

    return @assignments;

}

1;


