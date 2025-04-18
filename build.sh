#!/usr/bin/env bash

# Purge, but suppress output about "The following modules were not unloaded..."
module purge 2> /dev/null
module load ncarenv/24.12
module load nvhpc cuda cray-mpich ncarcompilers
ml

FLAGS="-Mfree"
if [ -n "${BLD_ACC}" ] ; then
    FLAGS+=" -target-accel=nvidia80 -acc -gpu=lineinfo -Minfo=accel"
else
    FLAGS+=" -noacc"
fi
if [ -n "${BLD_DBG}" ] ; then
    FLAGS+=" -O0 -g -traceback"
    if [ -n "${BLD_ACC}" ] ; then
        FLAGS+=" -gpu=debug"
    fi
else
    FLAGS+=" -O -gopt"
fi

ftn ${FLAGS} -o mpi-acc_toy.out mpi_openacc_toy.F

# Default CPU Build
# mpif90 -Mfree -O -gopt -noacc -o mpi-acc_toy.out mpi_openacc_toy.F
# Debug CPU Build
# mpif90 -Mfree -O0 -g -noacc -o mpi-acc_toy.out mpi_openacc_toy.F
# Default GPU Build
# mpif90 -Mfree -O -gopt -acc -o mpi-acc_toy.out mpi_openacc_toy.F
# Debug GPU Build
# mpif90 -Mfree -O0 -g -G -acc -o mpi-acc_toy.out mpi_openacc_toy.F