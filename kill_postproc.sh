#!/bin/bash
$HOME/datbin/onPSKill/kill9_pstree.sh -f "rtfdda_postproc_driver.*GECN3KM" ncar_fdda
$HOME/datbin/onPSKill/kill9_pstree.sh -f "rtfdda_postproc_aux3_run.*GECN3KM" ncar_fdda
$HOME/datbin/onPSKill/kill_old_process.sh -f "ncl.*\.ncl" 600

