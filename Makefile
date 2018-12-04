# This Makefile prepares the DVD directories
SHELL := /bin/bash


CONFIG_DIR=/opt/odie/config

BUILD_VERSION?=snapshot
OUTPUT_DIR?=output
OUTPUT_DISC?=base
TARGET_DIR=$(OUTPUT_DIR)/$(OUTPUT_DISC)/

ISO_BUILD_DIR?=dist/

.PHONY: root_check

root_check:
	echo "The ODIE build must be build as a non-root user.  It uses sudo for all yum operations"
	id -nu  | grep -v root
	echo "Non-root proceed!"

all: clean setup full_media primary release iso

build: primary baseline_iso
setup: initial_setup initial_rpm install_dependencies

initial_rpm: list_pool_ids attach setup_repos

initial_setup:
	./odie.sh properties build.yml
	cp -n $(CONFIG_DIR)/odie-hosts.yml.build-sample $(CONFIG_DIR)/odie-hosts.yml

full_media: setup_repos rpms stage_rhel_iso pull_images  pull_odie_images

# everything is put into the same DVD now
bootable: root_check partial_clean	stage_rhel_iso clone_git_repo setup_scripts add_rpms_repo
release: root_check clone_cop_git create_docs checksum


slim_iso: bootable add_rpms_repo bootable_iso
base_iso: bootable add_rpms_repo ln_base_images bootable_iso
extra_iso: ln_supplemental_images content_iso
appdev_iso: ln_s2i_images content_iso
mega_iso: base_iso extra_iso appdev_iso bootable_iso


install_dependencies: root_check
	sudo yum -y install vim-enhanced `cat conf/build-rpms.txt`
	sudo ./scripts/install_asciidoctor.sh
	sudo yum -y --enablerepo=rhel-7-server-optional-rpms --enablerepo=epel install  maven python2-pip htop the_silver_searcher jq
	sudo pip install docker-py PyYAML
	sudo systemctl enable --now docker

rpms: root_check generate_rpm_manifest download_rpms fix_perms

clean:
	rm -rf $(OUTPUT_DIR)/$(OUTPUT_DISC)/

clean_all: clean clean_rpms clean_images clean_manifests
	rm -rf $(OUTPUT_DIR)/$(OUTPUT_DISC)/

clean_rpms:
	rm -rf $(OUTPUT_DIR)/media/{Packages,repodata}

clean_images:
	rm -rf $(OUTPUT_DIR)/media/container_images

clean_manifests:
	rm -rf $(OUTPUT_DIR)/manifests/*


add_rpms_repo: root_check cp_rpms
	sudo build/rpm-createrepo.sh $(OUTPUT_DIR)/$(OUTPUT_DISC)/

generate_rpm_manifest: root_check
	sudo build/rpm-generate-file-list.sh $(OUTPUT_DIR)/manifests/

download_rpms: root_check
	sudo build/rpm-download-files.sh $(OUTPUT_DIR)/$(OUTPUT_DISC)/

fix_perms:  root_check
	./build/fix-perms.sh

create_docs:
	source /opt/rh/rh-ruby22/enable && cd documentation/ && make pdfs

setup_scripts: root_check
	mkdir -p $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	cp -r scripts $(OUTPUT_DIR)/$(OUTPUT_DISC)/scripts
	cp odie.sh $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	cp INSTALLER_VERSION $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	cp OCP_VERSION $(OUTPUT_DIR)/$(OUTPUT_DISC)/

cve_changelog:
	./scripts/generate-cve-delta.pl 2>&1 > $(OUTPUT_DIR)/$(OUTPUT_DISC)/CVE_CHANGELOG

clone_git_repo:
	./build/init-git-repo-on-disc.sh $(TARGET)/

stage_rhel_iso: root_check
	./build/stage-rhel-iso.sh $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	./build/fix-perms.sh $(OUTPUT_DIR)/$(OUTPUT_DISC)/


checksum:
	cd output && sha256sum `find -type f | egrep -v '.*\.pdf'` > ../documentation/target/ISO_CHECKSUM

TARGETS?="--all"
pull_images:
	mkdir -p $(OUTPUT_DIR)/container_images
	./scripts/migrate-images.sh pull $(TARGETS)

ln_base_images:
	mkdir -p $(TARGET_DIR)/container_images/
	ln $(OUTPUT_DIR)/media/container_images/ocp-images-base* $(TARGET_DIR)/container_images/

ln_supplemental_images:
	mkdir -p $(TARGET_DIR)/container_images/
	ln $(OUTPUT_DIR)/media/container_images/ocp-images-supplemental* $(TARGET_DIR)/container_images/

ln_s2i_images:
	mkdir -p $(TARGET_DIR)/container_images/
	ln $(OUTPUT_DIR)/media/container_images/s2i* $(TARGET_DIR)/container_images/

cp_rpms:
	mkdir -p $(TARGET_DIR)/
	cp -r $(OUTPUT_DIR)/media/{Packages,repodata} $(TARGET_DIR)

ISO_NAME?=dist/RedHat-ODIE-$(BUILD_VERSION)-$(OUTPUT_DISC).iso
bootable_iso:
	mkdir -p $(ISO_BUILD_DIR)
	find -name 'TRANS.TBL' -exec rm -f {} \;
	rm -f ${ISO_NAME}
	mkisofs -quiet -o ${ISO_NAME} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V 'RHEL-7.5 Server.x86_64' -boot-load-size 4 -boot-info-table -r -J -T $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	implantisomd5 ${ISO_NAME}

content_iso:
	mkdir -p $(ISO_BUILD_DIR)
	find -name 'TRANS.TBL' -exec rm -f {} \;
	rm -f ${ISO_NAME}
	mkisofs -quiet -o ${ISO_NAME} -r -J -T $(OUTPUT_DIR)/$(OUTPUT_DISC)/
	implantisomd5 ${ISO_NAME}

partial_clean:
	./build/fix-perms.sh
#	mkdir -p $(OUTPUT_DIR)/$(OUTPUT_DISC)/
#	cd $(OUTPUT_DIR)/$(OUTPUT_DISC)/ && find . -maxdepth 1 -not -name 'container_images' -not -name 'Packages' \
#		-exec sudo rm -Irf {} \;

pull_odie_images: build_postgres_stig build_cac_proxy
	mkdir -p $(OUTPUT_DIR)/container_images
	./scripts/migrate-images.sh pull --odie -t $(OUTPUT_DIR)/container_images/


list_pool_ids:
	@echo "*******************************************"
	@echo "List all available pool ids"
	@echo ""
	@echo "The pool IDs vary for each account so they must be manually determined"
	@echo ""
	@echo "This will find the first pool with the 'Red Hat OpenShift Container Platform'  entitlement."
	@echo "Copy this into your paste buffer as you will need it in the next step."
	@echo ""
	@echo "If you do not find this pool, contact your Red Hat sales team for assistance."
	@echo "********************************************"
	@echo ""
	@(export LOG=$$(mktemp); read -p "Press enter to continue: " m;  echo $$LOG ; subscription-manager list --available > $$LOG ; \
		less -p'OpenShift Container Platform' $$LOG)

inital_setup:
	./odie.sh properties build.yml

register:
	@echo "*******************************************"
	@echo "Adding Red Hat subscription. Please enter your Red Hat username and password."
	@echo "********************************************"
	@subscription-manager register

attach:
	@read -p "Enter the Red Hat subscription pool ID: " poolid; \
	sudo subscription-manager attach --pool $$poolid

setup_repos:
	sudo subscription-manager repos --disable "*" --enable rhel-7-server-rpms --enable rhel-7-server-ose-3.11-rpms --enable rhel-server-rhscl-7-rpms --enable rhel-7-server-extras-rpms --enable=rhel-7-server-ansible-2.6-rpms
	sudo subscription-manager release --set=7.6
	sudo yum clean all
	sudo yum -y install  https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
	sudo yum-config-manager --disable epel

unsubscribe:
	sudo subscription-manager remove --all
	sudo subscription-manager unregister

build_postgres_stig:
	VERSION=`cat contrib/postgresql-container-stig/VERSION` && docker build --no-cache -f contrib/postgresql-container-stig/Dockerfile.rhel7 contrib/postgresql-container-stig -t "localhost:5000/odie/postgresql-95-rhel7-stig:$${VERSION}" -t "localhost:5000/odie/postgresql-95-rhel7-stig:latest"

build_cac_proxy:
	VERSION=`cat contrib/cac-proxy/VERSION` && docker build --no-cache -f contrib/cac-proxy/Dockerfile contrib/cac-proxy -t "localhost:5000/odie/cac-proxy:$${VERSION}" -t "localhost:5000/odie/cac-proxy:latest"


clone_cop_git:
	rm -rf $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/
	mkdir -p $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/
	git clone https://github.com/redhat-cop/casl-ansible $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/casl-ansible	
	git clone https://github.com/redhat-cop/openshift-applier.git  $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/openshift-applier
	git clone https://github.com/redhat-cop/openshift-playbooks $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/openshift-playbooks
	git clone https://github.com/redhat-cop/containers-quickstarts $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/containers-quickstart
	git clone https://github.com/redhat-cop/container-pipelines $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/container-pipelines
	git clone https://github.com/redhat-cop/infra-ansible.git $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/infra-ansible
	git clone https://github.com/redhat-cop/openshift-toolkit $(OUTPUT_DIR)/$(OUTPUT_DISC)/utilities/openshift-toolkit

# this explicitly uses the build.yml
setup_buildhost_dnsmasq:
	sudo ./playbooks/operations/setup_dnsmasq.yml  -e @$(CONFIG_DIR)/build.yml
