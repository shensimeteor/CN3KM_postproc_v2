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
  ; 1.1 Command line
  ;-----------------------------------------------------------------------------  
  if (.not. isvar("file_in")) then
       print(" ")
       print(" You did not define the input file --> EXIT")
       exit
  end if
  if (.not. isvar("zoom")) then
      zoom=False
  end if
  if (.not. isvar("dom")) then
       print(" ")
       print(" You did not define the domain, use default = 2")
       dom    = 2
  end if

  ;-----------------------------------------------------------------------------
  ; 1.2 Parameters
  ;-----------------------------------------------------------------------------  
  dir      = "."
  type     = "png"
  thres  = 0.2

  ;-----------------------------------------------------------------------------
  ; 1.3 WRFoptions
  ;-----------------------------------------------------------------------------    
  res = True
  res@MainTitlePos                = "Center"
  res@InitTime                    = False
  res@ValidTime                   = False
  res@TimePos                     = "Right"
  res@Footer                      = False 
  res@mpOutlineBoundarySets       = "AllBoundaries"

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
            sloc = sloc -1
            eloc = eloc -1
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
  time_units = "minutes since 2016-01-01 00:00:0.0"
  dow_a = (/"Sun","Mon","Tue","Wed","Thu","Fri","Sat"/)
  month_a = (/"","Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"/)

  ;-----------------------------------------------------------------------------
  ; 3.1 Loop over each time
  ;-----------------------------------------------------------------------------   
;  do it = 0,ntimes-1a

     it = 0
     time = it
     time_c = stringtochar(times(it))
     ccyy   = chartostring(time_c(0:3))
     mm     = chartostring(time_c(5:6))
     dd     = chartostring(time_c(8:9))
     hh     = chartostring(time_c(11:12))
     minute = chartostring(time_c(14:15))
     second = chartostring(time_c(17:18))

     year_wrf   = stringtoint(ccyy)
     month_wrf  = stringtoint(mm)
     day_wrf    = stringtoint(dd)
     hour_wrf   = stringtoint(hh)
     minute_wrf = stringtoint(minute)
     second_wrf = stringtoint(second)
     time_wrf = ut_inv_calendar(year_wrf,month_wrf,day_wrf,hour_wrf,minute_wrf,second_wrf,time_units, 0)

     file_in_head=systemfunc("echo "+ file_in+" | sed 's/\(.*\)" + ccyy + ".*$/\1/g' ")

     all_files = systemfunc("ls "+dir+"/"+file_in_head+"*")
     af = addfiles(all_files+".nc","r")
     atimes =  af[:]->Times
     accyy   = chartostring(atimes(:,0:3))
     amm     = chartostring(atimes(:,5:6))
     add     = chartostring(atimes(:,8:9))
     ahh     = chartostring(atimes(:,11:12))
     aminute = chartostring(atimes(:,14:15))
     asecond = chartostring(atimes(:,17:18))

     ayear_wrf   = stringtoint(accyy)
     amonth_wrf  = stringtoint(amm)
     aday_wrf    = stringtoint(add)
     ahour_wrf   = stringtoint(ahh)
     aminute_wrf = stringtoint(aminute)
     asecond_wrf = stringtoint(asecond)

     all_times = ut_inv_calendar(ayear_wrf,amonth_wrf,aday_wrf,ahour_wrf,aminute_wrf,0*aminute_wrf,time_units, 0)

 ;    time_wrf_bef = time_wrf - (3 * 60.)
 ;    time_wrf_bef@units = time_units 
 ;    date_bef = floattoint(ut_calendar(time_wrf_bef,  0))
 ;    file_bef = "auxhist3_d0"+dom+"_"+sprinti("%0.4i",date_bef(0,0))+"-"+sprinti("%0.2i",date_bef(0,1))+"-"+ \
 ;                                     sprinti("%0.2i",date_bef(0,2))+"_"+sprinti("%0.2i",date_bef(0,3))+":"+ \
 ;                                     sprinti("%0.2i",date_bef(0,4))+":00";+sprinti("%0.2i",date_bef(0,5))
     dow   = day_of_week(year_wrf,month_wrf,day_wrf)
     dow_c = dow_a(dow)
     month_c = month_a(month_wrf)
     year_c = sprinti("%0.2i",year_wrf-2000)
     time_utc = "Valid: "+hh+":"+minute+" UTC "+dow_c+" "+dd+" "+month_c+" "+year_c

     time_wrf_loc = time_wrf + (8*60)
     time_wrf_loc@units = time_units
     time_lab = floattoint(ut_calendar(time_wrf_loc,  0))
     dow2    =  day_of_week(time_lab(0,0),time_lab(0,1),time_lab(0,2))
     dow_loc = dow_a(dow2)
     month_loc = month_a(time_lab(0,1))
     year_loc  = sprinti("%0.2i",time_lab(0,0)-2000)
     time_MDT = sprinti("%0.2i",time_lab(0,3))+":"+sprinti("%0.2i",time_lab(0,4))+" CST "+dow_loc+" "+ \
                sprinti("%0.2i",time_lab(0,2))+" "+month_loc+" "+year_loc

     local_date = ""+ccyy+""+mm+""+dd+""+hh+""+minute
     system("mkdir "+local_date)

  ;-----------------------------------------------------------------------------
  ; 3.3 Define title
  ;----------------------------------------------------------------------------- 
     graph_main_title   = "Domain "+ dom_name + "~C~"+time_utc+" ("+time_MDT+")"; Valid: "+hh+"00 UTC"; on "+ccyy+"/"+mm+"/"+dd
     
     res@TimeLabel                   = times(it)
     res@MainTitle                   = graph_main_title
     res@MainTitlePos                = "Center"

      pltres = True
      ;pltres@gsnDraw  = False
      pltres@gsnFrame = False

      mpres = True
 ;     if (dom.ge.3) then
 ;       mpres@mpDataBaseVersion  = "HighRes"
 ;     else
 ;       mpres@mpDataBaseVersion  = "MediumRes"
 ;     end if
 ;     if (dom.gt.4) then
 ;       mpres@mpDataResolution   = "Finest"
 ;     else
 ;       if (dom.ge.3) then
 ;         mpres@mpDataSetName      = "Earth..4"
 ;;         mpres@mpDataResolution   = "Medium"
 ;       else
 ;         mpres@mpDataSetName      = "Earth..2"
;          mpres@mpDataResolution   = "Unspecified"
;        end if
;      end if
  mpres@mpDataBaseVersion = "MediumRes"
  mpres@mpOutlineOn           = True         ; Turn on map outlines
  mpres@mpOutlineSpecifiers = (/"China:states"/)
 ; mpres@mpOutlineBoundarySets = "National"
  mpres@mpDataSetName = "Earth..4"
  mpres@mpGeophysicalLineColor = "black"     ; color of continental outlines
  mpres@mpNationalLineColor     = "black"
  mpres@mpUSStateLineColor     = "black"
;  mpres@mpGridLineDashPattern  = 2         ; lat/lon lines as dashed

;      mpres@mpGeophysicalLineColor      = "White";"Black"
;      mpres@mpNationalLineColor         = "White";"Black"
;      mpres@mpUSStateLineColor          = "White";"Black"
;      mpres@mpGridLineColor             = "Black"
;      mpres@mpLimbLineColor             = "Black"
      mpres@mpPerimLineColor            = "Black"
      mpres@mpGeophysicalLineThicknessF = 1.
 ;     mpres@mpGridLineThicknessF        = 2.0
 ;     mpres@mpLimbLineThicknessF        = 2.0
      mpres@mpNationalLineThicknessF    = 1.
      mpres@mpUSStateLineThicknessF     = 1.
      mpres@ZoomIn = True
      mpres@Xstart = y_start
      mpres@Ystart = x_start
      mpres@Xend   = y_end
      mpres@Yend   = x_end
      ; mpres@gsnDraw  = False
      mpres@gsnFrame = False
      ; mpres@MainTitle                   = graph_main_title
      ; mpres@MainTitlePos                = "Center"
      ; mpres@tiMainFontThicknessF        = 0.8
      ; mpres@tiMainFontHeightF           = 0.018
      ; mpres@tiMainString                = graph_main_title
;      mpres@mpOutlineDrawOrder            = "Predraw"
      mpres@mpGridAndLimbOn = False

  ;-----------------------------------------------------------------------------
  ; 3.10 Plot lightning total FLASHCOUNT
  ;----------------------------------------------------------------------------- 
      file_out = local_date+"/"+sprinti("d%i",dom)+ \
                 "_RAW_WLPI"
      wks = gsn_open_wks(type,file_out)
      gsn_define_colormap(wks,"wh-bl-gr-ye-re")
      array = (/thres/);(/0.02,0.04,0.08,0.16,0.32,0.64,1.28,2.56,5.12,10.24,20.48,40.96/);ispan(0,50,2)
      nbval = dimsizes (array)
      ;color_tab = floattoint(fspan(2,198,nbval+1))

      opts_var = res
      opts_var@FieldTitle         = "WLPI"
      opts_var@UnitLabel          = "(J/kg)"
      ;opts_var@ContourParameters  = (/ -10., 30., 0.5/)
      ;opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      ;opts_var@cnLevels                = array
      ;opts_var@cnFillColors            = color_tab

      opts_var@cnFillOn           = True
      opts_var@cnFillMode = "RasterFill"
      ;opts_var@cnRasterSmoothingOn = "True"
      ;opts_var@gsnSpreadColors     = True
   opts_var@cnLinesOn       = False
   opts_var@cnLineLabelsOn  = False
   opts_var@cnInfoLabelOn   = False
   opts_var@lbTitlePosition = "Bottom"
   opts_var@gsnFrame        = False

   opts_var@lbLabelBarOn = False
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

      ;   opts_var@gsnSpreadColors      = True
      ;   opts_var@gsnSpreadColorStart  = 40
      opts_var@lbLabelAutoStride    = True

;  all_colors = (/"blue","green","red"/) 
  all_colors = (/66,100,199/)

  contour_var = new(3, graphic)
  do it = 0, 2

     mults = 3 - it
     multe = mults - 1
     time_wrf_s = time_wrf - (mults * 60.)
     time_wrf_e = time_wrf - (multe * 60.)
     indt = ind(all_times.le.time_wrf_e.AND.all_times.gt.time_wrf_s)

     if (all(ismissing(indt))) then
        continue
        delete(indt)
     end if
    print(all_files(indt))
  ;-----------------------------------------------------------------------------
  ; 3.2 Get WRF variables
  ;----------------------------------------------------------------------------- 
    WLPI_unzoom = af[:]->WLPI
    if (dimsizes(indt).eq.1) then
        WLPI = WLPI_unzoom(indt,x_start:x_end,y_start:y_end)
    else
        WLPI = dim_max_n(WLPI_unzoom(indt,x_start:x_end,y_start:y_end),0)
    end if
    delete(indt)
    WLPI@_FillValue = 9.96921e+36
    WLPI = where(WLPI.gt.9998.OR.WLPI.lt.-998, WLPI@_FillValue, WLPI)
    delete(WLPI_unzoom)

      ;array = (/28/);(/0.02,0.04,0.08,0.16,0.32,0.64,1.28,2.56,5.12,10.24,20.48,40.96/);ispan(0,50,2)
      ;nbval = dimsizes (array)
;      color_tab = (/"white",all_colors(it)/)
      color_tab = (/-1,all_colors(it)/)

;      opts_var@FieldTitle         = "WLPI "
;      opts_var@UnitLabel          = "(J/kg) "+sprinti("%0.2i",time_lab(0,3))+":"+sprinti("%0.2i",time_lab(0,4))
;      opts_var@tiMainString = "WLPI "
      opts_var@gsnLeftStringFontColor = all_colors(it)
      opts_var@tiMainFontColor = all_colors(it)

      opts_var@cnLevelSelectionMode    = "ExplicitLevels"
      opts_var@cnLevels                = array
      opts_var@cnFillColors            = color_tab

      contour_var(it)  = wrf_contour(a1,wks,WLPI,opts_var)
    delete(WLPI)
      ;plot = wrf_map_overlays(a1,wks,(/contour_var(it)/),pltres,mpres)
      ;draw(plot)
  end do

      ;plot = wrf_map_overlays(a1,wks,(/contour_var(2)/),pltres,mpres)
      ;draw(plot)
      ;frame(wks)
      ;plot = wrf_map_overlays(a1,wks,(/contour_var(1)/),pltres,mpres)
      ;draw(plot)
      ;frame(wks)
      ;plot = wrf_map_overlays(a1,wks,(/contour_var(0)/),pltres,mpres)
      ;draw(plot)
      ;frame(wks)
      plot = wrf_map_overlays(a1,wks,(/contour_var(2),contour_var(1),contour_var(0)/),pltres,mpres)
      draw(plot)
      frame(wks)

      delete(wks)
      delete(plot)
  system("convert -alpha off -trim +repage -density 120 "+file_out+".png"+" "+file_out+"x.gif") 
  system("convert -resize 800 "+file_out+"x.gif "+file_out+".gif") 
  system("rm "+file_out+".png "+file_out+"x.gif") 

  delete(color_tab)
  delete(array)
  delete(opts_var)

  ;-----------------------------------------------------------------------------
  ; 3.11 End loop over time
  ;-----------------------------------------------------------------------------    
 ;end do
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
