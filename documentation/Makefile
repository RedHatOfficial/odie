BUILD_VERSION?=$(shell cat ../INSTALLER_VERSION)
DATE=$(shell date '+%m-%d-%Y')

clean:
	rm -rf ../output/docs
	rm -rf target

pdfs: user_guide

user_guide:
	mkdir -p ../output/docs/
	asciidoctor-pdf -a version="${BUILD_VERSION}" -a revdate="${DATE}" -a revnumber=${BUILD_VERSION} -o ../output/docs/RedHat-ODIE-UserGuide-${BUILD_VERSION}.pdf volumes/vol04_userguide.adoc

blueprint:
	mkdir -p ../output/docs/
	mkdir -p target
	../scripts/parse_adoc_headers.py > target/scripts.adoc
	asciidoctor-pdf -a version="${BUILD_VERSION}" -a revdate="${DATE}" -a revnumber=${BUILD_VERSION}  -o ../output/docs/RedHat-ODIE-ArchitectureBlueprint-${BUILD_VERSION}.pdf volumes/vol02_architectureBlueprint.adoc

