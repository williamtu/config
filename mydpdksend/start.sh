if [ $# -lt 1 ]; then
	MICROFLOWS=2
else
	MICROFLOWS=$1
fi
ulimit -l unlimited
sudo ./build/app/mypktgen -c 0xff -n 1 -m 256 --log-level=7 -- $MICROFLOWS 
