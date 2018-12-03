# This Makefile prepares the DVD directories
SHELL := /bin/bash

BUILD_VERSION?=snapshot
DISC?=base/
DISC?=output

.PHONY: root_check

root_check:
	echo "The ODIE build must be build as a non-root user.  It uses sudo for all yum operations"
	id -nu  | grep -v root
	echo "Non-root proceed!"

all: clean setup full_media primary release iso

build: primary
setup: initial_setup initial_rpm install_dependencies

initial_rpm: list_pool_ids attach setup_repos

initial_setup:
	./odie.sh properties build.yml
	cp -n /opt/odie/config/hosts-build.csv.sample /opt/odie/config/hosts.csv

full_media: setup_repos rpms stage_rhel_iso pull_images  pull_odie_images

# everything is put into the same DVD now
primary: root_check partial_clean stage_rhel_iso clone_git_repo setup_scripts
release: root_check clone_cop_git create_docs checksum

install_dependencies: root_check
	sudo yum -y install vim-enhanced `cat conf/build-rpms.txt`
	sudo ./scripts/install_asciidoctor.sh
	sudo yum -y --enablerepo=rhel-7-server-optional-rpms --enablerepo=epel install  maven python2-pip htop the_silver_searcher jq
	sudo pip install docker-py PyYAML
	sudo systemctl enable --now docker

rpms: root_check generate_rpm_manifest download_rpms create_rpm_repos fix_perms

clean: fix_perms clean_rpms
	rm -rf manifests/*
	rm -rf output

clean_rpms:
	rm -rf output/{Packages,repodata}

create_rpm_repo: root_check
	sudo build/rpm-createrepo.sh

generate_rpm_manifest: root_check
	sudo build/rpm-generate-file-list.sh

download_rpms: root_check
	sudo build/rpm-download-files.sh

fix_perms:  root_check
	./build/fix-perms.sh

create_docs:
	source /opt/rh/rh-ruby22/enable && cd documentation/ && make pdfs

setup_scripts: root_check create_rpm_repo
	mkdir -p output
	cp -r scripts output/scripts
	cp odie.sh output/
	cp INSTALLER_VERSION output/
	cp OCP_VERSION output/

cve_changelog:
	./scripts/generate-cve-delta.pl 2>&1 > output/CVE_CHANGELOG


clone_git_repo:
	sh scripts/local-git-repo.sh

stage_rhel_iso: root_check
	./build/stage-rhel-iso.sh output/
	./build/fix-perms.sh

checksum:
	cd output && sha256sum `find -type f | egrep -v '.*\.pdf'` > ../documentation/target/ISO_CHECKSUM

pull_images:
	mkdir -p output/container_images
	./scripts/migrate-images.sh pull --all

ISO_NAME=dist/RedHat-ODIE-$(BUILD_VERSION).iso
baseline_iso:
	mkdir -p dist/
	find -name 'TRANS.TBL' -exec rm -f {} \;
	rm -f ${ISO_NAME}
	mkisofs -quiet -o ${ISO_NAME} -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V 'RHEL-7.5 Server.x86_64' -boot-load-size 4 -boot-info-table -r -J -T output/
	implantisomd5 ${ISO_NAME}

7z:
	7za a -m0 -v900m ${ISO_NAME}.7z  ${ISO_NAME}

partial_clean:
	./build/fix-perms.sh
	mkdir -p output
	cd output/ && find . -maxdepth 1 -not -name 'container_images' -not -name 'Packages' \
		-exec sudo rm -Irf {} \;

pull_odie_images: build_postgres_stig build_cac_proxy
	mkdir -p output/container_images
	./scripts/migrate-images.sh pull --odie -t output/container_images/

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
	rm -rf output/utilities/
	mkdir -p output/utilities/
	git clone https://github.com/redhat-cop/casl-ansible output/utilities/casl-ansible	
	git clone https://github.com/redhat-cop/openshift-applier.git  output/utilities/openshift-applier
	git clone https://github.com/redhat-cop/openshift-playbooks output/utilities/openshift-playbooks
	git clone https://github.com/redhat-cop/containers-quickstarts output/utilities/containers-quickstart
	git clone https://github.com/redhat-cop/container-pipelines output/utilities/container-pipelines
	git clone https://github.com/redhat-cop/infra-ansible.git output/utilities/infra-ansible
	git clone https://github.com/redhat-cop/openshift-toolkit output/utilities/openshift-toolkit
