/*************************************************************************
 * Copyright (c) 2016, NVIDIA CORPORATION. All rights reserved.
 *
 * See LICENSE.txt for license information
 ************************************************************************/

#include "core.h"
#include "transport.h"
#include <cuda_runtime.h>
#include "net.h"
#include "gdcopy.h"
#include <assert.h>

#define PUSH_PROXY 1

struct netInfo {
  int rank;
};

struct netConnectInfo {
  ncclNetHandle_t netHandle;
};

struct netSendResources {
  void* netSendComm;
  cudaStream_t stream;
  struct ncclSendRecvMem* hostMem;
  struct ncclSendRecvMem* devHostMem;
  struct ncclSendRecvMem* hostDevMem;
};

#define MAXSTEPS 8

struct netRecvResources {
  void* netRecvComm;
  cudaStream_t stream;
  cudaEvent_t syncEvent[MAXSTEPS];
  struct ncclSendRecvMem* hostMem;
  struct ncclSendRecvMem* devHostMem;
  struct ncclSendRecvMem* hostDevMem;
};

/* Fill information necessary to exchange between ranks to choose whether or not
 * to use this transport */
ncclResult_t netFillInfo(ncclTinfo_t* opaqueInfo, int rank) {
  struct netInfo* info = (struct netInfo*)opaqueInfo;
  static_assert(sizeof(struct netInfo) <= sizeof(ncclTinfo_t), "NET Info too large");
  info->rank = rank;
  return ncclSuccess;
}

/* Determine if we can communicate with the peer */
ncclResult_t netCanConnect(int* ret, ncclTinfo_t* myOpaqueInfo, ncclTinfo_t* peerOpaqueInfo) {
  *ret = 1;
  return ncclSuccess;
}

/* Create and return connect structures for this peer to connect to me */

void connectScattered(int nranks, int* groups, int group, int nextGroup, int* src, int* dst, int steps) {
  *src = groupPos(nranks, groups, group, steps+1);
  *dst = groupPos(nranks, groups, nextGroup, steps);
}

ncclResult_t netGetRings(int nranks, int ngroups, int* groups, int* values, int* nringsRet, int* prev, int* next, int pattern) {
  if (pattern >= 2) {
    *nringsRet = 0;
    return ncclSuccess;
  }
  *nringsRet = 1;
  for (int ring = 0; ring<*nringsRet; ring++) {
    for (int group = 0; group<ngroups; group++) {
      // Check if this group is already connected
      int skip = 0;
      for (int rank = 0; rank<nranks; rank++) {
        if (groups[rank] == group && next[ring*nranks+rank] != -1) skip = 1;
      }
      if (skip) continue;

      int nextGroup = (group+1)%ngroups;
      int source = -1, destination = -1;
      if (pattern == 0) {
        if (ring % 2 == 0) {
          source = groupLast(nranks, groups, group);
          destination = groupFirst(nranks, groups, nextGroup);
        } else {
          source = groupFirst(nranks, groups, group);
          destination = groupLast(nranks, groups, nextGroup);
        }
      } else if (pattern == 1) {
        source = groupPos(nranks, groups, group, ring*2+1);
        destination = groupPos(nranks, groups, nextGroup, ring*2);
      }
      if (source == -1 || destination == -1) {
        WARN("source %d dest %d, stopping\n", source, destination);
        *nringsRet = ring;
        return ncclSuccess;
      }
      next[ring*nranks+source] = destination;
      prev[ring*nranks+destination] = source;
    }
  }
  return ncclSuccess;
}

/* Determine if we will use this transport for this peer and return connect
 * information for this peer */
ncclResult_t netSendSetup(ncclTinfo_t* myOpaqueInfo, ncclTinfo_t* peerOpaqueInfo, struct ncclConnect* connectInfo, struct ncclRing* ring) {
  struct netSendResources* resources = (struct netSendResources*) malloc(sizeof(struct netSendResources));
  ring->send.transportResources = resources;
  resources->hostDevMem = (struct ncclSendRecvMem*)gdptr(ring->devMem, ring->buffSize);

#ifdef PUSH_PROXY
  // Create stream for proxy
  CUDACHECK(cudaStreamCreateWithFlags(&resources->stream, cudaStreamNonBlocking));
#endif

  int size = offsetof(struct ncclSendRecvMem, buff)+ring->buffSize;
  CUDACHECK(cudaHostAlloc(&resources->hostMem, size, cudaHostAllocMapped));
  CUDACHECK(cudaHostGetDevicePointer(&resources->devHostMem, resources->hostMem, 0));

  return ncclSuccess;
}

ncclResult_t netRecvSetup(ncclTinfo_t* myOpaqueInfo, ncclTinfo_t* peerOpaqueInfo, struct ncclConnect* connectInfo, struct ncclRing* ring) {
  struct netRecvResources* resources = (struct netRecvResources*) malloc(sizeof(struct netRecvResources));
  ring->recv.transportResources = resources;
  resources->hostDevMem = (struct ncclSendRecvMem*)gdptr(ring->devMem, ring->buffSize);

#ifdef PUSH_PROXY
  // Create stream for proxy
  CUDACHECK(cudaStreamCreateWithFlags(&resources->stream, cudaStreamNonBlocking));
  // And event
  for (int i=0; i<MAXSTEPS; i++)
    CUDACHECK(cudaEventCreate(resources->syncEvent+i));
#endif

  int size = offsetof(struct ncclSendRecvMem, buff)+ring->buffSize;
  CUDACHECK(cudaHostAlloc(&resources->hostMem, size, cudaHostAllocMapped));
  CUDACHECK(cudaHostGetDevicePointer(&resources->devHostMem, resources->hostMem, 0));
  
  struct netInfo* myInfo = (struct netInfo*)myOpaqueInfo;
  struct netInfo* peerInfo = (struct netInfo*)peerOpaqueInfo;
  INFO("%d -> %d via NET%s%s", peerInfo->rank, myInfo->rank, ncclNetCudaSupport() == ncclSuccess ? "/GDRDMA" : "", (resources->hostDevMem != NULL) ? "/GDCopy" : "");
  struct netConnectInfo* info = (struct netConnectInfo*) connectInfo;
  NCCLCHECK(ncclNetGetHandle(&info->netHandle, &resources->netRecvComm));
  return ncclSuccess;
}

ncclResult_t netSendConnect(struct ncclConnect* connectInfo, struct ncclConnector* send) {
  // Setup device pointers
  struct netSendResources* resources = (struct netSendResources*)send->transportResources;
  send->conn.buff = resources->devHostMem->buff;
  send->conn.tail = &resources->devHostMem->tail;
  send->conn.opCount = &resources->devHostMem->opCount;
  send->conn.fifo = resources->devHostMem->sizesFifo;
#ifndef PUSH_PROXY
  send->conn.head = &resources->devHostMem->head;
#endif

  // Setup remote MPI rank / tag
  struct netConnectInfo* info = (struct netConnectInfo*)connectInfo;
  NCCLCHECK(ncclNetConnectHandle(info->netHandle, &resources->netSendComm));
  return ncclSuccess;
}

/* Connect to this peer */
ncclResult_t netRecvConnect(struct ncclConnect* connectInfo, struct ncclConnector* recv) {
  // Setup device pointers
  struct netRecvResources* resources = (struct netRecvResources*)recv->transportResources;
  recv->conn.head = &resources->devHostMem->head;
#ifndef PUSH_PROXY
  recv->conn.tail = &resources->devHostMem->tail;
  recv->conn.buff = resources->devHostMem->buff;
  recv->conn.opCount = &resources->devHostMem->opCount;
  recv->conn.fifo = resources->devHostMem->sizesFifo;
#endif

  // Setup remote MPI rank / tag
  return ncclSuccess;
}

ncclResult_t netSendFree(void* transportResources) {
  struct netSendResources* resources = (struct netSendResources*)transportResources;
  CUDACHECK(cudaStreamDestroy(resources->stream));
  CUDACHECK(cudaFreeHost(resources->hostMem));
  // TODO : unmap hostDevMem
  free(resources);
  return ncclSuccess;
}

ncclResult_t netRecvFree(void* transportResources) {
  struct netRecvResources* resources = (struct netRecvResources*)transportResources;
  CUDACHECK(cudaStreamDestroy(resources->stream));
  for (int i=0; i<MAXSTEPS; i++) {
    CUDACHECK(cudaEventDestroy(resources->syncEvent[i]));
  }
  CUDACHECK(cudaFreeHost(resources->hostMem));
  // TODO : unmap hostDevMem
  free(resources);
  return ncclSuccess;
}

ncclResult_t netSendProxy(struct ncclProxyArgs* args) {
  struct ncclRing* ring = args->ring;
  struct netSendResources* resources = (struct netSendResources*) (ring->send.transportResources);
  struct ncclSendRecvMem* devMem = ring->devMem;
  volatile int* prevTail = &resources->hostMem->tail;
#ifdef PUSH_PROXY
  int* prevHead = &devMem->head;
#else
  int* prevHead = &resources->hostMem->head;
#endif
  char* localBuff = resources->hostMem->buff;
  int* sizesFifo = resources->hostMem->sizesFifo;
  int buffSize = ring->buffSize;
  int sliceSize = buffSize / args->substeps;

  int head = 0;
  int data[args->substeps];

  // Update in case we skipped some collectives
  resources->hostMem->opCount = args->opCount;

  int tail = 0;
  int idle = 0;
  void* requests[args->substeps];
  while (tail < args->nsteps) {
    idle++;
    while (head != *prevTail) {
      // Send through MPI
      int slot = head%args->substeps;
      NCCLCHECK(ncclNetIsend(resources->netSendComm, localBuff+slot*sliceSize, sizesFifo[slot], requests+slot));
      head++;
      idle = 0;
    }
    if (tail < head) {
      int done;
      int slot = tail%args->substeps;
      NCCLCHECK(ncclNetTest(requests[slot], &done, NULL));
      if (done) {
        tail++;
#ifdef PUSH_PROXY
        data[slot] = tail;
        CUDACHECK(cudaMemcpyAsync(prevHead, data+slot, sizeof(int), cudaMemcpyHostToDevice, resources->stream));
#else
        *prevHead = tail;
#endif
        idle = 0;
      }
      if (idle) transportProxyIdle(idle);
    }
  }
#ifdef PUSH_PROXY
  // Ensure all updates are pushed
  CUDACHECK(cudaStreamSynchronize(resources->stream));
#endif

  // Reset
  *prevTail = 0;
  resources->hostMem->opCount = args->opCount+1;
  return ncclSuccess;
}

ncclResult_t netRecvProxy(struct ncclProxyArgs* args) {
  struct ncclRing* ring = args->ring;
  struct netRecvResources* resources = (struct netRecvResources*) (ring->recv.transportResources);
  struct ncclSendRecvMem* devMem = ring->devMem;

  int netCudaSupport = ncclNetCudaSupport() == ncclSuccess ? 1 : 0;
  bool directDevMem = resources->hostDevMem != NULL;

  assert(MAXSTEPS >= args->substeps);

#ifdef PUSH_PROXY
  if (directDevMem) {
    int* nextOpCount = &resources->hostDevMem->opCount;
    transportProxyWait([=] { return *nextOpCount >= args->opCount; });
  } else {
    int val = 0;
    int* nextOpCount = &devMem->opCount;
    while (val != args->opCount) {
      CUDACHECK(cudaMemcpyAsync(&val, nextOpCount, sizeof(int), cudaMemcpyDeviceToHost, resources->stream));
      CUDACHECK(cudaStreamSynchronize(resources->stream));
    }
  }
#else
  int* nextOpCount = &resources->hostMem->opCount;
  transportProxyWait([=] { return *nextOpCount >= args->opCount; });
#endif

  volatile int* nextHead = &resources->hostMem->head;
  char* localBuff = resources->hostMem->buff;
#ifdef PUSH_PROXY
  int* nextTail = (netCudaSupport && directDevMem) ? &resources->hostDevMem->tail : &devMem->tail;
  char* nextBuff = devMem->buff;
#else
  int* nextTail = &resources->hostMem->tail;
  char* nextBuff = resources->hostMem->buff;
#endif

  int buffSize = ring->buffSize;
  int sliceSize = buffSize / args->substeps;

  int head = 0;
  int data[args->substeps];

  int tail = 0;
  int idle = 0;
  void* requests[args->substeps];
#ifdef PUSH_PROXY
  while (tail < args->nsteps) {
    idle++;
    if (netCudaSupport == 1) {
      while (((head - *nextHead) < args->substeps) && (head < args->nsteps)) {
        int slot = head%args->substeps;
        NCCLCHECK(ncclNetIrecv(resources->netRecvComm, nextBuff+slot*sliceSize, sliceSize, requests+slot));
        head++;
        idle = 0;
      }
      if (tail < head) {
        int done;
        int slot = tail%args->substeps;
        NCCLCHECK(ncclNetTest(requests[slot], &done, NULL));
        if (done) {
          tail++;
          if (directDevMem) {
            *nextTail = tail;
          } else {
            data[slot] = tail;
            CUDACHECK(cudaMemcpyAsync(nextTail, data+slot, sizeof(int), cudaMemcpyHostToDevice, resources->stream));
          }
          idle = 0;
        }
      }
    } else {
      if (((head - tail) < args->substeps) && (head < args->nsteps)) {
        int slot = head%args->substeps;
        if (cudaEventQuery(resources->syncEvent[slot]) == cudaSuccess) {
          NCCLCHECK(ncclNetIrecv(resources->netRecvComm, localBuff+slot*sliceSize, sliceSize, requests+slot));
          head++;
          idle = 0;
        }
      }
      if (tail < head && ((tail - *nextHead) < args->substeps)) {
        int done;
        int slot = tail%args->substeps;
        int size;
        NCCLCHECK(ncclNetTest(requests[slot], &done, &size));
        if (done) {
          // Send to GPU
          CUDACHECK(cudaMemcpyAsync(nextBuff+slot*sliceSize, localBuff+slot*sliceSize, size, cudaMemcpyHostToDevice, resources->stream));
          CUDACHECK(cudaEventRecord(resources->syncEvent[slot], resources->stream));
          tail++;
          data[slot] = tail;
          CUDACHECK(cudaMemcpyAsync(nextTail, data+slot, sizeof(int), cudaMemcpyHostToDevice, resources->stream));
        }
        idle = 0;
      }
    }
    if (idle) transportProxyIdle(idle);
  }
  // Ensure all updates are pushed
  CUDACHECK(cudaStreamSynchronize(resources->stream));
#else
  while (tail < args->nsteps) {
    idle++;
    if (((head - tail) < args->substeps) && (head < args->nsteps)) {
      int slot = head%args->substeps;
      if (*nextHead > head) {
        printf("Posting Irecv %d\n", head);
        NCCLCHECK(ncclNetIrecv(resources->netRecvComm, localBuff+slot*sliceSize, sliceSize, requests+slot));
        head++;
        idle = 0;
      }
    }
    if (tail < head && ((tail - *nextHead) < args->substeps)) {
      int done;
      int slot = tail%args->substeps;
      int size;
      NCCLCHECK(ncclNetTest(requests[slot], &done, &size));
      if (done) {
        printf("Test %d done\n", tail);
        tail++;
        *nextTail = tail;
      }
      idle = 0;
    }
    if (idle) transportProxyIdle(idle);
  }
#endif

  // Wait for last ack and reset
  transportProxyWait([=] { return *nextHead == head; });
  *nextHead = 0;

  return ncclSuccess;
}

struct ncclTransport netTransport = {
  "NET",
  netFillInfo,
  netCanConnect,
  netGetRings,
  { netSendSetup, netSendConnect, netSendFree, netSendProxy },
  { netRecvSetup, netRecvConnect, netRecvFree, netRecvProxy }
};
