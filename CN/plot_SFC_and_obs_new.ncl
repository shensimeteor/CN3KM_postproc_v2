;sishen, 20170815, add option: showStats="True"(default:False), fileStats="file_to_save_stats"(default:null,don't save)
;sishen, 20170915, add option: optOutput="all"(default), "cycleOnly", "updateOnly" 
;sishen, 20171002, add option: filterQCValue=0..10 (only obs with qc>=x will be used to plot & statis, default 0)
;==============================================================================;
; 0. Define function
;==============================================================================;
  ;-------------------------------------------------------------
  ; 0.0 Load useful ncl scripts
  ;-------------------------------------------------------------
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
  load "$NCARG_ROOT/lib/ncarg/nclscripts/wrf/WRFUserARW.ncl"
  load "$CSH_ARCHIVE/ncl/StationModel.ncl"
  load "$CSH_ARCHIVE/ncl/RTFDDAUser.ncl"    
  load "initial_mpres.ncl" 
  load "convert_and_copyout.ncl"
  load "$CSH_ARCHIVE/ncl/get_wrf_obs_stats.ncl" 
  ;-------------------------------------------------------------
  function sub_string_double(s:string,i:integer,j:integer)
  begin
     s_char = stringtochar(s)

     sub_str = s_char(i:j)
     return (stringtodouble(chartostring(sub_str)))
  end

  ;-------------------------------------------------------------
  function sub_string_float(s:string,i:integer,j:integer)
  begin
     s_char = stringtochar(s)
     sub_str = s_char(i:j)
     return (stringtofloat(chartostring(sub_str)))
  end

  ;-------------------------------------------------------------
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
  if (.not. isvar("cycle")) then
      print(" ")
      print(" You did not define cycle --> EXIT")
      exit
  end if
  if (.not. isvar("qcfile_sfc_in")) then
      print(" ")
      print(" You did not define the qcfile_sfc_in")
      print(" - use default: ../stations/<yyyymmddhh>.hourly.obs_sgl.nc")
  end if
   ; add by sishen
  if (.not. isvar("season")) then 
      mon=tointeger(systemfunc("echo "+cycle+" | cut -c 5-6"))
      if (mon .ge. 11) .or. (mon .le. 4) then
          season="winter"
      else
          season="summer"
      end if
      print((/" You did not define season, so guess it's "+season/))
  else
      season=str_lower(season)
      print((/" Use specified season: "+season/))
  end if
  ; end of sishen modification

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
  
  if (.not. isvar("zoom")) then
      zoom=False
  end if

  if(.not. isvar("showStats")) then
      showStats=False
  end if
  saveStats=True
  if(.not. isvar("fileStats")) then
      saveStats=False
  end if
  if(.not. isvar("optOutput")) then
      optOutput="all"
  end if
  if(.not. isvar("filterQCValue")) then
      filterQCValue=0
  end if
  optOutput=str_lower(optOutput)
  ;-----------------------------------------------------------------------------
  ; 1.2 Parameters
  ;-----------------------------------------------------------------------------  
  dir      = "."
  type     = "png"
  if (dom.eq.5) then
        city_name =(/"S03","S08","S29","S31","S02","S28","S30","TWR","S12"/)
        city_lat = (/40.20802,40.19662,40.1012,40.1081,40.04613,40.14751,40.22899,40.0938,40.09075/)
        city_lon = (/-113.3386,-113.1671,-113.2208,-113.3073,-113.2081,-113.1559,-113.2174,-113.2032,-113.1096/)
  else
    city_name =(/"S01","S02","S03","S04","S05","S06","S07","S08","S09","S10","S11","S12","S13","S14","S15","S16","S17","S18","S19","S20","S21","S22","S23","S24","S25","S26","S27","S28","S29","S30","S31","TWR"/)
    city_lat = (/40.1838, 40.04613, 40.20802, 40.04602, 40.15694, 40.11945, 40.2269, 40.19662, 40.24254, 40.18169, 40.10345, 40.09075, 40.1067, 40.35306, \
                     40.34109, 40.36726, 40.72728, 40.11649, 39.90445, 39.94554, 39.91933, 40.20812, 40.27838, 40.45272, 40.51593, 40.28214, 40.90886, 40.14751, 40.1012, 40.22899, 40.1081,40.0938/)
    city_lon = (/-112.9217, -113.2081, -113.3386, -113.0455, -112.8937, -112.9542, -112.7253, -113.1671, -113.093, -113.0218, -112.9804, -113.1096, \
                     -112.8082, -113.0764, -113.2353, -113.0044, -113.4691, -113.5334, -113.3441, -113.7015, -112.939, -112.9596, -112.9811, -113.4724, \
                     -113.7465, -113.7002, -113.1528, -113.1559, -113.2208, -113.2174, -113.3073,-113.2032/)
  end if
  nb_cplot = dimsizes(city_name)

  if (dom.ge.5) then
      offs = 0.0035
  end if
  if (dom.eq.4 .OR.dom.eq.3) then
      offs = 0.01
  end if
  if (dom.eq.3) then
      offs = 0.018
  end if
  if (dom.eq.1 .OR.dom.eq.2) then
      offs = 0.02
  end if



  ;-----------------------------------------------------------------------------
  ; 1.3 WRFoptions
  ;-----------------------------------------------------------------------------    
  res = True
  res@MainTitlePos                = "Center"
  res@InitTime                    = False
  res@ValidTime                   = False
  res@TimePos                     = "Right"
  res@Footer                      = False 
 ; res@mpOutlineBoundarySets       = "AllBoundaries"

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
        dom_name = sprinti("%0.2i",dom)
        dom_area=" "+x_start+" "+x_end+" "+y_start+" "+y_end
        print((/dom_area/))
   else
       x_start = 0
       y_start = 0
       x_end   = nlat-1
       y_end   = nlon-1
       dom_name = sprinti("%0.2i",dom)
   end if

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
  time_units = "minutes since 2013-01-01 00:00:0.0"
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
     time_wrf = ut_inv_calendar(year_wrf,month_wrf,day_wrf,hour_wrf,minute_wrf,second_wrf,time_units, 0)
;     time_wrf = ut_inv_calendar(2010, 11, 7, 1, 0, 0,time_units, 0)
 
     dow   = day_of_week(year_wrf,month_wrf,day_wrf)
     dow_c = dow_a(dow)
     month_c = month_a(month_wrf)
     year_c = sprinti("%0.2i",year_wrf-2000)
     time_utc = "Valid: "+hh+"00 UTC "+dow_c+" "+dd+" "+month_c+" "+year_c

     time_wrf_loc = time_wrf - (6*60)
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
  ; 3.2 Get WRF variables
  ;----------------------------------------------------------------------------- 
     u10_unzoom = wrf_user_getvar(a1,"U10",time)
     u10        = u10_unzoom(x_start:x_end,y_start:y_end)
     v10_unzoom = wrf_user_getvar(a1,"V10",time)
     v10        = v10_unzoom(x_start:x_end,y_start:y_end)

     SPD10 = sqrt(u10*u10+v10*v10)
     SPD10@description = "10m Horizontal wind"
     SPD10@units = "m/s"

     terrain_unzoom  = wrf_user_getvar(a1,"HGT",time)
     terrain         = terrain_unzoom(x_start:x_end,y_start:y_end)

     t2_unzoom = wrf_user_getvar(a1,"T2",time)
     t2        = t2_unzoom(x_start:x_end,y_start:y_end)

     td2_unzoom = wrf_user_getvar(a1,"td2",time)
     td2        = td2_unzoom(x_start:x_end,y_start:y_end)

     rh2_unzoom = wrf_user_getvar(a1,"rh2",time)
     rh2        = rh2_unzoom(x_start:x_end,y_start:y_end)

     delete(t2_unzoom)
     delete(td2_unzoom)
     delete(rh2_unzoom)
     delete(u10_unzoom)
     delete(v10_unzoom)
     delete(terrain_unzoom)     

  ;-----------------------------------------------------------------------------
  ; 3.3 Convert
  ;----------------------------------------------------------------------------- 
     u10_plane     = u10*1.94386
     v10_plane     = v10*1.94386
     t2_plane      = t2 -273.15

  ;-----------------------------------------------------------------------------
  ; 3.3 Loop over each level
  ;----------------------------------------------------------------------------- 
     graph_main_title   = "Domain "+ dom_name + "~C~"+time_utc+" ("+time_MDT+")"; Valid: "+hh+"00 UTC"; on "+ccyy+"/"+mm+"/"+dd
     
     res@TimeLabel                   = times(it)
     res@MainTitle                   = graph_main_title
     res@MainTitlePos                = "Center"

  ;-----------------------------------------------------------------------------
  ; 3.7 Define outputs
  ;-----------------------------------------------------------------------------
      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_WSPD_10mAGL_barb"
      wks = gsn_open_wks(type,file_out)
      gsn_define_colormap(wks,"spd_4step")

      range_level = ispan(0,30,1); modify as SZMB
      nbval = dimsizes(range_level)
      color_level = floattoint(fspan(2,nbval+2,nbval+1))

  ;-----------------------------------------------------------------------------
  ; 3.7 Wind Speed resources
  ;-----------------------------------------------------------------------------
      opts_var = res
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      opts_var@cnLevels                = range_level
      opts_var@cnFillColors            = color_level
      delete(color_level)
      delete(range_level)
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
      if(showStats .eq. "True") then
        opts_var@pmLabelBarParallelPosF = 0.4
      end if
      ;res@lbLabelFontHeightF     = .010
      ;res@lbLabelStride          = 5
      opts_var@lbLabelFontHeightF      = 0.012
      opts_var@lbTitleOffsetF          = -0.5

      ;   opts_var@gsnSpreadColors      = True
      ;   opts_var@gsnSpreadColorStart  = 40
      opts_var@lbLabelAutoStride    = True
      opts_var@gsnContourZeroLineThicknessF = 2
      opts_var@gsnContourNegLineDashPattern = 1

      opts_var@FieldTitle          = SPD10@description
      opts_var@UnitLabel           = SPD10@units
      opts_var@cnFillOn            = True
      opts_var@cnFillMode = "RasterFill"
      opts_var@cnRasterSmoothingOn = "True"
      opts_var@lbLabelStride           = 4

  ;-----------------------------------------------------------------------------
  ; 3.7 Wind Vectors resources
  ;-----------------------------------------------------------------------------
      opts_vct = res
      opts_vct@NumVectors        = 25
      opts_vct@vcWindBarbLineThicknessF  = 2.
      ;  opts_vct@vcRefMagnitudeF         = 10.0
      ;  opts_vct@vcRefLengthF            = 0.045
      ;  opts_vct@vcMinDistanceF          = 0.017
      ;;opts_vct@vcGlyphStyl       = "LineArrow"
      ;opts_vct@vcLineArrowColor   ="red"

       ;;opts_vct@vcRefAnnoOrthogonalPosF  = .1          ; move ref vector down
      opts_vct@vcVectorDrawOrder  = "PostDraw"
      ;opts_vct@gsnDraw                  = False              ; don't draw yet
      ;opts_vct@gsnFrame                 = False              ; don't advance frame yet
      opts_vct@vcRefAnnoBackgroundColor = 0
      opts_vct@vcRefAnnoOn             = True
      opts_vct@vcRefAnnoOrthogonalPosF = -1.17          ; move ref vector
      opts_vct@vcRefAnnoPerimOn  = False
      opts_vct@vcRefAnnoParallelPosF   = 1.            ; move ref vector
      opts_vct@FieldTitle         = "Horizontal Wind"+ " at 10 m (AGL)"
      opts_vct@vcRefMagnitudeF    = 20.0
      opts_vct@vcGlyphStyle       = "WindBarb"
      opts_vct@UnitLabel          = "kts"
      opts_vct@vcMinFracLengthF   = 0

  ;-----------------------------------------------------------------------------
  ; 3.7 Map resources
  ;-----------------------------------------------------------------------------
      pltres = True
      ;pltres@gsnDraw  = False
      pltres@gsnFrame = False

      mpres=initial_mpres()
      mpres@ZoomIn = True
      mpres@Xstart = y_start
      mpres@Ystart = x_start
      mpres@Xend   = y_end
      mpres@Yend   = x_end
      mpres@gsnFrame = False
  ;-----------------------------------------------------------------------------
  ; 3.7 Plot
  ;-----------------------------------------------------------------------------
      contour_var  = wrf_contour(a1,wks,SPD10,opts_var)
      vector       = wrf_vector(a1,wks,u10_plane, v10_plane,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

  if( isvar("qcfile_sfc_in") ) then
     QCFile_sfc = qcfile_sfc_in
  else
     QCFile_sfc = "../stations/"+ccyy+""+mm+""+dd+""+hh+".hourly.obs_sgl.nc"
  end if
  if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      print ("File "+QCFile_sfc+"is present and processed")
      ff = addfile(QCFile_sfc,"r")
      latitude = ff->latitude
      longitude = ff->longitude
      longitude = where(longitude.gt.180.,longitude- 360.,longitude)
      ;namec = stringtochar(ff->name)
      ;name  = chartostring(namec(:,35:37))
      is_surface = ff->is_surface

      date_obs   = ff->date
      time_obs   = ut_inv_calendar(stringtoint(chartostring(date_obs(:,0:3))),   \
                                   stringtoint(chartostring(date_obs(:,4:5))),   \
                                   stringtoint(chartostring(date_obs(:,6:7))),   \
                                   stringtoint(chartostring(date_obs(:,8:9))),   \
                                   stringtoint(chartostring(date_obs(:,10:11))), \
                                   stringtoint(chartostring(date_obs(:,12:13))), time_units, 0)
      delete(date_obs)

      ;date = chartostring(ff->date(:,0:11))
      ;minutes = stringtointeger(chartostring(ff->date(:,10:11)))
    
      lat_ndc=new(dimsizes(latitude), float)
      lon_ndc=new(dimsizes(longitude), float)
      datatondc(plot,longitude,latitude,lon_ndc,lat_ndc)
      indx = ind(is_surface.eq.1 .AND. \
          (time_obs.ge.time_wrf-10 .AND. time_obs.lt.time_wrf+10) .AND.\
          ;(minutes .le. 10 .or. minutes .ge. 50) .AND. \
          ( lat_ndc.gt.0.  .AND.  lat_ndc.lt.1.).AND. \
          ( lon_ndc.gt.0.  .AND.  lon_ndc.lt.1.))
      ;delete(lat_ndc)
      ;delete(lon_ndc)
    
      nrec = dimsizes(.not.ismissing(indx))
      print ("Stations numbers: "+nrec)

      if (nrec.eq.0) then
          print("No stations to plot --> EXIT")
       ; exit
      end if


      temp = ff->temperature
      temp = where(temp.lt.-887,temp@_FillValue,temp)
      temp = temp - 273.15
      dewp = ff->dew_point
      dewp = where(dewp.lt.-887,dewp@_FillValue,dewp)
      dewp = dewp - 273.15
      ;qcsp = ff->wind_speed_qc
      ;qcsp = where(qcsp.lt.-887,qcsp@_FillValue,qcsp)

      rad  = 4.*atan(1.0)/180.
      u2    = ff->u_wind
      u2    = where(u2.lt.-887,u2@_FillValue,u2)
      v2    = ff->v_wind
      v2    = where(v2.lt.-887,v2@_FillValue,v2)
      wind_speed = ff->wind_speed
      wind_speed = where(wind_speed.lt.0,wind_speed@_FillValue,wind_speed)
      wind_dir = ff->wind_direction
      wind_dir = where(wind_dir.lt.-887,wind_dir@_FillValue,wind_dir)

      wspd_c = 1.9438445*sqrt(u2*u2 + v2*v2)   ; m/s -> knots
      wspdm_c = sqrt(u2*u2 + v2*v2)
      wdir_c = atan2(u2,v2)/rad +180.

      wdir  = where(ismissing(wind_dir),wdir_c,wind_dir)
      wspdm = where(ismissing(wind_speed),wspdm_c,wind_speed)
      wspd  = 1.9438445*wspdm
      
      if(filterQCValue .gt. 0) then
          temp_qc=ff->temperature_qc
          dewp_qc=ff->dew_point_qc
          ws_qc=ff->wind_speed_qc
          wd_qc=ff->wind_direction_qc
          u_qc=ff->u_wind_qc
          v_qc=ff->v_wind_qc
          temp_qc=where( temp_qc .gt. 990, temp_qc@_FillValue, temp_qc)
          dewp_qc=where( dewp_qc .gt. 990, dewp_qc@_FillValue, dewp_qc)
          ws_qc=where( ws_qc .gt. 990, ws_qc@_FillValue, ws_qc)
          wd_qc=where( wd_qc .gt. 990, wd_qc@_FillValue, wd_qc)
          u_qc=where(u_qc .gt. 990, u_qc@_FillValue, u_qc)
          v_qc=where(v_qc .gt. 990, v_qc@_FillValue, v_qc)
          uv_qc=where(u_qc .gt. v_qc, v_qc, u_qc)
          wspd_qc=where(ismissing(wind_speed), uv_qc, ws_qc)
          wdir_qc=where(ismissing(wind_dir), uv_qc, wd_qc)
          delete(uv_qc)
          temp = where(ismissing(temp_qc) .or. (temp_qc .lt. filterQCValue), temp@_FillValue, temp)
          dewp = where(ismissing(dewp_qc) .or. (dewp_qc .lt. filterQCValue), dewp@_FillValue, dewp)
          wspdm = where(ismissing(wspd_qc) .or. (wspd_qc .lt. filterQCValue), wspdm@_FillValue, wspdm) 
          wspd  = 1.9438445*wspdm
          wdir  = where(ismissing(wdir_qc) .or. (wdir_qc .lt. filterQCValue), wdir@_FillValue, wdir)
      end if


      ;wspd = mask(wspd,(abs(u2).gt.150.or.abs(v2).gt.150.),False)
      ;wspdm = mask(wspdm,(abs(u2).gt.150.or.abs(v2).gt.150.),False)
      ;wdir = mask(wdir,(abs(u2).gt.150.or.abs(v2).gt.150.),False)
      ; yliu 20140310 comment out the following 3 lines
      ;wspd = where(qcsp.lt.3,wspd@_FillValue,wspd)
      ;wspdm = where(qcsp.lt.3,wspdm@_FillValue,wspdm)
      ;wdir = where(qcsp.lt.3,wdir@_FillValue,wdir) 
    
      pmres               = True
      pmres@gsMarkerColor = "Red"
      pmres@gsMarkerIndex = 16
      pmres@gsMarkerThicknessF = 2.
      ;pmres@gsMarkerSizeF  = 0.001
      pmres@gsMarkerSizeF  = 0.001
      if (nrec.gt.1 .and. dom .ge. 3) then
          markers = gsn_add_polymarker(wks, plot, longitude(indx), latitude(indx), pmres)
      end if

      lonstart = LON2D(0,0)
      ndim2 = dimsizes(LON2D)
      lonend   = LON2D(ndim2(0)-1,ndim2(1)-1)
      dlon = (lonend-lonstart)
    
      if (nrec.gt.1) then
          sm   = new(nrec,graphic)
          anno = new(nrec,graphic)
          dmax = dlon/20.
          if (dom.ge.4) then
         ;     dmax = 0.001
          end if
          
          resT = True
          resT@ArrowLength      = 2.
          resT@CloudCircleColor = "red"
          resT@WindColor        = "red"
          m = 0
          do n=0,nrec-1
              far = True
              dist = 0.
              kk = 1
              k = indx(n)
    
              if (n.gt.0) then
                 delete(dist)
                 delete(kk)
                 dist = new(n,"float")
                 kk = indx(0:n-1)
                 dist = sqrt( (latitude(kk)-latitude(k))^2 + (longitude(kk)-longitude(k))^2 )
                 if (min(dist) .lt. dmax) then
                    far = False
                 end if
              end if
              fmt = "%8.2f"
              miss = -999.
              if (far) then
                 T  = miss;replace_missing(temp(k))
                 T@_FillValue = miss
                 Td = miss;replace_missing(dewp(k))
                 Td@_FillValue = miss
                 ws = replace_missing(wspd(k))
                 ws@_FillValue = miss
                 wd = replace_missing(wdir(k))
                 wd@_FillValue = miss
                 sm(m) = StationModel(wks, ws, wd, T, Td, resT)
                 anno(m) = NhlAddAnnotation(plot,sm(m))
                 setvalues anno(m)
                    "amTrackData"    : True    ; Use data coords to position each annotation
                    "amDataXF"       : longitude(k)
                    "amDataYF"       : latitude(k)
                    "amResizeNotify" : True      ; Resize annotations if map resizes.
                 end setvalues
                 m = m + 1
              else
                 latitude(k) = latitude@_FillValue
                 longitude(k) = longitude@_FillValue
              end if
          end do
   end if
  end if

  if (dom.gt.1) then
     mres = True
     mres@gsMarkerIndex     = 16      ; open circle
     mres@gsMarkerSizeF     = 0.006
     mres@gsMarkerColor     = "Black"
    ; marker = new(nb_cplot,"graphic")

     tres               = True
     tres@txFontHeightF = 0.01
     tres@txFontColor     = "Black"

     text = new(nb_cplot,"graphic")
         offset = offs
  ;   end if

    ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
    ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
     text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
  end if
  draw(plot)
  frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir) 


      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_WSPD_10mAGL"
      wks = gsn_open_wks(type,file_out)
      gsn_define_colormap(wks,"spd_4step")

      range_level = ispan(0,30,1); modify as SZMB
      nbval = dimsizes(range_level)
      color_level = floattoint(fspan(2,nbval+2,nbval+1))
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      opts_var@cnLevels                = range_level
      opts_var@cnFillColors            = color_level

      opts_vct@vcRefMagnitudeF    = 10.0
      opts_vct@vcRefLengthF       = 0.05
      opts_vct@vcGlyphStyle       = "CurlyVector"
      opts_vct@UnitLabel          = "m/s"
      opts_vct@vcMinFracLengthF   = 0

      contour_var  = wrf_contour(a1,wks,SPD10,opts_var)
      vector       = wrf_vector(a1,wks,u10, v10,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      latitude = ff->latitude
      longitude = ff->longitude
      longitude = where(longitude.gt.180.,longitude- 360.,longitude)

      if (nrec.gt.1 .and. dom .ge. 3) then
          markers2 = gsn_add_polymarker(wks, plot, longitude(indx), latitude(indx), pmres)
      end if

      if (nrec.gt.1) then
          sm   = new(nrec,graphic)
          anno = new(nrec,graphic)
          dmax = dlon/30.

          resT = True
          resT@ArrowLength      = 2.
          resT@CloudCircleColor = "red"
          resT@WindColor        = "red"
          m = 0
            do n=0,nrec-1
                 far = True
                 dist = 0.
                 kk = 1
                 k = indx(n)

                 if (n.gt.0) then
                    delete(dist)
                    delete(kk)

                    dist = new(n,"float")
                    kk   = indx(0:n-1)
                    dist = sqrt( (latitude(kk)-latitude(k))^2 + \
                               (longitude(kk)-longitude(k))^2 )
                    if (min(dist) .lt. dmax) then
                        far = False
                    end if
                 end if

                 fmt = "%8.2f"
                 miss = -999.
                 if (far) then
                    T   = miss;replace_missing(temp(k))
                    Td  = miss;replace_missing(dewp(k))
                    ws  = replace_missing(wspdm(k))
            ws@_FillValue = miss
                    wd  = replace_missing(wdir(k))
                    wd@_FillValue = miss
            rad = 0.01745329
                    Uo  = -ws*sin(wd*rad)
                    Uo@_FillValue = miss
                    Vo  = -ws*cos(wd*rad)
                    Vo@_FillValue = miss

            wmsetp("vrs - size of reference vector in user space", 10.00)
            wmsetp("vrn - size of reference vector on plot in NDC space", 0.05)
            wmsetp("vcw - linewidth scale",2.)
            wmsetp("vcc - vector color",34)
                    wmsetp("vch",0.006)
                    ;wmsetp("col", 240)    ; the vector color
                    ;          wmsetp("wbs", .03)  ; the vector arrow size
                    ;          wmsetp("vcw", 100.)   ; Increase the linewidth
                    ;wmsetp("vrn - size of reference vector on plot in NDC space", 0.08)

            wmvectmap(wks, latitude(k), longitude(k), Uo, Vo)

                    m = m + 1
                 else
                    latitude(k) = latitude@_FillValue
                    longitude(k) = longitude@_FillValue
                 end if

           end do
        end if
      end if

        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if

      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir)  


            ;2m-Temp
      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_T_2mAGL"
      wks = gsn_open_wks(type,file_out)
        setvalues NhlGetWorkspaceObjectId()
            "wsMaximumSize" : 300000000
         end setvalues
      ; sishen
      if (season .eq. "summer") then
          gsn_define_colormap(wks,"t_8step")
          array = ispan(-7, 39, 1); 
      else
          gsn_define_colormap(wks,"t_10step")
          array=ispan(-29, 29, 1);  10 step
      end if
      delete(opts_var)
      nbval = dimsizes(array)
      color_tab = floattoint(fspan(2,nbval+2,nbval+1))
      ; end of sishen

      opts_var = res    
      opts_var@FieldTitle         = "2-m Temperature"
      opts_var@UnitLabel          = "C"
      ;opts_var@ContourParameters  = (/ -10., 30., 0.5/)
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      opts_var@cnLevels                = array
      opts_var@cnFillColors            = color_tab

      opts_var@cnFillOn           = True
      opts_var@cnFillMode = "RasterFill"
      ;opts_var@cnRasterSmoothingOn = "True"
      ;opts_var@gsnSpreadColors     = True
   opts_var@cnLinesOn       = False
   opts_var@cnLineLabelsOn  = False
   opts_var@cnInfoLabelOn   = False
   opts_var@lbTitlePosition = "Bottom"
   opts_var@gsnFrame        = False

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
      if(showStats .eq. "True") then
        opts_var@pmLabelBarParallelPosF = 0.4
      end if
      ;res@lbLabelFontHeightF     = .010
      ;res@lbLabelStride          = 5
      opts_var@lbLabelFontHeightF      = 0.012
      opts_var@lbTitleOffsetF          = -0.5
  
      ;   opts_var@gsnSpreadColors      = True
      ;   opts_var@gsnSpreadColorStart  = 40
      opts_var@lbLabelAutoStride    = True

      contour_var  = wrf_contour(a1,wks,t2_plane,opts_var)
      vector       = wrf_vector(a1,wks,u10, v10,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      if (nrec.gt.1) then
          latitude = ff->latitude
          longitude = ff->longitude
          longitude = where(longitude.gt.180.,longitude- 360.,longitude)

          mres = True
          mres@gsMarkerIndex     = 16      ; open circle
          mres@gsMarkerSizeF     = 0.008    ; twice normal size
          vardata = temp(indx)
          marker  = new(nrec,"graphic")
      marker2 = new(nrec,"graphic")
      lons = longitude(indx)
          lats = latitude(indx)
      lats_ndc = lat_ndc(indx)
          lons_ndc = lon_ndc(indx)

  dmax2 = 0.004;mres@gsMarkerSizeF
  dmax2=0
  ind_all = ispan(0,nrec-1,1)

          bres = True
          bres@gsMarkerIndex     =  4       ; open circle
          bres@gsMarkerSizeF     = 0.008
          bres@gsMarkerColor     = "Black"
          bres@gsMarkerThicknessF = 1.5

          do perc_i=0, nbval
             if (perc_i.eq.0.OR.perc_i.eq.nbval) then
                 if (perc_i.eq.0) then
                     ind_color = ind(vardata.lt.array(perc_i))
                 else
                     ind_color = ind(vardata.gt.array(perc_i-1))
                 end if
             else
                 ind_color = ind(vardata.ge.array(perc_i-1).AND. \
                            vardata.lt.array(perc_i))
             end if
             if (.not.all(ismissing(ind_color))) then
         do nn = 0, dimsizes(ind_color)-1
                 mres@gsMarkerColor     = color_tab(perc_i)
                     marker(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),mres)
                     marker2(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),bres)
         end do
             end if
             delete(ind_color)
          end do
        ;;sishen, add stats
        stats=get_wrf_obs_stats(LON2D, LAT2D, t2_plane, lons, lats, vardata)
        print(stats)
        if(showStats .eq. "True") then
            txres = True
            txres@txPerimOn = True
            txres@txFontHeightF = 0.01
            txres@txBackgroundFillColor = "White"
            amres_tr = True
            amres_tr@amParallelPosF   = 0.5
            amres_tr@amOrthogonalPosF = 0.78
            amres_tr@amJust           = "BottomRight"
            txtplt=add_stats(wks,plot,stats,txres,amres_tr)
        end if
        if(saveStats) then
            save_stats(stats, "T2m", fileStats)
        end if
      end if
      end if
        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if
      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir)  


      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_TD_2mAGL"
      wks = gsn_open_wks(type,file_out)
        ; sishen
      if (season .eq. "summer") then
          gsn_define_colormap(wks,"t_8step")
          array = ispan(-7, 39, 1); 
      else
          gsn_define_colormap(wks,"t_10step")
          array=ispan(-29, 29, 1);  10 step
      end if
      ;delete(opts_var)
      nbval = dimsizes(array)
      color_tab = floattoint(fspan(2,nbval+2,nbval+1))
          ; end of sishen
      opts_var@FieldTitle         = "2-m Dew Point Temperature"
      opts_var@UnitLabel          = "C"

      contour_var  = wrf_contour(a1,wks,td2,opts_var)
      vector       = wrf_vector(a1,wks,u10, v10,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      if (nrec.gt.1) then
          mres = True
          mres@gsMarkerIndex     = 16      ; open circle
          mres@gsMarkerSizeF     = 0.008    ; twice normal size
          vardata = dewp(indx)
          marker  = new(nrec,"graphic")
          marker2 = new(nrec,"graphic")
          lons = longitude(indx)
          lats = latitude(indx)
cot = 0
          do perc_i=0, nbval
             if (perc_i.eq.0.OR.perc_i.eq.nbval) then
                 if (perc_i.eq.0) then
                     ind_color = ind(vardata.lt.array(perc_i))
                 else
                     ind_color = ind(vardata.gt.array(perc_i-1))
                 end if
             else
                 ind_color = ind(vardata.ge.array(perc_i-1).AND. \
                            vardata.lt.array(perc_i))
             end if
             if (.not.all(ismissing(ind_color))) then
             do nn = 0, dimsizes(ind_color)-1
                 mres@gsMarkerColor     = color_tab(perc_i)
                     marker(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),mres)
                     marker2(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),bres)
             end do

             end if
             delete(ind_color)
          end do
        ;;sishen, add stats
        stats=get_wrf_obs_stats(LON2D, LAT2D, td2, lons, lats, vardata)
        print(stats)
        if(showStats .eq. "True") then
            txres = True
            txres@txPerimOn = True
            txres@txFontHeightF = 0.01
            txres@txBackgroundFillColor = "White"
            amres_tr = True
            amres_tr@amParallelPosF   = 0.5
            amres_tr@amOrthogonalPosF = 0.78
            amres_tr@amJust           = "BottomRight"
            txtplt=add_stats(wks,plot,stats,txres,amres_tr)
        end if
        if(saveStats) then
            save_stats(stats, "TD2m", fileStats)
        end if
      end if
      end if
        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if
      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir)  


      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_RH_2mAGL"
      wks = gsn_open_wks(type,file_out)
     cmaprh = (/"(/1.00, 1.00, 1.00/)", "(/0.00, 0.00, 0.00/)", "(/1.00, 1.00, 1.00/)", \
               "(/1.,1.,0.63/)", "(/1.00, 1.00,0.39/)","(/0.96, 0.96, 0.43/)","(/1.00, 0.82, 0.14/)","(/1.00, 0.64, 0.10/)", \
       "(/0.90, 0.48, 0.40/)", "(/0.93, 0.57,0.49/)", "(/0.94, 0.70, 0.57/)", "(/0.97, 0.78, 0.70/)", "(/1.00, 0.9, 0.9/)", \
           "(/.62, .62, .96/)", "(/.76, .76, .98/)", "(/0.86, 0.86, 1.00/)", "(/.51, .82, 1.00/)", \
        "(/.58, .96, .96/)","(/.73, .96, .73/)", "(/0.55, 0.92, 0.55/)", "(/.36, .82, .36/)", "(/.05, .92, .05/)"/)
     gsn_define_colormap(wks,cmaprh)
      ;gsn_define_colormap(wks,"rh_19lev")
      ;gsn_define_colormap(wks,"WhViBlGrYeOrRe")
      ;gsn_define_colormap(wks,"spd_4step")
     delete(array)
     array = ispan(5,95,5)
     nbval = dimsizes(array)
     delete(color_tab)
     color_tab = ispan(2,21,1);(/2,5,9,12,18,27,44,131,126,114/);floattoint(fspan(2,118,nbval+1))

      opts_var@FieldTitle         = "2-m Relative Humidity"
      opts_var@UnitLabel          = "%"
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      delete(opts_var@cnLevels)
      delete(opts_var@cnFillColors)
      opts_var@cnLevels                = array
      opts_var@cnFillColors            = color_tab

      contour_var  = wrf_contour(a1,wks,rh2,opts_var)
      vector       = wrf_vector(a1,wks,u10, v10,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      if (nrec.gt.1) then
          mres = True
          mres@gsMarkerIndex     = 16      ; open circle
          mres@gsMarkerSizeF     = 0.008    ; twice normal size
      tempk = temp(indx)+273.15
      dewpk = dewp(indx)+273.15
      delete(vardata)
          vardata = relhum_ttd (tempk, dewpk, 0)
          marker  = new(nrec,"graphic")
          marker2 = new(nrec,"graphic")
          lons = longitude(indx)
          lats = latitude(indx)

          do perc_i=0, nbval
             if (perc_i.eq.0.OR.perc_i.eq.nbval) then
                 if (perc_i.eq.0) then
                     ind_color = ind(vardata.lt.array(perc_i))
                 else
                     ind_color = ind(vardata.gt.array(perc_i-1))
                 end if
             else
                 ind_color = ind(vardata.ge.array(perc_i-1).AND. \
                            vardata.lt.array(perc_i))
             end if
             if (.not.all(ismissing(ind_color))) then
             do nn = 0, dimsizes(ind_color)-1
                 mres@gsMarkerColor     = color_tab(perc_i)
                     marker(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),mres)
                     marker2(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),bres)
             end do
             end if
             delete(ind_color)
          end do
        ;;sishen, add stats
        stats=get_wrf_obs_stats(LON2D, LAT2D, rh2, lons, lats, vardata)
        print(stats)
        if(showStats .eq. "True") then
            txres = True
            txres@txPerimOn = True
            txres@txFontHeightF = 0.01
            txres@txBackgroundFillColor = "White"
            amres_tr = True
            amres_tr@amParallelPosF   = 0.5
            amres_tr@amOrthogonalPosF = 0.78
            amres_tr@amJust           = "BottomRight"
            txtplt=add_stats(wks,plot,stats,txres,amres_tr)
        end if
        if(saveStats) then
            save_stats(stats, "RH2m", fileStats)
        end if

      end if
      end if

        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if
      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir)  

      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_SPD_10mAGL_vect"
      wks = gsn_open_wks(type,file_out)
      gsn_define_colormap(wks,"spd_4step")

      delete(range_level)
      range_level = ispan(0,30,1); modify as SZMB
      nbval = dimsizes(range_level)
      color_level = floattoint(fspan(2,nbval+2,nbval+1))
  
      delete(array)
      array = range_level
      delete(color_tab)
      color_tab = color_level

      opts_var@FieldTitle         = "10-m Wind Speed"
      opts_var@UnitLabel          = "m/s"
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      delete(opts_var@cnLevels)
      delete(opts_var@cnFillColors)
      opts_var@cnLevels                = range_level
      opts_var@cnFillColors            = color_level

      contour_var  = wrf_contour(a1,wks,SPD10,opts_var)
      vector       = wrf_vector(a1,wks,u10, v10,opts_vct)
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      if (nrec.gt.1) then
          mres = True
          mres@gsMarkerIndex     = 16      ; open circle
          mres@gsMarkerSizeF     = 0.008    ; twice normal size
          delete(vardata)
          vardata = wspdm(indx)
          marker  = new(nrec,"graphic")
          marker2 = new(nrec,"graphic")
          lons = longitude(indx)
          lats = latitude(indx)

          do perc_i=0, nbval
             if (perc_i.eq.0.OR.perc_i.eq.nbval) then
                 if (perc_i.eq.0) then
                     ind_color = ind(vardata.lt.array(perc_i))
                 else
                     ind_color = ind(vardata.gt.array(perc_i-1))
                 end if
             else
                 ind_color = ind(vardata.ge.array(perc_i-1).AND. \
                            vardata.lt.array(perc_i))
             end if
             if (.not.all(ismissing(ind_color))) then
             do nn = 0, dimsizes(ind_color)-1
                 mres@gsMarkerColor     = color_tab(perc_i)
                     marker(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),mres)
                     marker2(ind_color(nn)) = gsn_add_polymarker(wks,plot,lons(ind_color(nn)),\
                                                     lats(ind_color(nn)),bres)
             end do
             end if
             delete(ind_color)
          end do
        ;;sishen, add stats
        stats=get_wrf_obs_stats(LON2D, LAT2D, SPD10, lons, lats, vardata)
        print(stats)
        if(showStats .eq. "True") then
            txres = True
            txres@txPerimOn = True
            txres@txFontHeightF = 0.01
            txres@txBackgroundFillColor = "White"
            amres_tr = True
            amres_tr@amParallelPosF   = 0.5
            amres_tr@amOrthogonalPosF = 0.78
            amres_tr@amJust           = "BottomRight"
            txtplt=add_stats(wks,plot,stats,txres,amres_tr)
        end if
        if(saveStats) then
            save_stats(stats, "SPD10m", fileStats)
        end if

      end if
      end if
        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if
      draw(plot)
      frame(wks)
  ;si shen
  delete(wks)
  delete(plot)
  convert_and_copyout(file_out+"."+type, figure_output_dir)  

      file_out = "upper_air/"+sprinti("d%i",dom)+ \
                 "_upper_air_SPD_10mAGL_stream"
      wks = gsn_open_wks(type,file_out)

      cmap = (/"(/1.00, 1.00, 1.00/)", "(/0.00, 0.00, 0.00/)", "(/1.00, 1.00, 1.00/)", "(/1.00, 1.00, 1.00/)", "(/0.86, 1.00, 0.86/)", \
           "(/.73, .93, .73/)", "(/.55, .92, .55/)", "(/.36, .82, .36/)",\
           "(/0.00, .72, 0.00/)", "(/.78, .73, .17/)", "(/0.89, .82, 0.00/)", "(/.99, .93, .50/)",\
           "(/.99, .95, .66/)", "(/1.00, .99, .84/)", \
           "(/.92, .80, 1.00/)", "(/0.87, .69, 1.00/)", \
           "(/.78, .58, .93/)", "(/0.73, .44, .93/)", \
           "(/.67, .30, .93/)","(/1.00, 0.00, 0.00/)","(/.75, 0.00, .00/)"/)

      gsn_define_colormap(wks,cmap)
      delete(array)
;      array = (/10,25,50,75,100,150,200,250,300,350,400,450,500,750,1000,1500/)
      array = (/100,250,500,750,1000,1500,2000,2500,3000,3500,4000,4500,5000,5500,6000,6500/)

      nbval = dimsizes(array)
      delete(color_tab)
      color_tab = ispan(2,19,1)

      opts_var@FieldTitle         = "Terrain Height"
      opts_var@UnitLabel          = "m"
      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      delete(opts_var@cnLevels)
      delete(opts_var@cnFillColors)
      opts_var@cnLevels                = array
      opts_var@cnFillColors            = color_tab
      
      delete(opts_vct)
      opts_vct = res
      opts_vct@vcWindBarbLineThicknessF  = 2.
      opts_vct@vcVectorDrawOrder  = "PostDraw"
      ;opts_vct@vcRefAnnoBackgroundColor = 0
      opts_vct@vcRefAnnoOn             = False
;      opts_vct@FieldTitle         = "";Horizontal Wind"+ " at 10 m (AGL)"
      opts_vct@gsnLeftString         = "";Horizontal Wind"+ " at 10 m (AGL)"
      opts_vct@gsnRightString          = "";m/s"

      opts_vct@stArrowLengthF     = 0.006
    ;  opts_vct@stMinArrowSpacingF = 0.01
      opts_vct@stArrowStride      = 6
  opts_vct@stLineThicknessF   = 1.
  opts_vct@stLineColor        = "black"
  opts_vct@stMinDistanceF = 0.015
  opts_vct@stMinLineSpacingF = 0.0015
      opts_vct@stLineStartStride = 1
      opts_vct@gsnFrame = False
      opts_vct@gsnDraw  = False
      opts_vct@vcMinFracLengthF   = 0

      mpres@mpGeophysicalLineColor      = "Brown";20;"White";"Black"
      mpres@mpNationalLineColor         = "Brown";20;"White";"Black"
      mpres@mpUSStateLineColor          = "Brown";20;"White";"Black"
      mpres@mpOutlineDrawOrder            = "Predraw"

      contour_var  = wrf_contour(a1,wks,terrain,opts_var)
      dims_wrf=dimsizes(u10)
      if(dims_wrf(0) .ge. 1000) then
          vector = gsn_csm_streamline(wks, u10(::10, ::10), v10(::10, ::10), opts_vct)
      else
          vector       = gsn_csm_streamline(wks,u10, v10,opts_vct)
      end if
      plot = wrf_map_overlays(a1,wks,(/contour_var,vector/),pltres,mpres)

      if (isfilepresent(QCFile_sfc).AND.dom.ge.1) then
      latitude = ff->latitude
      longitude = ff->longitude
      longitude = where(longitude.gt.180.,longitude- 360.,longitude)

      if (nrec.gt.1 .and. dom .ge. 3) then
          markers2 = gsn_add_polymarker(wks, plot, longitude(indx), latitude(indx), pmres)
      end if

      if (nrec.gt.1) then
          sm   = new(nrec,graphic)
          anno = new(nrec,graphic)
          dmax = dlon/40.

          resT = True
          resT@ArrowLength      = 2.
          resT@CloudCircleColor = 20;"red"
          resT@WindColor        = 20;"red"
          m = 0
            do n=0,nrec-1
                 far = True
                 dist = 0.
                 kk = 1
                 k = indx(n)

                 if (n.gt.0) then
                    delete(dist)
                    delete(kk)

                    dist = new(n,"float")
                    kk   = indx(0:n-1)
                    dist = sqrt( (latitude(kk)-latitude(k))^2 + \
                               (longitude(kk)-longitude(k))^2 )
                    if (min(dist) .lt. dmax) then
                        far = False
                    end if
                 end if

                 fmt = "%8.2f"
                 miss = -999.
                 if (far) then
                    T   = miss;replace_missing(temp(k))
                    Td  = miss;replace_missing(dewp(k))
                    ws  = replace_missing(wspdm(k))
                    ws@_FillValue = miss
                    wd  = replace_missing(wdir(k))
                    wd@_FillValue = miss
                    rad = 0.01745329
                    Uo  = -ws*sin(wd*rad)
                    Uo@_FillValue = miss
                    Vo  = -ws*cos(wd*rad)
                    Vo@_FillValue = miss

                    wmsetp("vrs - size of reference vector in user space", 10.00)
                    wmsetp("vrn - size of reference vector on plot in NDC space", 0.05)
                    wmsetp("vcw - linewidth scale",2.)
                    wmsetp("vcc - vector color",19)
                    wmsetp("vch",0.006)
                    ;wmsetp("col", 240)    ; the vector color
                    ;          wmsetp("wbs", .03)  ; the vector arrow size
                    ;          wmsetp("vcw", 100.)   ; Increase the linewidth
                    ;wmsetp("vrn - size of reference vector on plot in NDC space", 0.08)

                    wmvectmap(wks, latitude(k), longitude(k), Uo, Vo)

                    m = m + 1
                 else
                    latitude(k) = latitude@_FillValue
                    longitude(k) = longitude@_FillValue
                 end if

           end do
        end if
      end if
        if (dom.gt.1) then
              mres = True
              mres@gsMarkerIndex     = 16      ; open circle
              mres@gsMarkerSizeF     = 0.006
              mres@gsMarkerColor     = "Black"
              ;marker = new(nb_cplot,"graphic")

              tres               = True
              tres@txFontHeightF = 0.01
              tres@txFontColor     = "Black"

              text = new(nb_cplot,"graphic")
                  offset = offs
           ;   end if

             ; marker = gsn_add_polymarker(wks,plot,city_lon,city_lat,mres)
             ; text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
              text   = gsn_add_text(wks,plot,city_name, city_lon,city_lat-offset,tres)
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
      end if
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
