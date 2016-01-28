package csv;

use strict;
use warnings;

use XXX;
use Cwd;
use Text::CSV;
use IO::Handle;
use List::MoreUtils 'zip';
use Data::Dumper;

sub new {
    my $package = shift;
    my $fn = shift or die;
    my $header_row_num = shift || 0;
    my $record_class = shift || 'csv::rec';

    my $csv = Text::CSV->new({ binary => 1 }) or die Text::CSV->error_diag;

    my $fh;
    if( ref $fn ) {
        $fh = $fn;  # already a filehandle
        seek $fh, 0, 0;
    } else {
        open $fh, '+<', $fn or die "$fn: $!";
        flock $fh, 2;
        seek $fh, 0, 0;
    }

    my $mod_time = -M $fn;

    my @preheader_data;
    die if $header_row_num < 0;
    my $header_row_num_cp = $header_row_num;
    push @preheader_data, $csv->getline( $fh ) || die "unexpected end of csv data while reading pre-headed data in $fn" while $header_row_num_cp--;  # header is probably row 0 or row 1

    my $header = $csv->getline( $fh ) or die "unexpected end of cvs data:  no header at all, reading $fn";
    for my $i ( 0 .. $#$header ) { $header->[$i] ||=  "column_number_$i" }

    my @rows;

    while ( my $line = $csv->getline( $fh ) ) {
       push @$line, undef while @$line < @$header;
       push @$header, "column_number_" . ( $#$header + 1 ) while @$line > @$header;
       push @rows, bless { zip @$header, @$line }, $record_class;
    }

    bless { 
        rows => \@rows, 
        preheader_data => \@preheader_data, 
        header => $header, 
        header_row_num => $header_row_num, 
        # in_filename => $fn, 
        mod_time => $mod_time,
        record_class => $record_class,
        fh => $fh,
    }, $package;
}

sub reload {
    my $self = shift;

    if( -M $self->{fh} != $self->{mod_time} ) {
        # warn "file changed; reloading; $self->{mod_time} vs " . -M $self->{fh};
        my $new_self = ref($self)->new( $self->{fh}, $self->{header_row_num} );
        for my $k ( keys %$new_self ) {
            $self->{$k} = $new_self->{$k};
        }
        $self->{mod_time} = -M $self->{fh};
    }
    return $self;
}

sub write {
    my $self = shift;
    @_ and die;

    my $fh = $self->{fh};
    my $header = $self->{header};
    my $rows = $self->{rows};

    my $csv = Text::CSV->new({ binary => 1, eol => "\015\012" }) or die Text::CSV->error_diag;

    seek $fh, 0, 0;

    # write the stuff that comes before the header

    for my $row ( @{ $self->{preheader_data} } ) {
        $csv->print( $fh, $row ) or die $!;
    }

    # write the header 

    $csv->print( $fh, $header ) or die $!;

    # write the data

    for my $row ( @$rows ) {
        my @row_data = map { $row->{$_} } @$header;
        $csv->print( $fh, \@row_data ) or die $!;
    }
    $fh->flush;
}

sub find {
    my $self = shift;
    my $field_name = shift;
    my $field_value = shift;
    my $transform = shift() || sub { $_[0] };
    return unless @{ $self->{rows} };
    exists $self->{rows}->[0]->{$field_name} or die "field name ``$field_name'' provided to find not found: " . Data::Dumper::Dumper $self->{rows}->[0];
    my @res = grep { defined $_->{$field_name} and $transform->( $_->{$field_name} ) eq $transform->( $field_value ) } @{ $self->{rows} };
    return unless @res;
    return $res[0];
}

sub add {
    my $self = shift;
    my $header = $self->{header};
    my $rows = $self->{rows};
    my @fill_data = (undef) x $#$header;
    my $new_row = bless { zip @$header, @fill_data }, $self->{record_class};
    push @$rows, $new_row;
    return $new_row;
}

sub rows {
    my $self = shift;
    my $rows = $self->{rows};
    return wantarray ? @$rows : $rows;
}

sub headers {
    my $self = shift;
    return wantarray ? @{ $self->{header} } : $self->{header};
}

sub add_column {
    my $self = shift;
    my $column_name = shift or die;
    die "column already exists" if grep $_ eq $column_name, @{ $self->{header} };
    push @{ $self->{header} }, $column_name;
    for my $row ( @{ $self->{rows} } ) {
        $row->{ $column_name } = undef;
    }
    1;
}

package csv::rec;

sub AUTOLOAD :lvalue {
    my $self = shift;
    my $method = our $AUTOLOAD;
    $method =~ s/.*:://;
    return if $method eq 'DESTROY';
    $self->{$method};
}

1;
