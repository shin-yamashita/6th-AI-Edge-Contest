#!/bin/sh


#shin@E6520:~/ultra96v2/tfacc_u8/doc/img$ ps2pdf -dEPSCrop tfacc-blk.eps tfacc-blk.pdf
#shin@E6520:~/ultra96v2/tfacc_u8/doc/img$ pdf2svg tfacc-blk.pdf tfacc-blk-1.svg
#fn=$1

tmpfn=`mktemp`

for fn in $*; do
 tgif -print -color -eps -stdout -quiet $fn | ps2pdf -dEPSCrop - $tmpfn
 fn=`basename $fn .obj`
 pdf2svg $tmpfn $fn.svg
done

rm $tmpfn


 