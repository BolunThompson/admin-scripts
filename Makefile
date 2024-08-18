SHELL=bash

all: build
	${SHELL} ./build build
clean:
	${SHELL} ./build clean
