Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/focal64"    # Ubuntu 20.04 LTS; change to jammy/22.04 if preferred
  config.vm.hostname = "forensics-practice"
  config.vm.network "private_network", ip: "192.168.56.50"
  config.vm.synced_folder ".", "/vagrant", type: "virtualbox"
  config.vm.provider "virtualbox" do |vb|
    vb.memory = "3072"
    vb.cpus = 2
  end

  # Forward a port so you can optionally curl a tiny webserver
  config.vm.network "forwarded_port", guest: 8000, host: 8080

  config.vm.provision "shell", path: "provision.sh", privileged: true
end
