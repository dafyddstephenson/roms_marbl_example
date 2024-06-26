#!/bin/bash


case "$CSTAR_SYSTEM" in
    osx_arm64_gnu)
        ROMS_EXEC_CMD() {
            mpirun -n 9 ./roms ./roms.in_${PREFIX}
        }
        ;;
    sdsc_expanse_intel)
        ROMS_EXEC_CMD() {
            srun --mpi=pmi2 -n 9 ./roms ./roms.in_${PREFIX}
        }
        ;;
    ncar_derecho_intel)
	cd $PBS_O_WORKDIR
        ROMS_EXEC_CMD() {
            mpirun -n 9 ./roms ./roms.in_${PREFIX}	    
        }
        ;;
    *)
        echo "System $CSTAR_SYSTEM not recognised. Configure your ROMS-MARBL environment using C-Star (https://github.com/CWorthy-ocean/C-Star)"
	exit 1
        ;;
esac


NP_XI=3; # from code/param.opt
NP_ETA=3;

if grep -q "\!\# define BIOLOGY_BEC2" code/cppdefs.opt;
then
    if grep -q "\!\# define MARBL\b" code/cppdefs.opt;
    then
	PREFIX=NOBGC # No biology
    elif grep -q "\# define MARBL\b" code/cppdefs.opt;
    then
	 PREFIX=MARBL # BGC with MARBL
    fi
elif grep -q "\# define BIOLOGY_BEC2" code/cppdefs.opt;
then
    PREFIX=BEC # BGC with BEC
fi


# Split the initial and boundary conditions for use on multiple CPUs (default 8)
rundir=$(pwd)
if [ -e roms ];then rm roms;fi
ln -s code/roms .

cd INPUT/
mkdir PARTED/
for X in {\
roms_bry_2012.nc,roms_bry_bgc_"${PREFIX}".nc,roms_frc.201112.nc,\
roms_frc.2012??.nc,roms_frc_bgc.nc,roms_grd.nc,\
"${PREFIX}"_rst.20120103120000.nc};do

    if [ "${X}" = "roms_bry_bgc_NOBGC.nc" ];then continue;fi
    
    if [ -e PARTED/"${X/.nc}".0.nc ];then
	echo "INPUT/${X} appears to have already been partitioned. Continuing."
	continue
    else
    partit "${NP_XI}" "${NP_ETA}" "${X}";
    mv -v "${X/.nc}".?.nc PARTED/
    fi
done
cd ${rundir}
if [ ! -d RST ];then mkdir RST;fi
ln -s ${rundir}/INPUT/PARTED/${PREFIX}_rst.20120103120000.?.nc RST/

#mpirun -n 9 ./roms ./roms.in_"${PREFIX}"
ROMS_EXEC_CMD


echo "MAIN RUN DONE"
echo "########################################################################"

cp ${PREFIX}_rst.*.?.nc RST/

for X in ${PREFIX}_???.*.0.nc; do
    ncjoin ${X/.0.nc}.?.nc
    if [ -e ${X/.0.nc}.nc ]; then
	rm ${X/.0.nc}.?.nc
    fi
done
