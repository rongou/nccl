#
# Copyright (c) 2015-2016, NVIDIA CORPORATION. All rights reserved.
#
# See LICENCE.txt for license information
#
.PHONY : all clean

default : src.build

TARGETS := src test fortran debian
all:   ${TARGETS:%=%.build}
clean: ${TARGETS:%=%.clean}
debian.build fortran.build test.build: src.build
%.build:
	${MAKE} -C $* build

%.clean:
	${MAKE} -C $* clean

deb: debian.build
	${MAKE} -C debian package
