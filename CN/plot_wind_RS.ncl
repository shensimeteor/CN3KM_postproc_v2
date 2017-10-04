;sishen, 20170915, add option: optOutput="all"(default), "cycleOnly", "updateOnly" 
;==============================================================================;
; 0. Define function
;==============================================================================;
  ;-------------------------------------------------------------
  ; 0.0 Load useful ncl scripts
  ;-------------------------------------------------------------
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
  ;load "/opt/ncl_ncarg-5.1.1-pgi/lib/ncarg/nclscripts/csm/contributed.ncl"
  ;load "$CSH_ARCHIVE/ncl/WRFUserARW.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
  load "convert_and_copyout.ncl"

  function sub_string_double(s:string,i:integer,j:integer)
  begin
     s_char = stringtochar(s)

     sub_str = s_char(i:j)
     return (stringtodouble(chartostring(sub_str)))
  end

  function sub_string_float(s:string,i:integer,j:integer)
  begin
     s_char = stringtochar(s)
     sub_str = s_char(i:j)
     return (stringtofloat(chartostring(sub_str)))
  end

  ;-----------------------------------------------------------------------------
  ; 0.2 wrf_user_list_times
  ;-----------------------------------------------------------------------------  
  undef("wrf_user_list_times")
  function wrf_user_list_times( nc_file:file )

  local times, times_in_file, dims, i
  begin

     times_in_file = nc_file->Times
     dims = dimsizes(times_in_file)
     times = new(dims(0),string)
     do i=0,dims(0)-1
        times(i) = chartostring(times_in_file(i,:))
     end do
     times@description = "times in file"
     return(times)

  end

;==============================================================================;


begin
wcStrt     = systemfunc("date")
;==============================================================================;
; 1. Define Variables
;==============================================================================;
  ;-----------------------------------------------------------------------------
  ; 1.1 Commad line
  ;-----------------------------------------------------------------------------  
  if (.not. isvar("file_in")) then
       print(" ")
       print(" You did not define the input file --> EXIT")
       exit
  end if

    if (.not. isvar("dom")) then
       print(" ")
       print(" You did not define the domain")
       filc = stringtochar(file_in)
       dom  = stringtointeger(chartostring(filc(8:9)))
       print(" You will use dom="+dom)
  end if

    if (.not. isvar("web_dir")) then
       print(" ")
       print(" You did not define the web directory")
       web_dir = "smac-c4-int2:/www/htdocs/images/ens/GEDPGL/NAM_WCTRL/gifs/"
       print(" You will use web_dir="+web_dir)
  end if
  if(.not. isvar("optOutput")) then
      optOutput="all"
  end if
  optOutput=str_lower(optOutput)

  ;-----------------------------------------------------------------------------
  ; 1.2 Parameters
  ;-----------------------------------------------------------------------------  
  dir       = "."
  type      = "png"
  level_max = 1000
  ;type@wkWidth = 2500
  ;type@wkHeight = 2500 


;==============================================================================;
; 2. Load files
;==============================================================================;
  ;-----------------------------------------------------------------------------
  ; 2.1 Open the netCDF WRF-CHEM file
  ;-----------------------------------------------------------------------------    
  a1 = addfile(dir+"/"+file_in+".nc","r")

  ;-------------------------------------------------------------
  ; 1.2 Get zoom coordinates (if needed)
  ;-------------------------------------------------------------
   dims_all = dimsizes(a1->T2)
   nlat     = dims_all(1)
   nlon     = dims_all(2)
   if (nlat.le.0 .OR. nlon.le.0) then
       print("Problem: dim < 0 ==> EXIT")
       exit
   end if

  lat2d = a1->XLAT(0,:,:)
  lon2d = a1->XLONG(0,:,:)

  ;-----------------------------------------------------------------------------
  ; 2.3 Get the times to plot 
  ;-----------------------------------------------------------------------------    
  times  = wrf_user_list_times(a1)  
  ntimes = dimsizes(times)

  ;-------------------------------------------------------------
  ; 6.1 Read in range boundary lat/lon points
  ;-------------------------------------------------------------
      cmd = "ls stationlist_profile_dom"+dom
      stationlist_site = "stationlist_profile_dom"+dom
      file_here = systemfunc (cmd)
      if (ismissing (file_here)) then
          print("")
          print("Cannot find file stationlist_site, don't plot station on map")
      else

  ;-------------------------------------------------------------
  ; 6.2 Read station list file
  ;-------------------------------------------------------------
          stationlist = asciiread(stationlist_site,-1,"string")

  ;-------------------------------------------------------------
  ; 6.3 Extract information
  ;-------------------------------------------------------------
          nsmax = dimsizes (stationlist)-3
          station_id   = new((/nsmax, 4/),character)
          station_name = new((/nsmax,37/),character)
          ylat    = new(nsmax,double)
          xlon    = new(nsmax,double)
          hmsl    = new(nsmax,float)

          ns = 0

  ;-------------------------------------------------------------
  ; 6.4 Check if stations are in domain
  ;-------------------------------------------------------------
          do n = 3, dimsizes (stationlist)-1, 1
             linec = stringtochar(stationlist(n))

             ylat(ns)  = sub_string_double(stationlist(n), 55, 57) + \
                         sub_string_double(stationlist(n), 59, 60)/60d + \
                         sub_string_double(stationlist(n), 62, 63)/3600d
             xlon(ns)  = (sub_string_double(stationlist(n), 65, 68)/ \
                          abs(sub_string_double(stationlist(n), 65, 68)))* \
                         (abs(sub_string_double(stationlist(n), 65, 68))+ \
                         sub_string_double(stationlist(n), 70, 71)/60d + \
                         sub_string_double(stationlist(n), 73, 74)/3600d)

             hmsl(ns)  = sub_string_float(stationlist(n), 76, 79)

             station_id(ns,:)= linec(6:9)
             do sl = 0, 36
                if (linec(11+sl:11+sl+1).eq."  ") then
                    break
                else
                    station_name(ns,sl:sl) = linec(11+sl:11+sl)
                end if
             end do

             if (xlon(ns) .ge. min(lon2d) .and. xlon(ns) .lt. max(lon2d) .and. \
                 ylat(ns) .ge. min(lat2d) .and. ylat(ns) .le. max(lat2d)) then
                 ns = ns + 1
             end if
             delete (linec)
          end do

  ;-------------------------------------------------------------
  ; 6.5 Store the number of stations contained in the domain
  ;-------------------------------------------------------------
          nsac = ns

      end if
    delete (file_here)

;==============================================================================;
; 3. Plot the variables
;==============================================================================;
  ;-----------------------------------------------------------------------------
  ; 3.1 Loop over each time
  ;-----------------------------------------------------------------------------   
  do it = 0,ntimes-1
     time = it
     time_c = stringtochar(times(it))
     ccyy   = chartostring(time_c(0:3))
     mm     = chartostring(time_c(5:6))
     dd     = chartostring(time_c(8:9))
     hh     = chartostring(time_c(11:12))

     local_date = ""+ccyy+""+mm+""+dd+""+hh
     if(optOutput .eq. "all") then
         figure_output_dir=(/web_dir+"/"+local_date+"/", web_dir+"/../cycles/"+cycle+"/"+local_date/)
     end if
     if(optOutput .eq. "cycleonly") then
         figure_output_dir=(/web_dir+"/../cycles/"+cycle+"/"+local_date/)
     end if
     if(optOutput .eq. "updateonly") then
         figure_output_dir=(/web_dir+"/"+local_date+"/"/)
     end if

  ;-----------------------------------------------------------------------------
  ; 3.2 Get variables (u, v, z, VAR)
  ;----------------------------------------------------------------------------- 
     z = wrf_user_getvar(a1,"z",time)
     uvmet = wrf_user_getvar(a1,"uvmet",time)
     u = uvmet(0,:,:,:)
     v = uvmet(1,:,:,:)
     delete(uvmet)

     terrain = wrf_user_getvar(a1,"HGT",time)

     WSPD = sqrt(u*u+v*v) ;*1.94386
     WSPD@description = "Horizontal wind"
     WSPD@units = "m/s"
   ;  delete(u)
   ;  delete(v)

     VARloc  = rcm2points (lat2d,lon2d,WSPD,ylat,xlon,1)
     VARloc@_FillValue = -999.
     VARloc!0 = "lev"
     VARloc!1 = "station"

     Uloc  = rcm2points (lat2d,lon2d,u,ylat,xlon,1)
     Uloc@_FillValue = -999.

     Vloc  = rcm2points (lat2d,lon2d,v,ylat,xlon,1)
     Vloc@_FillValue = -999.

     zloc  = rcm2points (lat2d,lon2d,z,ylat,xlon,1)
     zloc@_FillValue   = -999.
     terloc = rcm2points (lat2d,lon2d,terrain,ylat,xlon,1)
     terloc@_FillValue = -999.
     terloc_2d = conform(zloc,terloc,(/1/))
     zagl  = zloc - terloc_2d
     zagl!0 = "lev"
     zagl!1 = "station"

     delete(z)
     delete(terrain)
   ;  delete(terloc)

     ;level = ispan(0,level_max,50)
     ;VARplane = int2p(zloc, VARloc, level,1)
     ;VARhh = int2p(zagl(station|:, lev|:), \
     ;              VARloc(station|:, lev|:), \
     ;              level,1)

  do ijk = 0, ns-1

  ;-----------------------------------------------------------------------------
  ; 3.4 Open workstation 
  ;-----------------------------------------------------------------------------
      file_out =  "upper_air/"+sprinti("d%i",dom)+ \
                  "_RS_WSPD_"+chartostring(station_id(ijk,:))

      wks = gsn_open_wks(type,file_out)
      ;gsn_define_colormap(wks,"WhViBlGrYeOrRe")
      gsn_define_colormap(wks,"rainbow")

  res = True

  ;-------------------------------------------------------------
  ; 4.1 Set gsn resources
  ;-------------------------------------------------------------
     res@gsnPaperOrientation = "portrait"
     ;res@gsnMaximize        = True
     res@gsnDraw             = False
     res@gsnFrame            = False

  ;-------------------------------------------------------------
  ; 4.2 Set title resources
  ;-------------------------------------------------------------
     res@tiXAxisOn             = True
     res@tiMainFontHeightF     = .02
     res@tiXAxisFontHeightF    = 0.015
     res@tiXAxisFontThicknessF = 0.01
     res@tiXAxisString         = "Wind Speed (m/s)"
     res@tiYAxisString         = "Height agl (Km)"
     res@tiYAxisFontHeightF    = 0.019

     res@tiMainOn= True
   res@tiMainFontHeightF     = .018
   res@tiMainString = chartostring(station_name(ijk,:));+ \
;    "~C~(lat: "+ylat(ijk)+" lon: "+xlon(ijk)+ " alt: "+terloc(ijk)+"m)"

   res@gsnLeftString  = hh+":00Z on "+  mm+"/"+dd+" "+ccyy
   res@gsnRightString ="lat: "+ylat(ijk)+" lon: "+xlon(ijk)+ " alt: "+terloc(ijk)+"m"

  ;-------------------------------------------------------------
  ; 4.3 Set axis resources
  ;-------------------------------------------------------------
        res@tiYAxisOn     = True
        res@tmYLOn        = True
        res@tmYLLabelsOn  = True

     res@trYMinF          = 0
     res@trYMaxF          = level_max/1000.
     res@trXMinF          = 0
     res@trXMaxF          = 20

  ;-------------------------------------------------------------
  ; 4.3 Set tickmark resources
  ;-------------------------------------------------------------
     res@tmLabelAutoStride           = True

     res@tmXMajorGrid                = True
     res@tmXMajorGridThicknessF      = 0.9
     res@tmXMajorGridLineDashPattern = 2
     res@tmXMajorGridLineColor       = 239

     ;res@tmYBMode                    = "Manual"
     ;res@tmYBLabelFontHeightF        = 0.01
     ;res@tmYBLabelFontThicknessF     = 1.
     ;res@tmYBTickEndF                = 2.
     ;res@tmYBTickStartF              = 0.
     ;res@tmYBTickSpacingF            = 0.2

     res@tmXTOn                      = False

     res@tmYMajorGrid                = True
     res@tmYMajorGridThicknessF      = 0.9
     res@tmYMajorGridLineDashPattern = 2
     res@tmYMajorGridLineColor       = 239

    res@tmYROn                      = True
     res@tmYRLabelsOn                = False

     res@tmYLFormat = "@*+^sg"

    ;  res@tmYBMode          = "Explicit"
    ;  res@tmYBValues        = ispan(0,20,2)/10.
    ;  res@tmYBLabels        =  ispan(0,20,1)/10.

  ;-------------------------------------------------------------
  ; 4.4 Set drawing resources
  ;-------------------------------------------------------------
     res@xyLineThicknesses = 2
     res@xyLineColors      = "red"
    ; res@xyDashPatterns    = plot_pattern
     res@tfPolyDrawOrder   = "Predraw"

     ;res@vpXF              = vpXF
     ;res@vpYF              = vpYF
     res@vpWidthF          = 0.44
     res@vpHeightF         = 0.7


;   res@tmYUseLeft  = False      ; Keep top axis independent of bottom.
;   res@tmYRLabelsOn  = True       ; have tick mark labels
;   res@tmYROn        = True       ; have tick marks
;   res@tmYRMode      = "Explicit" ; label independently
;   res@tmYRValues    = (/0.0,0.10,0.20,0.30,0.40,0.50/)
;   res@tmYRLabels    = (/"0.0","10.0","5.0","3.3","2.5","2.0"/)







;==============================================================================;
; 5. PLOT
;==============================================================================;
  ;-------------------------------------------------------------
  ; 5.1 Plot spaghetti
  ;-------------------------------------------------------------
     plot=gsn_csm_xy (wks,VARloc(:,ijk),zagl(:,ijk)/1000.,res)

     x_out = VARloc(:,ijk)+1.
     y_out = zagl(:,ijk)/1000.

 y_out = where(y_out.gt.level_max/1000.,y_out@_FillValue,y_out)

     ;datatondc(plot,VARloc(:,ijk),zagl(:,ijk)/1000.,x_out,y_out)
     wmsetp("wbs",0.04)
     wmsetp("wdf",1)
     wmbarb(wks, x_out, y_out, Uloc(:,ijk)*1.94386, Vloc(:,ijk)*1.94386)

     draw(plot)
     frame(wks)

  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir) 

  ;-----------------------------------------------------------------------------
  ; 3.9 Clean
  ;----------------------------------------------------------------------------- 
      ; Delete options and fields, so we don't have carry over
      print("")
      print("End of the plots")
      print("The plot file is "+file_out+"."+type)  
      print("")

  ;-----------------------------------------------------------------------------
  ; 3.10 End loop over levels
  ;-----------------------------------------------------------------------------       
   end do


  ;-----------------------------------------------------------------------------
  ; 3.11 End loop over time
  ;-----------------------------------------------------------------------------    
 end do

;==============================================================================;
; 4. End of Script
;==============================================================================;    
  ;-----------------------------------------------------------------------------
  ; 4.1 Delete everything
  ;-----------------------------------------------------------------------------  
  delete(a1)

  print("")
  print("End of the plots")
  print("The plot file is "+file_out+"."+type)  
  print("")
  
  ;-----------------------------------------------------------------------------
  ; 4.2 Get the time used to process the file
  ;-----------------------------------------------------------------------------    
  wallClockElapseTime(wcStrt, "Plotting  "+file_out, 0)
  
end
