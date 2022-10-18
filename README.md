# Documentation

 - [RHOSP 16.2 Deployment Guide](https://access.redhat.com/documentation/en-us/red_hat_openstack_platform/16.2/html-single/director_installation_and_usage/index)

# Pre deploy steps

## Set hostname and add user

Running as a user **root**

    useradd stack
    passwd stack
    echo "stack ALL=(root) NOPASSWD:ALL" | tee -a /etc/sudoers.d/stack
    chmod 0440 /etc/sudoers.d/stack
    echo "$(ip r g 1 | head -1 | cut -d' ' -f7) rhosp-director.local rhosp-director" | tee -a /etc/hosts
    su - stack

Running as a user **stack**

    mkdir ~/images
    sudo hostnamectl set-hostname rhosp-director.local
    sudo hostnamectl set-hostname --transient rhosp-director.local
    sudo hostname rhosp-director.local
    echo rhosp-director.local | sudo tee /etc/hostname
    sudo reboot


## Register repositories and update OS

Running as a user **stack**

    sudo subscription-manager register --username redhat.infi --force
    sudo subscription-manager list --available --all --matches="Red Hat OpenStack"
    sudo subscription-manager attach --pool=<pool id>
    cat /etc/redhat-release
    sudo subscription-manager release --set=8.4
    sudo subscription-manager repos --disable=*
    sudo subscription-manager repos \
      --enable=rhel-8-for-x86_64-baseos-eus-rpms \
      --enable=rhel-8-for-x86_64-appstream-eus-rpms \
      --enable=rhel-8-for-x86_64-highavailability-eus-rpms \
      --enable=ansible-2.9-for-rhel-8-x86_64-rpms \
      --enable=openstack-16.2-for-rhel-8-x86_64-rpms \
      --enable=fast-datapath-for-rhel-8-x86_64-rpms
    sudo dnf module disable -y container-tools:rhel8
    sudo dnf module enable -y container-tools:3.0
    sudo dnf update -y
    sudo reboot


## Install base packages, TripleO client and registry

Running as a user **stack**

    sudo dnf -y install vim git strace tmux tcpdump python3-tripleoclient ipmitool rhosp-director-images rhosp-director-images-ipa-x86_64


## Update your templates

    # Update your secrets.yaml with real RedHat registry credentials
    # Update the nodes.yaml file with IPMI access for undercloud ironic controller
    # Specify infinibox addresses and pools for cinder backends at cinder-infinidat-config.yaml
    # Check the ip address of the control network for overcloud containers-prepare-parameter.yaml
    # Update custom-undercloud-params.yaml with your values to adopt the deployment to your environment


## Build and store plugin docker image

Running as a user **stack**

    sudo mkdir /srv/volumes/registry -p
    sudo podman run -d --network host -e REGISTRY_HTTP_ADDR=192.168.24.1:5051 -v /srv/volumes/registry:/var/lib/registry:Z --restart=always --name local_registry registry:2
    sudo podman login registry.redhat.io
    sudo podman build -f Dockerfile.cinder-infi -t 192.168.24.1:5051/openstack-cinder-volume-infinidat-plugin:16.2s
    sudo podman tag 192.168.24.1:5051/openstack-cinder-volume-infinidat-plugin:16.2m 192.168.24.1:5051/openstack-cinder-backup-infinidat-plugin:16.2s
    sudo podman push --tls-verify=false 192.168.24.1:5051/openstack-cinder-volume-infinidat-plugin:16.2s
    sudo podman push --tls-verify=false 192.168.24.1:5051/openstack-cinder-backup-infinidat-plugin:16.2s


## Install undercloud

Running as a user **stack**

    tail -3 secrets.yaml >> containers-prepare-parameter.yaml
    openstack undercloud install


## Store prebuilt image in your local registry

Running as a user **stack**

    sudo openstack tripleo container image push --local 192.168.24.1:5051/openstack-cinder-volume-infinidat-plugin:16.2s
    sudo openstack tripleo container image push --local 192.168.24.1:5051/openstack-cinder-backup-infinidat-plugin:16.2s
    sudo podman rmi 192.168.24.1:5051/openstack-cinder-backup-infinidat-plugin:16.2s
    sudo podman rmi 192.168.24.1:5051/openstack-cinder-volume-infinidat-plugin:16.2s


## Install overcloud

Running as a user **stack**

    ./deploy_rhsop.sh --redeploy
