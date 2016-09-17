/*************************************************************************
 * Copyright (c) 2015-2016, NVIDIA CORPORATION. All rights reserved.
 *
 * See LICENSE.txt for license information
 ************************************************************************/

#include "libwrap.h"
#include <dlfcn.h>
#include "core.h"

typedef enum { SUCCESS = 0 } RetCode;
int symbolsLoaded = 0;

static RetCode (*nvmlInternalInit)(void);
static RetCode (*nvmlInternalShutdown)(void);
static RetCode (*nvmlInternalDeviceGetHandleByPciBusId)(const char* pciBusId, nvmlDevice_t* device);
static RetCode (*nvmlInternalDeviceGetIndex)(nvmlDevice_t device, unsigned* index);
static RetCode (*nvmlInternalDeviceSetCpuAffinity)(nvmlDevice_t device);
static RetCode (*nvmlInternalDeviceClearCpuAffinity)(nvmlDevice_t device);
static const char* (*nvmlInternalErrorString)(RetCode r);
static RetCode (*nvmlInternalDeviceGetHandleByIndex)(unsigned int index, nvmlDevice_t* device);
static RetCode (*nvmlInternalDeviceGetNvLinkState)(nvmlDevice_t device, unsigned int link, nvmlEnableState_t *isActive);

ncclResult_t wrapSymbols(void) {

  if (symbolsLoaded)
    return ncclSuccess;

  static void* nvmlhandle = NULL;
  void* tmp;
  void** cast;

  nvmlhandle=dlopen("libnvidia-ml.so", RTLD_NOW);
  if (!nvmlhandle) {
    nvmlhandle=dlopen("libnvidia-ml.so.1", RTLD_NOW);
    if (!nvmlhandle) {
      WARN("Failed to open libnvidia-ml.so[.1]");
      goto teardown;
    }
  }

  #define LOAD_SYM(handle, symbol, funcptr) do {         \
    cast = (void**)&funcptr;                             \
    tmp = dlsym(handle, symbol);                         \
    if (tmp == NULL) {                                   \
      WARN("dlsym failed on %s - %s", symbol, dlerror());\
      goto teardown;                                     \
    }                                                    \
    *cast = tmp;                                         \
  } while (0)

  #define LOAD_SYM_OPTIONAL(handle, symbol, funcptr) do {\
    cast = (void**)&funcptr;                             \
    tmp = dlsym(handle, symbol);                         \
    if (tmp == NULL) {                                   \
      INFO("dlsym failed on %s, ignoring", symbol);      \
    }                                                    \
    *cast = tmp;                                         \
  } while (0)

  LOAD_SYM(nvmlhandle, "nvmlInit", nvmlInternalInit);
  LOAD_SYM(nvmlhandle, "nvmlShutdown", nvmlInternalShutdown);
  LOAD_SYM(nvmlhandle, "nvmlDeviceGetHandleByPciBusId", nvmlInternalDeviceGetHandleByPciBusId);
  LOAD_SYM(nvmlhandle, "nvmlDeviceGetIndex", nvmlInternalDeviceGetIndex);
  LOAD_SYM(nvmlhandle, "nvmlDeviceSetCpuAffinity", nvmlInternalDeviceSetCpuAffinity);
  LOAD_SYM(nvmlhandle, "nvmlDeviceClearCpuAffinity", nvmlInternalDeviceClearCpuAffinity);
  LOAD_SYM(nvmlhandle, "nvmlErrorString", nvmlInternalErrorString);
  LOAD_SYM(nvmlhandle, "nvmlDeviceGetHandleByIndex", nvmlInternalDeviceGetHandleByIndex);
  LOAD_SYM_OPTIONAL(nvmlhandle, "nvmlDeviceGetNvLinkState", nvmlInternalDeviceGetNvLinkState);

  symbolsLoaded = 1;
  return ncclSuccess;

  teardown:
  nvmlInternalInit = NULL;
  nvmlInternalShutdown = NULL;
  nvmlInternalDeviceGetHandleByPciBusId = NULL;
  nvmlInternalDeviceGetIndex = NULL;
  nvmlInternalDeviceSetCpuAffinity = NULL;
  nvmlInternalDeviceClearCpuAffinity = NULL;
  nvmlInternalDeviceGetNvLinkState = NULL;
  nvmlInternalDeviceGetHandleByIndex = NULL;

  if (nvmlhandle != NULL) dlclose(nvmlhandle);
  return ncclSystemError;
}


ncclResult_t wrapNvmlInit(void) {
  if (nvmlInternalInit == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalInit();
  if (ret != SUCCESS) {
    WARN("nvmlInit() failed: %s",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlShutdown(void) {
  if (nvmlInternalShutdown == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalShutdown();
  if (ret != SUCCESS) {
    WARN("nvmlShutdown() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceGetHandleByPciBusId(const char* pciBusId, nvmlDevice_t* device) {
  if (nvmlInternalDeviceGetHandleByPciBusId == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceGetHandleByPciBusId(pciBusId, device);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceGetHandleByPciBusId() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceGetIndex(nvmlDevice_t device, unsigned* index) {
  if (nvmlInternalDeviceGetIndex == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceGetIndex(device, index);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceGetIndex() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceSetCpuAffinity(nvmlDevice_t device) {
  if (nvmlInternalDeviceSetCpuAffinity == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceSetCpuAffinity(device);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceSetCpuAffinity() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceClearCpuAffinity(nvmlDevice_t device) {
  if (nvmlInternalInit == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceClearCpuAffinity(device);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceClearCpuAffinity() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceGetNvLinkState(nvmlDevice_t device, unsigned int link, nvmlEnableState_t *isActive) {
  if (nvmlInternalDeviceGetNvLinkState == NULL) {
    /* Do not warn, this symbol is optional. */
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceGetNvLinkState(device, link, isActive);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceGetNvLinkState() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}

ncclResult_t wrapNvmlDeviceGetHandleByIndex(unsigned int index, nvmlDevice_t* device) {
  if (nvmlInternalDeviceGetHandleByIndex == NULL) {
    WARN("lib wrapper not initialized.");
    return ncclLibWrapperNotSet;
  }
  RetCode ret = nvmlInternalDeviceGetHandleByIndex(index, device);
  if (ret != SUCCESS) {
    WARN("nvmlDeviceGetHandleByIndex() failed: %s ",
      nvmlInternalErrorString(ret));
    return ncclSystemError;
  }
  return ncclSuccess;
}
