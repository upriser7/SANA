#!/bin/sh
echo() { /bin/echo "$@"
}
die() { echo "FATAL ERROR: $@" >&2; exit 1
}
CORES=`cpus 2>/dev/null || echo 4`
PATH="`pwd`/scripts:$PATH"
export PATH
DIR=/tmp/syeast.$$
MINSUM=0.25
MEASURE="-ms3 1 -ms3_type 1"
trap "/bin/rm -rf $DIR" 0 1 2 3 15
if [ `hostname` = Jenkins ]; then
    ITERS=99; minutes=1
else
    ITERS=40; minutes=1
fi
case "$#" in
2) ITERS=$1;minutes=$2; shift 2;;
3) ITERS=$1;minutes=$2; MEASURE="$3"; shift 3;;
esac
/bin/rm -rf $DIR networks/*/autogenerated /var/preserve/autogen* /tmp/autogen* networks/*-shadow*
echo "Running $ITERS iterations of $minutes minute(s) each"
./multi-pairwise.sh ./sana.multi "$MEASURE" $ITERS $minutes "-parallel $CORES" $DIR networks/syeast[12]*/*.el || die "multi-pairwise failed"
cd $DIR
rename.sh ';dir;dir0;' dir?
mv dir00 dir0 # all except this zeroth one
echo "Now check NC values: below are the number of times the multiple alignment contains k correctly matching nodes, k=2,3,4:"
echo "iter	NC2	NC3	NC4"
for d in dir??; do echo "$d" `for i in 2 3 4; do gawk '{delete K;for(i=1;i<=NF;i++)++K[$i];for(i in K)if(K[i]>='$i')print}' $d/multiAlign.tsv | wc -l; done` | sed 's/ /	/g'; done
echo "And now the Multi-NC, or MNC, measure, of the final alignment"
echo 'k	number	MNC'
for k in 2 3 4; do echo "$k	`gawk '{delete K;for(i=1;i<=NF;i++)++K[$i];for(i in K)if(K[i]>='$k')nc++}END{printf "%d\t%.3f\n",nc,nc/NR}' dir$ITERS/multiAlign.tsv`"
done | tee $DIR/MNC.txt
echo "Check MNC are high enough: k=2,3,4 => 0.25,0.15,0.05, or sum >= $MINSUM"
echo "DIR is $DIR"
gawk 'BEGIN{code=0}{k=$1;expect=(0.45-k/10);sum+=$3;if($3<expect)code=1}END{if(sum>'$MINSUM')code=0; exit(code)}' $DIR/MNC.txt || die "MNC failed"
