# Makefile for go-sdk-abstract-factory.

# "Simple expanded" variables (':=')

# PROGRAM_NAME is the name of the GIT repository.
PROGRAM_NAME := $(shell basename `git rev-parse --show-toplevel`)
MAKEFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
MAKEFILE_DIRECTORY := $(dir $(MAKEFILE_PATH))
TARGET_DIRECTORY := $(MAKEFILE_DIRECTORY)/target
DOCKER_CONTAINER_NAME := $(PROGRAM_NAME)
DOCKER_IMAGE_NAME := senzing/$(PROGRAM_NAME)
DOCKER_BUILD_IMAGE_NAME := $(DOCKER_IMAGE_NAME)-build
BUILD_VERSION := $(shell git describe --always --tags --abbrev=0 --dirty  | sed 's/v//')
BUILD_TAG := $(shell git describe --always --tags --abbrev=0  | sed 's/v//')
BUILD_ITERATION := $(shell git log $(BUILD_TAG)..HEAD --oneline | wc -l | sed 's/^ *//')
GIT_REMOTE_URL := $(shell git config --get remote.origin.url)
GO_PACKAGE_NAME := $(shell echo $(GIT_REMOTE_URL) | sed -e 's|^git@github.com:|github.com/|' -e 's|\.git$$||' -e 's|Senzing|senzing|')

# Recursive assignment ('=')

CC = gcc

# Conditional assignment. ('?=')
# Can be overridden with "export"
# Example: "export LD_LIBRARY_PATH=/path/to/my/senzing/g2/lib"

LD_LIBRARY_PATH ?= /opt/senzing/g2/lib
SENZING_TOOLS_DATABASE_URL ?= sqlite3://na:na@/tmp/sqlite/G2C.db

# Export environment variables.

.EXPORT_ALL_VARIABLES:

# The first "make" target runs as default.

.PHONY: default
default: help

# -----------------------------------------------------------------------------
# Build
# -----------------------------------------------------------------------------

.PHONY: dependencies
dependencies:
	@go get -u ./...
	@go get -t -u ./...
	@go mod tidy

# -----------------------------------------------------------------------------
# Test
# -----------------------------------------------------------------------------

.PHONY: test
test:
	@go test -v -p 1 ./...
#	@go test -v ./.
#	@go test -v ./factory


.PHONY: test-base
test-base: export SENZING_TOOLS_TESTCASE_NUMBER=1
test-base:
	@go test -v ./.


.PHONY: test-grpc
test-grpc: export SENZING_TOOLS_TESTCASE_NUMBER=2
test-grpc:
	@go test -v ./.

# -----------------------------------------------------------------------------
# Run
# -----------------------------------------------------------------------------

.PHONY: run
run:
	@go run main.go

# -----------------------------------------------------------------------------
# Utility targets
# -----------------------------------------------------------------------------

.PHONY: update-pkg-cache
update-pkg-cache:
	@GOPROXY=https://proxy.golang.org GO111MODULE=on \
		go get $(GO_PACKAGE_NAME)@$(BUILD_TAG)


.PHONY: clean
clean:
	@go clean -cache
	@go clean -testcache
	@docker rm --force $(DOCKER_CONTAINER_NAME) 2> /dev/null || true
	@docker rmi --force $(DOCKER_IMAGE_NAME) $(DOCKER_BUILD_IMAGE_NAME) 2> /dev/null || true
	@rm -rf $(TARGET_DIRECTORY) || true
	@rm -f $(GOPATH)/bin/$(PROGRAM_NAME) || true
	@rm -rf /tmp/sqlite
	@mkdir  /tmp/sqlite
	@cp testdata/sqlite/G2C.db /tmp/sqlite/G2C.db


.PHONY: print-make-variables
print-make-variables:
	@$(foreach V,$(sort $(.VARIABLES)), \
		$(if $(filter-out environment% default automatic, \
		$(origin $V)),$(warning $V=$($V) ($(value $V)))))


.PHONY: help
help:
	@echo "Build $(PROGRAM_NAME) version $(BUILD_VERSION)-$(BUILD_ITERATION)".
	@echo "All targets:"
	@$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$' | xargs
