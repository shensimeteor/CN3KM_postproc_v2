#! /usr/bin/perl
#usage:
#thin obs for plot_SFC_and_obs.ncl plot
#output: $DIR_SPD/$THIS_CYCLE/$date/obs_thin/d$dom/yyyymmddHH.hourly.obs_sgl|mpl.nc
#e.g.: $DIR_SPD/2017050500/2017050420/obs_thin/d2/2017050420.hourly.obs_sgl.nc
#record:
#modify by sishen, 2017.5.5: modify for thining for plot_SFC_and_obs
#update by sishen, 2017.5.10: use RT_all.obs_trim-merge_addqc.USA_ss

#==============================================================================#
# 1. Define inputs
#==============================================================================#
#----------------------------------------------------------------------------#
# 1.1 User's arguments
#----------------------------------------------------------------------------#
if(scalar(@ARGV) < 7) {
    print("Error: 7 or 8 arguments needed: <cycle> <start_date> <end_date> <nb_dom> <GMID> <OBS_MEMBER> <dir_spd> [<dir_cpout>]\n");
    exit();
}
$THIS_CYCLE = $ARGV[0];
$start_date = $ARGV[1];
$end_date   = $ARGV[2];
$nb_dom     = $ARGV[3];
$GSJOBID    = $ARGV[4];
$OBS_MEMBER = $ARGV[5];
$DIR_SPD    = $ARGV[6]; #actual dir is $DIR_SPD/$THIS_CYCLE/$date/obs_thin/$dom(d1/d2)
$DIR_CPOUT  = $ARGV[7]; #cpout as : $DIR_CPOUT/$THIS_CYCLE/$date/obs_thin/$dom(d1/d2)

#----------------------------------------------------------------------------#

#----------------------------------------------------------------------------#
$GSJOBDIR = "$ENV{HOME}/data/GMODJOBS/$GSJOBID";

$DIR_SFC="$ENV{HOME}/data/cycles/ensprocs/$GSJOBID/";
if (! -e "$GSJOBDIR/ensprocinput.pl") {
    print "\nERROR: Cannot find file $GSJOBDIR/ensprocinput.pl\n\n";
    exit -1;
}else {
    require "$GSJOBDIR/ensprocinput.pl";
}

# Path root to the MM5/WRF run directory (usual cycles)
$RUNDIR_ROOT = "$ENV{HOME}/data/cycles";

#----------------------------------------------------------------------------#
# 1.3 Define parameters
#----------------------------------------------------------------------------#
$time_start = 53; $time_end=7; # select 14 minutes obs
$latlon_filename = "latlon.txt";
$MYLOGIN         = $ENV{'LOGNAME'};
$RANGE           = "CEPRI";
@fields = ( 'sfcobs', '850rpr', '700rpr', '500rpr', '300rpr', '0535sw', '3560sw', '60sfsw' );
$KEY = "~/.ssh/id_dsa";
@domains = reverse(1 .. $nb_dom); #sishen,temp

#----------------------------------------------------------------------------#
# 1.4 Build full paths
#----------------------------------------------------------------------------#
$HOMEDIR         = $ENV{HOME};
$MM5HOME         = "$HOMEDIR/fddahome";
$POSTPROCS_DIR   = "$MM5HOME/cycle_code/POSTPROCS";
$CSH_ARCHIVE     = $MM5HOME.'/cycle_code/CSH_ARCHIVE';
$EXECUTABLE_ARCHIVE = $MM5HOME.'/cycle_code/EXECUTABLE_ARCHIVE';
$MustHaveDir     = $EXECUTABLE_ARCHIVE."/MustHaveDir";
$DIR_QC          = "$RUNDIR_ROOT\/$GSJOBID\/$OBS_MEMBER\/$THIS_CYCLE\/RAP_RTFDDA";
$DIR_HERE        = `pwd`;
$DIR_TERRAIN     = "$HOMEDIR\/data\/GMODJOBS\/$GSJOBID\/wps";
$RIP_ROOT        = "$MM5HOME/cycle_code/CONSTANT_FILES/RIP4";

#----------------------------------------------------------------------------#
# 1.5 Add variables to environment
#----------------------------------------------------------------------------#
# Directory where reside ncl scripts
$ENV{CSH_ARCHIVE} = "$ENV{MM5HOME}/cycle_code/CSH_ARCHIVE";

# Directory where reside executables (QCtoNC.exe)
$ENV{EXECUTABLE_ARCHIVE} = "$ENV{MM5HOME}/cycle_code/EXECUTABLE_ARCHIVE";

$ENV{'RIP_ROOT'} = "$MM5HOME/cycle_code/CONSTANT_FILES/RIP4";

#----------------------------------------------------------------------------#
# 1.6 Define short cuts
#----------------------------------------------------------------------------#
$ENSPROCS      = "$ENV{CSH_ARCHIVE}/ncl";
$POSTPROCS_DIR = "$ENV{MM5HOME}/cycle_code/POSTPROCS";
$NCARG_ROOT    = "$ENV{NCARG_ROOT}";
$CONVERT       = "$ENV{CONVERT}";

#----------------------------------------------------------------------------#
# 1.7 Create the post-processing directories if it does not exist yet
#----------------------------------------------------------------------------#
$DIR_WORK="$DIR_SPD/$THIS_CYCLE";

print "Work directory is $DIR_WORK\n";

system("$MustHaveDir $JOB_LOC");

#==============================================================================#
# 2. Process QC files
#==============================================================================#
#----------------------------------------------------------------------------#
# 2.0 Start loop around date
#----------------------------------------------------------------------------#
$proc_date = $start_date;
while ($proc_date <=$end_date ) {
    print "\n\nProcess date: $proc_date\n";
    $workdir="$DIR_WORK/$proc_date/obs_thin/";
    system(" test -d $workdir || mkdir -p $workdir");
    print $workdir."\n";
    chdir "$workdir"; #original: $OBS_DIR\/$proc_date

# 2.1 Link useful files
    symlink("$ENSPROCS\/RT_all.obs_trim-merge.USA_ss","$workdir\/RT_all.obs_trim-merge.USA_ss");
    symlink("$GSJOBDIR\/$latlon_filename","$workdir\/latlon.txt");

# 2.2 Get qc_out* files and concatenate them in 'hourly.obs'
    $valid_m1     = &hh_advan_date( $proc_date, -1);
    $valid_p1     = &hh_advan_date( $proc_date, 1);
    $date_time    = &dtstring($proc_date);
    $date_time_m1 = &dtstring($valid_m1);
    $date_time_p1 = &dtstring($valid_p1);
    print "date_time = $DIR_QC/qc_out_${date_time}:00:00.0000; date_time_m1 = qc_out_${date_time_m1}:00:00.0000\n";

    print "\n  ==> get obs data\n\n";
    if (-s "$DIR_QC/qc_out_${date_time_m1}:00:00.0000" &&
            -s "$DIR_QC/qc_out_${date_time}:00:00.0000") {
        system("cat $DIR_QC/qc_out_${date_time_m1}:00:00.0000 $DIR_QC/qc_out_${date_time}:00:00.0000 > hourly.obs");
    } elsif (-s "$DIR_QC/qc_out_${date_time_m1}:00:00.0000" &&
            ! -s "$DIR_QC/qc_out_${date_time}:00:00.0000") {
        system("cp $DIR_QC/qc_out_${date_time_m1}:00:00.0000 hourly.obs");
    } elsif (-s "$DIR_QC/qc_out_${date_time}:00:00.0000" &&
            ! -s "$DIR_QC/qc_out_${date_time_m1}:00:00.0000") {
        system("cp $DIR_QC/qc_out_${date_time}:00:00.0000 hourly.obs");
    } else {
        print "No obs plot for $proc_date\n";
    }

# 2.3 Get only obs we need (using RT_all.obs_trim-merge.USA)
    if (-s "hourly.obs" && -e "latlon.txt") {
        system("RT_all.obs_trim-merge.USA_ss hourly.obs $time_start $time_end latlon.txt > /dev/null");
        unlink 'hourly.obs';
    }

#do thin & convert to nc
    $valid_time_short = substr($proc_date,0,10);
    foreach $domi (@domains)  {
       chdir($workdir);
       if ( -e "${valid_time_short}.hourly.obs") {
          $dir_dom="$workdir/d${domi}";
          system("test -d $dir_dom || mkdir -p $dir_dom");
          chdir($dir_dom);
          symlink("$EXECUTABLE_ARCHIVE/obs_thin/obs_thinning_v2.0.exe", "obs_thinning.exe");
          symlink("$workdir/${valid_time_short}.hourly.obs", "$dir_dom/${valid_time_short}.hourly.obs");
          #thin
          symlink("$GSJOBDIR/ensproc/obs_thin/namelist.thin.d${domi}", "namelist.thin");
          system("./obs_thinning.exe -i ${valid_time_short}.hourly.obs -o thined.hourly.obs < namelist.thin >& thin_d${domi}.log"); 
          #convert
          print "\n  ==> convert data to netCDF\n\n";
          if (-s "thined.hourly.obs") {
             system("rm -rf ${valid_time_short}.hourly.obs && ln -sf thined.hourly.obs ${valid_time_short}.hourly.obs");
             system("$EXECUTABLE_ARCHIVE\/QCtoNC.exe ${valid_time_short}.hourly.obs");
             system("rm -f *.hourly.obs");
          }
       }
    }
#optional, plot obs
    $do_plot="False";
    if ($do_plot eq "True") {
        foreach $domi (@domains) {
            chdir("$workdir/d${domi}");
	        symlink("$ENSPROCS\/SfcStatsThin.ncl","$workdir/d${domi}/SfcStatsThin.ncl");
            symlink("$ENSPROCS\/UpperAirObs.ncl","$workdir/d${domi}/UpperAirObs.ncl");
            symlink("$ENSPROCS\/UpperAirObsSat.ncl","$workdir/d${domi}/UpperAirObsSat.ncl");
      		symlink("$DIR_TERRAIN\/geo_em.d0${domi}.nc","geo_em.d0${domi}.nc");
            $file_mpres_file="$GSJOBDIR/ensproc/ncl_functions/initial_mpres_obs_d0${domi}.ncl";
            symlink("$file_mpres_file", "initial_mpres.ncl");
		    if (-s "${valid_time_short}.hourly.obs_mpl.nc" || -s "${valid_time_short}.hourly.obs_sgl.nc" ) {
			    print "\n  ==> process sfc obs\n\n";
                $cmdncl="ncl 'latlon=\"False\"' 'zoom=\"False\"' 'lat_s=1' 'lat_e=10' 'lon_s=1' 'lon_e=10' 'Range=\"$RANGE\"' Date=$valid_time_short Domain=$domi SfcStatsThin.ncl";
                print($cmdncl."\n");
			    system($cmdncl);
                print "\n  ==> process upper air obs\n\n";
                $cmdncl="ncl 'latlon=\"False\"' 'zoom=\"False\"' 'lat_s=1' 'lat_e=10' 'lon_s=1' 'lon_e=10' 'Range=\"$RANGE\"' Date=$valid_time_short Domain=$domi UpperAirObs.ncl";
                print($cmdncl."\n");
	     		system($cmdncl);
                print "\n  ==> process sat obs\n\n";
                $cmdncl="ncl 'latlon=\"False\"' 'zoom=\"False\"' 'lat_s=1' 'lat_e=10' 'lon_s=1' 'lon_e=10' 'Range=\"$RANGE\"' Date=$valid_time_short Domain=$domi UpperAirObsSat.ncl";
                print($cmdncl."\n");
	     		system($cmdncl);
			}
            unlink("geo_em_d0${domi}.nc");
            unlink("initial_mpres");
		}
        unlink("SfcStatsThin.ncl");
        unlink("UpperAirObsSat.ncl");
        unlink("UpperAirObs.ncl");
    }

    if (length($DIR_CPOUT) > 0) {
        $outdir="$DIR_CPOUT/$THIS_CYCLE/$valid_time_short/obs_thin/";
        system("test -d $outdir/ || mkdir -p $outdir");
        foreach $domi (@domains) {
            system("cp -rf $workdir/d${domi} $outdir/");
        }
    }

#----------------------------------------------------------------------------#
# 3.5 Clean
#----------------------------------------------------------------------------#
    unlink 'RT_all.obs_trim-merge.USA' if -e ('RT_all.obs_trim-merge.USA');
    unlink 'latlon.txt'                if -e ('latlon.txt');

    $proc_date = &hh_advan_date($proc_date,+1);
}

#==============================================================================#
# 5. Subroutines used
#==============================================================================#
#----------------------------------------------------------------------------#
# 5.1 Subroutine dtstring
#----------------------------------------------------------------------------#
sub dtstring {
    my $date_time = $_[0]; # input arg in YYYYMMDDHH<MN<SS>>
        my $yr = substr($date_time,0,4);
    my $mo = substr($date_time,4,2);
    my $dy = substr($date_time,6,2);
    my $hr = substr($date_time,8,2);
    my $string = "${yr}-${mo}-${dy}_${hr}";
    return $string;
}

#-----------------------------------------------------------------------------
# 5.2 Subroutine to avance the date
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

#==============================================================================#
# 5. End
#==============================================================================#

1;

