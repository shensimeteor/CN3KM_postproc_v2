;system specific
undef("covert_and_copyout")
procedure convert_and_copyout(figure_name, arr_dir_copyout)
begin
    convert="convert -alpha off -trim +repage -density 120 "
;GECN3KM, with .gif name, but png format
;    strs=str_split(figure_name, ".")
;    nstr=dimsizes(strs)
;    strs(nstr-1) = "png"
;    new_name=str_join(strs, ".")
;    system(convert+figure_name+" "+new_name)
;    strs(nstr-1) = "gif"
;    x_name=str_join(strs,".")
;    system("mv "+new_name + " " +x_name)
;    new_name=x_name
;just .gif format with .gif suffix 
    strs=str_split(figure_name, ".")
    nstr=dimsizes(strs)
    strs(nstr-1) = "gif"
    new_name=str_join(strs, ".")
    system(convert+figure_name+" "+new_name)
    ndir=dimsizes(arr_dir_copyout)
    do i=0,ndir-1
        system("test -d "+arr_dir_copyout(i) + " || mkdir -p "+arr_dir_copyout(i))
        system("cp "+new_name + " " +arr_dir_copyout(i))
    end do
end

