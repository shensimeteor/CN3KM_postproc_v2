undef("convert_figure")  
procedure convert_figure(fig_title:string, in_format:string, out_format:string) 
local in_figure, out_figure, temp_figure
begin
    in_figure=fig_title+"."+in_format
    out_figure=fig_title+"."+out_format
    if (in_format .eq. out_format) then
        temp_figure=fig_title+".temp."+out_format
        cmd1="convert -alpha off -trim +repage -density 120 "+in_figure+" "+temp_figure
        cmd2="rm "+in_figure+" && mv "+temp_figure+" "+out_figure
    else
        cmd1="convert -alpha off -trim +repage -density 120 "+in_figure+" "+out_figure
        cmd2="rm "+in_figure
    end if
    system(cmd1)
    system(cmd2)
end
