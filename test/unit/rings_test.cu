/*************************************************************************
 * Copyright (c) 2015-2016, NVIDIA CORPORATION. All rights reserved.
 *
 * See LICENSE.txt for license information
 ************************************************************************/

#include "nccl.h"
#include "core.h"
#include "rings.h"
/*=========== Topologies definitions =============*/
int PCI2_tr[] = 
  { 0, 0,
    0, 0 };
int PCI2_vl[] =
  { 1, 4,
    4, 1 };

int PCI4_tr[] = 
  { 0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0 };
int PCI4_vl[] =
  { 1, 4, 3, 3,
    4, 1, 3, 3,
    3, 3, 1, 4,
    3, 3, 4, 1 };

int PCI8_tr[] = 
  { 0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0,
    0, 0, 0, 0, 0, 0, 0, 0 };
int PCI8_vl[] =
  { 1, 4, 3, 3, 2, 2, 2, 2,
    4, 1, 3, 3, 2, 2, 2, 2,
    3, 3, 1, 4, 2, 2, 2, 2,
    3, 3, 4, 1, 2, 2, 2, 2,
    2, 2, 2, 2, 1, 4, 3, 3,
    2, 2, 2, 2, 4, 1, 3, 3,
    2, 2, 2, 2, 3, 3, 1, 4,
    2, 2, 2, 2, 3, 3, 4, 1 };

int PCI16_tr[] = 
  { 0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0 };
int PCI16_vl[] =
  {  1,  4,  3,  3,  2,  2,  2,  2, 04, 04, 04, 04, 04, 04, 04, 04,
     4,  1,  3,  3,  2,  2,  2,  2, 04, 04, 04, 04, 04, 04, 04, 04,
     3,  3,  1,  4,  2,  2,  2,  2, 04, 04, 04, 04, 04, 04, 04, 04,
     3,  3,  4,  1,  2,  2,  2,  2, 04, 04, 04, 04, 04, 04, 04, 04,
     2,  2,  2,  2,  1,  4,  3,  3, 02, 02, 02, 02, 02, 02, 02, 02,
     2,  2,  2,  2,  4,  1,  3,  3, 02, 02, 02, 02, 02, 02, 02, 02,
     2,  2,  2,  2,  3,  3,  4,  4, 02, 02, 02, 02, 02, 02, 02, 02,
     2,  2,  2,  2,  3,  3,  4,  1, 02, 02, 02, 02, 02, 02, 02, 02,
    04, 04, 04, 04, 04, 04, 04, 04,  1,  4,  3,  3,  2,  2,  2,  2,
    04, 04, 04, 04, 04, 04, 04, 04,  4,  1,  3,  3,  2,  2,  2,  2,
    04, 04, 04, 04, 04, 04, 04, 04,  3,  3,  1,  4,  2,  2,  2,  2,
    04, 04, 04, 04, 04, 04, 04, 04,  3,  3,  4,  1,  2,  2,  2,  2,
    02, 02, 02, 02, 02, 02, 02, 02,  2,  2,  2,  2,  1,  4,  3,  3,
    02, 02, 02, 02, 02, 02, 02, 02,  2,  2,  2,  2,  4,  1,  3,  3,
    02, 02, 02, 02, 02, 02, 02, 02,  2,  2,  2,  2,  3,  3,  1,  4,
    02, 02, 02, 02, 02, 02, 02, 02,  2,  2,  2,  2,  3,  3,  4,  1 };

int QPI4_tr[] = 
  { 0, 0, 1, 1,
    0, 0, 1, 1,
    1, 1, 0, 0,
    1, 1, 0, 0 };
int QPI4_vl[] =
  { 1, 2, 1, 1,
    2, 1, 1, 1,
    1, 1, 1, 2,
    1, 1, 2, 1 };

int QPI8_tr[] = 
  { 0, 0, 0, 0, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1,
    0, 0, 0, 0, 1, 1, 1, 1,
    1, 1, 1, 1, 0, 0, 0, 0,
    1, 1, 1, 1, 0, 0, 0, 0,
    1, 1, 1, 1, 0, 0, 0, 0,
    1, 1, 1, 1, 0, 0, 0, 0 };
int QPI8_vl[] =
  { 1, 4, 2, 2, 1, 1, 1, 1,
    4, 1, 2, 2, 1, 1, 1, 1,
    2, 2, 1, 4, 1, 1, 1, 1,
    2, 2, 4, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 4, 2, 2,
    1, 1, 1, 1, 4, 1, 2, 2,
    1, 1, 1, 1, 2, 2, 1, 4,
    1, 1, 1, 1, 2, 2, 4, 1 };

int QPI16_tr[] = 
  { 0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 0 };
int QPI16_vl[] =
  {   1,   4,   2,   2,   1,   1,   1,   1, 012, 012, 012, 012, 012, 012, 012, 012,
      4,   1,   2,   2,   1,   1,   1,   1, 012, 012, 012, 012, 012, 012, 012, 012,
      2,   2,   1,   4,   1,   1,   1,   1, 012, 012, 012, 012, 012, 012, 012, 012,
      2,   2,   4,   1,   1,   1,   1,   1, 012, 012, 012, 012, 012, 012, 012, 012,
      1,   1,   1,   1,   1,   4,   2,   2, 021, 021, 021, 021, 021, 021, 021, 021,
      1,   1,   1,   1,   4,   1,   2,   2, 021, 021, 021, 021, 021, 021, 021, 021,
      1,   1,   1,   1,   2,   2,   1,   4, 021, 021, 021, 021, 021, 021, 021, 021,
      1,   1,   1,   1,   2,   2,   4,   1, 021, 021, 021, 021, 021, 021, 021, 021,
    012, 012, 012, 012, 012, 012, 012, 012,   1,   4,   2,   2,   1,   1,   1,   1,
    012, 012, 012, 012, 012, 012, 012, 012,   4,   1,   2,   2,   1,   1,   1,   1,
    012, 012, 012, 012, 012, 012, 012, 012,   2,   2,   1,   4,   1,   1,   1,   1,
    012, 012, 012, 012, 012, 012, 012, 012,   2,   2,   4,   1,   1,   1,   1,   1,
    021, 021, 021, 021, 021, 021, 021, 021,   1,   1,   1,   1,   1,   4,   2,   2,
    021, 021, 021, 021, 021, 021, 021, 021,   1,   1,   1,   1,   4,   1,   2,   2,
    021, 021, 021, 021, 021, 021, 021, 021,   1,   1,   1,   1,   2,   2,   1,   4,
    021, 021, 021, 021, 021, 021, 021, 021,   1,   1,   1,   1,   2,   2,   4,   1 };

int QPU4_tr[] = 
  { 0, 1, 0, 1,
    1, 0, 1, 0,
    0, 1, 0, 1,
    1, 0, 1, 0 };
int QPU4_vl[] =
  { 1, 1, 4, 1,
    1, 1, 1, 4,
    4, 1, 1, 1,
    1, 4, 1, 1 };

int QPI6_tr[] = 
  { 0, 0, 0, 1, 2, 2,
    0, 0, 0, 1, 2, 2,
    0, 0, 0, 1, 2, 2, 
    1, 1, 1, 0, 2, 2,
    2, 2, 2, 2, 0, 0,
    2, 2, 2, 2, 0, 0 };
int QPI6_vl[] =
  { 1, 4, 2, 1, 1, 1,
    4, 1, 2, 1, 1, 1,
    2, 2, 1, 1, 1, 1,
    1, 1, 1, 1, 4, 2,
    1, 1, 1, 4, 1, 2,
    1, 1, 1, 2, 2, 1 };

int QPU6_tr[] = 
  { 0, 1, 0, 0, 2, 2,
    1, 0, 1, 1, 2, 2,
    0, 1, 0, 0, 2, 2, 
    0, 1, 0, 0, 2, 2,
    2, 2, 2, 2, 0, 0,
    2, 2, 2, 2, 0, 0 };
int QPU6_vl[] =
  { 1, 1, 2, 2, 1, 1,
    1, 1, 1, 1, 4, 4,
    2, 1, 1, 4, 1, 1,
    2, 1, 4, 1, 1, 1,
    1, 1, 1, 1, 1, 4,
    1, 1, 1, 1, 4, 1 };

int QPU8_tr[] = 
  { 0, 1, 1, 0, 1, 0, 0, 1,
    1, 0, 0, 1, 0, 1, 1, 0,
    1, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 0, 0, 1,
    1, 0, 0, 1, 0, 1, 1, 0,
    0, 1, 1, 0, 1, 0, 0, 1,
    0, 1, 1, 0, 1, 0, 0, 1,
    1, 0, 0, 1, 0, 1, 1, 0 };
int QPU8_vl[] =
  { 1, 1, 1, 2, 1, 2, 4, 1,
    1, 1, 2, 1, 2, 1, 1, 4,
    1, 2, 1, 1, 4, 1, 1, 2,
    2, 1, 1, 1, 1, 4, 2, 1,
    1, 2, 4, 1, 1, 1, 1, 2,
    2, 1, 1, 4, 1, 1, 2, 1,
    4, 1, 1, 2, 1, 2, 1, 1,
    1, 4, 2, 1, 2, 1, 1, 1 };

int QPU16_tr[] = 
  { 0, 1, 1, 0, 1, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 0, 1, 0, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 0, 1, 0, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 0, 1, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 0, 1, 0, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 0, 1, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 0, 1, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 0, 1, 0, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 0, 1, 0, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 1, 0, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 1, 0, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 0, 1, 0, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 1, 0, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 0, 1, 0, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 0, 1, 0, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 1, 0, 1, 1, 0 };
int QPU16_vl[] =
  {   1,   1,   1,   2,   1,   2,   4,   1, 011, 011, 011, 011, 011, 011, 011, 011,
      1,   1,   2,   1,   2,   1,   1,   4, 033, 033, 033, 033, 033, 033, 033, 033,
      1,   2,   1,   1,   4,   1,   1,   2, 033, 033, 033, 033, 033, 033, 033, 033,
      2,   1,   1,   1,   1,   4,   2,   1, 011, 011, 011, 011, 011, 011, 011, 011,
      1,   2,   4,   1,   1,   1,   1,   2, 033, 033, 033, 033, 033, 033, 033, 033,
      2,   1,   1,   4,   1,   1,   2,   1, 011, 011, 011, 011, 011, 011, 011, 011,
      4,   1,   1,   2,   1,   2,   1,   1, 011, 011, 011, 011, 011, 011, 011, 011,
      1,   4,   2,   1,   2,   1,   1,   1, 033, 033, 033, 033, 033, 033, 033, 033,
    001, 001, 001, 001, 001, 001, 001, 001,   1,   1,   1,   2,   1,   2,   4,   1,
    003, 003, 003, 003, 003, 003, 003, 003,   1,   1,   2,   1,   2,   1,   1,   4,
    003, 003, 003, 003, 003, 003, 003, 003,   1,   2,   1,   1,   4,   1,   1,   2,
    001, 001, 001, 001, 001, 001, 001, 001,   2,   1,   1,   1,   1,   4,   2,   1,
    003, 003, 003, 003, 003, 003, 003, 003,   1,   2,   4,   1,   1,   1,   1,   2,
    001, 001, 001, 001, 001, 001, 001, 001,   2,   1,   1,   4,   1,   1,   2,   1,
    001, 001, 001, 001, 001, 001, 001, 001,   4,   1,   1,   2,   1,   2,   1,   1,
    003, 003, 003, 003, 003, 003, 003, 003,   1,   4,   2,   1,   2,   1,   1,   1 };

int QPX9_tr[] = 
  { 0, 0, 0, 1, 1, 2, 2, 2, 2,
    0, 0, 0, 1, 1, 2, 2, 2, 2,
    0, 0, 0, 1, 1, 2, 2, 2, 2,
    1, 1, 1, 0, 0, 2, 2, 2, 2,
    1, 1, 1, 0, 0, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 0, 0, 1, 1,
    2, 2, 2, 2, 2, 0, 0, 1, 1,
    2, 2, 2, 2, 2, 1, 1, 0, 0,
    2, 2, 2, 2, 2, 1, 1, 0, 0 };
int QPX9_vl[] =
  {   1,   4,   2,   1,   1, 022, 022, 022, 022,
      4,   1,   2,   1,   1, 022, 022, 022, 022,
      2,   2,   1,   1,   1, 044, 044, 044, 044,
      1,   1,   1,   1,   4, 011, 011, 011, 011,
      1,   1,   1,   4,   1, 011, 011, 011, 011,
    022, 022, 022, 022, 022,   1,   4,   1,   1,
    022, 022, 022, 022, 022,   4,   1,   1,   1,
    011, 011, 011, 011, 011,   1,   1,   1,   4,
    011, 011, 011, 011, 011,   1,   1,   4,   1, };

int NVL4_tr[] = 
  { 0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0 };
int NVL4_vl[] =
  { 1, 6, 5, 5,
    6, 1, 5, 5,
    5, 5, 1, 6,
    5, 5, 6, 1 };

int NVH4_tr[] = 
  { 0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0,
    0, 0, 0, 0 };
int NVH4_vl[] =
  { 1, 5, 5, 5,
    5, 1, 5, 5,
    5, 5, 1, 5,
    5, 5, 5, 1 };

int NVL6_tr[] = 
  { 0, 0, 0, 0, 0, 1,
    0, 0, 0, 0, 1, 0,
    0, 0, 0, 0, 1, 1,
    0, 0, 0, 0, 1, 1,
    0, 1, 1, 1, 0, 0,
    1, 0, 1, 1, 0, 0 };
int NVL6_vl[] =
  { 1, 5, 5, 5, 5, 1,
    5, 1, 5, 5, 1, 5,
    5, 5, 1, 5, 1, 1,
    5, 5, 5, 1, 1, 1,
    5, 1, 1, 1, 1, 5,
    1, 5, 1, 1, 5, 1 };

int NVL8_tr[] = 
  { 0, 0, 0, 0, 0, 1, 1, 1,
    0, 0, 0, 0, 1, 0, 1, 1,
    0, 0, 0, 0, 1, 1, 0, 1,
    0, 0, 0, 0, 1, 1, 1, 0,
    0, 1, 1, 1, 0, 0, 0, 0,
    1, 0, 1, 1, 0, 0, 0, 0,
    1, 1, 0, 1, 0, 0, 0, 0,
    1, 1, 1, 0, 0, 0, 0, 0 };
int NVL8_vl[] =
  { 1, 5, 5, 5, 5, 1, 1, 1,
    5, 1, 5, 5, 1, 5, 1, 1,
    5, 5, 1, 5, 1, 1, 5, 1,
    5, 5, 5, 1, 1, 1, 1, 5,
    5, 1, 1, 1, 1, 5, 5, 5,
    1, 5, 1, 1, 5, 1, 5, 5,
    1, 1, 5, 1, 5, 5, 1, 5,
    1, 1, 1, 5, 5, 5, 5, 1 };

int NVV8_tr[] = 
  { 0, 0, 0, 0, 0, 1, 1, 1,
    0, 0, 0, 0, 1, 0, 1, 1,
    0, 0, 0, 0, 1, 1, 0, 1,
    0, 0, 0, 0, 1, 1, 1, 0,
    0, 1, 1, 1, 0, 0, 0, 0,
    1, 0, 1, 1, 0, 0, 0, 0,
    1, 1, 0, 1, 0, 0, 0, 0,
    1, 1, 1, 0, 0, 0, 0, 0 };
int NVV8_vl[] =
  { 1, 6, 6, 5, 5, 1, 1, 1,
    6, 1, 5, 5, 1, 6, 1, 1,
    6, 5, 1, 6, 1, 1, 5, 1,
    5, 5, 6, 1, 1, 1, 1, 6,
    5, 1, 1, 1, 1, 6, 6, 5,
    1, 6, 1, 1, 6, 1, 5, 5,
    1, 1, 5, 1, 6, 5, 1, 6,
    1, 1, 1, 6, 5, 5, 6, 1 };

int NVLX8_tr[] = 
  { 0, 0, 0, 0, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2,
    0, 0, 0, 0, 2, 2, 2, 2,
    2, 2, 2, 2, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0,
    2, 2, 2, 2, 0, 0, 0, 0 };
int NVLX8_vl[] =
  {     1,     5,     5,     5, 02411, 02411, 02411, 02411,
        5,     1,     5,     5, 02411, 02411, 02411, 02411,
        5,     5,     1,     5, 04211, 04211, 04211, 04211,
        5,     5,     5,     1, 04211, 04211, 04211, 04211,
    02411, 02411, 02411, 02411,     1,     5,     5,     5,
    02411, 02411, 02411, 02411,     5,     1,     5,     5,
    04211, 04211, 04211, 04211,     5,     5,     1,     5,
    04211, 04211, 04211, 04211,     5,     5,     5,     1 };

int NVL16_tr[] = 
  { 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 0, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 0, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0 };
int NVL16_vl[] =
  {     1,     5,     5,     5,     5,     1,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
        5,     1,     5,     5,     1,     5,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
        5,     5,     1,     5,     1,     1,     5,     1, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
        5,     5,     5,     1,     1,     1,     1,     5, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
        5,     1,     1,     1,     1,     5,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
        1,     5,     1,     1,     5,     1,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
        1,     1,     5,     1,     5,     5,     1,     5, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
        1,     1,     1,     5,     5,     5,     5,     1, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     1,     5,     5,     5,     5,     1,     1,     1,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     5,     1,     5,     5,     1,     5,     1,     1,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     1,     5,     1,     1,     5,     1,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     5,     1,     1,     1,     1,     5,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     5,     1,     1,     1,     1,     5,     5,     5,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     1,     5,     1,     1,     5,     1,     5,     5,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     5,     1,     5,     5,     1,     5,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     1,     5,     5,     5,     5,     1 };

int NVL32_tr[] = 
  { 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 0, 1, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 0, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 1, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 1, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 0, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 0, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 0, 1, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 1, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 1, 0, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 0, 0 };
int NVL32_vl[] =
  {     1,     5,     5,     5,     5,     1,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,  01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
        5,     1,     5,     5,     1,     5,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,  01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
        5,     5,     1,     5,     1,     1,     5,     1, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,  01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
        5,     5,     5,     1,     1,     1,     1,     5, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,  01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
        5,     1,     1,     1,     1,     5,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,  02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
        1,     5,     1,     1,     5,     1,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,  02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
        1,     1,     5,     1,     5,     5,     1,     5, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,  04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
        1,     1,     1,     5,     5,     5,     5,     1, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,  04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     1,     5,     5,     5,     5,     1,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     5,     1,     5,     5,     1,     5,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     1,     5,     1,     1,     5,     1, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     5,     1,     1,     1,     1,     5, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     5,     1,     1,     1,     1,     5,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     1,     5,     1,     1,     5,     1,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     5,     1,     5,     5,     1,     5, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     1,     5,     5,     5,     5,     1, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     1,     5,     5,     5,     5,     1,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     5,     1,     5,     5,     1,     5,     1,     1, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     1,     5,     1,     1,     5,     1, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     5,     1,     1,     1,     1,     5, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     5,     1,     1,     1,     1,     5,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     1,     5,     1,     1,     5,     1,     5,     5, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     5,     1,     5,     5,     1,     5, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     1,     5,     5,     5,     5,     1, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     1,     5,     5,     5,     5,     1,     1,     1,
    01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124, 01124,     5,     1,     5,     5,     1,     5,     1,     1,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     1,     5,     1,     1,     5,     1,
    01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142, 01142,     5,     5,     5,     1,     1,     1,     1,     5,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     5,     1,     1,     1,     1,     5,     5,     5,
    02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411, 02411,     1,     5,     1,     1,     5,     1,     5,     5,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     5,     1,     5,     5,     1,     5,
    04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211, 04211,     1,     1,     1,     5,     5,     5,     5,     1 };

int NVG8_tr[] = 
  { 0, 0, 1, 1, 1, 1, 1, 0,
    0, 0, 0, 1, 1, 1, 1, 1,
    1, 0, 0, 0, 1, 1, 1, 1,
    1, 1, 0, 0, 0, 1, 1, 1,
    1, 1, 1, 0, 0, 0, 1, 1,
    1, 1, 1, 1, 0, 0, 0, 1,
    1, 1, 1, 1, 1, 0, 0, 0,
    0, 1, 1, 1, 1, 1, 0, 0 };
int NVG8_vl[] =
  { 1, 6, 1, 1, 1, 1, 1, 6,
    6, 1, 6, 1, 1, 1, 1, 1,
    1, 6, 1, 6, 1, 1, 1, 1,
    1, 1, 6, 1, 6, 1, 1, 1,
    1, 1, 1, 6, 1, 6, 1, 1,
    1, 1, 1, 1, 6, 1, 6, 1,
    1, 1, 1, 1, 1, 6, 1, 6,
    6, 1, 1, 1, 1, 1, 6, 1 };

int NVG16_tr[] = 
  { 0, 0, 1, 1, 1, 1, 1, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 0, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 0, 0, 0, 1, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 0, 0, 0, 1, 2, 2, 2, 2, 2, 2, 2, 2,
    1, 1, 1, 1, 1, 0, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    0, 1, 1, 1, 1, 1, 0, 0, 2, 2, 2, 2, 2, 2, 2, 2,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 1, 1, 1, 1, 1, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 0, 0, 1, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 0, 0, 0, 1, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 0, 0, 0, 1, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 0, 0, 0, 1, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 0, 0, 0, 1,
    2, 2, 2, 2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 0, 0, 0,
    2, 2, 2, 2, 2, 2, 2, 2, 0, 1, 1, 1, 1, 1, 0, 0 };
int NVG16_vl[] =
  { 1, 6, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1,
    6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 6, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1,
    6, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 6,
    1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6, 1, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6, 1, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6, 1, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6, 1, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6, 1,
    1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 6,
    1, 1, 1, 1, 1, 1, 1, 1, 6, 1, 1, 1, 1, 1, 6, 1 };


/*=========== Print functions =============*/
#define TESTMAXRANKS 32
char dashes[TESTMAXRANKS*3+1];

static void writeHeader() {
  char spaces[TESTMAXRANKS*3-sizeof("Rings")+1];
  memset(spaces, ' ', sizeof(spaces));
  spaces[sizeof(spaces)-1] = '\0';
  memset(dashes, '-', sizeof(dashes));
  dashes[sizeof(dashes)-1] = '\0';
  printf(".---------.--------.%s.\n", dashes);
  printf("|  Topo   | NRings | Rings%s|\n", spaces);
}

static void writeFooter(int errors) {
  printf("|---------+--------+%s|\n", dashes);
  const char* result = errors ? "FAILED" : "OK";
  printf("| Errors  |  %3d   | %s", errors, result);
  for (int i=strlen(result)+1; i<3*TESTMAXRANKS; i++) printf(" ");
  printf("|\n");
  printf("'---------'--------'%s'\n", dashes);
}

static void dumpRings(int nrings, int *rings, int nranks, const char* toponame, const char* errormsg) {
  printf("|---------+--------+%s|\n", dashes);
  printf("|  %s |  %3d   |", toponame, nrings);
  if (nrings == 0 && errormsg == NULL) errormsg = "No ring !";
  int ring = 0;
  for (; ring<nrings; ring++) {
    if (ring) printf("|         |        |");
    for (int index = 0; index<nranks; index++) {
      printf(" %2d", rings[ring*nranks+index]);
    }
    for (int i=nranks; i<TESTMAXRANKS; i++) printf("   ");
    printf("|\n");
  }
  if (errormsg) {
    if (ring) printf("|         |        |");
    printf(" %s ", errormsg);
    for (int i=strlen(errormsg)+2; i<3*TESTMAXRANKS; i++) printf(" ");
    printf("|\n");
  }
}

/*=========== Main test function =============*/
static ncclResult_t getRings(int nranks, int* transports, int* values, const char* toponame, int expectedNrings, int expectedNthreads) {
  int nrings_final = -1;
  int nthreads_final = -1;
  int prev[MAXRINGS*nranks];
  int next[MAXRINGS*nranks];
  int next_final[MAXRINGS*nranks];
  char* errormsg = NULL;
  char errortext[120];

  int rings[MAXRINGS*nranks];

  for (int rank=0; rank<nranks; rank++) {
    int nrings = MAXRINGS;
    int nthreads;
    ncclResult_t ret = ncclGetRings(&nrings, &nthreads, rank, nranks, transports, values, prev, next);
    if (ret != ncclSuccess) {
      sprintf(errortext, "Error : getRings returned %s", ncclGetErrorString(ret));
      errormsg = errortext;
      goto end;
    }
    /*for (int ring=0; ring<nrings; ring++) {
      printf("[%d] Prev :", ring);
      for (int i=0; i<nranks; i++) printf(" %d", prev[ring*nranks+i]);
      printf("\n");
      printf("[%d] Next :", ring);
      for (int i=0; i<nranks; i++) printf(" %d", next[ring*nranks+i]);
      printf("\n");
    }*/
    if (nrings_final == -1) nrings_final = nrings;
    if (nrings_final != nrings) { 
      sprintf(errortext, "Error : got %d rings for rank %d instead of %d", nrings, rank, nrings_final);
      errormsg = errortext;
      goto end;
    }
    if (nthreads_final == -1) nthreads_final = nthreads;
    if (nthreads_final != nthreads) {
      sprintf(errortext, "Error : got %d threads for rank %d instead of %d", nthreads, rank, nthreads_final);
      errormsg = errortext;
      goto end;
    }
    for (int ring=0; ring<nrings; ring++) {
      next_final[ring*nranks+rank] = next[ring*nranks+rank];
    }
  }
  {
    int in_ring[nranks];
    for (int rank = 0; rank < nranks; rank++) in_ring[rank] = 0;
    for (int ring=0; ring<nrings_final; ring++) {
      int currank = 0;
      for (int index=0; index<nranks; index++) {
        in_ring[currank] = 1;
        rings[ring*nranks+index] = currank;
        currank = next_final[ring*nranks+currank];
      }
      if (currank != 0) {
        sprintf(errortext, "Error : ring does not loop back to start");
        errormsg = errortext;
        goto end;
      }
      for (int rank = 0; rank < nranks; rank++) {
        if (in_ring[rank] == 0) {
          sprintf(errortext, "Error : ring does not contain rank %d", rank);
          errormsg = errortext;
          return ncclInternalError;
        }
      }
    }
  }
  if (nrings_final != expectedNrings) {
    sprintf(errortext, "Error : got %d rings instead of %d", nrings_final, expectedNrings);
    errormsg = errortext;
  } else if (nthreads_final != expectedNthreads) {
    sprintf(errortext, "Error : got %d threads instead of %d", nthreads_final, expectedNthreads);
    errormsg = errortext;
  }
end:
  dumpRings(nrings_final, rings, nranks, toponame, errormsg);
  return errormsg ? ncclInternalError : ncclSuccess;
}

#define CHECK(a) if ((a) != ncclSuccess) { err++; }

int main() {
  int err = 0;
  writeHeader();
  CHECK(getRings(2, PCI2_tr, PCI2_vl, "PCI  2", 1, 512));
  CHECK(getRings(4, PCI4_tr, PCI4_vl, "PCI  4", 1, 512));
  CHECK(getRings(8, PCI8_tr, PCI8_vl, "PCI  8", 1, 512));
  CHECK(getRings(16, PCI16_tr, PCI16_vl, "PCI 16", 1, 512));
  CHECK(getRings(4, QPI4_tr, QPI4_vl, "QPI  4", 1, 512));
  CHECK(getRings(8, QPI8_tr, QPI8_vl, "QPI  8", 1, 512));
  CHECK(getRings(16, QPI16_tr, QPI16_vl, "QPI 16", 2, 512));
  CHECK(getRings(4, QPU4_tr, QPU4_vl, "QPU  4", 1, 512));
  CHECK(getRings(6, QPI6_tr, QPI6_vl, "QPI  6", 1, 512));
  CHECK(getRings(6, QPU6_tr, QPU6_vl, "QPU  6", 1, 512));
  CHECK(getRings(8, QPU8_tr, QPU8_vl, "QPU  8", 1, 512));
  CHECK(getRings(16, QPU16_tr, QPU16_vl, "QPU 16", 1, 512));
  CHECK(getRings(9, QPX9_tr, QPX9_vl, "QPX  9", 2, 512));
  CHECK(getRings(4, NVL4_tr, NVL4_vl, "NVL  4", 8, 128));
  CHECK(getRings(6, NVL6_tr, NVL6_vl, "NVL  6", 4, 128));
  CHECK(getRings(4, NVH4_tr, NVH4_vl, "NVH  4", 12, 128));
  CHECK(getRings(8, NVL8_tr, NVL8_vl, "NVL  8", 8, 128));
  CHECK(getRings(8, NVLX8_tr, NVLX8_vl, "NVL X8", 2, 512));
  CHECK(getRings(16, NVL16_tr, NVL16_vl, "NVL 16", 4, 512));
  CHECK(getRings(32, NVL32_tr, NVL32_vl, "NVL 32", 4, 512));
  CHECK(getRings(8, NVG8_tr, NVG8_vl, "NVG  8", 8, 128));
  CHECK(getRings(16, NVG16_tr, NVG16_vl, "NVG 16", 1, 512));
  CHECK(getRings(8, NVV8_tr, NVV8_vl, "NVV  8", 12, 128));
  writeFooter(err);
  return err;
}
