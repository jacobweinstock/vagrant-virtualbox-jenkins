require "yaml"

CONF = YAML.load(File.open("config.yaml", File::RDONLY).read)

Vagrant.configure("2") do |config|
    config.vm.box = "ubuntu/xenial64"
    config.vm.network "forwarded_port", guest: 8080, host: CONF['jenkins_external_port']
    config.vm.provider "virtualbox" do |v|
        v.memory = 4096
        v.cpus = 3
    end
    
    config.vm.provision "docker"
    config.vm.provision "shell", path: "prereqs.sh"
    
    ## mounts for salt provisioner, source code and jenkins job xml
    config.vm.synced_folder "salt/roots/", "/srv/salt/"
    config.vm.synced_folder CONF['src_path'], "/src/" + CONF['job_name'] + "/"
    config.vm.synced_folder ".", "/tmp/local"

    ## install Jenkins
    config.vm.provision :salt do |salt|

        salt.masterless = true
        salt.minion_config = "salt/minion"
        salt.run_highstate = true

    end
    config.vm.provision "shell", path: "setup.sh"

end
