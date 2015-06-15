#!/home/biketempe/bin/perl
#!/usr/bin/perl

BEGIN {
    print "Content-type: text/html\r\n\r\n";
    close STDERR;
    open STDERR, '>>', 'repop.log' or die $!;
};

use strict;
use warnings;

use lib '/home/biketempe/perl5/lib/perl5/'; # I have no idea... cpanm is putting things there on the dreamhost machine

use CGI;
use CGI::Carp 'fatalsToBrowser';

use Text::CSV;
# use lib '/home/scott/projects/perl';
use Data::Dumper;
use lib '.', '..';
use repop 'repop';
use csv;

# config

my $csv_fn = '2015_Batch.csv';

#

my $count_data = csv->new($csv_fn);

# header column names to numbers

my $header_row = $count_data->{header} or die;

my %header;
for my $i ( 0 .. $#$header_row ) {
    $header{ $header_row->[$i] } = '0e0';  # for a quick existance check
}

$header_row->[0] eq 'HITId' or die;  # sanity

# HTML entry form

open my $fh, '<', 'Sheet1_tidy_amazon.html' or die $!;
read $fh, my $html_entry_sheet, -s $fh;
close $fh;
    
my $request = CGI->new;

# handle submitted data

if( $request->param('submit') ) {
    # hopefully row_num and HITId
    my $hit_id = $request->param('HITId') or die "not HITId posted in update";
    (my $row) = $count_data->find(HITId => $hit_id) or die "row not found";
    update_row( $request, $row );
}

# redraw the screen

my $row_num = $request->param('row_num');
$row_num = 0 if ! defined $row_num;  # hopefully only happens on view, not submit

my $row_num_minus_1 = $row_num - 1;
my $row_num_plus_1 = $row_num + 1;
print( scalar( @{ $count_data->rows } ) . " pages.<br>\n" );
print(qq{ <a href="?row_num=$row_num_minus_1">&lt;&lt; Page $row_num_minus_1</a> }) if $row_num > 0;
print("Page $row_num");
print(qq{ <a href="?row_num=$row_num_plus_1">Page $row_num_plus_1 &gt;&gt;</a> }) if $row_num < @{ $count_data->rows };
print(qq{ <nobr><form method="get">Jump to page <input name="row_num" type="text" size="3"/><input type="submit" value="Go"></form></nobr> });

show_row( $request, $count_data->rows->[ $row_num ], $row_num );

#
# subroutines 
#

sub update_row {

    my $request = shift;
    my $row_to_modify = shift;
 
    my @params = $request->param;

    if( grep $_ eq 'location_id', @params ) {
        # if they're posting location_id (not essential but helpful), make it first, so that diagnostic output is more coherent
        @params = ('location_id', grep $_ ne 'location_id', @params);
    };

    for my $k (@params) {
        next if $k eq 'submit';
        next if $k eq 'row_num';
        next unless defined $k and length $k;  # not sure why we're getting a null key
        next if $k eq '/'; # not sure why that's happening; browser isn't posting it; but that was almost certainly a Continuity thing
        exists $header{ $k } or do { warn "no entry for field ``$k'' in " . Data::Dumper::Dumper \%header; next; };
        if($row_to_modify->{$k} ne $request->param($k)) {
            warn $row_to_modify->location_id . ": value for ``$k'' changed: was: ``@{[ $row_to_modify->{$k} ]}'' now: ``@{[ $request->param($k) ]}''\n";
            $row_to_modify->{$k} = $request->param($k);
        }
    }

    $count_data->write;

}

sub show_row {

    my $request = shift;
    my $row = shift;
    my $row_num = shift;

    print("<pre>HITId: $row->{HITId}</pre><br>\n");

    my $html = $html_entry_sheet;

    # fix things in the file that aren't input tag values, like this:  <p><img width="800" height="600" src="${image_url}" alt="" /></p>

    $html =~ s!\$\{(\w+)\}! $row->{$1} !ges;

    my $extended_html = qq{
        <form method="post">
<!--
    ... starting with entry here rather than from Amazon, so there is no approve/reject process
        Approve:  Place an "x" here if the data entry work needed few or no corrections:  <input type="text" name="Approve" size="1" maxlength="1"/><br>
        Reject: Describe the problems with the data entry work here if it needed more than a couple of corrections: <input type="text" name="Reject" size="80"/><br>
  -->
        <input type="submit" name="submit" value="Save Changes"/>
        <input type="hidden" name="HITId" value="$row->{HITId}"/>
        <input type="hidden" name="row_num" value="$row_num"/>
    } . $html . qq{
        </form>
    };

    print( repop( $extended_html, $row ) );  # slightly abusive; $row is a blessed hashref of key/value pairs; just using it as a hashref
    
}
    

