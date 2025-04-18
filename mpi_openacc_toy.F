
module my_routines

use mpi, only : MPI_COMM_WORLD, MPI_Send, MPI_Recv, MPI_REAL, MPI_WAIT, MPI_STATUS_IGNORE, MPI_SUCCESS, MPI_BARRIER

implicit none

integer :: size=-1, rank=-1

contains

subroutine run_rank0(N_arr, values, ierr)

   ! inputs and outputs
   integer, intent(in) :: N_arr
   real, intent(in) :: values
   integer, intent(inout) :: ierr

   ! local variables
   integer :: i, mpi_err = 0
   real, dimension(:), allocatable :: arr
   character(len=256) :: msg


   ierr = 0
   msg = ''

   ! create data on rank0
   allocate(arr(N_arr))
   arr(:) = 0.0
   !$acc enter data copyin(arr)

   ! initialize GPU data on rank0 to pi
   !$acc parallel default(present)
   !$acc loop gang vector
   do i=1, N_arr
      arr(i) = values
   end do
   !$acc end parallel

   ! print CPU array on rank0
   write(msg,'(I0,A)') rank, ': CPU arr='
   write(*,*) trim(msg), arr
   call flush()

   ! Send array to rank1
   !$acc host_data use_device(arr)
   call MPI_Send(arr, N_arr, MPI_REAL, 1, 2, MPI_COMM_WORLD, mpi_err)
   !$acc end host_data
   if (mpi_err .ne. MPI_SUCCESS) then
      write(*,'(A,I0,A,I0)') 'ERROR ', rank, ': MPI_Send returned non-zero status mpi_err=', mpi_err
      ierr = 1
      return
   end if
 
   ! print GPU array on rank0
   !! Careful with asynchonous MPI, we could remove the device(arr)
   !! before the send finishes. Undetermined behavior.
   call MPI_BARRIER(MPI_COMM_WORLD, mpi_err)
   
   !$acc exit data copyout(arr)
   
   write(msg,'(I0,A)') rank, ': GPU (sent) arr='
   write(*,*) trim(msg), arr
   call flush()


end subroutine run_rank0


subroutine run_rank1(N_arr, values, ref_vals, ierr)

   ! inputs and outputs
   integer, intent(in) :: N_arr
   real, intent(in) :: values, ref_vals
   integer, intent(inout) :: ierr

   ! local variables
   integer :: i,  mpi_err = 0
   real, dimension(:), allocatable :: arr
   character(len=256) :: msg

   msg = ''
   ierr = 0

   ! create data on rank0
   allocate(arr(N_arr))
   arr(:) = 0.0
   !$acc enter data copyin(arr)
   write(msg,'(I0,A)') rank, ': init GPU arr='
   write(*,*) trim(msg), arr
   call flush()

   ! initialize data on rank1, on CPU
   do i=1, N_arr
      arr(i) = values
   end do
   write(msg,'(I0,A)') rank, ': init CPU arr='
   write(*,*) trim(msg), arr
   call flush()

   ! Get array from rank0
   !$acc host_data use_device(arr)
   call MPI_Recv(arr, N_arr, MPI_REAL, 0, 2, MPI_COMM_WORLD, MPI_STATUS_IGNORE, mpi_err)
   !$acc end host_data
   if (mpi_err .ne. MPI_SUCCESS) then
      write(*,'(A,I,A,I)') 'ERROR ', rank, ': MPI_Recv returned non-zero status,', mpi_err
      ierr = 1
      return
   end if
   call MPI_BARRIER(MPI_COMM_WORLD, mpi_err)

   ! print CPU array on rank0
   write(msg,'(I0,A)') rank, ': post-recv, pre-copyout CPU arr='
   write(*,*) trim(msg), arr
   write(*,*) rank, ': post-recv CPU arr=', arr
   call flush()
   
   ! print GPU array on rank0
   !$acc exit data copyout(arr)
   write(msg,'(I0,A)') rank, ': post-recv, post-copyout GPU/CPU arr='
   write(*,*) trim(msg), arr
   write(msg, '(I0,A,L1)') rank, ': post-recv matches reference values? ', all(arr == ref_vals)
   write(*,*) trim(msg)
   call flush()

end subroutine run_rank1
end module my_routines


program main

   use mpi, only : MPI_INIT, MPI_FINALIZE, MPI_COMM_WORLD, MPI_COMM_SIZE, MPI_COMM_RANK
   use my_routines 

   
   integer, parameter :: N = 5
   real, parameter :: val0 = 3.14159
   real, parameter :: val1 = -1.0
   integer :: ierr = 0


   call MPI_INIT(ierr)
   call MPI_COMM_SIZE(MPI_COMM_WORLD, size, ierr)
   call MPI_COMM_RANK(MPI_COMM_WORLD, rank, ierr)
   if (ierr .ne. 0) then
      print *, 'ERROR starting MPI.'
      call MPI_ABORT()
   end if

   print '(I0,A)', rank, ': Starting mpi_openacc_toy program\n'

   ! abort if size != 2
   if ( size .ne. 2) then
      if ( rank .eq. 0) then
         write(*,'(A,I0)'), "ERROR this should be run with only 2 MPI ranks comm_size is: ", size
         call MPI_ABORT()
      end if
   end if
   ! call MPI_WAIT(-2, MPI_STATUS_IGNORE, ierr)

   if ( rank .eq. 0) then
      call run_rank0(N, val0, ierr)
   else if (rank .eq. 1) then
      call run_rank1(N, val1, val0, ierr)
   else
      write(*,'(A,I0)'), "ERROR rank should only be 0 or 1 but rank is: ", rank
      call MPI_ABORT()
   end if

   if (ierr .ne. 0) then
      write(*,'(A,I0,A,I0)') "ERROR ", rank, ":  ierr isn't 0 after calling run_* routine. ierr=", ierr 
      call MPI_ABORT()
   end if

   call MPI_FINALIZE(ierr)

end program

