#! /usr/bin/perl 
use File::Copy;

#==============================================================================#
# 1. Define inputs
#==============================================================================#
  system ("date");

  #----------------------------------------------------------------------------#
  # 1.0 Parse arguments
  #----------------------------------------------------------------------------#
  if (! $ARGV[0] || $ARGV[0] eq "--" || $ARGV[0] eq "-h") {
    print "\nrtfdda_postproc_date.pl <-c cycle> <-s start_forecast_hour> <-e end_forecast_hour> <-m member_name> <-id GSID> -h\n";
        print " where  \n";
        print "   -c cycle:               format is YYYYMMDDhh;'\n";
        print "   -s start_forecast_hour: format is YYYYMMDDhh or integer;'\n";
        print "   -e end_forecast_hour:   format is YYYYMMDDhh or integer;'\n";
        print "   -m member_name:         format is GFS_MCTRL for example;'\n";
        print "   -id GSID:               GEDPG for example.'\n\n";
        exit(-1);
  }else{
      $length = @ARGV;
      $i = 0;
      for($i = 0; $i < $length; $i++){
          if ($ARGV[$i] eq "--"){
              last;
          }elsif ($ARGV[$i] eq "-c"){
              $THIS_CYCLE = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-o"){
              $OFFSET = $ARGV[$i+1];
              $ttime = time - $OFFSET *3600;
              ($sec,$mm,$hh,$dd,$mo,$yy,@_) = gmtime($ttime);
              if ($yy<50){ $yy+=2000; } else { $yy+=1900; }
 #             if ($hh>=0 && $hh <3) {
 #                 $hh = 2;
 #             }elsif ($hh>=3 && $hh <6) {
 #                 $hh = 5;
 #             }elsif ($hh>=6 && $hh <9) {
 #                 $hh = 8;
 #             }elsif ($hh>=9 && $hh <12) {
 #                 $hh = 11;
 #             }elsif ($hh>=12 && $hh <15) {
 #                 $hh = 14;
 #             }elsif ($hh>=15 && $hh <18) {
 #                 $hh = 17;
 #             }elsif ($hh>=18 && $hh <21) {
 #                 $hh = 20;
 #             }else{
 #                 $hh = 23;
 #             }
              $THIS_CYCLE = sprintf("%04d%02d%02d%02d",$yy,$mo+1,$dd,$hh);
          }elsif ($ARGV[$i] eq "-s"){
              $START_FCST = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-e"){
              $END_FCST = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-m"){
              $MEM_NAME = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-id"){
              $JOB_ID = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-h"){
              print "\nrtfdda_postproc_date.pl <-c cycle> <-s start_forecast_hour> <-e end_forecast_hour> <-m member_name> <-id GSID> -h\n";
              print " where  \n";
              print "   -c cycle:               format is YYYYMMDDhh;'\n";
              print "   -s start_forecast_hour: format is YYYYMMDDhh or integer;'\n";
              print "   -e end_forecast_hour:   format is YYYYMMDDhh or integer;'\n";
              print "   -m member_name:         format is GFS_MCTRL for example;'\n";
              print "   -id GSID:               GEDPG for example.'\n\n";
              exit(-1);
          }else{
              next;
          }
      }
  }

  if (!"$THIS_CYCLE") {
      $ttime = time - 0 *3600;
      ($sec,$mm,$hh,$dd,$mo,$yy,@_) = gmtime($ttime);
      if ($yy<50){ $yy+=2000; } else { $yy+=1900; }
              if ($hh>=0 && $hh <6) {
                  $hh = 0;
              }elsif ($hh>=6 && $hh <12) {
                  $hh = 6;
              }elsif ($hh>=12 && $hh <18) {
                  $hh = 12;
              }else{
                  $hh = 18;
              }
      $THIS_CYCLE = sprintf("%04d%02d%02d%02d",$yy,$mo+1,$dd,$hh);
  }

  #----------------------------------------------------------------------------#
  # 1.1 Default values
  #----------------------------------------------------------------------------#
  if (!"$THIS_CYCLE" || !"$MEM_NAME" || !"$JOB_ID") { 
        print "\nrtfdda_postproc_date.pl <-c cycle> <-s start_forecast_hour> <-e end_forecast_hour> <-m member_name> <-id GSID> -h\n";
        print " where  \n";
        print "   -c cycle:               format is YYYYMMDDhh;'\n";
        print "   -s start_forecast_hour: format is YYYYMMDDhh or integer;'\n";
        print "   -e end_forecast_hour:   format is YYYYMMDDhh or integer;'\n";
        print "   -m member_name:         format is GFS_MCTRL for example;'\n";
        print "   -id GSID:               GEDPG for example.'\n\n";
        exit(-1);
  }

  if ("$END_FCST"<"$START_FCST") {
    print "END_FCST should be lower than START_FCST ($END_FCST < $START_FCST) ==> EXIT";
        exit(-1);
  }
 
  $mylogdir="$ENV{HOME}/data/cycles/$JOB_ID/zout/postproc/cyc$THIS_CYCLE";
  system("test -d $mylogdir || mkdir -p $mylogdir");
  $mydir=$0;
  $mydir =~ /(.+\/)/;
  $mydir = $1;
  if(! $mydir) {
      $mydir=".";
  }
  print("$mydir/rtfdda_postproc_aux3_run_v2.pl @ARGV -nothinobs >& $mylogdir/zoust.postproc.log \n");
  system("$mydir/rtfdda_postproc_aux3_run_v2.pl @ARGV -nothinobs >& $mylogdir/zoust.postproc.log");
  
