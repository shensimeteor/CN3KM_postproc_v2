#! /usr/bin/perl 
use File::Copy;
#v2 contains:
#update, sishen, 20170713, add subdomain plot (require postproc.subdom.pl--same format with verif_sfcobs.input.pl)
#update, sishen, 20170716, move process_qc_out_SfcObs & cpto bank earlier 
#update, sishen, 20170717, add cmdline opts (-noplotobs, -nothinobs); adopt clean_datedir from 3KMT; use tool_file_wait_sizeconverge, to avoid emprical waiting seconds
#update, sishen, 20171002, remove plot WRF_F SFC+OBS (moved to verif_SFC_OBS)

#==============================================================================#
# 1. Define inputs
#==============================================================================#
  system ("date");
  #----------------------------------------------------------------------------#
  # 1.0 Parse arguments
  #----------------------------------------------------------------------------#
  $plot_OBS="True";
  $thin_OBS="True";
  if (! $ARGV[0] || $ARGV[0] eq "--" || $ARGV[0] eq "-h") {
     print "\nrtfdda_postproc_aux3_run_v2.pl  <-id GMID>  <-m MEMBER>  <-c cycle | -o offset_hr>  [<-s start_forecast_hour>]  [<-e end_forecast_hour>]  [<-noplotobs>]  [<-nothinobs>] \n";
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
              $THIS_CYCLE = sprintf("%04d%02d%02d%02d",$yy,$mo+1,$dd,$hh);
          }elsif ($ARGV[$i] eq "-s"){
              $START_FCST = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-e"){
              $END_FCST = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-m"){
              $MEM_NAME = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-id"){
              $JOB_ID = $ARGV[$i+1];
          }elsif ($ARGV[$i] eq "-noplotobs"){
              $plot_OBS="False";
          }elsif ($ARGV[$i] eq "-nothinobs"){
              $thin_OBS="False";
          }else{
              next;
          }
      }
  }


  #----------------------------------------------------------------------------#
  # 1.1 Default values
  #----------------------------------------------------------------------------#
  if (!"$THIS_CYCLE" || !"$MEM_NAME" || !"$JOB_ID") { 
        exit(-1);
  }

  if ("$END_FCST"<"$START_FCST") {
    print "END_FCST should be lower than START_FCST ($END_FCST < $START_FCST) ==> EXIT";
        exit(-1);
  }

  $ttime = time - 0 *3600;
  ($sec,$mm,$hh,$dd,$mm,$yy,@_) = gmtime($ttime);

  if ($yy<50){
        $yy+=2000;
  } else {
    $yy+=1900;
  }

  if ( $MM5MPP eq "yes" && ! $THIS_CYCLE ) {
    # Force a 3-hr cycle time
    $NOW_CYCLE =      sprintf("%04d%02d%02d%02d",$yy,$mm+1,$dd,$hh) if(! $THIS_CYCLE);
    $rh = ($hh-2)%3;
    $THIS_CYCLE = &hh_advan_date( $NOW_CYCLE, -$rh);
  } else {
    $THIS_CYCLE =      sprintf("%04d%02d%02d%02d",$yy,$mm+1,$dd,$hh) if(! $THIS_CYCLE);
  }

  system "ssh node1 killall ncl";

  #----------------------------------------------------------------------------#
  # 1.2 User's inputs
  #----------------------------------------------------------------------------#
  $OLD              = 0;
  $SLEEP_TIME       = 120;
  $FINAL_SLEEP_TIME = 120;
  $every_hour       = 1;
  #$every_cycle      = 6;
  $RANGE            = "GRM";
  $DEBUG            = 1;
  $KEEP_CYCLE       = 0;
  $plot_ncl         = "True";
  $rename_file      = "False";
  $get_KF           = "False";#"True";
  $get_farm         = "False";
  $station_KF       = "station_liste";     
  $do_vdras         = "False";
  $get_verif        = "False";
  $get_SFC          = "False";

  #----------------------------------------------------------------------------#
  # 1.3 Parameters
  #----------------------------------------------------------------------------#
  #$ram_disk   = "/dev/shm/";
  @SEASONS    = ( 'winter', 'winter', 'winter', 'summer', 'summer', 'summer', 'summer', 'summer', 'summer', 'summer', 'winter', 'winter');
  $MYLOGIN    = $ENV{'LOGNAME'};
  $HOMEDIR    = "/home/$MYLOGIN";
  $RUNDIR     = "$HOMEDIR/data/cycles/$JOB_ID/$MEM_NAME";
  $GSJOBDIR   = "$HOMEDIR/data/GMODJOBS/$JOB_ID";
  $DIR_PAIR   = "$RUNDIR/veri_dat/sfc/fcst";
  $DIR_LOG    = "$HOMEDIR/data/cycles/$JOB_ID/zout";
  $mylogdir = "$DIR_LOG/postproc/cyc$THIS_CYCLE";
  system("test -d $mylogdir || mkdir -p $mylogdir");

  # code and run-time directories
  $MM5HOME            = "$HOMEDIR/fddahome";
  $POSTPROCS_DIR      = "$MM5HOME/cycle_code/POSTPROCS";
  $WORK_DIR           = "$RUNDIR/postprocs";
  $MustHaveDir        = "/home/$ENV{LOGNAME}/bin/musthavedir";
  $READV3             = "$HOMEDIR/datbin/readv3";
  $CSH_ARCHIVE       =  "$MM5HOME/cycle_code/CSH_ARCHIVE";
#  $ENSPROCS           = "$ENV{CSH_ARCHIVE}/ncl";
  $ENV{CSH_ARCHIVE}   = "$CSH_ARCHIVE";
  $ENSPROCS           = "$CSH_ARCHIVE/ncl";
  $DIR_KF             = "$WORK_DIR";
  $LOC_WEB_DIR        = "$RUNDIR/postprocs/web";

  # Pair files parameters
  $cycle_length = 25;
  $nbytes       = 56;
  $missing      = -8888;

  #----------------------------------------------------------------------------#
  # 1.4 Read these from the configuration file
  #----------------------------------------------------------------------------#
  if (! -e "$GSJOBDIR/ensprocinput.pl") {
        print "\nERROR: Cannot find file $GSJOBDIR/ensprocinput.pl\n\n";
        exit -1;
  }else{
    require "$GSJOBDIR/ensprocinput.pl";
  }
  require ("$ENSPROCS/common_tools.pl");

  require "$GSJOBDIR/flexinput.pl";
  require "$GSJOBDIR/postproc.subdom.pl"; #

  $RUNDIR     = "$HOMEDIR/data/cycles/$JOB_ID/$MEM_NAME";
  # Domain parameters
  $NDOMAINS     = $NUM_DOMS;
  @domains      = (2); #only plot domain2
  $CHECK_DOMAIN = 2;

  $FINAL_TIME_STEPS  = $CYC_INT*60.0 / $OUT_INT + $FIN_END + 1;
  $PRELIM_TIME_STEPS = $FCST_LENGTH*60.0 / $OUT_INT ;
  $every_cycle       = $CYC_INT;
  $END_FCST  = $FCST_LENGTH;

  if ( !"$START_FCST" ) {
        $START_FCST = -1*$every_cycle;
  }
  if ( !"$END_FCST" ) {
        $END_FCST = 26;
  }

  if ("$START_FCST">=-6 &&"$START_FCST"<=78) {
        $START_DATE = &hh_advan_date( $THIS_CYCLE, $START_FCST);
  }else{
        $START_DATE = "$START_FCST";
  }

  if ("$END_FCST">=-6 &&"$END_FCST"<=78) {
        $END_DATE = &hh_advan_date( $THIS_CYCLE, $END_FCST);
  }else{
        $END_DATE = "$END_FCST";
  }

  #----------------------------------------------------------------------------#
  # 1.5 Create postprocinput files
  #----------------------------------------------------------------------------#
  print("$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl");
  if ( -e  "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl" ) {
    require "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl";
  } else {
    if (! -e "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME") {mkdir "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME"}
    if ("$MEM_NAME"=~/_M/) {
        $MODPOST_DIR = "MM5POST";
    }elsif ("$MEM_NAME"=~/_W/) {
        $MODPOST_DIR = "WRFPOST";
    }
    if ( -e "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MODPOST_DIR/") {
        system("ln -sf $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MODPOST_DIR/Mdomain\*.GRM $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/");
        system("ln -sf $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MODPOST_DIR/conv2gif_GRM.pl $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/");
        system("cp $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MODPOST_DIR/postprocinput.pl $HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/");
        open(POST,"<$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl") || die "Cannot open postprocinput.pl for reading: $!";
            undef @stock_line;
                while (<POST>) {
                $line = "$_";
                if ("$line" =~ /DEST_SERVER/) {
                    $line = "\$DEST_SERVER = \"smac-c4-int1\";\n";
                }
                if ("$line" =~ /JOB_LOC/) {
                    $line = "\$JOB_LOC = \"/www/htdocs/images/ens/${JOB_ID}/${MEM_NAME}/\";\n";
                }
                        push(@stock_line,$line);
                }
        close (POST) || die "Cannot close postprocinput.pl: $!";
        open(POST2,">$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl") || die "Cannot open postprocinput.pl for writing: $!";
                print POST2 @stock_line;
        close (POST2) || die "Cannot close postprocinput.pl: $!";

        require "$HOMEDIR/data/GMODJOBS/$JOB_ID/postprocs/$MEM_NAME/postprocinput.pl";

    }else{
        print " Required configuration file $MODPOST_DIR/postprocinput.pl is missing ==> EXIT\n";
        exit 1;
    }
  }

  #----------------------------------------------------------------------------#
  # 1.6 Set environment vars for other scripts
  #----------------------------------------------------------------------------#
  $NCARG_ROOT        = "$ENV{NCARG_ROOT}";
  $ENV{'NCARG_LIB'}  = "${NCARG_ROOT}/lib";
  $ENV{'MM5HOME'}    = $MM5HOME;
  $ENV{'RUNDIR'}     = $RUNDIR;
  $ENV{'DATADIR'}    = $DATADIR;
  $ENV{'DATA_DIR'}   = $DATADIR;
  $ENV{'NCARG_RANGS'}   = "/opt/ncl/rangs/";
  
  $LD_LIBRARY_PATH   = "$ENV{LD_LIBRARY_PATH}";
  #$ENV{'LD_LIBRARY_PATH'} = "$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/runtime/glnxa64:$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/bin/glnxa64:$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/sys/os/glnxa64:$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/sys/java/jre/glnxa64/jre/lib/amd64/native_threads:$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/sys/java/jre/glnxa64/jre/lib/amd64/server:$CSH_ARCHIVE/ncl/ankf_exe/MCRInstaller64/v81/sys/java/jre/glnxa64/jre/lib/amd64:$LD_LIBRARY_PATH";

  #----------------------------------------------------------------------------#
  # 1.7 RIP settings
  #----------------------------------------------------------------------------#
  if ( $IS_WRF ) {
    $RIPDP_EXE = "$MM5HOME/cycle_code/EXECUTABLE_ARCHIVE/ripdp_wrf";
    $RIPDP_OBS = "$MM5HOME/cycle_code/EXECUTABLE_ARCHIVE/ripdp_wrf";
  }else{
    $RIPDP_EXE = "$MM5HOME/cycle_code/EXECUTABLE_ARCHIVE/ripdp_mm5";
    $RIPDP_OBS = "$MM5HOME/cycle_code/EXECUTABLE_ARCHIVE/ripdp_obs.exe";
  }
  $RIP_EXE = "$MM5HOME/cycle_code/EXECUTABLE_ARCHIVE/rip4.exe";
  $ENV{'STATIONLIST'} = "$MM5HOME/cycle_code/CONSTANT_FILES/RIP4/stationlist";
  $ENV{'RIP_ROOT'} = "$MM5HOME/cycle_code/CONSTANT_FILES/RIP4";
  $RIP_ROOT = "$MM5HOME/cycle_code/CONSTANT_FILES/RIP4";
  $ENV{'HIRESMAP'}   = "$RIP_ROOT/${RANGE}_map.ascii";
  $ENV{'RANGEMAP'}   = "$RIP_ROOT/${RANGE}_map.ascii";

  #----------------------------------------------------------------------------#
  # 1.8 Make directories
  #----------------------------------------------------------------------------#
  $cnt = 0;
  while ( ! -e $RUNDIR && $cnt < 100 ) {
        $cnt++;
    sleep (30);
  }
  if ( ! -e $RUNDIR ) {
    print ( " RUNDIR does not exist!  $RUNDIR \n");
    exit (1);
  }

  # Make the working directory
  system("$MustHaveDir $WORK_DIR");

  # Make the web-dest-dir ---- this will not work for some web-dest hosts!
  $mkdir_command = "mkdir -p $JOB_LOC";
  system( "$mkdir_command" );

#==============================================================================#
# 2. Get data
#==============================================================================#
  #----------------------------------------------------------------------------#
  # 2.1 Check critic.time
  #----------------------------------------------------------------------------#
  $colds = 0;
  $CRITICAL_TIME_FILE = "$RUNDIR/critic.time";
  open(CRITIC, $CRITICAL_TIME_FILE);
        $time_max = <CRITIC>;
  close(CRITIC); 
  chomp($time_max);

  if ($OLD == 0) {
    if( ($time_max == 0) || (! $time_max) ){
        &debug($DEBUG, "Previous cycle failed and $THIS_CYCLE is not good for cold-start\n");
#        exit(0);
    }elsif( $time_max == 1 ){
        &debug($DEBUG, "Previous cycle failed and $THIS_CYCLE is a cold-start\n");
        $colds = $colds + 1;
    }else{
        &debug($DEBUG, "The cycle $THIS_CYCLE is a normal cycle\n");
    }
  }

  #----------------------------------------------------------------------------#
  # 2.2 Check previous cycle
  #----------------------------------------------------------------------------#
  $PREVIOUS_CYCLE = &hh_advan_date($THIS_CYCLE, -1 * $every_cycle);
  if (! -e "$RUNDIR\/$PREVIOUS_CYCLE") {
    $colds = $colds + 1;
  }

  #----------------------------------------------------------------------------#
  # 2.3 Get the domain
  #----------------------------------------------------------------------------#
  $this_domain = $CHECK_DOMAIN;

  #----------------------------------------------------------------------------#
  # 2.4 Go to working directory
  #----------------------------------------------------------------------------#
  $DIR_SFC = "$WORK_DIR\/";
  system("$MustHaveDir $WORK_DIR");
  $WORK_DIR = "$WORK_DIR\/cycle";
  system("$MustHaveDir $WORK_DIR");
  $WORK_DIR = "$WORK_DIR\/$THIS_CYCLE";
  system("$MustHaveDir $WORK_DIR");
  chdir "$WORK_DIR";

  $ram_disk = "/dev/shm/";
  if (-d "$ram_disk") {
    $tempdir = "$ram_disk/postprocs/";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${JOB_ID}";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${MEM_NAME}";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${THIS_CYCLE}";
    system("$MustHaveDir $tempdir");
    &clean_dir_except("$tempdir/../", ($THIS_CYCLE));
  }elsif (-d "$loc_disk") {
    $tempdir = "$loc_disk/postprocs/";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${JOB_ID}";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${MEM_NAME}";
    system("$MustHaveDir $tempdir");
    $tempdir = "$tempdir/${THIS_CYCLE}";
    system("$MustHaveDir $tempdir");
    &clean_dir_except("$tempdir/../", ($THIS_CYCLE));
  }else{
    $tempdir = "$WORK_DIR";
    system("$MustHaveDir $WORK_DIR");
  }

  if (! -e  "${DIR_SFC}\/process") {mkdir "${DIR_SFC}\/process";}
  if (! -e  "${DIR_SFC}\/process\/files") {mkdir "${DIR_SFC}\/process\/files";}
  if (! -e  "${DIR_SFC}\/process\/qc") {mkdir "${DIR_SFC}\/process\/qc";}
  if (! -e  "${DIR_SFC}\/process\/obs") {mkdir "${DIR_SFC}\/process\/obs";}
  if (! -e  "${DIR_SFC}\/process\/fcst") {mkdir "${DIR_SFC}\/process\/fcst";}

#==============================================================================#
# 3. Start processing each date
#==============================================================================#
  #----------------------------------------------------------------------------#
  # 3.1 Initialize
  #----------------------------------------------------------------------------#
  print "\n=============================================================================";
  print "\n\nProcess cycle ${THIS_CYCLE}\n";

  $n = 0;
#  $first_date     = &hh_advan_date($THIS_CYCLE, -1 * $every_cycle);
#  $second_date    = &hh_advan_date($first_date, $every_hour);
  $first_forecast = "$THIS_CYCLE";#&hh_advan_date($THIS_CYCLE, -1 * $every_hour);#"$THIS_CYCLE";
  $first_date     = &hh_advan_date($first_forecast, -1 * $every_cycle);
  $second_forecast = &hh_advan_date($first_forecast, $every_hour);
  $d              = $START_DATE;
  $nbdd           = 0;

  system("$MustHaveDir $LOC_WEB_DIR");
  $OBS_WEB_DIR = "$LOC_WEB_DIR/obs/";
  system("$MustHaveDir $OBS_WEB_DIR");

  $NCL_WEB_DIR = "$LOC_WEB_DIR/gifs/";
  system("$MustHaveDir $NCL_WEB_DIR");
  $NCL_WEB_DIR2="$LOC_WEB_DIR/cycles/$THIS_CYCLE/";
  system("$MustHaveDir $NCL_WEB_DIR2");

  $SFC_WEB_DIR = "$LOC_WEB_DIR/process/";
  system("$MustHaveDir $SFC_WEB_DIR");
  $SFC15_WEB_DIR = "$LOC_WEB_DIR/process2/";
  system("$MustHaveDir $SFC15_WEB_DIR");

  &clean_dir ("$DIR_SFC/cycle/",2);
  &clean_dir ("$DIR_SFC/$JOB_ID/",16);

  #do process_qc_out_SfcObs first
  if($thin_OBS eq "True") {
      print("to wait_qcout_or_wrff --- \n");
      $stat = &wait_qcout_or_wrff("$RUNDIR/$THIS_CYCLE", $first_date, $first_forecast, 20, 60); #wait max 20 minutes
      $d=$first_date; 
      SFCOBS: while("$d" <= "$first_forecast") {
          print "\ndo process_qc_out_SfcObs \n";
          #test to cp out
          $dir_thin_cpout=$LOC_WEB_DIR;
          #sishen, prepare thinned obs
          $com_obs = "${GSJOBDIR}/process_qc_out_SfcObs.pl $THIS_CYCLE $d $d 3 $JOB_ID $MEM_NAME $tempdir/../ >& $mylogdir/zobs.sfcobs.$d";
          print("$com_obs \n");
          system("date");
          system ("$com_obs");
          system("date");
          for $domi (1..3) {
              #cp thined obs, for use of verification 
              $thined_obs_file="$tempdir/$d/obs_thin/d$domi/$d.hourly.obs_sgl.nc";
              $dir_thined_obs_bank="$LOC_WEB_DIR/../thined_obs/d${domi}";
              system("test -d $dir_thined_obs_bank || mkdir -p $dir_thined_obs_bank");
              system("mv $thined_obs_file $dir_thined_obs_bank/");
          }
          system("rm -rf $tempdir/$d");
          $d=&hh_advan_date($d, 1);
      }
  }
  $d=$START_DATE;
  #----------------------------------------------------------------------------#
  # 3.2 Start loop over each date
  #----------------------------------------------------------------------------#
  DATE: while ("$d" <= "$END_DATE") {
      print "\n";
      print "=======================================================================";
      system ("date");
      print "\n  ==> Process date $d\n";

      if ("$plot_OBS" eq "True" && "$d" <= "$first_forecast") {
          $DIR_SPD = "$tempdir/${d}/ncl_OUTPUTS/stations/";
          system("$MustHaveDir $tempdir/${d}/");
          system("$MustHaveDir $tempdir/${d}/ncl_OUTPUTS/");
          system("$MustHaveDir $tempdir/${d}/ncl_OUTPUTS/stations/");
          $com_obs = "${GSJOBDIR}/process_qc_out.pl $THIS_CYCLE $d $d 2 $JOB_ID $OBS_WEB_DIR $DIR_SPD";
          print "\n$com_obs\n";
          system ("date");
          system ("$com_obs >& $mylogdir/zobs_${THIS_CYCLE}_$d.log");
          system ("date");
      }
  #----------------------------------------------------------------------------#
  # 3.3 Check working dir and count number of date
  #----------------------------------------------------------------------------#
      #$WORK_DIR_STEP = "${WORK_DIR}/${d}";
      $WORK_DIR_STEP = "$tempdir/${d}";
      system("$MustHaveDir $WORK_DIR_STEP");
      chdir "$WORK_DIR_STEP";
      # Count number of date processed
      $n ++;
      $init_size = 0;

  #----------------------------------------------------------------------------#
  # 3.4 Get filename
  #----------------------------------------------------------------------------#
      if ( $IS_WRF ) {
          $model_out_name = "wrfout_d0";
          $dir_name_s = "WRF";
      }else{
          $model_out_name = "mm5out_d0";
          $dir_name_s = "MM5";
      }
          # Add a tag for analysis or forecast
      if ($d <=$first_forecast) {
          $end_file = ".${MEM_NAME}_F";
          $dir_name_e  = "_F";
          $type = "F";
      }else {
          $end_file = ".${MEM_NAME}_P+FCST";
          $dir_name_e  = "_P";
          $type = "P+FCST";
      }
      if ($OLD > 0) {
          $dir_name = "";
      }else{
          $dir_name = "${dir_name_s}${dir_name_e}";
          $end_filebis = "$end_file";
          $end_file = "";
      }

      $SUFFIX = &time_suffix($d);

      $filename="$RUNDIR/$THIS_CYCLE/$dir_name/auxhist3_d0${this_domain}$SUFFIX";
#==============================================================================#
# 4. Process the first date
#==============================================================================#
      &debug($DEBUG, "Waiting for file ${filename}\n");
      $flag=&tool_file_wait(30,60,$filename);  #make sure $filename exist
      $flag=&tool_file_wait_sizeconverge($filename,1000,10,2,1); #make sure its size converges
      if ( $flag =~ /Fail/ ) {
          print "wait fails!";
          exit(-1);
      }else{
 #         sleep(7); #wait for file write
          foreach $dom (@domains)  {
              #reformat aux3 (similar with GECN9KME/ensproc_dom_aux3/nco_wrf_aux3)
              chdir($WORK_DIR_STEP);
              symlink("$ENSPROCS/add_files.ncl", "add_files.ncl");
              $cmd="$ENSPROCS/reformat_aux3.pl $filename aux3_reformatted.nc >& $mylogdir/aux3_reformat_${d}.log";
              print("$cmd \n");
              system("$cmd");
          }
      }
      if ( $d == $first_date ) {
          $d =  &hh_advan_date($d, $every_hour);
          next DATE;
      }

#==============================================================================#
# 8. Plot
#==============================================================================#
      $PLOTS_DIR = "$WORK_DIR_STEP/";
      our %wind_rs_done={};
      if ("$plot_ncl" eq "True" && $d <= $first_forecast ) {
            system ("date");
            print "\ndo NCL\n";
            #test to cp out
       #     $dir_thin_cpout=$LOC_WEB_DIR;
       #     #sishen, prepare thinned obs
       #     $com_obs = "${GSJOBDIR}/process_qc_out_SfcObs.pl $THIS_CYCLE $d $d 3 $JOB_ID $tempdir/../ $dir_thin_cpout>& $mylogdir/zobs.sfcobs.$d";
      #      print("$com_obs \n");
      #      system("date");
      #      system ("$com_obs");
      #      system("date");
            #
            $n_subdom=scalar(@DOM_ID);
            for ($idom=0; $idom < $n_subdom; $idom++) {
                $domid=$DOM_ID[$idom];
                $wrfdomid=$WRF_DOM_ID[$idom];
                $obsdomid=$OBS_DOM_ID[$idom];
                print("idom=$idom, domid=$domid, wrfdomid=$wrfdomid, obsdomid=$obsdomid \n");
                $thined_obs_file1="$tempdir/$d/obs_thin/d$obsdomid/$d.hourly.obs_sgl.nc";
                if( !-e $thined_obs_file1 ) {
                    $dir_thined_obs_bank="$LOC_WEB_DIR/../thined_obs/d${obsdomid}";
                    $thined_obs_file2="$dir_thined_obs_bank/$d.hourly.obs_sgl.nc";
                    system("test -d $tempdir/$d/obs_thin/d$obsdomid/ || mkdir -p $tempdir/$d/obs_thin/d$obsdomid/");
                    system("cp $thined_obs_file2 $thined_obs_file1");
                }
                print($tempdir."\n");
                #SFC_and_obs, wind_HGT, wind_RS
                #&do_plots_ncl_v2 ($PLOTS_DIR, $idom, $THIS_CYCLE, $d, $NCL_WEB_DIR, $thined_obs_file1);
                &do_plots_ncl_v2 ($PLOTS_DIR, $idom, $THIS_CYCLE, $d, $NCL_WEB_DIR);
                #Rain, WMXDBZ, CG, WLPI
                &do_plots_ncl2_v2($PLOTS_DIR, $idom, $THIS_CYCLE, $d, $NCL_WEB_DIR);
            }
      } elsif  ("$plot_ncl" eq "True" ){
            system("date");
            print "\ndo NCL\n";
            $n_subdom=scalar(@DOM_ID);
            for ($idom=0; $idom < $n_subdom; $idom++) {
                $domid=$DOM_ID[$idom];
                $wrfdomid=$WRF_DOM_ID[$idom];
                $obsdomid=$OBS_DOM_ID[$idom];
                print("idom=$idom, domid=$domid, wrfdomid=$wrfdomid, obsdomid=$obsdomid \n");
                #SFC_and_obs, wind_HGT, wind_RS
                &do_plots_ncl_v2 ($PLOTS_DIR, $idom,  $THIS_CYCLE, $d, $NCL_WEB_DIR);
                #Rain, WMXDBZ, CG, WLPI
                &do_plots_ncl2_v2($PLOTS_DIR, $idom, $THIS_CYCLE, $d, $NCL_WEB_DIR);
            }
      }
      system ("date");
      
      &clean_datedir($tempdir, 4);

      $d =  &hh_advan_date($d, $every_hour);
      $nbdd++;
  }


  #----------------------------------------------------------------------------#
  # 9.2 Exit
  #----------------------------------------------------------------------------#
  exit(0);

#==============================================================================#
# 10. Subroutines used
#==============================================================================#
  #-----------------------------------------------------------------------------
  # 10.1 Subroutine to sleep until the size of the specified file changes
  #-----------------------------------------------------------------------------
  sub wait_for_file{
        local($filename) = $_[0];
        local($sleep)    = $_[1];
        local($start_size) = $_[2];
        local($filenamebis) = $_[3];

        # Get the initial file size
        $current_size = &get_file_size($filename);
        $current_sizebis = &get_file_size($filenamebis);
        $j = 0;
        # Sleep while the file size has not changed
print "Check $filename and $filenamebis\n";
    if ($current_sizebis <= 0) {
            while( $start_size == $current_size && $j < 50) {
            sleep($sleep);
                $j++;
            $current_size = &get_file_size($filename);
            &debug($DEBUG, "    Checking file $filename $current_size\n");
            }
        if ($current_size < $start_size) {
            return $filenamebis;
        }
            $current_size = &get_file_size($filename);
            if ( $current_size > 0 ) {
                    $start_size   = $current_size;
                    $_[2]  = $current_size;
                    # Sleep until the file is no longer changing
                    $file_done = 0;
                    until ($file_done) {
                            $start_size   = $current_size;
                            sleep 15;
                            $current_size = &get_file_size($filename);
                            $file_done = ($start_size == $current_size)? 1: 0;
                    }
                    &debug($DEBUG, "About to process out file with size $current_size\n");
                    return $filename ;
            } else {
                    return 1 ;
            }
    }else{
                print "NO $filename AND $filenamebis is present\n";
                $start_size   = $current_sizebis;
                $_[2]  = $current_sizebis;
                # Sleep until the file is no longer changing
                $file_done = 0;
                until ($file_done) {
                        $start_size   = $current_sizebis;
                        sleep 30;
                        $current_sizebis = &get_file_size($filenamebis);
                        $file_done = ($start_size == $current_sizebis)? 1: 0;
                }
                &debug($DEBUG, "About to process out file with size $current_sizebis\n");
                return $filenamebis;
    }
  }

  #-----------------------------------------------------------------------------
  # 10.2 Subroutine to return the file size of the specified file
  #-----------------------------------------------------------------------------
  sub get_file_size{
        local($filename) = $_[0];

        # If the file doesn't exist, then its size is zero
        if( ! -e $filename ){
        return 0;
        }

        # Stat the file and get the size
        local(@file_info) = lstat( $filename );
        local($file_size) = $file_info[7];

        return $file_size;
  }

  #-----------------------------------------------------------------------------
  # 10.3 Subroutine to avance the date
  #-----------------------------------------------------------------------------
  # Name: hh_advan_date
  # Arguments: 1) a date as yyyymmddhh
  #            2) number of hours as an integer
  # Return: a date in 'yyyymmddhh'-form
  # Description: advances given date in 1st argument by the number of hours given
  #              in the second argument
  #----------------------------------------------------------------------------
  sub hh_advan_date {

  %mon_days = (1,31,2,28,3,31,4,30,5,31,6,30,7,31,8,31,9,30,10,31,11,30,12,31);
  (my $s_date, my $advan_hh) = @_ ;

  my $yy = substr($s_date,0,4);
  my $mm = substr($s_date,4,2);
  my $dd = substr($s_date,6,2);
  my $hh = substr($s_date,8,2);

  my $feb = 2;
  $mon_days{$feb} = 29 if ($yy%4 == 0 && ($yy%400 == 0 || $yy%100 != 0));

  $hh = $hh + $advan_hh;
  while($hh > 23) {
  $hh -= 24;
  $dd++;
  }
  while($dd > $mon_days{$mm+0}) {
  $dd = $dd - $mon_days{$mm+0};
  $mm++;
  while($mm > 12) {
  $mm -= 12;
  $yy++;
  }
  }
  while($hh < 0) {
  $hh += 24;
  $dd--;
  }
  if($dd < 1) {
  $mm--;
  while($mm < 1) {
  $mm += 12;
  $yy--;
  }
  $dd += $mon_days{$mm+0};
  }

  my $new_date = sprintf("%04d%02d%02d%02d",$yy,$mm,$dd,$hh);
  }

  #-----------------------------------------------------------------------------
  # 10.4 If the debugging information is turned on, then print the message
  #-----------------------------------------------------------------------------
  sub debug {
        $debug_on = $_[0];
        $debug_message = $_[1];

        if( $debug_on == 1 ){
        $| =1;
        print( $debug_message );
        }
  }

  #-----------------------------------------------------------------------------
  # 10.5 Subroutine do_plots_ncl_v2
  #-----------------------------------------------------------------------------
  #plot CG/WMXDBZ/RAIN/WLPI
  #v2, support subdomain,
  sub do_plots_ncl2_v2 {
        my ($workdir, $idom, $cycle, $valid_time, $dest) = @_;
        my $domid = $DOM_ID[$idom]; 
        my $wrfdomid = $WRF_DOM_ID[$idom];
        my $obsdomid = $OBS_DOM_ID[$idom];
        $file_plot_missing="$GSJOBDIR/postprocs/no_plots.gif"; #if exist, thenln -sf non-plot-time
        system("$MustHaveDir $workdir");
        system("$MustHaveDir $workdir/ncl_OUTPUTS2");
        system("$MustHaveDir $workdir/ncl_OUTPUTS2/d0${domid}");
        chdir ($workdir);
        $fn="aux3_reformatted.nc";
        chdir("$workdir/ncl_OUTPUTS2/d0${domid}");
        #link existing aux3 here
        @MDL=`ls $workdir/../`;
        @MDL1=sort @MDL;
        foreach $d (@MDL1) {
            chomp($d);
            if ( $d <= $valid_time ){
                $aux_fn=&tool_date12_to_outfilename("auxhist3_d0${wrfdomid}_","${d}00","");
                symlink("$workdir/../$d/$fn", "$workdir/ncl_OUTPUTS2/d0${domid}/$aux_fn");
            }
        }
        #link ncl
        chdir("$workdir/ncl_OUTPUTS2/d0${domid}/");
        symlink("$ENSPROCS/plot_SFC_and_obs_CG.ncl", "plot_SFC_and_obs_CG.ncl");
        symlink("$ENSPROCS/plot_SFC_and_obs_SW.ncl", "plot_SFC_and_obs_SW.ncl");
        symlink("$ENSPROCS/plot_SFC_and_obs_RR1h.ncl", "plot_SFC_and_obs_RR1h.ncl");
        symlink("$ENSPROCS/plot_SFC_and_obs_WLPI.ncl", "plot_SFC_and_obs_WLPI.ncl");
        symlink("$ENSPROCS/plot_SFC_and_obs_WMXDBZ.ncl", "plot_SFC_and_obs_WMXDBZ.ncl");
        #plot
        $fda=&tool_date12_to_outfilename("auxhist3_d0${wrfdomid}_", "${valid_time}00", "");
        while (`ps -ef | grep "ncl.*\.ncl" | grep -v grep |wc -l` > 10) {
            sleep 2;
            print "wait to submit ncl ++  ";
        }
        chomp($fda);
        $hau = substr($valid_time, 8,2);
        $mau = substr($fda,29,2);
        $file_date= &tool_outfilename_to_date12($fda);
        system("test -d $file_date || mkdir -p $file_date");
        #
        if($DOM_LAT1[$idom] < 0) {
            $iszoom="False";
        }else{
            $iszoom="True";
        }
        $subdom_para=qq('dom=${domid}' 'zoom="$iszoom"' 'latlon="True"' 'lat_s=$DOM_LAT1[$idom]' 'lon_s=$DOM_LON1[$idom]' 'lat_e=$DOM_LAT2[$idom]' 'lon_e=$DOM_LON2[$idom]');
        $ncl = "ncl 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_CG.ncl >& plot_SFC_CG.log &";
        print "\nNCL: $ncl\n";
        system "$ncl";
        $ncl = "ncl 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_WMXDBZ.ncl >& plot_SFC_WMXDBZ.log &";
        print "\nNCL: $ncl\n";
        system "$ncl";
        $ncl = "ncl 'rrh=1' 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_RR1h.ncl >& plot_SFC_RR1h.log &";
        print "\nNCL: $ncl\n";
        system "$ncl";
        $ncl = "ncl 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_SW.ncl >& plot_SFC_SW.log &";
        print "\nNCL: $ncl\n";
        system "$ncl";
        if ("$hau" == 0 || "$hau" == 3 || "$hau" == 6 || "$hau" == 9 || "$hau" == 12 || "$hau" == 15 || "$hau" == 18 || "$hau" == 21) {
            $ncl = "ncl 'rrh=3' 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_RR1h.ncl >& plot_SFC_RR3h.log &";
            print "\nNCL: $ncl\n";
            system "$ncl";
            $ncl = "ncl 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_WLPI.ncl >& plot_SFC_WLPI.log &";
            print "\nNCL: $ncl\n";
            system "$ncl";
        } else{
            symlink("$file_plot_missing", "$file_date/d${domid}_RAW_RR3H.gif");
            symlink("$file_plot_missing", "$file_date/d${domid}_RAW_WLPI.gif");
        }
        if ("$hau" == 0 || "$hau" == 6 || "$hau" == 12 || "$hau" == 18) {
            $ncl = "ncl 'rrh=6' 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_RR1h.ncl >& plot_SFC_RR6h.log &";
            print "\nNCL: $ncl\n";
            system "$ncl";
        } else{
            symlink("$file_plot_missing", "$file_date/d${domid}_RAW_RR6H.gif");
        }
        if ("$hau" == 0 || "$hau" == 12) {
            $ncl = "ncl 'rrh=12' 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_RR1h.ncl >& plot_SFC_RR12h.log &";
            print "\nNCL: $ncl\n";
            system "$ncl";
        } else{
            symlink("$file_plot_missing", "$file_date/d${domid}_RAW_RR12H.gif");
        }
        if ("$hau" == 0) {
            $ncl = "ncl 'rrh=24' 'file_in=\"$fda\"' $subdom_para plot_SFC_and_obs_RR1h.ncl >& plot_SFC_RR24h.log &";
            print "\nNCL: $ncl\n";
            system "$ncl";
        } else{
            symlink("$file_plot_missing", "$file_date/d${domid}_RAW_RR24H.gif");
        }
        #wait until ncl finish
        $wait_count=0; $max_wait=100; 
        while (`ps -ef | grep "ncl.*plot_SFC_and_obs\_.*\.ncl" | grep -v "grep" |wc -l` > 0) {
            print qq( -ef | grep "ncl.*plot_SFC_and_obs\_.*\.ncl" | grep -v);
            print `ps -ef | grep "ncl.*plot_SFC_and_obs\_.*\.ncl" | grep -v "grep"`; 
            sleep 2;
            $wait_count++;
            print " wait++";
            last if($wait_count > $max_wait);
        }           
        #mv to dest (convert_to_gif has occurred in NCL already)
        foreach $dir (`ls -d 20*`) {
            chomp($dir);
            #
            $ymdh=substr($dir, 0, 10);
            system("mv $dir $ymdh");
        }
        print "to mv gifs to webdest\n";
        system("cp -rf 20* $dest/");
        system("cp -rf 20* $dest/../cycles/$cycle/");
#        system("mv *log $mylogdir/");
  }

  sub do_plots_ncl_v2 {
        my ($workdir, $idom, $cycle, $valid_time, $dest, $qcfile) = @_;
        my $domid = $DOM_ID[$idom]; 
        my $wrfdomid = $WRF_DOM_ID[$idom];
        my $obsdomid = $OBS_DOM_ID[$idom];

        system("$MustHaveDir $workdir");
        system("$MustHaveDir $workdir/ncl_OUTPUTS");
        system("$MustHaveDir $workdir/ncl_OUTPUTS/d0${domid}");
        system("$MustHaveDir $workdir/ncl_OUTPUTS/d0${domid}/upper_air");
        system("$MustHaveDir $workdir/ncl_OUTPUTS/d0${domid}/wind_energy");
        system("$MustHaveDir $workdir/ncl_OUTPUTS/stations");
        chdir "$workdir";

        $fn = "aux3_reformatted.nc";
        if ( -e $fn ) {
            chdir "$workdir/ncl_OUTPUTS/d0${domid}";
            symlink("$workdir/$fn","$workdir/ncl_OUTPUTS/d0${domid}/$fn");
            symlink("$ENSPROCS/plot_wind_height.ncl","$workdir/ncl_OUTPUTS/d0${domid}/plot_wind_height.ncl");
            symlink("$ENSPROCS/plot_wind_RS.ncl","$workdir/ncl_OUTPUTS/d0${domid}/plot_wind_RS.ncl");
            symlink("$ENSPROCS/plot_SFC_and_obs_new.ncl","$workdir/ncl_OUTPUTS/d0${domid}/plot_SFC_and_obs.ncl");
            symlink("$ENSPROCS/plot_wind_HGT.ncl","$workdir/ncl_OUTPUTS/d0${domid}/plot_wind_HGT.ncl");
            #symlink("$ENSPROCS/movexcel_to_web.csh","$workdir/ncl_OUTPUTS/movexcel_to_web.csh");
            symlink("$GSJOBDIR/ensproc/stationlist_profile_dom${wrfdomid}","$workdir/ncl_OUTPUTS/d0${domid}/stationlist_profile_dom${domid}");
            symlink("$GSJOBDIR/ensproc/stationlist_site_dom${wrfdomid}","$workdir/ncl_OUTPUTS/d0${domid}/stationlist_site_dom${domid}");
            symlink("$GSJOBDIR/ensproc/map.ascii","$workdir/ncl_OUTPUTS/d0${domid}/map.ascii");
            symlink("$GSJOBDIR/ensproc/ncl_functions/initial_mpres_d0${domid}.ncl", "$workdir/ncl_OUTPUTS/d0${domid}/initial_mpres.ncl");
            symlink("$GSJOBDIR/ensproc/ncl_functions/convert_figure.ncl", "$workdir/ncl_OUTPUTS/d0${domid}/convert_figure.ncl");
            symlink("$GSJOBDIR/ensproc/ncl_functions/convert_and_copyout.ncl", "$workdir/ncl_OUTPUTS/d0${domid}/convert_and_copyout.ncl");
                  
            $n_proc_ncl=`ps -ef | grep "ncl.*\\.ncl" | wc -l`;
            chomp($n_proc_ncl);
            print("n_proc_ncl=$n_proc_ncl\n");
            while ($n_proc_ncl > 10) {
                  sleep 2;
                  print("wait for process ncl");
                  $n_proc_ncl=`ps -ef | grep "ncl.*\\.ncl" |wc -l`;
                  chomp($n_proc_ncl);
            }
            print("\n");
            if($DOM_LAT1[$idom] < 0) {
                $iszoom="False";
            }else{
                $iszoom="True";
            }
            $subdom_para=qq('dom=${domid}' 'zoom="$iszoom"' 'latlon="True"' 'lat_s=$DOM_LAT1[$idom]' 'lon_s=$DOM_LON1[$idom]' 'lat_e=$DOM_LAT2[$idom]' 'lon_e=$DOM_LON2[$idom]');
            $ncl = "$NCARG_ROOT/bin/ncl 'cycle=\"$cycle\"' 'file_in=\"$fn\"' 'web_dir=\"$dest\"' 'optOutput=\"cycleOnly\"' $subdom_para plot_wind_HGT.ncl >& zout.nclH.d${domid}.$valid_time.log &";
            print "\n";
            print "$ncl\n";
            system "$ncl";
            sleep 5;

            if (length($qcfile) > 0) {
                  $ncl = "$NCARG_ROOT/bin/ncl 'cycle=\"$cycle\"' 'file_in=\"$fn\"' 'qcfile_sfc_in=\"$qcfile\"'  'web_dir=\"$dest\"' 'optOutput=\"cycleOnly\"' $subdom_para 'showStats=\"True\"' plot_SFC_and_obs.ncl >& zout.nclSFC.d${domid}.$valid_time.log &";
            } else {
                  $ncl = "$NCARG_ROOT/bin/ncl 'cycle=\"$cycle\"' 'file_in=\"$fn\"' 'web_dir=\"$dest\"' 'optOutput=\"cycleOnly\"' $subdom_para plot_SFC_and_obs.ncl >& zout.nclSFC.d${domid}.$valid_time.log & ";
            }
            print "\n";
            print "$ncl\n";
            system "$ncl";
            sleep 10;

            #only need once
            if( ! $wind_rs_done{$valid_time}) {
                $ncl = "$NCARG_ROOT/bin/ncl 'cycle=\"$cycle\"' 'file_in=\"$fn\"' 'dom=$domid' 'web_dir=\"$dest\"' 'optOutput=\"cycleOnly\"' plot_wind_RS.ncl  >& zout.nclRS.d${domid}.$valid_time.log &";
                print "\n";
                print "$ncl\n";
                system "$ncl";
                $wind_rs_done{$valid_time}='DONE';
            }
            chdir "$workdir";
            #unlink "$fn";
        }else {
            print " Error finding fn  $fn \n";
        }
        chdir "$workdir";
  }

  sub do_get_fcst {
        my ($workdir, $domi, $cycle, $valid_time, $dest) = @_;
        system("$MustHaveDir $workdir");
        system("$MustHaveDir $workdir\/fcst");
        system("$MustHaveDir $workdir\/fcst\/d0${domi}");
        chdir "$workdir";
    $fn = "modout_d0${domi}_0";
        if ( -e $fn ) {
        chdir "$workdir/fcst/d0${domi}";
        symlink("$workdir/$fn","$workdir/fcst/d0${domi}/$fn");
        symlink("$ENSPROCS/create_fcst.ncl","$workdir/fcst/d0${domi}/create_fcst.ncl");
                print "\n$ENSPROCS/station_liste,$workdir/fcst/d0${domi}/station_liste\n";
        symlink("$ENSPROCS/station_liste","$workdir/fcst/d0${domi}\/station_liste");
                $ncl = "$NCARG_ROOT/bin/ncl 'file_in=\"$fn\"' 'file_out=\"${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_${valid_time}.nc\"' 'dom=$domi' 'cycle=\"$cycle\"' 'stat_file=\"$station_KF\"' create_fcst.ncl >& $workdir/fcst/d0${domi}/zout.fcst.d${domi}.log ";
                print "\n";
                print "$ncl\n";
                system "$ncl";
        chdir "$workdir";
        system("$MustHaveDir $dest");
                system("$MustHaveDir $dest\/KF");
            system("$MustHaveDir $dest\/KF\/fcst");
            system("$MustHaveDir $dest\/KF\/fcst\/${cycle}");
        if (-e "$workdir/fcst/d0${domi}\/${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_${valid_time}.nc") {
            symlink("$workdir/fcst/d0${domi}\/${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_${valid_time}.nc","${dest}\/KF\/fcst\/${cycle}\/${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_${valid_time}.nc");
        }
        }else {
                print " Error finding fn  $fn \n";
        }
    chdir "$workdir";
  }

  sub fcst2nc {
        my ($domi, $cycle, $dest) = @_;
        system("$MustHaveDir $dest");
        system("$MustHaveDir $dest\/KF");
        system("$MustHaveDir $dest\/KF\/fcst");
        system("$MustHaveDir $dest\/KF\/fcst\/${cycle}");
    chdir "$dest\/KF\/fcst\/${cycle}";
    symlink("$ENSPROCS/create_nc_fcst.ncl","$dest\/KF\/fcst\/${cycle}\/create_nc_fcst.ncl");
        @fkf   = `ls ${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_\*.nc`;
    @fkf   = sort @fkf;
    foreach $fk (@fkf) {
            chomp($fk );
            push(@allfk, $fk);
    }
        if ($#fkf > 0) {
        $nco = "ncrcat @allfk -o ${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_all.nc";
                print "$nco\n";
                system "$nco";
        $chr = substr($cycle,8,2);
        $ncl = "ncl 'file_in=\"${JOB_ID}_${MEM_NAME}_d0${domi}_${cycle}_all.nc\"' 'file_out=\"${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc\"' 'dom=$domi' 'cycles=\"$cycle\"' create_nc_fcst.ncl >& $dest\/KF\/fcst\/${cycle}/zout.ncfcst.d${domi}.log ";
                print "$ncl\n";
                system "$ncl";
        system ("mv ${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc $dest\/KF\/fcst\/");
    }else{
        print "No files found in $dest\/KF\/fcst\/${cycle} \n";
    }
  }

  sub all2nc {
        my ($domi, $cycle, $dest) = @_;
        chdir "$dest\/KF\/";
    $chr = substr($cycle,8,2);
    print "\n\n$dest\/KF\/obs\/${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc $dest\/KF\/fcst\/${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc\n\n\n";
    if (-e "$dest\/KF\/obs\/${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc" && -e "$dest\/KF\/fcst\/${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc") {
            symlink("$dest\/KF\/fcst\/${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc","$dest\/KF\/${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc");
            symlink("$dest\/KF\/obs\/${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc","$dest\/KF\/${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc");
        $nco = "ncrcat -O ${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc ${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc -o ${MEM_NAME}_d0${domi}_all${chr}Z.nc";
            print "\n$nco\n";
            system "$nco";
            unlink "${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc";
            unlink "${MEM_NAME}_d0${domi}_fcst_all${chr}Z.nc";
        $nco2 ="ncatted -a _FillValue,,m,f,-999 ${MEM_NAME}_d0${domi}_all${chr}Z.nc";
                print "\n$nco2\n";
                system "$nco2";
                $nco3 ="ncatted -a missing_value,,c,f,-999 ${MEM_NAME}_d0${domi}_all${chr}Z.nc";
                print "\n$nco3\n";
                system "$nco3";
    }
  }

  sub doKF {
        my ($domi, $cycle, $dest) = @_;



  }

  sub pair2nc {
        my ($pairdata, $domi, $cycle, $outdir) = @_;
    my $pfile = "${cycle}_veri_dat_${MEM_NAME}_P+FCST";
    chmod($pairdata);
    system("$MustHaveDir $outdir");
    system("$MustHaveDir $outdir\/KF");
        system("$MustHaveDir $outdir\/KF\/obs");
        system("$MustHaveDir $outdir\/KF\/obs\/${cycle}");
    if (-e "$pairdata\/$pfile")  {
        chdir ("$outdir\/KF\/obs\/${cycle}");
        symlink("$pairdata\/$pfile","$outdir\/KF\/obs\/${cycle}\/$pfile");
        symlink("$ENSPROCS/create_nc.ncl","$outdir\/KF\/obs\/${cycle}\/create_nc.ncl");
        symlink("$ENSPROCS/${station_KF}","$outdir\/KF\/obs\/${cycle}\/${station_KF}");     

  #----------------------------------------------------------------------------#
  # Open output ascii file
  #----------------------------------------------------------------------------#
            $out = "obs_fcst_all_${cycle}.asc";
            open(OUT,">$out") || die "Cannot open $out for writing";

  #----------------------------------------------------------------------------#
  # Check input binary file
  #----------------------------------------------------------------------------#
            if (!-e $pfile) {
                    print "$pfile is missing --> NEXT\n";
                    next;
            }else{

  #----------------------------------------------------------------------------#
  # Read input binary file
  #----------------------------------------------------------------------------#
                    $mmdd = substr(${cycle},4,4);
                    open(IN,"$pfile") || die "Cannot open $pfile for reading";
                        seek(IN,0,0);
                    while (read(IN,$buf,$nbytes) > 0) {
                            seek(IN,0,1);
                            ($year,$monthday,$hourmin,$lat,$lon,$domain_id,$platform,
                            $psfc_m,$psfc_o,$psfc_qc,
                            $slp_m,$slp_o,$slp_qc,
                            $ter_m,$ter_o,
                            $t_m,$t_o,$t_qc,
                            $q_m,$q_o,$q_qc,
                            $ws_m,$ws_o,$ws_qc,
                            $wd_m,$wd_o,$wd_qc)=unpack("s6a4s20",$buf);

  #----------------------------------------------------------------------------#
  # Write output ascii file
  #----------------------------------------------------------------------------#
                            if ($domain_id == ${domi}) {
                                    print OUT "$year $monthday $hourmin $lat $lon $domain_id $t_m $t_o $t_qc $ws_m $ws_o $ws_qc $wd_m $wd_o $wd_qc $ter_m $ter_o $q_m $q_o $q_qc $psfc_m $psfc_o $psfc_qc $slp_m $slp_o $slp_qc $platform\n";
                            }
                    }
                    close (IN) || die "Cannot close $pfile";
            }
            close (OUT) || die "Cannot close $out";

        system "mv $out $outdir\/KF\/obs\/${cycle}\/$out";

  #----------------------------------------------------------------------------#
  # Use an ncl script to create the netcdf file
  #----------------------------------------------------------------------------#
        $file_nc_out = "${MEM_NAME}_d0${domi}_obs_${cycle}.nc";
        $ncl = "ncl 'cycles=(/\"$cycle\"/)' 'stat_file=\"$station_KF\"' 'file_out=\"$file_nc_out\"' 'dom=$domi' create_nc.ncl >& ncl_nc.log";
        print "\nNCL pair2nc: $ncl\n";
        system "$ncl";

  #----------------------------------------------------------------------------#
  # Clean
  #----------------------------------------------------------------------------#
        #unlink "create_nc.ncl";
        #unlink "$station_file";
        #unlink "$out";

  #----------------------------------------------------------------------------#
  # Check all file
  #----------------------------------------------------------------------------#
            chdir ("$outdir\/KF\/obs");
            symlink ("$outdir\/KF\/obs\/${cycle}\/${file_nc_out}","$outdir\/KF\/obs\/${file_nc_out}");
            $chr = substr($cycle,8,2);
            $all_obs_file = "${MEM_NAME}_d0${domi}_obs_all_${chr}Z.nc";
        if (-e "$all_obs_file") {

  #----------------------------------------------------------------------------#
  # Concatenate files
  #----------------------------------------------------------------------------#
                $concat = "ncrcat $all_obs_file $file_nc_out -o test.nc";
                print "\n$concat\n";
                system "$concat";
                        unlink "$all_obs_file";
                system "mv test.nc $all_obs_file";
            unlink "$file_nc_out";
        }else{

  #----------------------------------------------------------------------------#
  # Copy
  #----------------------------------------------------------------------------#
                system "cp $file_nc_out $all_obs_file";
                        unlink "$file_nc_out";
        }

    }else{
        print " Error finding $pfile in  $pairdata\n";
    }
  }

  #if qc_out files exist or WRF_F exist, return; else: wait until either (qc_out/WRF_F) exist
  sub wait_qcout_or_wrff {
      my ($cycle_rundir, $qcout_start_date, $qcout_end_date, $max_wait, $wait_int_sec) = @_;
      my $qcfile;
      my $qcoutdir="$cycle_rundir/RAP_RTFDDA";
      my $iwait=0;
      my $status=0; #1, exist; 0, no
      print("in wait_qcout_or_wrff --- \n");
      for ($iwait=0; $iwait < $max_wait; $iwait++){
          if ( -d "$cycle_rundir/WRF_F" ) {
              $status=1;
              $nqc=`ls -l $qcoutdir/qc_out* | wc -l `;
              print("WRF_F found, nqcout = $nqc, return\n");
          }else {
              my $d= $qcout_start_date;
              my $flag = "yes";
              while($d < $qcout_end_date) {
                 $qcfile = &tool_date12_to_outfilename("qc_out_", $d, ".0000");
                 if ( ! -e "$qcoutdir/$qcfile") {
                     $flag="no";
                     last;
                 }
                 $d=&hh_advan_date($d, 1);
              }
              if($flag eq "yes") {
                   $status=1;
                   print("qc_out all files exist, return \n");
              }
         }
         if($status == 1) {
             return "True"; #meaning WRF_F or all qc_out exist
         }else {
             print("to wait, iwait=$iwait\n");
             sleep($wait_int_sec);
         }
      }
      print("max_wait exceed, return False\n");
      return "False";
  }


  sub do_rename {
    my ($datdir,$gmid,$cycle,$type,$member) = @_;
    chdir "$datdir";
    symlink("$ENSPROCS/rename_wrf_timeseries.csh","$datdir/rename_wrf_timeseries.csh");

    $cmd = "rename_wrf_timeseries.csh $gmid $cycle $member $type >& $datdir/rename_ts.log &";
        print "\n";
        print "$cmd\n";
        system "$cmd";
  }

  #-----------------------------------------------------------------------------
  # 10.6 Subroutine link_rip: link useful files to be processed with rip
  #-----------------------------------------------------------------------------
  sub link_rip {
    my ($file_0, $file_1, $dirwork, $doma) = @_;
    print "here $file_0\n";
    print "here $file_1\n";
        print "here $dirwork \n";
    chdir "$dirwork";
    if (-e "$file_0") {
        #symlink("$file_0","$dirwork/modout_d0${doma}-1");
                copy("$file_0","$dirwork/modout_d0${doma}-1") || die "File $file_0 cannot be copied.";
    }
    if (-e "$file_1") {
        #symlink("$file_1","$dirwork/modout_d0${doma}_0");
                copy("$file_1","$dirwork/modout_d0${doma}_0") || die "File $file_1 cannot be copied.";
    }
    if (-e "$dirwork/modout_d0${doma}-1" && -e "$dirwork/modout_d0${doma}_0") {
        if ("$file_1" =~ /wrfout/) {
                    $command0 = "ncrcat -O $dirwork/modout_d0${doma}-1 $dirwork/modout_d0${doma}_0 -o $dirwork/modout_d0${doma} >& $dirwork/ncrcat_d0${doma}.log\n";
        }else{
                    $command0 = "cat $dirwork/modout_d0${doma}-1 $dirwork/modout_d0${doma}_0 > $dirwork/modout_d0${doma}\n";
        }
            print "$command0\n";
                system("$command0");
        unlink "$dirwork/modout_d0${doma}-1";
        #unlink "$dirwork/modout_d0${doma}_0";
    }elsif (-e "$dirwork/modout_d0${doma}_0" && !-e "$dirwork/modout_d0${doma}-1") {
                $command0 = "mv  $dirwork/modout_d0${doma}_0 $dirwork/modout_d0${doma} >& $dirwork/cp_d0${doma}.log\n";
                print "$command0\n";
                system("$command0");
    }
  }


  #-----------------------------------------------------------------------------
  # 10.7 Subroutine test_cold: test whether it is a cold start or not.
  #-----------------------------------------------------------------------------
  sub test_cold {
    my ($file_test) = @_;
    if ("$file_test" =~ /wrfout/) {
        @all_att = `ncks -A -x $file_test`;
        foreach $line (@all_att) {
                if ($line =~ /\: START_DATE/) {
                        @check_start = split(/value \=/,$line);
                }
                if ($line =~ /SIMULATION_START_DATE/) {
                        @sim_start = split(/value \=/,$line);
                }
        }
        $check_start_date     = $check_start[1];
        $check_sim_date       = $sim_start[1];
        chomp($check_start_date);
        chomp($check_sim_date);
        if ("$check_start_date" eq "$check_sim_date") {
            $check_cold = 1;
        }

    }else{
        $check_mm5  = `$READV3 $file_test | grep Hours`;
        @check_all  = split($check_mm5);
        if ($check_all[1] <= 1) {
            $check_cold = 1;
        }
    }
    return ($check_cold);
  }

  #-----------------------------------------------------------------------------
  # 10.8 Subroutine time_suffix: get suffix
  #-----------------------------------------------------------------------------
  sub time_suffix {
        my $dname = $_[0];
        my $yr = substr($dname,0,4);
        my $mo = substr($dname,4,2);
        my $dy = substr($dname,6,2);
        my $hr = substr($dname,8,2);
        my $vtime = "_${yr}-${mo}-${dy}_${hr}:00:00";
        return ($vtime);
  }

 sub vdras {
        my ($do_vdras, $path_in, $filewrf_in, $gmid_in, $member_in, $cycle_in, $type_in, $path_out) = @_;
    $cmd = "/raid3/special_code/vdras_code/vdras_cutter.csh $path_in $filewrf_in $gmid_in $member_in $cycle_in $type_in $path_out";
    if ("$do_vdras" eq "True") {
        print "VDRAS: $cmd\n";
        system ("$cmd >& /home/$ENV{LOGNAME}/data/GMODJOBS/$JOB_ID/zout_vdras.log&");
    }
 }

 sub cp_sfc {
    my ($do_cp_sfc, $file_in, $file_out, $dom_sfc) = @_;
    if ("$do_cp_sfc" eq "True" && $dom_sfc > 1) {
        if (-e "$file_in") {
            $com = "ncks -h -O -v HGT,XLAT,XLONG,XTIME,Times,T2,U10,V10,PBLH,PSFC,Q2,TH2 $file_in -o $file_out";
            system "$com\n";
            system ("mv $file_out $dir_out\/$file_out");
        }
    }
 }
 
 #keep recent nkeep(hours) datedir and their companion datedir used for RR1h,CG,WLPI plots, clean others
 sub clean_datedir {
     my($dir, $nkeep)=@_;
     @datedir = `ls -d $dir/2*`;
     if( scalar (@datedir) == 0) {
         return;
     }
     @rev_datedir=reverse(@datedir);
     $cnt=0;
     %hr_cnts=(1 => 0, 3 => 0, 6 => 0, 12 => 0, 24 => 0);
     for $ddir (@rev_datedir) {
         $dir_delete = 1; #default to remove
         chomp($ddir);
         $hr=`basename $ddir | cut -c 9-10`;
         chomp($hr);
         $cnt+=1;
         if ($cnt<=$nkeep) {
             $dir_delete=0;
             next;
         }
         for $h (keys(%hr_cnts)) {
             if ($hr % $h == 0) {
                 $hr_cnts{$h}+=1;
                 if($hr_cnts{$h} <= 1) {
                     $dir_delete = 0;
                 }
             }
        }
        if($dir_delete == 1) {
            $cmd="rm -rf $ddir";
            print(" in clean_datedir: $cmd \n");
            system($cmd);
        }
     }
 }

  sub clean_dir {
        my ($cleandir, $nbfi) = @_;
        @dclean = `ls -d $cleandir\/*20*`;
        $numd = @dclean;
        if ($numd > $nbfi ) {
                $ndel = $numd - $nbfi ;
                $ndel--;
                @rdirs = @dclean[0 .. $ndel];
                foreach  $rdir (@rdirs)  {
                        chomp $rdir;
                        system ("rm -rf $rdir");
                }
        }
  }
  sub clean_dir_except {
      my ($cleandir, @except_items)=@_;
      @items=`ls $cleandir`;
      for $item (@items) {
          chomp($item);
          if (grep {$_ eq $item} @except_items){
             next;
          }
          else{
             system("rm -rf $cleandir/$item");
           }
      }
  }
      

1;
