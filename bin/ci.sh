#!/bin/bash
set -xe
bash bin/ci/build_and_install
bash bin/ci/generate_pizza_builder
rspec
