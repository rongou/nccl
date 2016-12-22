/*************************************************************************
 * Copyright (c) 2015-2016, NVIDIA CORPORATION. All rights reserved.
 *
 * See LICENCE.txt for license information
 ************************************************************************/
#include "../include/macros.h"
#include "ErrorChecker.h"
#include "TEST_ENV.h"
#include "mpi.h"
#include "mpi_fixture.h"
#include "nccl.h"
TYPED_TEST(mpi_test, ncclAllReduce_basic) {
    for (auto op : this->RedOps) {
        MNCCL_ASSERT(ncclAllReduce(
            (const void*)this->buf_send_d, (void*)this->buf_recv_d,
            this->count1, this->ncclDataType, op, this->comm, this->stream));
        MCUDA_ASSERT(cudaStreamSynchronize(this->stream));
        MCUDA_ASSERT(cudaMemcpy(this->buf_recv_h.data(), this->buf_recv_d,
                                this->count1 * sizeof(TypeParam),
                                cudaMemcpyDeviceToHost));
        MPI_Allreduce(this->buf_send_h.data(), this->buf_recv_mpi.data(),
                      this->count1, this->mpiDataType, this->MpiOps.at(op),
                      MPI_COMM_WORLD);
        EXPECT_NO_FATAL_FAILURE(this->Verify(this->countN));
    }
}
