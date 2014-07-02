#!/usr/bin/perl

# ssh -v -N -R *:1234:127.0.0.1:1234 -l scott slowass.net    # <-- set up a proxy from slowass.net:1234 to the local machine

use strict;
use warnings;

use Continuity;

use Text::CSV;
# use lib '/home/scott/projects/perl';
use Data::Dumper;
use lib '.';
use repop 'repop';

my $csv_fn = shift() or die "pass csv fn";
my $desired_row_num = shift;

# data entered CSV

my $csv = Text::CSV->new ( { binary => 1 } )  # should set binary attribute.
                or die "Cannot use CSV: ".Text::CSV->error_diag ();

my @rows;
open my $fh, "<:encoding(utf8)", $csv_fn or die "$csv_fn: $!";
my $header_row = $csv->getline( $fh );
my $row;
while ( $row = $csv->getline( $fh ) ) {
    push @rows, $row;
}
$csv->eof or $csv->error_diag();
close $fh;

# header column names to numbers

my %header;
for my $i ( 0 .. $#$header_row ) {
    my $name = $header_row->[$i];
    $header{ $name } = $i;
    if( $name =~ m{^\w+\.} ) {
        # alias without the 'Input.' or 'Answer.' prefix
        $name=~ s{^\w+\.}{};
        $header{ $name } = $i;
    }
}

# HTML entry form

open $fh, '<', 'Sheet1_tidy_amazon.html' or die $!;
read $fh, my $html_entry_sheet, -s $fh;
close $fh;
    
# Continuity

my $server = Continuity->new( port => 1234, );

sub main {
    my $request = shift;
    my $row_num = 0;

    while(1) {

        # handle submitted data

        if( $request->param('submit') ) {
            update_row( $request, $rows[ $row_num ] );
        }

        my $new_row_num = $request->param('row_num');
        $row_num = $new_row_num if defined $new_row_num;

        # redraw the screen

        my $row_num_minus_1 = $row_num - 1;
        my $row_num_plus_1 = $row_num + 1;
        $request->print( scalar(@rows) . " pages.<br>\n" );
        $request->print(qq{ <a href="?row_num=$row_num_minus_1">&lt;&lt; Page $row_num_minus_1</a> }) if $row_num > 0;
        $request->print("Page $row_num");
        $request->print(qq{ <a href="?row_num=$row_num_plus_1">Page $row_num_plus_1 &gt;&gt;</a> }) if $row_num < $#rows;
        $request->print(qq{ <nobr><form method="post">Jump to page <input name="row_num" type="text" size="3"/><input type="submit" value="Go"></form></nobr> });

        show_row( $request, $rows[ $row_num ] );

        # wait for the next request

        $request->next;

    }
}

sub update_row {

    my $request = shift;
    my $row_to_modify = shift;
 
    open my $fh, ">:encoding(utf8)", "$csv_fn.new" or die "$csv_fn.new: $!";

    my $csv = Text::CSV->new( { binary => 1, always_quote => 1, eol => "\015\012"  } ) or die "Cannot use CSV: ".Text::CSV->error_diag(); # without the eol bit, it won't write line endings at all with $csv->print()

    $csv->print( $fh, $header_row ) or die Text::CSV->error_diag();

    # write all of the rows back out again
    # if we see the row that's supposed to be modified, modify it first

    for my $row (@rows) {

        if( $row->[0] eq $row_to_modify->[0] ) {
            $header_row->[0] eq 'HITId' or die; # sanity check; we should be comparing the HITIds to make sure we're editing the exact right one
            my %params = $request->param;
            for my $k (keys %params) {
                next if $k eq 'submit';
                next if $k eq 'row_num';
                next unless defined $k and length $k;  # not sure why we're getting a null key
                exists $header{ $k } or die "no entry for field ``$k'' in " . Data::Dumper::Dumper \%header;
                warn "$row->[ $header{ 'Answer.location_id' } ]: value for ``$k'' (column $header{$k}) changed: was: ``$row->[ $header{ $k } ]'' now: ``$params{$k}''\n" if $row->[ $header{ $k } ] ne $params{$k};
                $row->[ $header{ $k } ] = $params{$k};
            }
        }

        $csv->print( $fh, $row ) or die Text::CSV->error_diag();
    }

    close $fh or die "$csv_fn.new: $!";
    rename "$csv_fn.new", $csv_fn or die "rename to $csv_fn: $!";
    
}

sub show_row {

    my $request = shift;
    my $row = shift;

    $request->print("<pre>HITId: $row->[0]</pre><br>\n");

    my $html = $html_entry_sheet;

    my %values;
    my %inputs;
    for my $i ( 0 .. $#$header_row ) {

        if( $header_row->[$i] =~ m/^Input\./ ) {
            my $input_name = $header_row->[$i];
            $input_name =~ s{^Input\.}{};
            $request->print(qq{<pre>$input_name: $row->[$i]</pre><br>\n});
            # fix things like this in the file:  <p><img width="800" height="600" src="${image_url}" alt="" /></p>
            $html =~ s!\$\{$input_name\}!$row->[$i]!g;
        }

        if( $header_row->[$i] =~ m/^Answer\./ ) {
            my $answer_name = $header_row->[$i];
            $answer_name =~ s{^Answer\.}{};
            $values{ $answer_name } = $row->[$i];
        }

        if( grep $header_row->[$i] eq $_, 'Approve', 'Reject' ) {
            $values{ $header_row->[$i] } = $row->[$i];
        }
    }

    my $extended_html = qq{
        <form method="post">
        Approve:  Place an "x" here if the data entry work needed few or no corrections:  <input type="text" name="Approve" size="1" maxlength="1"/><br>
        Reject: Describe the problems with the data entry work here if it needed more than a couple of corrections: <input type="text" name="Reject" size="80"/><br>
        <input type="submit" name="submit" value="Save Changes"/>
    } . $html . qq{
        </form>
    };

    $request->print( repop( $extended_html, \%values ) );

    
}
    

$server->loop;

