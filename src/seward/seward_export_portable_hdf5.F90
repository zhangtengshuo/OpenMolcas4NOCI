!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
!***********************************************************************

#include "compiler_features.h"
#ifdef _HDF5_

module Seward_Portable_HDF5

use, intrinsic :: iso_c_binding, only: c_int64_t
use Cholesky, only: InfVec, mmBstRT, NumCho
use filesystem, only: mkdir_
use mh5, only: mh5_close_dset, mh5_close_file, mh5_close_group, mh5_create_dset_i64, mh5_create_dset_real, &
               mh5_create_dset_real_large_uncompressed, mh5_create_dset_str, mh5_create_file, mh5_create_group, &
               mh5_flush_file, mh5_init_attr, mh5_put_dset, mh5_put_dset_i64, mh5_put_dset_real_hyperslab_noflush
use Molcas, only: LenIn
use OneDat, only: sNoNuc, sNoOri
use Para_Info, only: King, MyRank, nProcs
use Definitions, only: wp, iwp, u6

implicit none
private

integer(kind=iwp), parameter :: FORMAT_MAJOR = 1_iwp
integer(kind=iwp), parameter :: FORMAT_MINOR = 0_iwp
integer(kind=iwp), parameter :: MAX_PATH = 4096_iwp
integer(kind=c_int64_t), parameter :: TARGET_BATCH_BYTES = 256_c_int64_t*1024_c_int64_t*1024_c_int64_t

public :: Seward_Export_Portable_HDF5

contains

subroutine Seward_Export_Portable_HDF5()
  integer(kind=iwp) :: batch, dsetid, fileid, first_vector, global_numcho(1), groupid, i, irc, local_numcho, n_ao, n_bas(1), n_reduced
  integer(kind=iwp) :: dims2(2), exts2(2), offs2(2), chunks2(2)
  integer(kind=iwp), allocatable :: coverage(:), local_counts(:), local_bounds(:,:), reduced_pairs(:,:)
  integer(kind=c_int64_t), allocatable :: global_ids(:)
  real(kind=wp), allocatable :: factors(:,:), scratch(:)
  character(len=MAX_PATH) :: final_dir, manifest_path, output_dir, partial_dir, shard_path, shard_temp
  character(len=64) :: shard_name
  character(len=256) :: project
  logical(kind=iwp) :: exists
  integer(kind=iwp), external :: AixMv

  call get_environment_variable('Project',project)
  call get_environment_variable('MOLCAS_OUTPUT',output_dir)
  if (len_trim(project) == 0) call export_error('Project is not defined.')
  if (len_trim(output_dir) == 0) call export_error('MOLCAS_OUTPUT is not defined.')

  partial_dir = trim(output_dir)//'/'//trim(project)//'.NOCI_SEWARD_H5.partial'
  final_dir = trim(output_dir)//'/'//trim(project)//'.NOCI_SEWARD_H5'
  if (King()) then
    inquire(file=trim(partial_dir),exist=exists)
    if (exists) call export_error('Refusing to overwrite existing partial export: '//trim(partial_dir))
    inquire(file=trim(final_dir),exist=exists)
    if (exists) call export_error('Refusing to overwrite existing export: '//trim(final_dir))
    call mkdir_(trim(partial_dir),irc)
    if (irc /= 0) call export_error('Could not create export directory: '//trim(partial_dir))
  end if
  call GASync()

  call Get_iArray('NumCho',global_numcho,1)
  if (global_numcho(1) < 1) call export_error('The RunFile contains no Cholesky vectors.')
  call Get_iArray('nBas',n_bas,1)
  n_ao = n_bas(1)

  call Cho_X_Init(irc,0.0_wp)
  if (irc /= 0) call export_error('Cho_X_Init failed during HDF5 export.')

  n_reduced = mmBstRT
  local_numcho = NumCho(1)
  if (n_reduced < 1) call export_error('The reduced AO-pair dimension is zero.')
  if (local_numcho < 1) call export_error('Format version 1 requires at least one local Cholesky vector per MPI rank.')

  allocate(reduced_pairs(2,n_reduced))
  call Cho_RstOF(reduced_pairs,2,n_reduced,1)
  if (any(reduced_pairs < 1) .or. any(reduced_pairs > n_ao)) then
    call export_error('Invalid reduced AO-pair mapping returned by Cho_RstOF.')
  end if

  allocate(global_ids(local_numcho),coverage(global_numcho(1)))
  coverage = 0
  do i=1,local_numcho
    global_ids(i) = int(InfVec(i,5,1),c_int64_t)
    if ((global_ids(i) < 1_c_int64_t) .or. (global_ids(i) > int(global_numcho(1),c_int64_t))) then
      call export_error('A local Cholesky vector has an invalid global auxiliary index.')
    end if
    coverage(int(global_ids(i),iwp)) = coverage(int(global_ids(i),iwp))+1
  end do
  call GAIGOP(coverage,global_numcho(1),'+')
  if (any(coverage /= 1)) call export_error('MPI Cholesky shards do not cover every global auxiliary index exactly once.')
  deallocate(coverage)

  allocate(local_counts(nProcs),local_bounds(2,nProcs))
  local_counts = 0
  local_bounds = 0
  local_counts(MyRank+1) = local_numcho
  local_bounds(1,MyRank+1) = int(minval(global_ids),iwp)
  local_bounds(2,MyRank+1) = int(maxval(global_ids),iwp)
  call GAIGOP(local_counts,nProcs,'+')
  call GAIGOP(local_bounds,2*nProcs,'+')
  if (sum(local_counts) /= global_numcho(1)) call export_error('MPI shard counts do not sum to the global Cholesky count.')

  write(shard_name,'("rank_",I4.4,".h5")') MyRank
  shard_temp = trim(partial_dir)//'/'//trim(shard_name)//'.partial'
  shard_path = trim(partial_dir)//'/'//trim(shard_name)
  fileid = mh5_create_file(trim(shard_temp))
  call write_root_attributes(fileid,'shard')
  call mh5_init_attr(fileid,'MPI_RANK',MyRank)
  call mh5_init_attr(fileid,'MPI_SIZE',nProcs)
  call mh5_init_attr(fileid,'N_LOCAL_AUXILIARY',local_numcho)
  call mh5_init_attr(fileid,'N_REDUCED_PAIRS',n_reduced)
  groupid = mh5_create_group(fileid,'cholesky')

  dsetid = mh5_create_dset_i64(groupid,'global_auxiliary_indices',1,[local_numcho])
  call mh5_init_attr(dsetid,'INDEX_BASE',1_iwp)
  call mh5_put_dset_i64(dsetid,global_ids)
  call mh5_close_dset(dsetid)

  batch = int(min(int(local_numcho,c_int64_t),max(1_c_int64_t,TARGET_BATCH_BYTES/max(1_c_int64_t,16_c_int64_t*int(n_reduced,c_int64_t)))),iwp)
  dims2 = [n_reduced,local_numcho]
  chunks2 = [n_reduced,batch]
  dsetid = mh5_create_dset_real_large_uncompressed(groupid,'factors',2,dims2,chunks2)
  call mh5_init_attr(dsetid,'AXIS_ORDER','auxiliary,reduced_pair')
  call mh5_init_attr(dsetid,'COMPRESSION','none')

  allocate(factors(n_reduced,batch),scratch(n_reduced*(batch+1)+1))
  first_vector = 1
  do while (first_vector <= local_numcho)
    i = min(batch,local_numcho-first_vector+1)
    call Cho_GetVec(factors(:,1:i),n_reduced,i,first_vector,1,scratch,size(scratch))
    exts2 = [n_reduced,i]
    offs2 = [0,first_vector-1]
    call mh5_put_dset_real_hyperslab_noflush(dsetid,factors(:,1:i),exts2,offs2)
    first_vector = first_vector+i
  end do
  call mh5_flush_file(fileid)
  call mh5_close_dset(dsetid)
  call mh5_close_group(groupid)
  call mh5_close_file(fileid)
  deallocate(factors,scratch,global_ids)
  irc = AixMv(trim(shard_temp),trim(shard_path))
  if (irc /= 0) call export_error('Could not atomically publish an HDF5 shard.')

  call GASync()
  if (King()) then
    manifest_path = trim(partial_dir)//'/manifest.h5.partial'
    call write_manifest(trim(manifest_path),project,n_ao,n_reduced,global_numcho(1),reduced_pairs,local_counts,local_bounds)
    irc = AixMv(trim(manifest_path),trim(partial_dir)//'/manifest.h5')
    if (irc /= 0) call export_error('Could not atomically publish the HDF5 manifest.')
  end if
  call GASync()

  call Cho_X_Final(irc)
  if (irc /= 0) call export_error('Cho_X_Final failed after HDF5 export.')
  deallocate(reduced_pairs,local_counts,local_bounds)

  call GASync()
  if (King()) then
    irc = AixMv(trim(partial_dir),trim(final_dir))
    if (irc /= 0) call export_error('Could not atomically publish the completed HDF5 export directory.')
    write(u6,'(6X,A)') 'Portable NOCI SEWARD data: '//trim(final_dir)
  end if
  call GASync()
end subroutine Seward_Export_Portable_HDF5

subroutine write_root_attributes(fileid,file_kind)
  integer(kind=iwp), intent(in) :: fileid
  character(len=*), intent(in) :: file_kind
  call mh5_init_attr(fileid,'FORMAT_NAME','OpenMolcas NOCI SEWARD portable data')
  call mh5_init_attr(fileid,'FORMAT_MAJOR',FORMAT_MAJOR)
  call mh5_init_attr(fileid,'FORMAT_MINOR',FORMAT_MINOR)
  call mh5_init_attr(fileid,'FILE_KIND',file_kind)
  call mh5_init_attr(fileid,'INDEX_BASE',1_iwp)
  call mh5_init_attr(fileid,'FLOAT_FORMAT','IEEE_F64LE')
  call mh5_init_attr(fileid,'INTEGER_FORMAT','I64LE')
  call mh5_init_attr(fileid,'SYMMETRY_MODE','C1')
  call mh5_init_attr(fileid,'FACTOR_CONVENTION','(pq|rs)=sum_L L[pq,L]*L[rs,L]')
  call mh5_init_attr(fileid,'PAIR_CONVENTION','explicit AO indices in basis/reduced_pair_indices')
end subroutine write_root_attributes

subroutine write_manifest(path,project,n_ao,n_reduced,n_auxiliary,reduced_pairs,local_counts,local_bounds)
  character(len=*), intent(in) :: path, project
  integer(kind=iwp), intent(in) :: n_ao, n_reduced, n_auxiliary, reduced_pairs(2,n_reduced), local_counts(:), local_bounds(:,:)
  integer(kind=iwp) :: basis_group, dsetid, fileid, i, one_group, provenance_group, shards_group, system_group
  integer(kind=c_int64_t), allocatable :: bounds64(:,:), counts64(:), pairs64(:,:)
  character(len=64), allocatable :: shard_names(:)
  real(kind=wp) :: potnuc, threshold
  real(kind=wp), allocatable :: atom_coordinates(:,:), effective_charges(:), nuclear_charges(:), center_of_mass(:), &
                                core_hamiltonian(:,:), dipole(:,:,:), &
                                kinetic(:,:), multipole_origins(:,:), nuclear_attraction(:,:), overlap(:,:), quadrupole(:,:,:)
  character(len=LenIn), allocatable :: atom_names(:)
  character(len=LenIn+8), allocatable :: basis_names(:)
  integer(kind=iwp) :: n_atoms

  fileid = mh5_create_file(path)
  call write_root_attributes(fileid,'manifest')
  system_group = mh5_create_group(fileid,'system')
  basis_group = mh5_create_group(fileid,'basis')
  one_group = mh5_create_group(fileid,'one_electron')
  shards_group = mh5_create_group(fileid,'shards')
  provenance_group = mh5_create_group(fileid,'provenance')

  call write_i64_scalar(system_group,'n_symmetry',1_c_int64_t)
  call write_i64_scalar(system_group,'n_ao',int(n_ao,c_int64_t))
  call write_i64_scalar(system_group,'n_reduced_pairs',int(n_reduced,c_int64_t))
  call write_i64_scalar(system_group,'n_auxiliary_global',int(n_auxiliary,c_int64_t))
  call write_i64_scalar(system_group,'n_mpi_ranks',int(size(local_counts),c_int64_t))
  call Get_dScalar('PotNuc',potnuc)
  call Get_dScalar('Cholesky Threshold',threshold)
  call write_real_scalar(system_group,'nuclear_repulsion',potnuc,'hartree')
  call write_real_scalar(system_group,'cholesky_threshold',threshold,'hartree')

  allocate(pairs64(2,n_reduced))
  pairs64 = int(reduced_pairs,c_int64_t)
  dsetid = mh5_create_dset_i64(basis_group,'reduced_pair_indices',2,[2,n_reduced])
  call mh5_init_attr(dsetid,'AXIS_ORDER','reduced_pair,ao_index')
  call mh5_init_attr(dsetid,'INDEX_BASE',1_iwp)
  call mh5_put_dset_i64(dsetid,pairs64)
  call mh5_close_dset(dsetid)
  deallocate(pairs64)

  allocate(basis_names(n_ao))
  call Get_cArray('Unique Basis Names',basis_names,(LenIn+8)*n_ao)
  dsetid = mh5_create_dset_str(basis_group,'ao_labels',1,[n_ao],LenIn+8)
  call mh5_put_dset(dsetid,basis_names)
  call mh5_close_dset(dsetid)
  deallocate(basis_names)

  call Get_iScalar('Unique centers',n_atoms)
  allocate(atom_names(n_atoms),atom_coordinates(3,n_atoms),effective_charges(n_atoms),nuclear_charges(n_atoms),center_of_mass(3))
  call Get_cArray('Un_cen Names',atom_names,LenIn*n_atoms)
  call Get_dArray('Un_cen Coordinates',atom_coordinates,3*n_atoms)
  call Get_dArray('Un_cen Effective Charge',effective_charges,n_atoms)
  call Get_dArray('Nuclear charge',nuclear_charges,n_atoms)
  call Get_dArray('Center of Mass',center_of_mass,3)
  dsetid = mh5_create_dset_str(system_group,'atom_labels',1,[n_atoms],LenIn)
  call mh5_put_dset(dsetid,atom_names)
  call mh5_close_dset(dsetid)
  call write_real_array(system_group,'atom_coordinates_bohr',2,[3,n_atoms],atom_coordinates)
  call write_real_array(system_group,'nuclear_charges',1,[n_atoms],nuclear_charges)
  call write_real_array(system_group,'effective_nuclear_charges',1,[n_atoms],effective_charges)
  call write_real_array(system_group,'center_of_mass_bohr',1,[3],center_of_mass)
  deallocate(atom_names,atom_coordinates,effective_charges,nuclear_charges,center_of_mass)

  allocate(overlap(n_ao,n_ao),kinetic(n_ao,n_ao),nuclear_attraction(n_ao,n_ao),core_hamiltonian(n_ao,n_ao))
  allocate(dipole(n_ao,n_ao,3),quadrupole(n_ao,n_ao,6),multipole_origins(3,2))
  call read_symmetric_one_electron('Mltpl  0',1,n_ao,.true.,overlap)
  call read_symmetric_one_electron('Kinetic ',1,n_ao,.true.,kinetic)
  call read_symmetric_one_electron('Attract ',1,n_ao,.true.,nuclear_attraction)
  core_hamiltonian = kinetic+nuclear_attraction
  do i=1,3
    call read_multipole('Mltpl  1',i,n_ao,dipole(:,:,i),multipole_origins(:,1))
  end do
  do i=1,6
    call read_multipole('Mltpl  2',i,n_ao,quadrupole(:,:,i),multipole_origins(:,2))
  end do
  call write_real_array(one_group,'overlap',2,[n_ao,n_ao],overlap)
  call write_real_array(one_group,'kinetic',2,[n_ao,n_ao],kinetic)
  call write_real_array(one_group,'nuclear_attraction',2,[n_ao,n_ao],nuclear_attraction)
  call write_real_array(one_group,'core_hamiltonian',2,[n_ao,n_ao],core_hamiltonian)
  call write_real_array(one_group,'dipole',3,[n_ao,n_ao,3],dipole)
  call write_real_array(one_group,'quadrupole',3,[n_ao,n_ao,6],quadrupole)
  call write_real_array(one_group,'multipole_origins_bohr',2,[3,2],multipole_origins)
  deallocate(overlap,kinetic,nuclear_attraction,core_hamiltonian,dipole,quadrupole,multipole_origins)

  allocate(shard_names(size(local_counts)),counts64(size(local_counts)),bounds64(2,size(local_counts)))
  do i=1,size(local_counts)
    write(shard_names(i),'("rank_",I4.4,".h5")') i-1
  end do
  counts64 = int(local_counts,c_int64_t)
  bounds64 = int(local_bounds,c_int64_t)
  dsetid = mh5_create_dset_str(shards_group,'filenames',1,[size(shard_names)],len(shard_names))
  call mh5_put_dset(dsetid,shard_names)
  call mh5_close_dset(dsetid)
  dsetid = mh5_create_dset_i64(shards_group,'local_auxiliary_counts',1,[size(counts64)])
  call mh5_put_dset_i64(dsetid,counts64)
  call mh5_close_dset(dsetid)
  dsetid = mh5_create_dset_i64(shards_group,'first_and_last_global_ids',2,[2,size(local_counts)])
  call mh5_init_attr(dsetid,'AXIS_ORDER','mpi_rank,bound')
  call mh5_put_dset_i64(dsetid,bounds64)
  call mh5_close_dset(dsetid)
  deallocate(shard_names,counts64,bounds64)

  call write_string_scalar(provenance_group,'project',trim(project))
  call write_string_scalar(provenance_group,'producer','OpenMolcas4NOCI-v26.06.1 SEWARD CHH5')
  call write_string_scalar(provenance_group,'source_kind','SEWARD AO Cholesky decomposition')

  call mh5_close_group(provenance_group)
  call mh5_close_group(shards_group)
  call mh5_close_group(one_group)
  call mh5_close_group(basis_group)
  call mh5_close_group(system_group)
  call mh5_flush_file(fileid)
  call mh5_close_file(fileid)
end subroutine write_manifest

subroutine read_symmetric_one_electron(label,component,n_ao,no_origin,matrix)
  character(len=8), intent(in) :: label
  integer(kind=iwp), intent(in) :: component, n_ao
  logical(kind=iwp), intent(in) :: no_origin
  real(kind=wp), intent(out) :: matrix(n_ao,n_ao)
  integer(kind=iwp) :: irc, iopt, isym, n_packed
  real(kind=wp), allocatable :: packed(:)

  n_packed = n_ao*(n_ao+1)/2
  allocate(packed(n_packed+4))
  packed = 0.0_wp
  irc = -1
  iopt = ibset(0,sNoNuc)
  if (no_origin) iopt = ibset(iopt,sNoOri)
  isym = 1
  call RdOne(irc,iopt,label,component,packed,isym)
  if (irc /= 0) call export_error('Could not read ONEINT operator '//label//'.')
  call Square(packed,matrix,1,n_ao,n_ao)
  deallocate(packed)
end subroutine read_symmetric_one_electron

subroutine read_multipole(label,component,n_ao,matrix,origin)
  character(len=8), intent(in) :: label
  integer(kind=iwp), intent(in) :: component, n_ao
  real(kind=wp), intent(out) :: matrix(n_ao,n_ao), origin(3)
  integer(kind=iwp) :: irc, iopt, isym, n_packed
  real(kind=wp), allocatable :: packed(:)

  n_packed = n_ao*(n_ao+1)/2
  allocate(packed(n_packed+3))
  packed = 0.0_wp
  irc = -1
  iopt = ibset(0,sNoNuc)
  isym = 0
  call RdOne(irc,iopt,label,component,packed,isym)
  if (irc /= 0) call export_error('Could not read ONEINT multipole '//label//'.')
  call Square(packed,matrix,1,n_ao,n_ao)
  origin = packed(n_packed+1:n_packed+3)
  deallocate(packed)
end subroutine read_multipole

subroutine write_i64_scalar(groupid,name,value)
  integer(kind=iwp), intent(in) :: groupid
  character(len=*), intent(in) :: name
  integer(kind=c_int64_t), intent(in) :: value
  integer(kind=iwp) :: dsetid
  dsetid = mh5_create_dset_i64(groupid,name)
  call mh5_put_dset_i64(dsetid,value)
  call mh5_close_dset(dsetid)
end subroutine write_i64_scalar

subroutine write_real_scalar(groupid,name,value,units)
  integer(kind=iwp), intent(in) :: groupid
  character(len=*), intent(in) :: name, units
  real(kind=wp), intent(in) :: value
  integer(kind=iwp) :: dsetid
  dsetid = mh5_create_dset_real(groupid,name)
  call mh5_init_attr(dsetid,'UNITS',units)
  call mh5_put_dset(dsetid,value)
  call mh5_close_dset(dsetid)
end subroutine write_real_scalar

subroutine write_real_array(groupid,name,rank,dims,values)
  integer(kind=iwp), intent(in) :: groupid, rank, dims(rank)
  character(len=*), intent(in) :: name
  real(kind=wp), intent(in) :: values(*)
  integer(kind=iwp) :: dsetid
  dsetid = mh5_create_dset_real(groupid,name,rank,dims)
  call mh5_put_dset(dsetid,values)
  call mh5_close_dset(dsetid)
end subroutine write_real_array

subroutine write_string_scalar(groupid,name,value)
  integer(kind=iwp), intent(in) :: groupid
  character(len=*), intent(in) :: name, value
  integer(kind=iwp) :: dsetid
  dsetid = mh5_create_dset_str(groupid,name,len_trim(value))
  call mh5_put_dset(dsetid,trim(value))
  call mh5_close_dset(dsetid)
end subroutine write_string_scalar

subroutine export_error(message)
  character(len=*), intent(in) :: message
  call WarningMessage(2,'SEWARD CHH5: '//trim(message))
  call Abend()
end subroutine export_error

end module Seward_Portable_HDF5

#endif
