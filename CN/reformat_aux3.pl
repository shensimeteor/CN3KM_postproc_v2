#!/usr/bin/perl
#$0 <file_aux> <file_output>
#
if ( scalar(@ARGV) != 2 ) {
    print "Error: usage: reformt_aux3.pl <file_aux> <file_output>\n";
    exit(2);
}

$file_aux3=$ARGV[0];
$file_output=$ARGV[1];

#rename
print("cp -f $file_aux3 $file_output \n");
system("cp -f $file_aux3 $file_output");
$size_1=`stat $file_aux3 -c %s`;
$size_2=`stat $file_output -c %s`;
chomp($size_1);
chomp($size_2);
print("size_1=$size_1, size_2=$size_2 \n");
$cnt=1;
while ( abs($size_1 - $size_2) > 1024) { 
    if($cnt > 2) { 
        print("fail to copy for 3 times, give up\n");
        last;
    }
    print("$size_1, $size_2, cp fails, do recopy \n");
    print("cp -f $file_aux3 $file_output \n");
    system("cp -f $file_aux3 $file_output");
    $size_1=`stat $file_aux3 -c %s`;
    $size_2=`stat $file_output -c %s`;
    chomp($size_1);
    chomp($size_2);
    $cnt+=1;
}


$cmd="tcsh -c 'ncrename -h -v USIG,U -v VSIG,V -v WSIG,W -v TSIG,T -v PHSIG,PH -v PHBSIG,PHB -v PSIG,P -v PBSIG,PB -v WSLP,SLP -v QVSIG,QVAPOR -v QCSIG,QCLOUD -v QRSIG,QRAIN -v QISIG,QICE -v QSSIG,QSNOW -v QGSIG,QGRAUP -v QHSIG,QHAIL -d nsigout,bottom_top $file_output'";
print("$cmd \n");
system($cmd);
print("after rename var\n");

#addvar
$cmd="$ENV{NCARG_ROOT}/bin/ncl add_files.ncl 'file_in=\"$file_output\"'";
print("$cmd \n");
system($cmd);
print("after addfiles\n");

1;
