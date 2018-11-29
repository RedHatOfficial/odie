# This Makefile prepares the DVD directories
SHELL := /bin/bash

BUILD_VERSION?=snapshot

build: primary
setup: import_pki setup_repos install_dependencies setup_repo_pki

full_media: setup_repos rpms stage_rhel_iso pull_images  pull_odie_images
#delta_media: setup_repos rpms pull_delta_images  pull_odie_images

# everything is put into the same DVD now
dvd: primary iso
primary: stage_rhel_iso clone_git_repo setup_scripts create_rpm_repo
release: clone_cop_git create_docs cve_changelog checksum

install_dependencies:
	sudo yum -y install vim-enhanced `cat conf/build-rpms.txt`
	./scripts/install_asciidoctor.sh
	systemctl enable --now docker

rpms: generate_rpm_manifest download_rpms create_rpm_repos

clean_rpms:
	rm -rf {Packages,repodata}

create_rpm_repo:
	sudo build/rpm-createrepo.sh

generate_rpm_manifest:
	sudo build/rpm-generate-file-list.sh

download_rpms:
	sh build/rpm-download-files.sh

create_docs:
	source /opt/rh/rh-ruby22/enable && cd documentation/ && make pdfs

setup_scripts:
	cp -r scripts output/scripts
	cp odie.sh output/
	cp INSTALLER_VERSION output/

cve_changelog:
	./scripts/generate-cve-delta.pl 2>&1 > output/CVE_CHANGELOG


clone_git_repo:
	sh scripts/local-git-repo.sh

stage_rhel_iso:
	scripts/stage-rhel-iso.sh output/

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
	mkisofs -quiet -o ${ISO_NAME} -m 'delta_*' -m 'container_images/extra*' -b isolinux/isolinux.bin -c isolinux/boot.cat -no-emul-boot -V 'RHEL-7.5 Server.x86_64' -boot-load-size 4 -boot-info-table -r -J -T output/
	implantisomd5 ${ISO_NAME}

clean:
	rm -rf output/ dist/

7z:
	7za a -m0 -v900m ${ISO_NAME}.7z  ${ISO_NAME}

partial_clean:
	mkdir -p output
	cd output/ && find . -maxdepth 1 -not -name 'container_images' -not -name 'Packages' \
		-not -name 'delta_*' -not -name 'CVE_CHANGELOG' -exec rm -rf {} \;

#all: disconnected

pull_odie_images: build_postgres_stig build_cac_proxy
	mkdir -p output/container_images
	./scripts/migrate-images.sh pull --odie -t output/container_images/

setup_repo_pki:
	./scripts/repo-pki.sh

#### The rest of the file contains misc runtime functions, not related to media building
webdirs:
	mkdir -p /var/www/html/repos
	rm -f /var/www/html/repos/odie-custom
	ln -s --force /opt/odie/repo/odie-custom /var/www/html/repos/odie-custom

import_pki:
	rpm --import /etc/pki/rpm-gpg/RPM-GPG-KEY-redhat-release

localrepos:
	cp files/ose.repo /etc/yum.repos.d/ose.repo
	yum clean all
	#yum -y update

register:
	@echo "*******************************************"
	@echo "Adding Red Hat subscription. Please enter your Red Hat username and password."
	@echo "********************************************"
	@subscription-manager register
	@read -p "Enter the Red Hat subscription pool ID: " poolid; \
	subscription-manager attach --pool $$poolid

setup_repos:
	@subscription-manager repos --disable "*" --enable rhel-7-server-rpms --enable rhel-7-server-ose-3.11-rpms --enable rhel-server-rhscl-7-rpms --enable rhel-7-server-extras-rpms --enable=rhel-7-server-ansible-2.6-rpms
	subscription-manager release --set=7.6
	yum clean all

unsubscribe:
	subscription-manager remove --all
	subscription-manager unregister

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


setup_dnsmasq:
	sudo ./playbooks/operations/setup_dnsmasq.yml  -e @/opt/odie/config/build.yml

