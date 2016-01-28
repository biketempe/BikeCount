package main;

use Test::More;
use Carp;

use_ok 'csv';

do {

    # test

    $SIG{USR1} = sub { Carp::confess @_; };

    my $test_data = <<'EOF';
"Location ID",Time,Recorder,"Rec Count",Page,Segment,Direction,Count,"Gender ",Age_Y,Age_O,Helmet,"Wrong way",Sidewalk,Distracted,Pedestrian,Motoroized,Electric,Decor/Lights,"ADA Peds","ADA Chairs",Notes,Construction,LocRank,LocRankUniq,Seg,Seg1,LocTime,LocTimeDir,,"Gender ",Age_Y,Age_O,Helmet,"Wrong way",Sidewalk,Distracted,,"Cordon in","Cordon out","Bike Lane Size","Bike Lane"
1101,AM,"Joe (Okie) Oconnor",1,1,1,1,2,,,,2,,,,1,,,,,,,,1,1,1,101_1,101AM,101AMNS,,,,,,,,,,0,0,3,1
2101,AM,"Joe (Okie) Oconnor",1,1,1,2,2,,,,2,,,,1,,,,,,,,1,,1,101_1,101AM,101AMNS,,,,,,,,,,0,0,0,0
3101,AM,"Joe (Okie) Oconnor",1,1,1,3,1,1,,,1,,1,,,,,,,,,,1,,1,101_1,101AM,101AMEW,,,,,,,,,,0,0,3,1
4101,AM,"Joe (Okie) Oconnor",1,1,1,4,2,,,,2,,,,1,,,,,,,,1,,1,101_1,101AM,101AMEW,,,,,,,,,,0,0,0,0
5101,AM,"Joe (Okie) Oconnor",1,1,2,1,5,,,,4,,,,1,,,,,,,,1,,2,101_2,101AM,101AMNS,,,,,,,,,,0,0,3,1
6101,AM,"Joe (Okie) Oconnor",1,1,2,2,1,,,,1,,,,,,,,,,,,1,,2,101_2,101AM,101AMNS,,,,,,,,,,0,0,0,0
7101,AM,"Joe (Okie) Oconnor",1,1,2,3,3,,,,2,,1,,,,,,,,,,1,,2,101_2,101AM,101AMEW,,,,,,,,,,0,0,3,1
8101,AM,"Joe (Okie) Oconnor",1,1,2,4,2,1,,,2,,,,,,,,,,,,1,,2,101_2,101AM,101AMEW,,,,,,,,,,0,0,0,0
9101,AM,"Joe (Okie) Oconnor",1,1,3,1,6,,,,6,1,1,,,,,,,,,,1,,3,101_3,101AM,101AMNS,,,,,,,,,,0,0,3,1
EOF
    open my $fh, '>', '/tmp/test.csv' or die $!;
    $fh->print($test_data);
    close $fh;    

    my $me = csv->new('/tmp/test.csv', 0);
    my $rec = $me->find('Location ID', 2101);
    ok $rec, 'rec found'; 
    # warn Data::Dumper::Dumper $rec;
    is $rec->Time,'AM', 'Time field as expected';
    is $rec->Direction,'2', 'Direction field as expected';
    $rec->Direction = '212';
    is $rec->Direction, '212', 'Updated Direction field as expected';
    $me->write;
    $me = undef;  # needed to release the flock

    $me = csv->new('/tmp/test.csv', 0);
    ok $me, 'Re-read the csv file after write';
    $rec = $me->find('Location ID', 2101);
    # warn "rec after find: " . Data::Dumper::Dumper $rec;
    ok $rec, 'rec found after write'; 
    is $rec->Direction, '212', 'Updated Direction field as expected after write';
    $rec = $me->find('Location ID', 8101);
    is $rec->Direction, '4', 'Not updated Direction field as expected after write';

    $rec = $me->add;
    $rec->{'Location ID'} = 4321;
    $rec->Time = 'PM';
    $rec->Recorder = 'Fred';
    $rec->Sidewalk = 10;
    $me->write;
    $me = undef;

    $me = csv->new('/tmp/test.csv', 0);
    $rec = $me->find('Location ID', 4321);
    ok $rec, "Found newly added rec after write and re-read";
    is $rec->Recorder, 'Fred', "Data in new record is as expected";

    done_testing;
};


1;
