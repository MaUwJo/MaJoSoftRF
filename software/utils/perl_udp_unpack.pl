#!/usr/bin/perl -w
use strict;
use warnings;
use Date::Format;
use DBI;
my $dbh = DBI->connect('dbi:mysql:dbname=dnmdfndbfasdmn;host=mysqXX.1blu.de','jhjhjhjjhjkjk','sdsdsdsds',{AutoCommit=>1,RaiseError=>1,PrintError=>0});
my $init =1 ;
use IO::Socket;
my $filename = '/home/markus//hack/softrf/nmea_log.txt';

#&remove_and_create_tables();
#&GETfromFile();
&GETfromUDP();


sub GETfromUDP {
my($sock, $oldmsg, $newmsg, $hisaddr, $hishost, $MAXLEN, $PORTNO);
$MAXLEN = 1024;
$PORTNO = 10110;
$sock = IO::Socket::INET->new(LocalPort => $PORTNO, Proto => 'udp')
    or die "socket: $@";
print "Awaiting UDP messages on port $PORTNO\n";
open(my $fh, '>>:encoding(UTF-8)', $filename);

while ($sock->recv($newmsg, $MAXLEN)) {
    my($port, $ipaddr) = sockaddr_in($sock->peername);
    $hishost = gethostbyaddr($ipaddr, AF_INET);
    my $row =  $hishost .  " " . $newmsg ;
    print $row;
    &process_line($row);
    print $fh $row;
}
}


sub GETfromFile {
if (open(my $fh, '<:encoding(UTF-8)', $filename)) {
  while (my $row = <$fh>) {
    &process_line($row)
  }
  } else {
    warn "Could not open file '$filename' $!";
  }
}

sub process_line {
  my    $row = $_[0];
    chomp $row;
	my @values = split(',', $row);
	if ($values[0] =~ /PSRFI/ )
	{
    my $RFDBI = $values[3];
    my $formatted_time = time2str("%c", $values[1]) ;

	 my( @hex ) = unpack( '(A2)*', $values[2] );
 	 my( $newencoded ) = pack( '(H2)*', @hex );

	 my $ExtendedHeader =   ( hex($hex[0])  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,
     my $Forward        =    ( hex($hex[0])  >> 6 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 6.,
     my $Type           =    ( hex($hex[0])  >> 0 ) & ( 1 << 5 ) - 1;  # 5 bit  starting at bit 0.,
     my $Manufacturer   =    $hex[1];
     my $UniqueID       =    $hex[3].$hex[2];
     if ($Type != 8){
     ##debug filter
  #   next;
   }
     my $startmsg       =   4;
      print "RFDBI          $RFDBI
formatted_time $formatted_time
@hex
ExtendedHeader = $ExtendedHeader
Forward        = $Forward
Type           = $Type
Manufacturer   = $Manufacturer
UniqueID       = $UniqueID
";
$dbh->do('INSERT INTO FANET_Header
(Manufacturer, UniqueID, Forward, `Type`, ExtendedHeader, DBI, received_by, Original, `Timestamp`)
VALUES(?, ?, ?, ?, ?, ?, ?, ?, FROM_UNIXTIME(?))', undef, $Manufacturer, $UniqueID, $Forward, $Type, $ExtendedHeader, $RFDBI, $values[0], $values[2], $values[1]);
my $id = $dbh->last_insert_id( undef, undef, undef, undef );
print("$id\n");

      if ($ExtendedHeader == 1){
         my $ExtendedHeaderACK = hex(join('',reverse(@hex[$startmsg+0 .. $startmsg+1]) )   );
         my $ExtendedHeaderCast = $hex[$startmsg+2];
         my $ExtendedHeaderSignatureBit;
         my $ExtendedHeaderGeobasedForwarded;
         my $startmsg = 5;
         if ($ExtendedHeaderCast == 1){
            my $ExtendedHeaderCastDestinationManufacturer;
            my $ExtendedHeaderCastDestinationUniqueID;
            my $startmsg = 8;
         }
         if ($ExtendedHeaderSignatureBit == 1){
            my $ExtendedHeaderSignature;
            my $startmsg += 3 ;
         }
          }


elsif ($Type==1) {
	#splice my @slice = @rainbow[0 .. $#rainbow - 5];
     my $Latitude        = hex(join('',reverse(@hex[$startmsg+0 .. $startmsg+2]) )   )/93206;
     my $Longitude       = hex(join('',reverse(@hex[$startmsg+3 .. $startmsg+5]) )   )/46603;
	 my $Type1_Type      = hex(join('',reverse(@hex[$startmsg+6 .. $startmsg+7]) )   );
	 my $OnlineTracking  = ( $Type1_Type  >> 15 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 15  ,;
	 my $AircraftType    = ( $Type1_Type  >> 12 ) & ( 1 << 3 ) - 1;  # 3 bit  starting at bit 12  ,;;
     my $Altitude        = ( $Type1_Type  >> 0 ) & ( 1 << 11 ) - 1;
     my $AltitudeScaling = ( $Type1_Type  >> 11 ) & ( 1 << 1 ) - 1 ;
     if  ( $AltitudeScaling               == 1) {
      $Altitude        = $Altitude * 4;
     }
     my $Speed_help    = hex($hex[$startmsg+8]);
     my $Speed_Scaling  = ( $Speed_help  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,;
     my $Speed  = (( $Speed_help  >> 0 ) & ( 1 << 7 ) - 1 )/2;  # 7 bit  starting at bit 0  ,;
     if ($Speed_Scaling ==1){
     $Speed  = $Speed  * 5;
     }

      my $Climb_help    = hex($hex[$startmsg+9]);
     my $Climb_Scaling  = ( $Climb_help  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,;
     my $Climb_2comple  = ( $Climb_help  >> 6 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 6  ,;
     my $Climb  =(-64 * $Climb_2comple + (( $Climb_help  >> 0 ) & ( 1 << 6 ) - 1  ) ) /10;  # 6 bit  starting at bit 0  ,; #-
     if ($Climb_Scaling ==1){
     $Climb  = $Climb  * 5;
     }

     my $Heading = hex($hex[$startmsg+10])/256*360;

      my $TurnRate_help    = hex($hex[$startmsg+11]);
     my $TurnRate_Scaling  = ( $TurnRate_help  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,;
     my $TurnRate_2comple  = ( $TurnRate_help  >> 6 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 6  ,;
     my $TurnRate  =(-64 * $TurnRate_2comple + (( $TurnRate_help  >> 0 ) & ( 1 << 6 ) - 1  ) ) /10;  # 6 bit  starting at bit 0  ,; #-
     if ($TurnRate_Scaling ==0){
     $TurnRate  = $TurnRate  /4;
     }

     #_GPS_KMPH_PER_KNOT 1.852  m TXRX_TEST_SPEED       50.0 = 92.5 = OK
     print "Latitude        $Latitude
Longitude       $Longitude
OnlineTracking  $OnlineTracking
AircraftType    $AircraftType
Altitude        $Altitude
Speed           $Speed  Speed_Scaling$Speed_Scaling
Climb           $Climb  Climb_Scaling$Climb_Scaling Climb_2comple$Climb_2comple
Heading        $Heading
TurnRate       $TurnRate
https://www.google.com/maps/search/?api=1&query=$Latitude,$Longitude
";

$dbh->do('INSERT INTO FANET_TYP_1
(Type1ID, Type1Latitude, Type1Longitude, Type1OnlineTracking, Type1AircraftType, Type1Altitude, Type1Speed, Type1Climb, Type1Heading, Type1TurnRate)
VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?);', undef, $id ,  $Latitude, $Longitude, $OnlineTracking,  $AircraftType, $Altitude, $Speed, $Climb, $Heading, $TurnRate);

}
elsif ($Type==2) {
my @hex    = @hex[$startmsg+0 .. $#hex-1];
my @dec    = map { hex($_) } @hex;
my @bytes  = map { pack('C', $_) } @dec;
my $Type2_name = join ('', @bytes);

 print ("Type2_name $Type2_name\n");
 # Blaettersbe
 $dbh->do('INSERT INTO FANET_TYP_2
 (Type2ID, Type2Name)
 VALUES(?, ?);', undef, $id ,  $Type2_name);

 $dbh->do('REPLACE INTO  FANET_NAME (Manufacturer, UniqueID, NAME) VALUES(?, ?, ?) ;', undef, $Manufacturer, $UniqueID ,  $Type2_name);


}

elsif ($Type==3) {
my @hex    = @hex[$startmsg+1 .. $#hex-1];
my @dec    = map { hex($_) } @hex;
my @bytes  = map { pack('C', $_) } @dec;
my $Type3_message = join ('', @bytes);
my $Type3_header = hex($hex[$startmsg+11]);


 print ("
 Type3_header  $Type3_header
 Type3_message $Type3_message\n");
 $dbh->do('INSERT INTO FANET_TYP_3
(Type3ID, Type3Header, Type3Message)
VALUES(?, ?, ?);
', undef, $id , $Type3_header, $Type3_message);


}
elsif ($Type==4) {
	 my $Type4Header         = hex($hex[$startmsg+0]);
   my $Type4HeaderInternetGateway   = ( $Type4Header  >> 7 ) & ( 1 <<  1 ) - 1;  # 1 bit  starting at bit 0  ,;;
   my $Type4HeaderTemperature       = ( $Type4Header  >> 6 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderWind              = ( $Type4Header  >> 5 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderHumidity          = ( $Type4Header  >> 4 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderBarometric        = ( $Type4Header  >> 3 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderSupport           = ( $Type4Header  >> 2 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderStateCharge       = ( $Type4Header  >> 1 ) & ( 1 <<  1 ) - 1;
   my $Type4HeaderExtendedHeader    = ( $Type4Header  >> 0 ) & ( 1 <<  1 ) - 1;
   my $Latitude        = hex(join('',reverse(@hex[$startmsg+1 .. $startmsg+3]) )   )/93206;
   my $Longitude       = hex(join('',reverse(@hex[$startmsg+4 .. $startmsg+6]) )   )/46603;
   my $Type4InternetGateway   ;
   my $Type4Temperature       ;
   my $Type4WindHeading;
   my $Type4WindSpeed;
   my $Type4WindGusts              ;
   my $Type4Humidity          ;
   my $Type4Barometric        ;
   my $Type4Support           ;
   my $Type4StateCharge       ;
   my $Type4ExtendedHeader    ;
   $startmsg += 7;
   if ($Type4HeaderInternetGateway   == 1){
    $startmsg += 0;
   }
   if ($Type4HeaderTemperature       == 1){

     my $Type4TemperatureByte = hex($hex[$startmsg]);
     #print ("Type4TemperatureByte  $hex[$startmsg] \n");
     #printf "Type4TemperatureBin   %b\n", hex($hex[$startmsg]);
     my $Type4Temperature2comp = ( $Type4TemperatureByte >> 7 ) & ( 1 << 1 ) - 1;
     #print ("Type4Temperature2comp $Type4Temperature2comColumn1p \n");
     $Type4Temperature  =(-128 * ($Type4Temperature2comp) + (( $Type4TemperatureByte  >> 0 ) & ( 1 << 7 ) - 1  ) ) /2;  # 7 bit  starting at bit 0  ,; #-
    $startmsg += 1;
   }
   if ($Type4HeaderWind              == 1){
     $Type4WindHeading =  hex($hex[$startmsg])/256*360;
     $Type4WindSpeed   = hex($hex[$startmsg+1])/5;
     #keinscale missing
     $Type4WindGusts   = hex($hex[$startmsg+2])/5;
     $startmsg += 3;
   }
   if ($Type4HeaderHumidity          == 1){
        $Type4Humidity =  hex($hex[$startmsg])*4/10;
     $startmsg += 1;
   }
   if ($Type4HeaderBarometric        == 1){
     $Type4Barometric = hex(join('',reverse(@hex[$startmsg+0 .. $startmsg+2]) )   )*10+430;
     $startmsg += 2;
   }
   if ($Type4HeaderSupport           == 1){
     $startmsg += 0;
   }
   if ($Type4HeaderStateCharge       == 1){
     $Type4StateCharge =  hex($hex[$startmsg])/256*100;
     $startmsg += 1;
   }
   if ($Type4HeaderExtendedHeader    == 1){
     $startmsg += 1;
   }
   print ("
Type4HeaderInternetGateway   =$Type4HeaderInternetGateway
Type4HeaderTemperature       =$Type4HeaderTemperature
Type4HeaderWind              =$Type4HeaderWind
Type4HeaderHumidity          =$Type4HeaderHumidity
Type4HeaderBarometric        =$Type4HeaderBarometric
Type4HeaderSupport           =$Type4HeaderSupport
Type4HeaderStateCharge       =$Type4HeaderStateCharge
Type4HeaderExtendedHeader    =$Type4HeaderExtendedHeader
Latitude                     =$Latitude
Longitude                    =$Longitude
Type4Temperature           =$Type4Temperature
Type4WindHeading           =$Type4WindHeading
Type4WindSpeed             =$Type4WindSpeed
Type4WindGusts             =$Type4WindGusts
Type4Humidity              =$Type4Humidity
Type4Barometric            =$Type4Barometric
Type4StateCharge           =$Type4StateCharge

https://www.google.com/maps/search/?api=1&query=$Latitude,$Longitude
   ");
   $dbh->do('   INSERT INTO FANET_TYP_4
   (Type4ID,
   Type4HeaderInternetGateway,
   Type4HeaderTemperature,
   Type4HeaderWind,
   Type4HeaderHumidity,
   Type4HeaderBarometric,
   Type4HeaderSupport,
   Type4HeaderStateCharge,
   Type4HeaderExtendedHeader,
   Type4Temperature,
   Type4WindHeading,
   Type4WindSpeed,
   Type4WindGusts,
   Type4Barometric,
   Type4Type4Humidity,
   Type4StateCharge)
   VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
   ', undef,
   $id ,
   $Type4HeaderInternetGateway,
   $Type4HeaderTemperature,
   $Type4HeaderWind,
   $Type4HeaderHumidity,
   $Type4HeaderBarometric,
   $Type4HeaderSupport,
   $Type4HeaderStateCharge,
   $Type4HeaderExtendedHeader,
   $Type4Temperature,
   $Type4WindHeading,
   $Type4WindSpeed,
   $Type4WindGusts,
   $Type4Barometric,
   $Type4Humidity,
   $Type4StateCharge);


 }
elsif ($Type==7) {
     my $Latitude               = hex(join('',reverse(@hex[$startmsg+0 .. $startmsg+2]) )   )/93206;
     my $Longitude              = hex(join('',reverse(@hex[$startmsg+3 .. $startmsg+5]) )   )/46603;
	 my $Type7_Type_help        = hex($hex[$startmsg+6])    ;
	 my $Type7_Type             = ( $Type7_Type_help >> 4 ) & ( 1 << 3 ) - 1;  # 3 bit  starting at bit 7  ,;
	 my $Type7OnlineTracking    = ( $Type7_Type_help  >> 0 ) & ( 1 <<  1 ) - 1;  # 1 bit  starting at bit 0  ,;;

      print ("
Latitude            $Latitude
Longitude           $Longitude
Type7_Type_help     $Type7_Type_help
Type7_Type          $Type7_Type
Type7OnlineTracking $Type7OnlineTracking
https://www.google.com/maps/search/?api=1&query=$Latitude,$Longitude
 ");
  $dbh->do('INSERT INTO FANET_TYP_7
 (Type7ID, Type7Latitude, Type7Longitude, Type7Type, Type7OnlineTracking)
 VALUES(?, ?, ?, ?, ?);', undef,
 $id, $Latitude, $Longitude, $Type7_Type, $Type7OnlineTracking);

 }
elsif ($Type==8) {
  my $DeviceType          = hex($hex[$startmsg])    ;
  my $FirmwareHelp        = hex(join('',reverse(@hex[$startmsg+1 .. $startmsg+2])))    ;
  print ("FirmwareHelpBIN   $FirmwareHelp");
  my $FirmwareRelease     = ( $FirmwareHelp    >> 16 ) & ( 1 << 1 ) - 1;
  my $FirmwareReleaseyear =  (( $FirmwareHelp   >> 9  ) & (( 1 << 5 ) - 1)) + 2019 ;
  my $FirmwareReleasemonth = (( $FirmwareHelp   >> 5  ) & (( 1 << 3 ) - 1));
  my $FirmwareReleaseday   = (( $FirmwareHelp   >> 0  ) & (( 1 << 4 ) - 1)) ;
  my $FirmwareReleaseDate   = $FirmwareReleaseyear * 10000 + $FirmwareReleasemonth*100+$FirmwareReleaseday;
  my $FirmwareReleaseDatestr = $FirmwareReleaseyear ."-". $FirmwareReleasemonth."-".$FirmwareReleaseday;
  print ("
DeviceType           $DeviceType
FirmwareHelp         $FirmwareHelp
FirmwareRelease      $FirmwareRelease
FirmwareReleaseDate   $FirmwareReleaseDate
");

  $dbh->do('INSERT INTO FANET_TYP_8
(Type8ID, Type8DeviceType, Type8FirmwareRelease, Type8FirmwareReleaseDate)
VALUES(?, ?, ?, STR_TO_DATE(?, "%Y-%m-%d"));', undef,
$id,
$DeviceType,
$FirmwareHelp,
$FirmwareRelease,
$FirmwareReleaseDatestr);
}
elsif ($Type==9) {
     my $Latitude               = hex(join('',reverse(@hex[$startmsg+0 .. $startmsg+2]) )   )/93206;
     my $Longitude              = hex(join('',reverse(@hex[$startmsg+3 .. $startmsg+5]) )   )/46603;
     my $Type1_Type      = hex(join('',reverse(@hex[$startmsg+6 .. $startmsg+7]) )   );
     my $confidence    = ( $Type1_Type  >> 12 ) & ( 1 << 3 ) - 1;  # 3 bit  starting at bit 12  ,;;
     my $ThermalAltitude        = ( $Type1_Type  >> 0 ) & ( 1 << 11 ) - 1;
     my $ThermalAltitudeScaling = ( $Type1_Type  >> 11 ) & ( 1 << 1 ) - 1 ;
     if  ( $ThermalAltitudeScaling               == 1) {
        $ThermalAltitude        = $ThermalAltitude * 4;
       }
      my $AvgClimb_help    = hex($hex[$startmsg+8]);
      my $AvgClimb_Scaling  = ( $AvgClimb_help  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,;
      my $AvgClimb = (( $AvgClimb_help  >> 0 ) & ( 1 << 7 ) - 1 )/10;  # 7 bit  starting at bit 0  ,;
      if ($AvgClimb_Scaling ==1){
      $AvgClimb  = $AvgClimb  * 5;
      }
      my $AvgWind_help    = hex($hex[$startmsg+9]);
      my $AvgWind_Scaling  = ( $AvgWind_help  >> 7 ) & ( 1 << 1 ) - 1;  # 1 bit  starting at bit 7  ,;
      my $AvgWind = (( $AvgWind_help  >> 0 ) & ( 1 << 7 ) - 1 )/2;  # 7 bit  starting at bit 0  ,;
      if ($AvgWind_Scaling ==1){
      $AvgWind  = $AvgWind  * 5;
      }
 my $WindHeading = hex($hex[$startmsg+10])/256*360;
 print ("
Latitude          $Latitude
Longitude         $Longitude
ThermalAltitude   $ThermalAltitude
AvgClimb          $AvgClimb
AvgWind           $AvgWind
WindHeading       $WindHeading
https://www.google.com/maps/search/?api=1&query=$Latitude,$Longitude
 ");
 $dbh->do('INSERT INTO FANET_TYP_9
(Type9ID, Type9Latitude, Type9Longitude, Type9ThermalAltitude, Type9AvgClimb, Type9AvgWind, Type9WindHeading)
VALUES(?, ?, ?, ?, ?, ?, ?);
', undef,
$id,
$Latitude,
$Longitude,
$ThermalAltitude,
$AvgClimb,
$AvgWind,
$WindHeading
);
 }
}
}

sub remove_and_create_tables{
$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_ExtendedHeader`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_ExtendedHeader` (
  `ExtendedHeaderID` bigint(20) NOT NULL,
  `ExtendedHeaderACK` smallint(5) unsigned DEFAULT NULL,
  `ExtendedHeaderCast` smallint(5) unsigned DEFAULT NULL,
  `ExtendedHeaderSignatureBit` bit(1) DEFAULT NULL,
  `ExtendedHeaderGeobasedForwarded` bit(1) DEFAULT NULL,
  PRIMARY KEY (`ExtendedHeaderID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL

$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_Signature`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_Signature` (
  `SignatureID` bigint(20) NOT NULL,
  `Signature` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`SignatureID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_Header`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_Header` (
  `ID` bigint(20) NOT NULL AUTO_INCREMENT,
  `Manufacturer` int(11) DEFAULT NULL,
  `UniqueID` varchar(6) COLLATE latin1_general_ci DEFAULT NULL,
  `Forward` TINYINT(1) DEFAULT NULL,
  `Type` int(11) DEFAULT NULL,
  `ExtendedHeader` TINYINT(1) DEFAULT NULL,
  `DBI` int(11) DEFAULT NULL,
  `received_by` varchar(100) COLLATE latin1_general_ci DEFAULT NULL,
  `Original` varchar(100) COLLATE latin1_general_ci DEFAULT NULL,
  `Timestamp` datetime DEFAULT NULL,
  PRIMARY KEY (`ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1 COLLATE=latin1_general_ci;
END_SQL

$dbh->do( <<'END_SQL');
ALTER TABLE FANET_Header ADD CONSTRAINT FANET_Header_UN UNIQUE KEY (Manufacturer,UniqueID,`Type`, ID);
END_SQL

$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_1`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_1` (
  `Type1ID` bigint(20) NOT NULL,
  `Type1Latitude` double DEFAULT NULL,
  `Type1Longitude` double DEFAULT NULL,
  `Type1OnlineTracking` bit(1) DEFAULT NULL,
  `Type1AircraftType` TINYINT(6) DEFAULT NULL,
  `Type1Altitude` int(10) unsigned DEFAULT NULL,
  `Type1Speed` int(10) unsigned DEFAULT NULL,
  `Type1Climb` int(11) DEFAULT NULL,
  `Type1Heading` TINYINT(6) DEFAULT NULL,
  `Type1TurnRate` int(11) DEFAULT NULL,
  PRIMARY KEY (`Type1ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_2`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_2` (
  `Type2ID` bigint(20) NOT NULL,
  `Type2Name` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`Type2ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL

$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_NAME`
END_SQL

$dbh->do( <<'END_SQL');
CREATE  TABLE `FANET_NAME` (
`Manufacturer` int(11) NOT NULL,
`UniqueID` varchar(6) COLLATE latin1_general_ci NOT NULL,
  `NAME` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`Manufacturer`, UniqueID )
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_3`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_3` (
  `Type3ID` bigint(20) NOT NULL,
  `Type3Header` int(11) DEFAULT NULL,
  `Type3Message` varchar(100) DEFAULT NULL,
  PRIMARY KEY (`Type3ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_4`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_4` (
  `Type4ID` bigint(20) NOT NULL,
  `Type4HeaderInternetGateway` bit(1) DEFAULT NULL,
  `Type4HeaderTemperature` bit(1) DEFAULT NULL,
  `Type4HeaderWind` bit(1) DEFAULT NULL,
  `Type4HeaderHumidity` bit(1) DEFAULT NULL,
  `Type4HeaderBarometric` bit(1) DEFAULT NULL,
  `Type4HeaderSupport` bit(1) DEFAULT NULL,
  `Type4HeaderStateCharge` bit(1) DEFAULT NULL,
  `Type4HeaderExtendedHeader` bit(1) DEFAULT NULL,
  `Type4Temperature` float DEFAULT NULL,
  `Type4WindHeading` int(11) DEFAULT NULL,
  `Type4WindSpeed` int(11) DEFAULT NULL,
  `Type4WindGusts` int(11) DEFAULT NULL,
  `Type4Barometric` int(11) DEFAULT NULL,
  `Type4Type4Humidity` float DEFAULT NULL,
  `Type4StateCharge` int(11) DEFAULT NULL,
  PRIMARY KEY (`Type4ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_7`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_7` (
  `Type7ID` bigint(20) NOT NULL,
  `Type7Latitude` double DEFAULT NULL,
  `Type7Longitude` double DEFAULT NULL,
  `Type7Type` int(11) DEFAULT NULL,
  `Type7OnlineTracking` bit(1) DEFAULT NULL,
  PRIMARY KEY (`Type7ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_8`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_8` (
  `Type8ID` varchar(100) NOT NULL,
  `Type8DeviceType` int(11) DEFAULT NULL,
  `Type8FirmwareRelease` bit(1) DEFAULT NULL,
  `Type8FirmwareReleaseDate` date DEFAULT NULL,
  PRIMARY KEY (`Type8ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL


$dbh->do( <<'END_SQL');
DROP TABLE IF EXISTS `FANET_TYP_9`
END_SQL

$dbh->do( <<'END_SQL');
CREATE TABLE `FANET_TYP_9` (
  `Type9ID` bigint(20) NOT NULL,
  `Type9Latitude` double DEFAULT NULL,
  `Type9Longitude` double DEFAULT NULL,
  `Type9ThermalAltitude` int(10) unsigned DEFAULT NULL,
  `Type9AvgClimb` float DEFAULT NULL,
  `Type9AvgWind` float DEFAULT NULL,
  `Type9WindHeading` int(11) DEFAULT NULL,
    PRIMARY KEY (`Type9ID`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;
END_SQL

$dbh->do( <<'END_SQL');
Create or replace View FANET_ALL_Messages as
SELECT FANET_Header.*, FANET_ExtendedHeader.*, FANET_Signature.*,
FANET_TYP_1.*,
FANET_TYP_2.*,
FANET_TYP_3.*,
FANET_TYP_4.*,
FANET_TYP_7.*,
FANET_TYP_8.*,
FANET_TYP_9.*
FROM FANET_Header
left outer join FANET_ExtendedHeader on ExtendedHeaderID = ID
left outer join FANET_Signature      on ID = SignatureID
left outer join FANET_TYP_1          on Type1ID = ID
left outer join FANET_TYP_2 ON ID = Type2ID
left outer join FANET_TYP_3 ON ID = Type3ID
left outer join FANET_TYP_4 ON ID = Type4ID
left outer join FANET_TYP_7 ON ID = Type7ID
left outer join FANET_TYP_8 ON ID = Type8ID
left outer join FANET_TYP_9 ON ID = Type9ID
END_SQL
}


=begin comment
/*



https://github.com/3s1d/fanet-stm32/blob/master/Src/fanet/radio/protocol.txt
 2089 Type           = 1   (OK)
     15 Type           = 2  (size of buffer in Softrf)
     Type = 3 (keine Beispiele aber OK)
      6 Type           = 4  (OK)
     39 Type           = 7  (OK)
      4 Type           = 8 ()
     33 Type           = 9 (OK)

--== PHY ==--

868.2Mhz
Syncword 0xF1
250kHz Bandwidth
Spreading Factor 7
ExplicitHeader: Coding Rate CR 5-8/8 (depending on #neighbors), CRC for Payload

--== FANET MAC ==--


Header:
[Byte 0]
7bit 		Extended Header
6bit 		Forward
5-0bit 		Type

Source Address:
[Byte 1-3]
1byte		Manufacturer
2byte		Unique ID (Little Endian)

Extended Header:
[Byte 4 (if Extended Header bit is set)]
7-6bit 		ACK:
			0: none (default)
			1: requested
			2: requested (via forward, if received via forward (received forward bit = 0). must be used if forward is set)
			3: reserved
5bit		Cast:
			0: Broadcast (default)
			1: Unicast (adds destination address (8+16bit)) (shall only be forwarded if dest addr in cache and no 'better' retransmission received)
4bit 		Signature (if 1, add 4byte)
3bit		Geo-based Forwarded	(prevent any further geo-based forwarding, can be ignored by any none-forwarding instances)
2-0bit 		Reserved	(ideas: indicate multicast interest add 16bit addr, emergency)

Destination Address (if unicast is set):
[Byte 5-7]
1byte		Manufacturer
2byte		Unique ID (Little Endian)

Signature (if signature bit is set):
[Byte 5-8 or Byte 8-11 (if unicast is set)]
4byte 		Signature



Types:
-----------

ACK (Type = 0)
No Payload, must be unicast

-----------

Tracking (Type = 1)
[recommended intervall: floor((#neighbors/10 + 1) * 5s) ]
Note: Done by app layer of the fanet module

[Byte 0-2]	Position	(Little Endian, 2-Complement)
bit 0-23	Latitude 	(Absolute, see below)
[Byte 3-5]	Position	(Little Endian, 2-Complement)
bit 0-23	Longitude 	(Absolute, see below)

[Byte 6-7]	Type		(Little Endian)
bit 15 		Online Tracking
bit 12-14	Aircraft Type
			0: Other
			1: Paraglider
			2: Hangglider
			3: Balloon
			4: Glider
			5: Powered Aircraft
			6: Helicopter
			7: UAV
bit 11		Altitude Scaling 1->4x, 0->1x
bit 0-10	Altitude in m

[Byte 8]	Speed		(max 317.5km/h)
bit 7		Scaling 	1->5x, 0->1x
bit 0-6		Value		in 0.5km/h

[Byte 9]	Climb		(max +/- 31.5m/s, 2-Complement)
bit 7		Scaling 	1->5x, 0->1x
bit 0-6		Value		in 0.1m/s

[Byte 10]	Heading
bit 0-7		Value		in 360/256 deg

[optional]
[Byte 11]	Turn rate 	(max +/- 64deg/s, positive is clock wise, 2-Complement)
bit 7		Scaling 	1->4x, 0->1x
bit 0-6		Value 		in 0.25deg/s

[optional, if used byte 11 is mandatory as well]
[Byte 12]	QNE offset 	(=QNE-GPS altitude, max +/- 254m, 2-Complement)
bit 7		Scaling 	1->4x, 0->1x
bit 0-6		Value 		in m

------------

Name (Type = 2)
[recommended intervall: every 4min]

8bit String (of arbitrary length, \0 termination not required)

------------

Message (Type = 3)

[Byte 0]	Header
bit 0-7 	Subheader, Subtype (TBD)
			0: Normal Message

8bit String (of arbitrary length)

------------
|station        |tms                |received_by|direction  |speed                 |gusts                 |temp                  |humid                 |
|---------------|-------------------|-----------|-----------|----------------------|----------------------|----------------------|----------------------|
|SkyTraxx-0117  |2020-05-30 13:14:59|FD0002     |30         |10.6                  |19.6                  |15.5                  |35.200001             |

{"rawMsg":{"datetime":"2020-05-30 13:14:59","length":17,
"hexMsg":" 44 01 17 01 76 FB 10 46 22 BD 05 1F 15 35 62 58 0F",
"source":"01:0117","dest":"00:0000","type":4,"radioData":{"timestamp":1590837299,"RSSI":-116,"pRSSI":-110,"pSNR":5,"CR":"4/8","CRCERR":0}}}

formatted_time 05/30/20 13:14:59
44 01 17 01 76 fb 10 46 22 bd 05 1f 15 35 62 58
ExtendedHeader = 0
Forward        = 1
Type           = 4
Manufacturer   = 01
UniqueID       = 0117
Type4TemperatureByte  1f
Type4TemperatureBin   11111

Type4HeaderInternetGateway   =0
Type4HeaderTemperature       =1
Type4HeaderWind              =1
Type4HeaderHumidity          =1
Type4HeaderBarometric        =0
Type4HeaderSupport           =1
Type4HeaderStateCharge       =1
Type4HeaderExtendedHeader    =0
Latitude                     =49.2657876102397
Longitude                    =8.07025298800506
Type4Temperature           =15.5
Type4WindHeading           =29.53125
Type4WindSpeed             =10.6
Type4WindGusts             =19.6

--
44 01 17 01 (hEADER)
76 FB 10 46 22 BD 05 (=??)
(15.5*2).toString(16) = 1F = Temperature
21/256*360 = 29.53125 - (21).toString(16) = "15" (grad)
35 62 58 0F

Service (Type = 4)
[recommended intervall: 40sec]

[Byte 0]	Header	(additional payload will be added in order 6 to 1, followed by Extended Header payload 7 to 0 once defined)
bit 7		Internet Gateway (no additional payload required, other than a position)
bit 6		Temperature (+1byte in 0.5 degree, 2-Complement)
bit 5		Wind (+3byte: 1byte Heading in 360/256 degree, 1byte speed and 1byte gusts in 0.2km/h (each: bit 7 scale 5x or 1x, bit 0-6))
bit 4		Humidity (+1byte: in 0.4% (%rh*10/4))
bit 3		Barometric pressure normailized (+2byte: in 10Pa, offset by 430hPa, unsigned little endian (hPa-430)*10)
bit 2		Support for Remote Configuration (Advertisement)
bit 1		State of Charge  (+1byte lower 4 bits: 0x00 = 0%, 0x01 = 6.666%, .. 0x0F = 100%)
bit 0		Extended Header (+1byte directly after byte 0)
		The following is only mandatory if no additional data will be added. Broadcasting only the gateway/remote-cfg flag doesn't require pos information.
[Byte 1-3 or Byte 2-4]	Position	(Little Endian, 2-Complement)
bit 0-23	Latitude	(Absolute, see below)
[Byte 4-6 or Byte 5-7]	Position	(Little Endian, 2-Complement)
bit 0-23	Longitude   (Absolute, see below)
+ additional data according to the sub header order (bit 6 down to 1)

------------

Landmarks (Type = 5)
Note: Landmarks are completely independent. Thus the first coordinate in each packet has to be an absolute one. All others are compressed in relation to the one before.
Note2: Identification/detection shall be done by hashing the whole payload, excluding bytes 0, 1 and, 2 (optional). That way one quietly can change the layer to 'Don't care' and quickly
	destroy the landmark w/o having to wait for it's relative live span to be exceeded.
Note3: In case a text has the same postion as the first position of any other landmark then the text is considered to be the label of that landmark.

[Byte 0]
bit 4-7		Time to live +1 in 10min (bit 7 scale 6x or 1x, bit 4-6) (0->10min, 1->20min, ..., F->8h)
bit 0-3		Subtype:
			0:     Text
			1:     Line
			2:     Arrow
			3:     Area
			4:     Area Filled
			5:     Circle
			6:     Circle Filled
			7:     3D Line		suitable for cables
			8:     3D Area		suitable for airspaces (filled if starts from GND=0)
			9:     3D Cylinder	suitable for airspaces (filled if starts from GND=0)
			10-15: TBD
[Byte 1]
bit 7-5		Reserved
bit 4		Internal wind dependency (+1byte wind sector)
bit 3-0		Layer:
			0:     Info
			1:     Warning
			2:     Keep out
			3:     Touch down
			4:     No airspace warn zone		(not yet implemented)
			5-14:  TBD
			15:    Don't care
[Byte 2 only if internal wind bit is set] Wind sectors +/-22.5degree (only display landmark if internal wind is within one of the advertised sectors.
									If byte 2 is present but is zero, landmark gets only displayed in case of no wind)
bit 7 		NW
bit 6		W
bit 5		SW
bit 4 		S
bit 3 		SE
bit 2 		E
bit 1 		NE
bit 0 		N

[n Elements]
			Text (0): 		Position (Absolute) + String 				//(2 Byte aligned, zero-termination is optional)
			Line/Arrow (1,2):	Position (1st absolute others compressed, see below, minimum 2 elements)
			Area (filled)(3,4): 	Position (1st absolute others compressed, see below, minimum 3 elements)
			Circle (filled)(5,6):	n times: Position (1st absolute others compressed, see below) + Radius (1Byte in 50m, bit 7 scale 8x or 1x, bit 0-6)
			3D Line (7):		n times: Position (1st in packet absolute others compressed, see below) + Altitude (('1Byte signed'+109) * 25m (-127->-450m, 127->5900m))
			3D Area (8):		Altitude bottom, top (each: ('1Byte signed'+109) * 25m (-127->-450m, 127->5900m), only once) +
							n times: Position (1st absolute others compressed, see below)
			3D Cylinder (9):	n times: Position (1st absolute others compressed, see below) + Radius (1Byte in 50m, bit 7 scale 8x or 1x, bit 0-6) +
							Altitude bottom, top (each: ('1Byte signed'+109) * 25m (-127->-450m, 127->5900m), only once)

------------

Remote Configuration (Type = 6)		NOTE: Do not use, in development!
Note: Signature (symmetric) is highly recommended. Skytraxx uses first 4byte of SHA1 + PSK
Note 2: Each reply feature with a suitable mask shall be played using round robin w/ 30sec intervals followed by a 3min pause.
Note 3: Empty subtype removes the feature

[Byte 0]
bit 7-0		Subtype:
			0:	Acknowledge configuration: Byte [1] subtype of ack
			1:	Request. Byte[1] Subtype
			2:	Position. Byte [1-6] latitude/longitude, Byte [7] altitude ('1Byte signed'+109) * 25m (-127->-450m, 127->5900m), Byte [8] heading (encoded like in type 1)
			3:	Reserved
			4..8:	Geofence for Geo-Forwarding: Altitude bottom, top (each: ('1Byte signed'+109) * 25m (-127->-450m, 127->5900m), only once) +
							n times: Position (1st absolute others compressed, see below)
			9..33:	Broadcast Reply feature. Byte[1] Wind Sectors (like in type 5), Byte [2] is type (and forward bit) followed by its payload.
				Recommendation: 9 for name. First 12 none-volatile, second 12 volatile

------------

Ground Tracking (Type = 7)
[recommended interval: floor((#neighbors/10 + 1) * 5s)]

[Byte 0-2]	Position	(Little Endian, 2-Complement)
bit 0-23	Latitude 	(Absolute, see below)
[Byte 3-5]	Position	(Little Endian, 2-Complement)
bit 0-23	Longitude 	(Absolute, see below)
[Byte 6]
bit 7-4		Type
			0:    Other
			1:    Walking
			2:    Vehicle
			3:    Bike
			4:    Boot
			8:    Need a ride
			9:    Landed well
			12:   Need technical support
			13:   Need medical help
			14:   Distress call
			15:   Distress call automatically
			Rest: TBD
bit 3-1		TBD
bit 0		Online Tracking

------------

HW Info (Type = 8)	(DEPRICATED)
[recommended intervall: very low, every 10min]

[Byte 0]	Instrument / Device Type (Manufacturer Spezific)
		Pull request 0x00 (has to be unicast, no further data)
		Manufacturer 0x01:			(Skytraxx)
			0x01 Wind station
		Manufacturer 0x06:			(Burnair)
			0x01 Base station Wifi
		Manufacturer 0x11:			(FANET +)
			0x01 Skytraxx 3.0
			0x02 Syltraxx 2.1
			0x03 Skytraxx Beacon
			0x10 Naviter Oudie 5
		Manufacturer 0xFB:
			0x01 Skytraxx WiFi base station
[Byte 1-2]	Firmware Build Date
bit 15			0: Release 1: Develop/Experimental Mode
bit 9-14		Year from 2019 (0 -> 2019, 1 -> 2020, ...)
bit 5-8			Month (1-12)
bit 0-4			Day (1-31)
+ additional type/manufacturer/version spezific optional data
e.g. Recomendation / Skytraxx best practice:
Byte [3-4]
bit 15-4	Uptime in 30sec steps
bit 0-3		unused (Skytraxx Windstation: number used volatile replay features)

------------

Thermal (Type = 9)
[recommended intervall: floor((#neighbors/10 + 1) * 30s), if a thermal is detected]

[Byte 0-2]	Position of thermal	(Little Endian, 2-Complement)
bit 0-23	Latitude 		(Absolute, see below)
[Byte 3-5]	Position of thermal	(Little Endian, 2-Complement)
bit 0-23	Longitude 		(Absolute, see below)

[Byte 6-7]	Type			(Little Endian)
bit 15		TBD, leave as 0
bit 14-12	confidence/quality	(0 = 0%, 7= 100%)
bit 11		Thermal Altitude Scaling 1->4x, 0->1x
bit 0-10	Thermal Altitude in m

[Byte 8]	Avg climb of thermal	(max +/- 31.5m/s, 2-Complement, climb of air NOT the paraglider)
bit 7		Scaling 	1->5x, 0->1x
bit 0-6		Value		in 0.1m/s

[Byte 9]	Avg wind speed at thermal (max 317.5km/h)
bit 7		Scaling 	1->5x, 0->1x
bit 0-6		Value		in 0.5km/h

[Byte 10]	Avg wind heading at thermal (attention: 90degree means the wind is coming from east and blowing towards west)
bit 0-7		Value		in 360/256 deg

------------

HW Info (Type = A) (EXPERIMENTAL, will replace type 8)
[recommended intervall: very low, every 10min]

[Byte 0]	Header	(additional payload will be added in order 6 to 1, followed by Extended Header payload 7 to 0 once defined)
bit 7		Ping-Pong Request (must be unicast and must not cotain any data other then subheader, bits in header are considered as requests)
bit 6		Hardware Subtype + Build Date
bit 5		ICAO address (+3byte address)
bit 4		Uptime (+2byte, time in minutes)
bit 3		Rx RSSI (+1byte RSSI+50, +3byte FANET address, example: -30 -> -80dBm, only valid for uni cast requests, reply usually broiadcast)
bit 2-1		TBD
bit 0		Extended Header (+1byte directly after byte 0)

Hardware Subtype + Build Date
[Byte 1]	Instrument / Device Type (Manufacturer Spezific)
		Pull request 0x00 (has to be unicast, no further data)
		Manufacturer 0x01:			(Skytraxx)
			0x01 Wind station
		Manufacturer 0x06:			(Burnair)
			0x01 Base station Wifi
		Manufacturer 0x11:			(FANET +)
			0x01 Skytraxx 3.0
			0x02 Syltraxx 2.1
			0x03 Skytraxx Beacon
			0x10 Naviter Oudie 5
		Manufacturer 0xFB:
			0x01 Skytraxx WiFi base station
[Byte 2-3]	Firmware Build Date
bit 15			0: Release 1: Develop/Experimental Mode
bit 9-14		Year from 2019 (0 -> 2019, 1 -> 2020, ...)
bit 5-8			Month (1-12)
bit 0-4			Day (1-31)


------------

Coordinate Formats

Compressed (reference coordinate required):
[Byte 0-1]	Position	(Little Endian, 2-Complement)
bit 0-15	Latitude
[Byte 2-3]	Position	(Little Endian, 2-Complement)
bit 0-15	Longitude

			Details:
			bit 15		even 0 odd 1 degree
			ddeg = (signed 15bit) * value / 2^15
			if(round(my_deg) is equal to bit15)
				deg = round(my_deg) + ddeg
			else
				find minimum of |round(my_deg)-1 + ddeg - my_lat| and |round(my_lat1)+1 + ddeg - my_lat|

			(Max allowed distance 1deg -> approx. 111km latitude or longitude@latitude=equator,
			longitude@latitude=60deg: 55km, longitude@latitude=70deg: 38km (critical))
			(Max error <2m)
			(Note: longitude block-bit could be extended by a further bit in case of lat > +/-60deg, future work...)

Sample C code for decompressing:
float fns_buf2coord_compressed(uint16_t *buf, float mycoord)
{
	/* decode buffer */
	bool odd = !!((1<<15) & *buf);
	int16_t sub_deg_int =         -126
formatted_time 05/29/20 17:00:35
08 11 b0 12 02 8f 02 c0 03 05 b1 95 7e 04 ac 00
ExtendedHeader = 0
Forward        = 0
Type           = 8
Manufacturer   = 11
UniqueID       = 12b0
FirmwareHelpBIN   655
DeviceType           2
FirmwareHelp         655
FirmwareRelease      0
FirmwareReleaseDate   20200415
(*buf&0x7FFF) | (1<<14&*buf)<<1;
	const float sub_deg = sub_deg_int / 32767.0f;


	/* retrieve coordinate */
	float mycood_rounded = roundf(mycoord);
	bool mycoord_isodd = ((int)mycood_rounded) & 1;

	/* target outside our segment. estimate where it is in */
	if(mycoord_isodd != odd)
	{
		/* adjust deg segment */
		const float mysub_deg = mycoord - mycood_rounded;
		if(sub_deg > mysub_deg)
			mycood_rounded--;
		else
			mycood_rounded++;
	}

	return mycood_rounded + sub_deg;
}

Sample C code for compressing (note: byte order in stream is low to high):
uint16_t fns_coord2buf_compressed(float ref_deg)
{
	const float deg_round = roundf(ref_deg);
	const bool deg_odd = ((int)deg_round) & 1;
	const float decimal = ref_deg - deg_round;
	int dec_int = (int)(decimal*32767.0f);
	clamp(dec_int, -16383, 16383);

	return ((dec_int&0x7FFF) | (!!deg_odd<<15));
}


Absolute:
[Byte 0-2]	Position	(Little Endian, 2-Complement)
bit 0-23	Latitude
[Byte 3-5]	Position	(Little Endian, 2-Complement)
bit 0-23	Longitude

			Details:
			Latitude = value_lat/93206	\in [-90, +90]
			Longitude = value_lon/46603 \in [-180, +180]
			(Note: 32bit floating point is required for direct conversion)


------------

Signature (symmetric)

Use SHA1 and iterate over pseudo header (first 4 byte:  type + source address, were bits 6 and 7 of byte 0 are set to 0), over the payload, and over a pre-shared secret/key.
The first 4 byte of the resulting hash shall be interpreted as 32bit integer and put into the signature field (= normal order due to little endian encoding).

------------

//todo address detection, etc...
//todo: as a base station is in rage, do not forward tracking info. only forward tracking info if very little traffic is present...
//todo: forward bit for type 1 should only be set it no inet gateway in in close range

Notes:
------
Version number:
We omitted a bit field that shows the protocol version as this would take to much space. The app layer should provide this, if required. (Todo)

Device ID:
-For unregistered Devices/Manufacturers: Set the Manufacturer to 0xFC or 0xFD and choose a random ID between 0x0001 and 0xFFFE.
List on the channel if the id is already used.
-0xFE shall be used for multicast (E.g. competition/group messaging).
-The manufacturers 0x00 and 0xFF as well as the IDs 0x0000 and 0xFFFF are reserved.


Manufacturer IDs:
0x00		[reserved]
0x01		Skytraxx
0x03		BitBroker.eu
0x04		AirWhere
0x05		Windline
0x06		Burnair.ch
0x07		SoftRF
...
0x11		FANET+ (incl FLARM. Currently Skytraxx, and Naviter)
...
0xE0		OGN Tracker
...
0xFB		Espressif based base stations, address is last 2bytes of MAC
0xFC		Unregistered Devices
0xFD		Unregistered Devices
0xFE		[Multicast]
0xFF		[reserved]

Reserved for compatibility issues:
0xDD
0xDE
0xDF
0xF0
0x20
*/
