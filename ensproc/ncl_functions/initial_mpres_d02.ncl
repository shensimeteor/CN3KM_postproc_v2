undef("initial_mpres")
function initial_mpres()
local mpres
begin
    mpres=True
    mpres@mpPerimOn = True
    mpres@mpDataBaseVersion = "MediumRes"
    mpres@mpOutlineOn           = True         ; Turn on map outlines
    mpres@mpOutlineSpecifiers = (/"China:states"/)
    mpres@mpDataSetName = "Earth..4"
    mpres@mpGeophysicalLineColor = "black"     ; color of continental outlines
    mpres@mpAreaMaskingOn            = True
    mpres@mpMaskAreaSpecifiers       = (/"China"/)
    mpres@mpNationalLineColor     = "black"
    mpres@mpUSStateLineColor     = "black"
    mpres@mpGeophysicalLineColor      = "Black"
    mpres@mpNationalLineColor         = "Black"
    mpres@mpUSStateLineColor          = "Black"
    mpres@mpGridLineColor             = "Black"
    mpres@mpLimbLineColor             = "Black"
    mpres@mpPerimLineColor            = "Black"
    mpres@mpGeophysicalLineThicknessF = 2.0
    mpres@mpNationalLineThicknessF    = 2.0
    mpres@mpUSStateLineThicknessF     = 1.5
    mpres@mpGridAndLimbOn = False
    mpres@mpGridLineThicknessF        = 1.5
    mpres@mpLimbLineThicknessF        = 1.5
    return(mpres)
end
