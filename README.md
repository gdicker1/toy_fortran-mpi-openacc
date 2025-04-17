# Toy MPI OpenACC Fortran Program

This program explores GPUDirect RDMA in a few set ups on NSF NCAR's Derecho system. This is to mainly look at run-time configuration (environment variables)

The build.sh script creates the program `mpi-acc_toy.out`:
```
./build.sh [BLD_ACC='some_str' BLD_DBG='some_str']
```
- If set `BLD_ACC` adds OpenACC flags to the build to run on GPUs (CPU otherwise).
- If set `BLD_DBG` uses debug flags for the build (optimized flags otherwise)

The program expects to only be run with 2 ranks, and fails with any other rank count. E.g.
```
mpiexec -n2 mpi-acc_toy.out
```

These kinds of MPI programs are best run within Derecho's queues, see the run.pbs and run_acc.pbs scripts.

There's no problems with CPU runs, but GPU runs can fail if environment variables are missing.
- The easiest way to get the correct flags is to use the NCAR-specific `set_gpu_rank` script within the `mpiexec` command
- With Cray-MPICH the `MPICH_GPU_SUPPORT_ENABLED=1` seems to be the most important environment variable (needs more testing).