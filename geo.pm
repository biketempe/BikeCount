
package geo;

use strict;
use warnings;

# use Geo::Coder::RandMcnally; # overlaps most of the intersections; sucks
# use Geo::Coder::Geocoder::US;  # seems to do a pretty good job but can't handle the canals and some other things; most stuff was geocoded with this one
use Geo::Coder::TomTom; 

sub geocode {

    my $count_sites = shift;

    # geocode

    if( ! grep $_ eq 'longitude', @{ $count_sites->headers } ) {
        $count_sites->add_column('longitude');
        $count_sites->add_column('latitude');
    }

    if( ! grep $_ eq 'automatic_geocoding_failed', @{ $count_sites->headers } ) {
        $count_sites->add_column('automatic_geocoding_failed');
    }

    if( ! grep $_ eq 'geocoded_by', @{ $count_sites->headers } ) {
        $count_sites->add_column('geocoded_by');
    }

    # note existing long/lats so we can catch things defaulting

    my %locs;
    for my $row ( $count_sites->rows ) {
        next if $row->longitude and $row->latitude;
        my $location_desc = $row->location_N_S . ' & ' . $row->location_W_E . ', Tempe, AZ';
        $locs{ $row->longitude . '_' . $row->latitude } = $location_desc;
    }

    for my $row ( $count_sites->rows ) {

        next if $row->longitude and $row->latitude;
        # next if $row->automatic_geocoding_failed; # XXX

        # my $geocoder = Geo::Coder::RandMcnally->new;
        # my $geocoder = Geo::Coder::Geocoder::US->new;
        # my $geocoder = Geo::Coder::Geocoder::US->new;
        my $geocoder = Geo::Coder::TomTom->new;

        my $location_desc = $row->location_N_S . ' & ' . $row->location_W_E . ', Tempe, AZ';

        my $location = $geocoder->geocode(
            location => $location_desc,
        );

        if( $location and ! $location->{error} ) {
            $row->longitude = $location->{lon} || $location->{long} || $location->{longitude} or die Data::Dumper::Dumper $location;
            $row->latitude = $location->{lat} || $location->{latitude} or die Data::Dumper::Dumper $location;
            $row->automatic_geocoding_failed = 0;
            warn "long/lat = " . $row->longitude . ', ' . $row->latitude;
            if( my $previous = $locs{ $row->longitude . '_' . $row->latitude } ) {
               warn "duplicate lon/lat of previous ``$previous'' at ``$location_desc''";
               $row->longitude = '';
               $row->latitude= '';
               $row->automatic_geocoding_failed = 1;
               next;
            }
            $locs{ $location->{lat} . '_' . $location->{lon} } = $location_desc;
            $row->geocoded_by = ref $geocoder;
        } else {
            warn $location->{error} if $location->{error};
            $row->automatic_geocoding_failed = 1;
            warn "failed to geolocate ``$location_desc''";
        }
        sleep 1;
    }

    $count_sites->write;

}

sub check_for_dups {
    my $count_sites = shift;
    # check for duplicates
    #my %locs;
    #for my $poi (@pois) {
    #    $locs{ $poi->{lat} . '_' . $poi->{lon} }++;
    #}
    # warn Data::Dumper::Dumper \%locs;
    die;
}

1;
