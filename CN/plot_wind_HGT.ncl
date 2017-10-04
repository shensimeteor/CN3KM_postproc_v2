;sishen, 20170915, add option: optOutput="all"(default), "cycleOnly", "updateOnly" 
;==============================================================================;
; 0. Define function
;==============================================================================;
  ;-------------------------------------------------------------
  ; 0.0 Load useful ncl scripts
  ;-------------------------------------------------------------
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
  load "$CSH_ARCHIVE/ncl/StationModel.ncl"
  load "$CSH_ARCHIVE/ncl/RTFDDAUser.ncl"
  load "initial_mpres.ncl"
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
function replace_missing(x:float)
begin
  if (.not.ismissing(x)) then
    px = x
  else
    px = -999.
  end if
  px@_FillValue = -999.
  return(px)
end


  ;-----------------------------------------------------------------------------
  ; 0.1 wrf_map_overlays
  ;-----------------------------------------------------------------------------  
  undef("wrf_map_overlays")
  function wrf_map_overlays(in_file[1]:file, \
                            wks:graphic, \
                            plots[*]:graphic, \
                            opt_arg[1]:logical, \
                            opt_mp[1]:logical) 
 
  ; This procedure takes an array of plots and overlays them on a
  ; base plot - map background.
  ;
  ; It will advance the plot and cleanup, unless you set the
  ; PanelPlot resource to True.
  ;
  ;  Attributes recognized by this procedure:
  ;     FramePlot
  ;     PanelPlot
  ;     NoTitles                  (don't do any titles) 
  ;     CommonTitle & PlotTile is used to overwrite field titles
  ;        CommonTitle will super-seed NoTitles
  ;
  ; If FramePlot False, then Draw the plot but do not Frame.
  ; In this case a user want to add to the drawing, and will
  ; have to advance the Frame manually in the script.
  ;
  ; If the "NoTitles" attribute exists and is set True, then
  ; don't create the top-left titles, and leave the main titles alone.
  ; This resource can be useful if you are planning to panel
  ; the plots.
  ;
  ; If PanelPlot is set to True, then this flags to wrf_map_overlays
  ; that these plots are going to be eventually paneled (likely
  ; by gsn_panel), and hence 1) draw and frame should not be called
  ; (unless gsnDraw and/or gsnFrame are explicitly set to True),
  ; and 2) the overlays and titles should not be removed with
  ; NhlRemoveOverlay and NhlRemoveAnnotation.
  ;
  begin

    ; Let's make the map first
    base = wrf_map(wks,in_file,opt_mp)

    opts = opt_arg      ; Make a copy of the resource list

    no_titles  = get_res_value(opts,"NoTitles",False)     ; Do we want field titles?
    com_title  = get_res_value(opts,"CommonTitle",False)     ; Do we have a common title?
    if ( com_title ) then
      plot_title = get_res_value(opts,"PlotTitle","  ")
      no_titles = True
    end if
  
    call_draw  = True
    call_frame = get_res_value(opts,"FramePlot",True)     ; Do we want to frame the plot?
    panel_plot = get_res_value(opts,"PanelPlot",False)    ; Are we paneling?
    opts@gsnMaximize = get_res_value_keep(opts,"gsnMaximize", True)

    nplots = dimsizes(plots)
  ;  font_color = "Black"

    do i=0,nplots-1
      if(.not.ismissing(plots(i))) then
  ;      class_name = NhlClassName(plots(i))
  ;      print(class_name)
  ;      if(class_name.eq."contourPlotClass") then
  ;        getvalues plots(i)
  ;          "cnFillOn"    : fill_on
  ;          "cnLineColor" : line_color
  ;        end getvalues
  ;        if (.not.fill_on) then
  ;          font_color = line_color      
  ;        end if       
  ;      end if
        if(.not.no_titles) then
          getvalues plots(i)
            "tiMainString" : SubTitle
          end getvalues
          if(i.eq.0) then
            SubTitles = SubTitle
          else
            SubTitles = SubTitles + "~C~" + SubTitle
          end if
        end if
        if(com_title .and. i .eq. nplots-1) then
          getvalues plots(i)
            "tiMainString" : SubTitle
          end getvalues
          SubTitles = plot_title
        end if
        setvalues plots(i)
          "tfDoNDCOverlay" : True
          "tiMainOn"       : False
        end setvalues
        overlay(base,plots(i))
      else
        print("wrf_map_overlays: Warning: overlay plot #" + i + " is not valid.")
      end if
    end do

    if(.not.no_titles .or. com_title) then
      font_height = get_res_value_keep(opts,"FontHeightF",0.01)
      txt = create "map_titles" textItemClass wks
        "txString"      : SubTitles
        "txFontHeightF" : font_height
       ;"txFontColor"   : font_color
      end create
      anno = NhlAddAnnotation(base,txt)
      setvalues anno
        "amZone"           : 3
        "amJust"           : "BottomLeft"
        "amSide"           : "Top"
        "amParallelPosF"   : 0.005
        "amOrthogonalPosF" : 0.03
        "amResizeNotify"   : False
      end setvalues
      base@map_titles = anno
    end if
  ;
  ; gsnDraw and gsnFrame default to False if panel plot.
  ;
    if(panel_plot) then
      call_draw = False
      call_frame= False
    end if


    opts@gsnDraw     = get_res_value_keep(opts,"gsnDraw",     call_draw)
    opts@gsnFrame    = get_res_value_keep(opts,"gsnFrame",    call_frame)

    draw_and_frame(wks,base,opts@gsnDraw,opts@gsnFrame,False, \
                   opts@gsnMaximize)

    if(.not.panel_plot) then
      do i=0,nplots-1
        if(.not.ismissing(plots(i))) then
          NhlRemoveOverlay(base,plots(i),False)
        else
          print("wrf_remove_map_overlays: Warning: overlay plot #" + i + " is not valid.")
          print("                        Nothing to remove.")
        end if
      end do
    end if
  
    if(.not.no_titles.and..not.panel_plot) then
      if(isatt(base,"map_titles")) then
        NhlRemoveAnnotation(base,base@map_titles)
        delete(base@map_titles)
      end if
    end if

  return(base)
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
  dir      = "."
  type     = "png"
  levels   = 1.*(/20, 30, 50, 80, 100, 200/);, 500, 1000, 1500, 2000/)
  var_to_plot = "WSPD"

  ;-----------------------------------------------------------------------------
  ; 1.3 WRFoptions
  ;-----------------------------------------------------------------------------    
  res = True
  res@MainTitlePos                = "Center"
  res@InitTime                    = False
  res@ValidTime                   = False
  res@TimePos                     = "Right"
  res@Footer                      = False 
;  res@mpOutlineBoundarySets       = "AllBoundaries"

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

   if (zoom.eq."True") then
        if (latlon.eq."True") then
            resll = True
            resll@returnInt = True
            sloc  = wrf_user_ll_to_ij(a1,lon_s , lat_s, resll)
            eloc  = wrf_user_ll_to_ij(a1,lon_e , lat_e, resll)
            sloc=sloc-1
            eloc=eloc-1
            x_start = sloc(1)
            y_start = sloc(0)
            x_end   = eloc(1)
            y_end   = eloc(0)
        else
            x_start = lat_s
            y_start = lon_s
            x_end   = lat_e
            y_end   = lon_e
        end if
        x_start=where(x_start .lt. 0, 0, x_start)
        x_end=where(x_end .gt. nlat-1, nlat-1, x_end)
        y_start=where(y_start .lt. 0, 0, y_start)
        y_end=where(y_end .gt. nlon-1,nlon-1, y_end)
   else
       x_start = 0
       y_start = 0
       x_end   = nlat-1
       y_end   = nlon-1
   end if

   dom_name = sprinti("%0.2i",dom)
   nbcity   = 0

  LAT2D = a1->XLAT(0,x_start:x_end,y_start:y_end)
  LON2D = a1->XLONG(0,x_start:x_end,y_start:y_end)

  ;-----------------------------------------------------------------------------
  ; 2.3 Get the times to plot 
  ;-----------------------------------------------------------------------------    
  times  = wrf_user_list_times(a1)  
  ntimes = dimsizes(times)

;==============================================================================;
; 3. Plot the variables
;==============================================================================;
  time_units = "hours since 2012-01-01 00:00:0.0"
  dow_a = (/"Sun","Mon","Tue","Wed","Thu","Fri","Sat"/)
  month_a = (/"","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)

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

     year_wrf   = stringtoint(ccyy)
     month_wrf  = stringtoint(mm)
     day_wrf    = stringtoint(dd)
     hour_wrf   = stringtoint(hh)
     minute_wrf = hour_wrf*0
     second_wrf = 0
     print(year_wrf+" "+month_wrf+" "+day_wrf+" "+hour_wrf+" "+minute_wrf+" "+second_wrf+" "+time_units)
     time_wrf = ut_inv_calendar(year_wrf,month_wrf,day_wrf,hour_wrf,minute_wrf,second_wrf,time_units, 0)
     dow   = day_of_week(year_wrf,month_wrf,day_wrf)
     dow_c = dow_a(dow)
     month_c = month_a(month_wrf)
     year_c = sprinti("%0.2i",year_wrf-2000)
     time_utc = "Valid: "+hh+"00 UTC "+dow_c+" "+dd+" "+month_c+" "+year_c
     time_wrf_loc = time_wrf - 6
     time_wrf_loc@units = time_units
     time_lab = floattoint(ut_calendar(time_wrf_loc,  0))
     dow2    =  day_of_week(time_lab(0,0),time_lab(0,1),time_lab(0,2))
     dow_loc = dow_a(dow2)
     month_loc = month_a(time_lab(0,1))
     year_loc  = sprinti("%0.2i",time_lab(0,0)-2000)
     time_MDT = sprinti("%0.2i",time_lab(0,3))+"00 MDT "+dow_loc+" "+ \
                sprinti("%0.2i",time_lab(0,2))+" "+month_loc+" "+year_loc


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
     z_unzoom = wrf_user_getvar(a1,"z",time)
     z        = z_unzoom(:,x_start:x_end,y_start:y_end)
     z!0      = "bottom_top"  
     z!1      = "south_north"
     z!2      = "west_east"

     u_unzoom = wrf_user_getvar(a1,"ua",time)
     u        = u_unzoom(:,x_start:x_end,y_start:y_end)
     v_unzoom = wrf_user_getvar(a1,"va",time)
     v        = v_unzoom(:,x_start:x_end,y_start:y_end)

     u!0      = "bottom_top"
     u!1      = "south_north"
     u!2      = "west_east"

     v!0      = "bottom_top"
     v!1      = "south_north"
     v!2      = "west_east"

     terrain_unzoom  = wrf_user_getvar(a1,"HGT",time)
     terrain         = terrain_unzoom(x_start:x_end,y_start:y_end)
  
     delete(z_unzoom)
     delete(u_unzoom)
     delete(v_unzoom)
     delete(terrain_unzoom)     

     if (var_to_plot .eq. "WSPD") then
         VAR1 = sqrt(u*u+v*v)
         VAR1@description = "Horizontal wind"
	 VAR1@units = "m/s"
     else
         VAR1_unzoom      = wrf_user_getvar(a1,var_to_plot,time)
         VAR1             = VAR1_unzoom(:,x_start:x_end,y_start:y_end)
         VAR1@description = VAR1@description
         delete(VAR1_unzoom)
     end if

     if (var_to_plot .eq. "TH") then
         VAR1 = VAR1 -273.15
         VAR1@description = "Potential Temperature (theta) (mean)"
	 VAR1@units = "C"
     end if
     VAR1!0      = "bottom_top"
     VAR1!1      = "south_north"
     VAR1!2      = "west_east"

     nb_dim_var = dimsizes(dimsizes(VAR1))
     nlevels    = dimsizes(levels)
     level = new((/nlevels,x_end-x_start+1,y_end-y_start+1/),float)
     level!0      = "height"
     level!1      = "south_north"
     level!2      = "west_east"
     do lev=0,nlevels-1
        level(lev,:,:) = terrain+levels(lev)
     end do

  ;-----------------------------------------------------------------------------
  ; 3.3 Interpolate to height AGL
  ;----------------------------------------------------------------------------- 
     linlog =1

     VAR1_plane   = int2p(z(south_north|:, west_east|:, bottom_top|:), \
                        VAR1(south_north|:, west_east|:, bottom_top|:), \
                        level(south_north|:, west_east|:, height|:),linlog)

     z_plane      = int2p(z(south_north|:, west_east|:, bottom_top|:), \
                          z(south_north|:, west_east|:, bottom_top|:), \
                          level(south_north|:, west_east|:, height|:), linlog)

     u_plane   = int2p(z(south_north|:, west_east|:, bottom_top|:), \
                       u(south_north|:, west_east|:, bottom_top|:), \
                       level(south_north|:, west_east|:, height|:), linlog)
     v_plane   = int2p(z(south_north|:, west_east|:, bottom_top|:), \
                       v(south_north|:, west_east|:, bottom_top|:), \
                       level(south_north|:, west_east|:, height|:), linlog)

     u_plane     = u_plane;*1.94386
     v_plane     = v_plane;*1.94386
 
     ;u10_plane     = u10;*1.94386
     ;v10_plane     = v10;*1.94386

  ;-----------------------------------------------------------------------------
  ; 3.3 Loop over each level
  ;----------------------------------------------------------------------------- 
   do lev=0,nlevels-1
       levH = levels(lev)
     graph_main_title   = "Domain "+ dom_name + "~C~"+time_utc+" ("+time_MDT+")"; Valid: "+hh+"00 UTC"; on "+ccyy+"/"+mm+"/"+dd
     
     res@TimeLabel                   = times(it)
     res@MainTitle                   = graph_main_title
     res@MainTitlePos                = "Center"

  ;-----------------------------------------------------------------------------
  ; 3.4 Open workstation 
  ;-----------------------------------------------------------------------------
      file_out =  "upper_air/"+sprinti("d%i",dom)+ \
                  "_upper_air_"+var_to_plot+"_"+levH+"mAGL"
      wks = gsn_open_wks(type,file_out)
      ;gsn_define_colormap(wks,"WhViBlGrYeOrRe")

 ;     if (levH.eq."50" .OR. levH.eq."80") then
      gsn_define_colormap(wks,"spd_4step")

      range_level = ispan(0,30,1); modify as SZMB
      nbval = dimsizes(range_level)
      color_level = floattoint(fspan(2,nbval+2,nbval+1))

      opts_var = res
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      opts_var@cnLevels                = range_level
      opts_var@cnFillColors            = color_level
      delete(color_level)
      delete(range_level)

;      opts_var = res
;  opts_var@cnLevelSelectionMode        = "ManualLevels"
;  opts_var@cnMinLevelValF              = 0.0
;  opts_var@cnMaxLevelValF              = 40.
; opts_var@cnLevelSpacingF              = 1.;0.5
;      opts_var@gsnSpreadColorStart  = 40
;      opts_var@gsnSpreadColors      = True


 ;    end if


  ;-----------------------------------------------------------------------------
  ; 3.6 Plotting options for VAR  
  ;-----------------------------------------------------------------------------
      opts_var@lbPerimOn               = False
      opts_var@lbOrientation           = "Horizontal"
      opts_var@lbTitlePosition         = "Bottom"
      opts_var@lbTitleFontHeightF      = 0.016
      opts_var@lbBoxLinesOn            = True
      opts_var@lbBoxLineThicknessF     = 0.6
      ;opts_var@pmLabelBarSide          = "Top"
      opts_var@pmLabelBarWidthF        = 0.70
      opts_var@pmLabelBarHeightF       = 0.2
      opts_var@pmLabelBarOrthogonalPosF = -0.1
   ;res@lbLabelFontHeightF     = .010
   ;res@lbLabelStride          = 5
      opts_var@lbLabelFontHeightF      = 0.012
      opts_var@lbTitleOffsetF          = -0.5

      opts_var@lbLabelAutoStride    = True
      opts_var@gsnContourZeroLineThicknessF = 2
      opts_var@gsnContourNegLineDashPattern = 1

      opts_var@FieldTitle          = VAR1@description+ " at "+levH+" m (AGL)"
      opts_var@UnitLabel           = VAR1@units
      opts_var@cnFillOn            = True  
      opts_var@cnLinesOn            = False
      opts_var@cnFillMode = "RasterFill"
      opts_var@cnRasterSmoothingOn = "True"
      opts_var@lbLabelStride           = 4

  ;-----------------------------------------------------------------------------
  ; 3.7 Plotting options for mean
  ;----------------------------------------------------------------------------                
    opts_ter                    = res
    opts_ter@FieldTitle         = "terrain";VAR1@description
    opts_ter@UnitLabel          = "m";VAR1@units
    opts_ter@cnLevelSpacingF    = 200; range_cn
    opts_ter@cnLineColor        = "White"
    opts_ter@cnHighLabelsOn     = False
    opts_ter@cnLowLabelsOn      = False
    opts_ter@cnLineLabelsOn     = False
    ;opts_ter@cnLineLabelFontColor ="Black"
    opts_ter@cnLineLabelBackgroundColor = -1
    opts_ter@gsnContourLineThicknessesScale = 2.0

  ;-----------------------------------------------------------------------------
  ; 3.7 Plotting options for Wind Vectors
  ;-----------------------------------------------------------------------------
      opts_vct = res
      opts_vct@FieldTitle        = "Horizontal Wind"+ " at "+levH+" m (AGL)"
      opts_vct@UnitLabel         = "m/s"
      opts_vct@NumVectors        = 25
      opts_vct@vcWindBarbLineThicknessF  = 2.
;      if (dom.ge.3) then
;          opts_vct@NumVectors        = 25
;      else
;          opts_vct@NumVectors        = 18
;      end if

 ;     if (level.le.500) then 
 ;         if (dom.ge.2) then
 ;             opts_vct@vcMinDistanceF           = 0.1
 ;             opts_vct@vcRefMagnitudeF          = 25.0
 ;             opts_vct@vcRefLengthF             = 0.05
 ;         else
;	  opts_vct@vcMinDistanceF           = 0.05
;          opts_vct@vcRefMagnitudeF          = 15.0
;          opts_vct@vcRefLengthF             = 0.05
;          end if
;      else
;          opts_vct@vcMinDistanceF           = 0.05
;          opts_vct@vcRefMagnitudeF          = 10.0
;          opts_vct@vcRefLengthF             = 0.05
;      end if

   opts_vct@vcRefMagnitudeF         = 20.0
 ;  opts_vct@vcRefLengthF            = 0.045
 ;  opts_vct@vcMinDistanceF          = 0.017


      ;;opts_vct@vcGlyphStyl       = "LineArrow"
      opts_vct@vcGlyphStyle       = "CurlyVector"
      ;opts_vct@vcLineArrowColor   ="red"

      ;opts_vct@vcMinDistanceF           = 0.017            ; thin vectors
       ;;opts_vct@vcRefAnnoOrthogonalPosF  = .1          ; move ref vector down
      ;opts_vct@vcRefLengthF       = 0.05
      ;opts_vct@vcVectorDrawOrder  = "PostDraw"
      ;opts_vct@gsnDraw                  = False              ; don't draw yet
      ;opts_vct@gsnFrame                 = False              ; don't advance frame yet
       ;;opts_vct@vcRefAnnoBackgroundColor = -1
      opts_vct@vcRefAnnoOn             = True
      opts_vct@vcRefAnnoOrthogonalPosF = -1.07          ; move ref vector
      opts_vct@vcRefAnnoParallelPosF   = 1.            ; move ref vector
      opts_vct@vcRefAnnoString2On = False
      opts_vct@vcMinFracLengthF   = 0

  ;-----------------------------------------------------------------------------
  ; 3.8 Make plots   
  ;-----------------------------------------------------------------------------
;      contour_var  = wrf_contour(a1,wks,VAR1_plane(:,:,lev)*1.94386,opts_var)
       contour_var  = wrf_contour(a1,wks,VAR1_plane(:,:,lev),opts_var)

      contour_hgt  = wrf_contour(a1,wks,terrain,opts_ter)   
      vector       = wrf_vector(a1,wks,u_plane(:,:,lev), v_plane(:,:,lev),opts_vct)

    ;  wrf_map_overlay(wks,map,(/contour_var,contour_hgt,vector/),False)

      pltres = True
;      pltres@gsnDraw  = False
      pltres@gsnFrame = False
      mpres=initial_mpres()
      mpres@ZoomIn = True
      mpres@Xstart = y_start
      mpres@Ystart = x_start
      mpres@Xend   = y_end
      mpres@Yend   = x_end
;      mpres@gsnDraw  = False
      mpres@gsnFrame = False
    ; mpres@MainTitle                   = graph_main_title
    ; mpres@MainTitlePos                = "Center"
   ;  mpres@tiMainFontThicknessF        = 0.8
   ;  mpres@tiMainFontHeightF           = 0.018
   ;  mpres@tiMainString                = graph_main_title

  if (dom.gt.2) then
       plot = wrf_map_overlays(a1,wks,(/contour_var,contour_hgt,vector/),pltres,mpres)
  else
       plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)
  end if
 ;    frame(wks)
      
;==============================================================================;
; 6. Plot range boundaries (if needed)
;==============================================================================;
  ;-------------------------------------------------------------
  ; 6.1 Read in range boundary lat/lon points
  ;-------------------------------------------------------------
      cmd = "ls stationlist_site_dom"+dom
      stationlist_site = "stationlist_site_dom"+dom
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

             if (xlon(ns) .ge. min(LON2D) .and. xlon(ns) .lt. max(LON2D) .and. \
                 ylat(ns) .ge. min(LAT2D) .and. ylat(ns) .le. max(LAT2D)) then
                 ns = ns + 1
             end if
             delete (linec)
          end do

  ;-------------------------------------------------------------
  ; 6.5 Store the number of stations contained in the domain
  ;-------------------------------------------------------------
          nsac = ns

          if (dom.eq.5) then
city_name =(/"S03","S08","S29","S31","S02","S28","S30","TWR","S12"/)
city_lat = (/40.2080,40.1966,40.1012,40.1081,40.0461,40.1475,40.2290,40.0938,40.0907/)
city_lon = (/-113.3286,-113.1571,-113.2108,-113.2973,-113.2081,-113.1559,-113.2174,-113.2032,-113.0733/)

          else
city_name =(/"S01","S02","S03","S04","S05","S06","S07","S08","S09","S10","S11","S12","S13","S14","S15","S16","S17","S18","S19","S20","S21","S22","S23","S24","S25","S26","S27","S28","S29","S30","S31","TWR"/)
city_lat = (/40.1838, 40.04613, 40.20802, 40.04602, 40.15694, 40.11945, 40.2269, 40.19662, 40.24254, 40.18169, 40.10345, 40.09075, 40.1067, 40.35306, \
    40.34109, 40.36726, 40.72728, 40.11649, 39.90445, 39.94554, 39.91933, 40.20812, 40.27838, 40.45272, 40.51593, 40.28214, 40.90886, 40.14751, 40.1012, 40.22899, 40.1081,40.0938/)
city_lon = (/-112.9217, -113.2081, -113.3386, -113.0455, -112.8937, -112.9542, -112.7253, -113.1671, -113.093, -113.0218, -112.9804, -113.1096, \
    -112.8082, -113.0764, -113.2353, -113.0044, -113.4691, -113.5334, -113.3441, -113.7015, -112.939, -112.9596, -112.9811, -113.4724, \
    -113.7465, -113.7002, -113.1528, -113.1559, -113.2208, -113.2174, -113.3073,-113.2032/)

          end if
	  nb_cplot = dimsizes(city_name)


          if (nsac .le. 0 .OR.nbcity.eq.0) then
              print("No station plotted")
          else
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "black"
              marker = new(nbcity,"graphic")
              marker2 = new(ns-nbcity+1,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              text = new(ns,"graphic")
              if (dom.eq.1) then
                   offset = 1.0
              end if
              if (dom.eq.2) then
                  offset = 0.12
              end if

              if (dom.ge.3) then
                  offset = 0.003
              end if

  ;---------------------------------------------------------------
  ; 6.6 Plot stations
  ;---------------------------------------------------------------
              marker = gsn_add_polymarker(wks,plot,xlon(:nbcity-1),ylat(:nbcity-1),mres)
              mres@gsMarkerSizeF     = 0.003
              marker2 = gsn_add_polymarker(wks,plot,xlon(nbcity:nsac-1),ylat(nbcity:nsac-1),mres)
              ;text   = gsn_add_text(wks,map,chartostring(station_id(:nsac-1,:)), xlon(:nsac-1),ylat(:nsac-1)-offset,tres)

          end if



      end if
    delete (file_here)


	if (dom.gt.2) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "black"
              marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              text = new(nb_cplot,"graphic")

              if (dom.eq.3) then
                  offset = 0.12
              end if

              if (dom.eq.4) then
                  offset = 0.015
              end if

              if (dom.ge.5) then
                  offset = 0.005
              end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat,tres)

      cmd = "ls map.ascii"
      file_here2 = systemfunc (cmd)
      if (.not.ismissing (file_here2)) then

      bndry_file = "map.ascii"

      lat_out  = new((/1000/),float)    ; Fix this later, set 1000 here
      lon_out  = new((/1000/),float)    ; and pass it in
      npts_out = new((/1000/),integer)

      read_map_ascii(bndry_file, lat_out, lon_out, npts_out)

      igood = ind(.not.ismissing(lat_out))  ; indices of non-missing values
      ipts = ind(.not.ismissing(npts_out))  ; indices of non-missing values

      if (.not.all(ismissing(igood)))
          bnd_lat = lat_out(igood)
          bnd_lon = lon_out(igood)
      else
          print ("bnd_lat, bnd_lon not created: all values are missing")
      end if

      if (.not.all(ismissing(ipts)))
          nptsline = npts_out(ipts)
      else
          print ("nptsline not created: all values are missing")
      end if

      delete (igood)
      delete (ipts)
      npts_dim = dimsizes(nptsline)

      plot_bndry = "True"
      gres                  = True          ; polyline mods desired
      gres@gsLineThicknessF = 4.0           ; line thickness
      gres@gsLineColor      = "black"       ; line color

  ;-------------------------------------------------------------
  ; 5.2 plot boundaries
  ;-------------------------------------------------------------
      jcount = 0
      dum = new(npts_dim,graphic)
      do i = 0,npts_dim - 1
         npairs = (nptsline(i)/2) - 1
         dum(i) = gsn_add_polyline(wks, plot, bnd_lon(jcount:jcount+npairs),\
         bnd_lat(jcount:jcount+npairs), gres)
         jcount = jcount + npairs + 1
      end do
      end if
;delete(file_here2)
end if



  draw(plot)
  frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir) 

 delete(opts_var)

  ;-----------------------------------------------------------------------------
  ; 3.9 Clean
  ;----------------------------------------------------------------------------- 
      ; Delete options and fields, so we don't have carry over
      print("")
      print("End of the plots")
      print("The plot file is "+file_out+"."+type)  
      print("")
  if (levH.eq.50.OR.levH.eq.80) then
     p_unzoom = wrf_user_getvar(a1,"pressure",time)
     p        = p_unzoom(:,x_start:x_end,y_start:y_end)
     delete(p_unzoom)

     tk_unzoom = wrf_user_getvar(a1,"tk",time)
     tk        = tk_unzoom(:,x_start:x_end,y_start:y_end)
     delete(tk_unzoom)

     qv_unzoom = wrf_user_getvar(a1,"QVAPOR",time)
     qv        = qv_unzoom(:,x_start:x_end,y_start:y_end)
     delete(qv_unzoom)

     eps = 0.622
     virtual = (tk*(eps+qv))/(eps*(1+qv))  
     delete(tk)
     delete(qv)
     
     rgas = 287.04
     rho = (p*100.)/(rgas*virtual)
     delete(p)

     terrain_3d = conform(z,terrain,(/1,2/))
     z_AGL  = z -terrain_3d
     delete(terrain_3d)
     rho_plane = wrf_user_intrp3d(rho,z_AGL,"h",levH,0.,False)
     delete(rho)
     Cp_Ng_Nb = 0.166
     WSPD_plane = VAR1_plane(:,:,lev)
     ;WSPD_plane = where(WSPD_plane.ge.25,0,WSPD_plane)
     energy = 0.5 * rho_plane * WSPD_plane *WSPD_plane * WSPD_plane * Cp_Ng_Nb
     delete(WSPD_plane)

      file_out =  "wind_energy/"+sprinti("d%i",dom)+ \
                  "_wind_energy_"+levH+"mAGL"

      wks = gsn_open_wks(type,file_out)
;            gsn_define_colormap(wks,"WhBlGrYeRe ")
  gsn_define_colormap(wks,"BlAqGrYeOrRe")
  new_index = NhlNewColor(wks,0.65,0.65,0.65)


      opts_var = res
  ;opts_var@cnLevelSelectionMode        = "ManualLevels"
  ;opts_var@cnMinLevelValF              = 0.0
  ;opts_var@cnMaxLevelValF              = 20.
  ;opts_var@cnLevelSpacingF              = 0.5

       opts_var@cnLevelSelectionMode = "ExplicitLevels"
      opts_var@cnLevels = (/0,1,5,10,20,35,50,75,100,150,200,250,300,400,500,600,800,1000,1250,1500/)*1.


      opts_var@lbPerimOn               = False
      opts_var@lbOrientation           = "Horizontal"
      opts_var@lbTitlePosition         = "Bottom"
      opts_var@lbTitleFontHeightF      = 0.016
      opts_var@lbBoxLinesOn            = True
      opts_var@lbBoxLineThicknessF     = 0.6
      ;opts_var@pmLabelBarSide          = "Top"
      opts_var@pmLabelBarWidthF        = 0.70
      opts_var@pmLabelBarHeightF       = 0.2
      opts_var@pmLabelBarOrthogonalPosF = -0.1
   ;res@lbLabelFontHeightF     = .010
   ;res@lbLabelStride          = 5
      opts_var@lbLabelFontHeightF      = 0.012
      opts_var@lbTitleOffsetF          = -0.5

      opts_var@gsnSpreadColors      = True
   ;   opts_var@gsnSpreadColorStart  = 40
   ;   opts_var@lbLabelAutoStride    = True
      opts_var@gsnSpreadColorStart  = 12  ;
      opts_var@gsnSpreadColorEnd  = 98  ;
      opts_var@gsnContourZeroLineThicknessF = 2
      opts_var@gsnContourNegLineDashPattern = 1

      opts_var@FieldTitle          = "Power per unit area at "+levH+" m (AGL)"
      opts_var@UnitLabel           = "W/m**2"
      opts_var@cnFillOn            = True
      opts_var@cnFillMode = "RasterFill"
      opts_var@cnRasterSmoothingOn = "True"
;opts_var@lbLabelStride           = 4





      contour_var  = wrf_contour(a1,wks,energy,opts_var)
      vector       = wrf_vector(a1,wks,u_plane(:,:,lev), v_plane(:,:,lev),opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)
          if (nsac .le. 0 .OR.nbcity.eq.0) then
              print ("No stations")
          else
              mres@gsMarkerSizeF     = 0.006
              marker = gsn_add_polymarker(wks,plot,xlon(:nbcity-1),ylat(:nbcity-1),mres)
              mres@gsMarkerSizeF     = 0.003
              marker2 = gsn_add_polymarker(wks,plot,xlon(nbcity:nsac-1),ylat(nbcity:nsac-1),mres)
          end if
      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir) 

      delete(opts_var)
  end if







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
