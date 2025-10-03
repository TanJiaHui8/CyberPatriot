AEACUS Enhanced Linux Forensics Practice VM

This enhanced package includes:
- Vagrantfile to build an Ubuntu VM (VirtualBox + Vagrant)
- provision.sh: installs toolchain (Go), attempts to build aeacus from source, creates realistic and subtle forensic artifacts
- Multiple difficulty configurations: scoring_easy.conf, scoring_medium.conf, scoring_hard.conf, and corresponding ReadMe_* files in /opt/aeacus
- A shim aeacus binary is provided if building fails; when network & Go are available during 'vagrant up' the real binary will be built automatically from the cloned repo.
- test_run.sh (inside VM) automates running aeacus check/score/forensics and validates outputs
- packer.json sample to build an OVA/QCOW2 with Packer (edit iso_url and checksums before use)
- host_test_run.sh helps automate vagrant up + test on host machine

Usage (host machine):
1. Install VirtualBox and Vagrant.
2. Unzip this project and cd into it.
3. Run: ./host_test_run.sh
   - This will create the VM, provision it, and run the automated test inside the VM.
4. After provisioning you can also:
   vagrant ssh
   sudo /opt/aeacus/aeacus --verbose check
   sudo /opt/aeacus/aeacus --verbose score
   sudo /opt/aeacus/aeacus forensics 3
   ls -l /home/vagrant/Desktop

Notes & Limitations:
- I created provisioning that installs 'golang-go' and attempts to build aeacus inside the VM. If you are offline or GitHub is rate-limited, the provisioning script will fall back to a robust shim so the exercises still work.
- The Packer template is a skeleton and may require additional customization for unattended Ubuntu installation.
- For maximum realism, run the VM, then optionally run 'sudo /home/vagrant/test_run.sh' inside the VM to validate artifacts and generated ForensicsQ files.
