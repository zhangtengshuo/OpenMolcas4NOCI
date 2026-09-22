!***********************************************************************
! This file is part of OpenMolcas.                                     *
!                                                                      *
! OpenMolcas is free software; you can redistribute it and/or modify   *
! it under the terms of the GNU Lesser General Public License, v. 2.1. *
!***********************************************************************

module Seward_HDF5_Export_Info

use Definitions, only: iwp

implicit none
private

logical(kind=iwp) :: Seward_HDF5_Export_Enabled = .false.

public :: Seward_HDF5_Export_Enabled

end module Seward_HDF5_Export_Info
