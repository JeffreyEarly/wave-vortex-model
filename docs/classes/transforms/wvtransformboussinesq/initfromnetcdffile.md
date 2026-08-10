---
layout: default
title: initFromNetCDFFile
parent: WVTransformBoussinesq
grand_parent: Transforms
nav_order: 150
mathjax: true
---

#  initFromNetCDFFile

initialize the flow from a NetCDF file


---

## Declaration
```matlab
 initFromNetCDFFile(ncfile,options)
```
## Parameters
+ `ncfile`  a NetCDF file object
+ `options.iTime`  time index to initialize from; default `1`
+ `options.shouldDisplayInit`  display the restored representation; default `false`

## Discussion

Clears variables Ap,Am,A0 and then sets them the values found in the file
at the requested time.

This is intended to be used in conjunction with
[`waveVortexTransformFromFile`](/classes/transforms/wvtransform/wavevortextransformfromfile.html)
e.g.,

```matlab
[wvt,ncfile] = WVTransform.waveVortexTransformFromFile('cyprus-eddy.nc');
t = ncfile.readVariables('t');
for iTime=1:length(t)
    wvt.initFromNetCDFFile(ncfile,iTime=iTime)
    // some analysis
end
```

Note that this method only lightly checks that you are reading from a
file that is compatible with this transform! So be careful.

See also the users guide for [reading and writing to
file](/users-guide/reading-and-writing-to-file.html).
