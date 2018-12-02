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
setup: import_pki setup_repos install_dependencies

full_media: setup_repos rpms stage_rhel_iso pull_images  pull_odie_images

# everything is put into the same DVD now
primary: root_check stage_rhel_iso clone_git_repo setup_scripts
release: root_check clone_cop_git create_docs cve_changelog checksum

install_dependencies: root_check
	sudo yum -y install vim-enhanced `cat conf/build-rpms.txt`
	sudo ./scripts/install_asciidoctor.sh
	sudo systemctl enable --now docker

rpms: root_check generate_rpm_manifest download_rpms create_rpm_repos fix_perms

clean: fix_perms clean_rpms

clean_rpms:
	rm -rf output/{Packages,repodata}

create_rpm_repo: root_check
	sudo build/rpm-createrepo.sh

generate_rpm_manifest: root_check
	sudo build/rpm-generate-file-list.sh

download_rpms: root_check
	sudo build/rpm-download-files.sh

fix_perms:  root_check
	(user=$(shell id -un):$(shell id -gn); sudo chown -R $$user /opt/odie/src )
	(user=$(shell id -un):$(shell id -gn); sudo chown -R $$user /opt/odie/config )
	(user=$(shell id -un):$(shell id -gn); sudo chown -R $$user /etc/odie-release )

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
	build/stage-rhel-iso.sh output/

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
	mkdir -p output
	cd output/ && find . -maxdepth 1 -not -name 'container_images' -not -name 'Packages' \
		-not -name 'delta_*' -not -name 'CVE_CHANGELOG' -exec rm -rf {} \;

pull_odie_images: build_postgres_stig build_cac_proxy
	mkdir -p output/container_images
	./scripts/migrate-images.sh pull --odie -t output/container_images/


register:
	@echo "*******************************************"
	@echo "Adding Red Hat subscription. Please enter your Red Hat username and password."
	@echo "********************************************"
	@subscription-manager register
	@read -p "Enter the Red Hat subscription pool ID: " poolid; \
	sudo subscription-manager attach --pool $$poolid

setup_repos:
	@sudo subscription-manager repos --disable "*" --enable rhel-7-server-rpms --enable rhel-7-server-ose-3.11-rpms --enable rhel-server-rhscl-7-rpms --enable rhel-7-server-extras-rpms --enable=rhel-7-server-ansible-2.6-rpms
	sudo subscription-manager release --set=7.6
	sudo yum clean all

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

import_pki:
	sudo rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release
