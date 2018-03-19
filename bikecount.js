
function view_current_assignments() {
    $.ajax({
        type: "GET",
        url: "?action=get_assignments&email=" + encodeURIComponent($('#email_address').val())
    }).done(function( html ) {
        $('#current_assignments').html(html);
        $('#current_assignments_popup').html(html);
        $('#assignments').css('display', 'block');
    });
}


function draw_map() {

    var mobile = (/android|webos|iphone|ipad|ipod|blackberry|iemobile|opera mini/i.test(navigator.userAgent.toLowerCase()));

    var map = new OpenLayers.Map("map");

    var fromProjection = new OpenLayers.Projection("EPSG:4326");   // Transform from WGS 1984
    // var toProjection   = map.getProjectionObject(); // new OpenLayers.Projection("EPSG:900913"); // to Spherical Mercator Projection ... that works for positioning hte map but breaks positioning the markers
    var toProjection   = new OpenLayers.Projection("EPSG:900913"); // to Spherical Mercator Projection

    var osm = new OpenLayers.Layer.OSM("OSM Layer", [
        "http://a.tile.opencyclemap.org/cycle/${z}/${x}/${y}.png",
        "http://b.tile.opencyclemap.org/cycle/${z}/${x}/${y}.png",
        "http://c.tile.opencyclemap.org/cycle/${z}/${x}/${y}.png"
    ]);
    map.addLayer(osm);   // addLayer on a scalar, addLayers on an array

    var markers = new OpenLayers.Layer.Markers( "Markers" );
    map.addLayer(markers);

    for( var i=0; i < pois.length; i++ ) {
 
        var lonLat = new OpenLayers.LonLat( pois[i].lon, pois[i].lat ).transform( fromProjection, toProjection );
        var new_marker = new OpenLayers.Marker(lonLat);

        (function() {
            var desc = pois[i].desc;
            var marker_selected = function (ob) {
                if( ! document.getElementById('email_address').value ) {
                    // no email addresss; show an error message
                    document.getElementById('enter_your_email').style.display = 'block';
                } else {

                    // populate the form with the location_id of the selected intersection, and display the name of it to the human
                    document.getElementById('location_id').value = desc;
                    document.getElementById('intersection_name').innerHTML = desc;

                    $('#map_alternative').val( desc ); // select the same thing on the back-up select list below

                    // fetch the part of the form that lists what days the user wouldn't have conflicts for counting that intersection


                    $.ajax({
                        type: "GET",
                        url: "?action=get_times_for_intersection&location_id=" + desc + "&email=" + encodeURIComponent(document.getElementById('email_address').value)
                    }).done(function( html ) {
                        document.getElementById('intersection_options').innerHTML = html;
                        document.getElementById('assignment_details').style.display = 'block';

                        // scroll to the form

                        var viewportHeight = $(window).height(), 
                            targ = $('#assignment_details'),
                            elHeight = targ.height(),
                            elOffset = targ.offset();
                        // $(window).scrollTop( elOffset.top + ( elHeight/2) - (viewportHeight/2));
                        $(window).scrollTop( elOffset.top );

                    });

                } 
            };
            // http://stackoverflow.com/questions/16772597/openlayers-how-to-add-click-and-touch-event-on-markers
            if(mobile) {
                new_marker.events.register( 'touchstart', new_marker, marker_selected );
            } else {
                new_marker.events.register( 'mousedown', new_marker, marker_selected );
            }
        })();
        markers.addMarker(new_marker);

    }

    // from http://opencyclemap.org/?zoom=12&lat=33.39199&lon=-111.93891&layers=B00
    var position = new OpenLayers.LonLat(-111.93891, 33.39199).transform( fromProjection, toProjection);
    var zoom = 12;
    map.setCenter( position, zoom );
}

$( document ).ready(function() {

      (function() {
var divs = document.getElementById('ss-form').
getElementsByTagName('div');
var numDivs = divs.length;
for (var j = 0; j < numDivs; j++) {
if (divs[j].className == 'errorbox-bad') {
divs[j].lastChild.firstChild.lastChild.focus();
return;
}
}
})(); 


    $('#map_alternative').change(function() {
        var desc = $('#map_alternative').val();
        document.getElementById('location_id').value = desc;
        document.getElementById('intersection_name').innerHTML = desc;
        $.ajax({
            type: "GET",
            url: "?action=get_times_for_intersection&location_id=" + encodeURIComponent(desc) + "&email=" + encodeURIComponent(document.getElementById('email_address'))
        }).done(function( html ) {
            document.getElementById('assignment_details').style.display = 'block';
            document.getElementById('intersection_options').innerHTML = html;
        });
    });

    draw_map();

});
