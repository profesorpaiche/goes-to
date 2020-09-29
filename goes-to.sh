#!/bin/sh

# Version 0.0.1

set -e

# Call getopt to validate the input

options=$(getopt -o U:I:O:tcpi -l ullr:,input:,output: -- "$@")

[ $? -eq 0 ] || {
    echo "Incorrect options provided"
    exit 1
}
 
eval set -- "$options"

keep_temp=false
keep_crop=false
keep_proj=false
show_info=false

while true
do
    case $1 in
        -U | --ullr) in_ullr="$2"; shift 2 ;;
        -I | --input) file_in="$2"; shift 2 ;;
        -O | --output) file_out="$2"; shift 2 ;;
        -t) keep_temp=true; shift ;;
        -c) keep_crop=true; shift ;;
        -p) keep_proj=true; shift ;;
        -i) show_info=true; shift ;;
        --) shift; break ;;
        *) break ;;
    esac
done

if [ -z $file_in ] ; then
    echo "Input file not specified"
    exit 1
fi

# General information

ginfo=$(gdalinfo $file_in -sd 1)

# Variable CMI

gvar=$(echo "NETCDF:$file_in:CMI")

# Get projection

prjini=$(echo "$ginfo" | grep 'PROJCRS' -n | head -1 | cut -d ':' -f 1)
prjfin=$(echo "$ginfo" | grep '\]\]\]\]' -n | tail -1 | cut -d ':' -f 1)
prjend=$(( $prjfin+1 ))
prjsel=$prjini","$prjfin"p;"$prjend"q"

echo "$ginfo" | sed -n $prjsel > g16_prj.txt

# Coordinates 

ul=$(echo "$ginfo" | grep 'Upper Left')
ulx=$(echo $ul | awk -F '(' '{print $2}' | awk -F ',' '{print $1}')
uly=$(echo $ul | awk -F ',' '{print $2}' | awk -F ')' '{print $1}')

lr=$(echo "$ginfo" | grep 'Lower Right')
lrx=$(echo $lr | awk -F '(' '{print $2}' | awk -F ',' '{print $1}')
lry=$(echo $lr | awk -F ',' '{print $2}' | awk -F ')' '{print $1}')

# Show only information of the file

if [ $show_info = true ]; then

    # Flattening

    iflat=$(echo "$ginfo" | grep 'inverse_flattening' | awk -F '=' '{print $2}')
    flat=$(echo "scale=20; 1/$iflat" | bc)

    # Longitude of projection

    plon=$(echo "$ginfo" | grep 'longitude_of_projection' | awk -F '=' '{print $2}')

    # Height of satellite

    height=$(echo "$ginfo" | grep 'perspective_point_height' | awk -F '=' '{print $2}')

    # Semi axis

    sma=$(echo "$ginfo" | grep 'semi_major_axis' | awk -F '=' '{print $2}')
    smb=$(echo "$ginfo" | grep 'semi_minor_axis' | awk -F '=' '{print $2}')

    # Parameters for byte -> temperature (K)

    offset=$(echo "$ginfo" | grep "CMI#add_offset" | awk -F '=' '{print $2}')
    scale=$(echo "$ginfo" | grep "CMI#scale_factor" | awk -F "=" '{print $2}')

    # Print information

    cat g16_prj.txt
    echo "flattening: $flat"
    echo "longitude proj: $plon"
    echo "height: $height"
    echo "semi major axis: $sma"
    echo "semi minor axis: $smb"
    echo "ullr: $ulx $uly $lrx $lry"
    echo "offset: $offset"
    echo "scale: $scale"

# Reprojection

else

    # Check for output file

    if [ -z $file_out ] ; then
        echo "Output file not specified"
        exit 1
    fi

    # Check for cropping coordinates

    if [ -z "$in_ullr" ] ; then
        echo "Cropping coordinates not specified"
        exit 1
    fi

    in_ulx=$(echo $in_ullr | awk '{print $1}')
    in_uly=$(echo $in_ullr | awk '{print $2}')
    in_lrx=$(echo $in_ullr | awk '{print $3}')
    in_lry=$(echo $in_ullr | awk '{print $4}')

    # Assing geostationary projection

    gdal_translate -of 'netCDF' -a_srs './g16_prj.txt' -a_ullr $ulx $uly $lrx $lry -a_nodata -1 $gvar 'G16_temp.nc'

    # Cropping

    gdal_translate -of 'netCDF' -projwin $in_ulx $in_uly $in_lrx $in_lry -projwin_srs 'EPSG:4326' 'G16_temp.nc' 'G16_crop.nc'

    # Warping

    gdalwarp -of 'netCDF' -t_srs 'EPSG:4326' -overwrite 'G16_crop.nc' $file_out

    # Erasing remaining files

    if [ $keep_temp = false ] ; then rm G16_temp.nc ; fi
    if [ $keep_crop = false ] ; then rm G16_crop.nc ; fi

fi

# Erasing projection file

if [ $keep_proj = false ] ; then rm g16_prj.txt ; fi

