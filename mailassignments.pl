#!/usr/bin/perl

use strict;
use warnings;

use csv;
use Data::Dumper;
use IO::Handle;
use Email::Send::SMTP::Gmail;

my $mail = Email::Send::SMTP::Gmail->new( -smtp=>'smtp.gmail.com',
                                           -login=>'scrottie@biketempe.org',
                                           -pass=>`/home/scott/bin/biketempegmail`) or die;


my $volunteers = csv->new('volunteers.csv', 0);

my $count_sites = csv->new('count_sites.csv', 1);

for my $volunteer ( $volunteers->rows ) {

    my $name = join ' ', $volunteer->first_name, $volunteer->last_name;

    my $intersections = $volunteer->intersections or next;
    my @intersections = split m/,/, $intersections or next;

    my $all_descs = '';

# next unless $volunteer->email_address eq 'scott@slowass.net'; # XXXXXXXXXXXx

    for my $intersection ( @intersections ) {

        my( $location_id, $ampm, $day ) = $intersection =~ m/(\d+)([AP])([A-Z][a-z]{2})/;

        my $location = $count_sites->find( 'location_id', $location_id ) or die;

        my $desc = $location->location_id . $ampm . ': ' . $location->location_N_S . ' and ' . $location->location_W_E . ' on ' . $day . ' ' . $ampm . 'M';
        $all_descs .= $desc . "\n";


    }

   print "emailing " . $volunteer->email_address . "...\n";

#       open my $fh, '-|', '/usr/sbin/sendmail' or die $!;
#       $fh->print('To: ' . $volunteer->email_address . "\n");
#       $fh->print("From: scrottie\@biketempe.org\n");
#       $fh->print("Subject: Your Bike Count shift details\n");
#       $fh->print("\n"); 
#
#       $fh->print(<<EOF);

my $body = <<EOF;

Dear $name,

This is a form email with your bike count shift information.  Please double 
check it and if it isn't what you expect, please contact me to sort it out.

You may download and print out the count sheet from here:

http://azcrap.org/bikecount/2013_count_sheet.pdf

You need two for each shift you have (one sheet per hour, and all shifts are
two hours).  Let me know if you need sheets but can't print them.

We're running behind on some things here.  The volunteer appreciation party
is probably Thursday the 28th, after the last count shift, at 7:30pm.  I'll
send another email when we have confirmation there.

Here are your shifts:

$all_descs

AM shifts are 7-9am.  PM shifts are 4-6pm.

Thanks for being part of the count!

-scott

EOF

    $mail->send( 
        -to => $volunteer->email_address,
        -subject => "Subject: Your Bike Count shift details",
        -body => $body,
    ); # or die; # always dies

#    close $fh;
       
}

$mail->bye;

