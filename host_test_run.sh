#!/usr/bin/env bash
set -euo pipefail
vagrant up --provision
vagrant ssh -c "sudo /home/vagrant/test_run.sh"
