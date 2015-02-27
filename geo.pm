
package geo;

use strict;
use warnings;

use Geo::Coder::Geocoder::US;  # seems to do a pretty good job but can't handle the canals and some other things; most stuff was geocoded with this one
use Geo::Coder::Google; # can't do intersections with a freeway to save its life and doesn't know when it has failed; fucks up a lot of small streets too; actually may be failing on everything
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
        next unless $row->longitude and $row->latitude;
        my $location_desc = $row->location_N_S . ' & ' . $row->location_W_E . ', Tempe, AZ';
        $locs{ $row->longitude . '_' . $row->latitude } = $location_desc;
    }

    for my $row ( $count_sites->rows ) {

        next if $row->longitude and $row->latitude;
        # next if $row->automatic_geocoding_failed; # XXX

        next unless $row->location_N_S or $row->location_W_E;
        warn "``" . $row->location_N_S . "'' ``" . $row->location_W_E . "''";
        # my $location_desc = $row->location_N_S . ' & ' . $row->location_W_E . ', Tempe, AZ';
        my $location_desc = ( $row->location_N_S and $row->location_W_E ) ? $row->location_N_S . ' & ' . $row->location_W_E : $row->location_N_S . $row->location_W_E;
        $location_desc .= ', Tempe, AZ'; # XXX hard-code

        # my $geocoder = Geo::Coder::RandMcnally->new;
        # my $geocoder = Geo::Coder::Geocoder::US->new;
        # my $geocoder = Geo::Coder::Google->new;
        my $geocoder = Geo::Coder::TomTom->new;

        my $location = $geocoder->geocode(
            location => $location_desc,
        );

        if( $location and ! $location->{error} ) {
            $row->longitude = $location->{lon} || $location->{long} || $location->{longitude} || $location->{geometry}->{location}->{lng} or die Data::Dumper::Dumper $location;
            $row->latitude = $location->{lat} || $location->{latitude} || $location->{geometry}->{location}->{lat} or die Data::Dumper::Dumper $location;
  
            $row->automatic_geocoding_failed = 0;
            warn "long/lat = " . $row->longitude . ', ' . $row->latitude;
            $locs{ $row->latitude . '_' . $row->longtide } = $location_desc;
            if( my $previous = $locs{ $row->longitude . '_' . $row->latitude } ) {
               warn "duplicate lon/lat of previous ``$previous'' at ``$location_desc''";
               $row->longitude = '';
               $row->latitude= '';
               $row->automatic_geocoding_failed = 1;
               next;
            }
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
