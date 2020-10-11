# goes-to

This little script reprojects the raw images from the GOES 16 satellite. At the moment, it only has been tested with single bands and full disk images. Also, the outputs from the script are in netCDF format.

You can download the data from:

http://home.chpc.utah.edu/~u0553130/Brian_Blaylock/cgi-bin/goes16_download.cgi

## Dependencies

- gdal-bin

## Examples

Get information from the image with the `-i` flag.

`goes-to -i --input GOES16_image.nc`

Reproject and crop image.

`goes-to --ullr "-84 2 -66 -19" --input GOES16_image.nc --output crop_image.nc`
