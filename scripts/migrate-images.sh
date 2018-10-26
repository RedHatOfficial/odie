#!/bin/bash

die()
{
	local _ret=$2
	test -n "$_ret" || _ret=1
	test "$_PRINT_HELP" = yes && print_help >&2
	echo "$1" >&2
	exit ${_ret}
}

begins_with_short_option()
{
	local first_option all_short_options
	all_short_options='h'
	first_option="${1:0:1}"
	test "$all_short_options" = "${all_short_options/$first_option/}" && return 1 || return 0
}

_positionals=()
_arg_operation="push"


# THE DEFAULTS INITIALIZATION - OPTIONALS
_arg_all=off
_arg_debug=''
_arg_odie=off
_arg_base=off
_arg_source=/opt/odie/images
_arg_target=/opt/odie/src/output/container_images
_arg_manifest=/opt/odie/src/conf/base-images.yml


print_help ()
{
	printf 'Usage: %s [--(no-)all] [--(no-)odie] [--(no-)efk] [--(no-)base] [--(no-)xpaas] [--(no-)docker] [--(no-)standard] [-h|--help]\n' "$0"
  	printf "\t%s\n" "<operation>: Whether you want to push or pull images (default: '""push""')"

	printf "\t%s\n" "--all,--no-all: Download All (default) (off by default)"
	printf "\t%s\n" "--odie,--no-odie: Download ODIE Images (off by default)"
	printf "\t%s\n" "--base,--no-base: Download Base OCP Images (off by default)"



	printf "\t%s\n" "-s,--source: Directory containing the source images & manifests (default: ''/opt/odie/images'')"
	printf "\t%s\n" "-t,--target: Target output directory (defaults /opt/openshift/images)"
	printf "\t%s\n" "-d,--debug: Enable Ansible verbose debugging"

	printf "\t%s\n" "-h,--help: Prints help"
  printf "\t%s\n" "-m,--manifest: Manifest (default: ''/opt/odie/src/conf/base-images.yml'')"
}

REPOS=()

parse_commandline ()
{
	while test $# -gt 0
	do
		_key="$1"
		case "$_key" in
			-s|--source)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_source="$2"
				shift
				;;
			--source=*)
				_arg_source=$(realpath "${_key##--source=}")
				;;
			-s*)
				_arg_source=$(realpath "${_key##-s}")
				;;
			-t|--target)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_target="$2"
				shift
				;;
			--target=*)
				_arg_target=$(realpath "${_key##--target=}")
				;;
			-t*)
				_arg_target=$(realpath "${_key##-t}")
				;;

		 	-m|--manifest)
				test $# -lt 2 && die "Missing value for the optional argument '$_key'." 1
				_arg_manifest="$2"
				shift
				;;
			--manifest=*)
				_arg_manifest="${_key##--manifest=}"
				;;
			-m*)
				_arg_manifest="${_key##-m}"
				;;
			--no-all|--all)
				_arg_all="on"
				test "${1:0:5}" = "--no-" && _arg_all="off"
        REPOS=('odie' 'base' )
				;;
			--no-odie|--odie)
				_arg_odie="on"
				test "${1:0:5}" = "--no-" && _arg_odie="off"
        REPOS+=('odie')
				;;
			--no-base|--base)
				_arg_base="on"
				test "${1:0:5}" = "--no-" && _arg_base="off"
        REPOS+=('base')
				;;
      --debug)
        _arg_debug="-vvv"
        ;;
			-h|--help)
				print_help
				exit 0
				;;
			-h*)
				print_help
				exit 0
				;;
			*)
				_positionals+=("$1")
				;;
		esac
		shift
	done
}

handle_passed_args_count ()
{
	test ${#_positionals[@]} -le 1 || _PRINT_HELP=yes die "FATAL ERROR: There were spurious positional arguments --- we expect between 0 and 1, but got ${#_positionals[@]} (the last one was: '${_positionals[*]: -1}')." 1
}

assign_positional_args ()
{
	_positional_names=('_arg_operation' )

	for (( ii = 0; ii < ${#_positionals[@]}; ii++))
	do
		eval "${_positional_names[ii]}=\${_positionals[ii]}" || die "Error during argument parsing, possibly an Argbash bug." 1
	done
}

parse_commandline "$@"
handle_passed_args_count
assign_positional_args



ARG=$_arg_operation

if [[ ${#REPOS[@]} -eq 0 ]]; then
  echo "Need to specify one or more image types (use --all for default)"
  exit 1
fi


set -e

export CMD="ansible-playbook ${_arg_debug} ./playbooks/container_images/"


function setup_host_target() {
  CMD="${CMD} -e host_target=registry"
}

function add_image_types() {
  if [[ "$_arg_all" = "off" ]]; then
    REPOS_CSV=$( IFS=$', '; echo "${REPOS[*]}" )
    CMD="${CMD} -e '{\"image_types\": [$REPOS_CSV] }'"
  fi
}


function add_odie_versions() {
  PSQL_VERSION=`cat contrib/postgresql-container-stig/VERSION`
  CAC_VERSION=`cat contrib/cac-proxy/VERSION`
  CMD="$CMD -e \"psql_stig_version=$PSQL_VERSION\" -e \"cac_proxy_version=$CAC_VERSION\""
}

function add_array_of_manifests() {
  if [[ "$_arg_all" = "off" ]]; then
    REPOS_MANIFEST=()
    for m in "${REPOS[@]}" ; do
      REPOS_MANIFEST+="\"$(realpath "$_arg_source/$m").yml\""
    done
    REPOS_CSV=$( IFS=$', '; echo "${REPOS_MANIFEST[*]}" )

    CMD="${CMD} -e '{\"image_manifests\": [$REPOS_CSV] }' "
  fi
}

function add_images_file() {
  CMD="${CMD} -e \"images_file=$_arg_manifest\""
}

function add_images_source() {
  # should this be conditional?
  CMD="${CMD} -e \"images_source=$(realpath $_arg_source)/\" "
}

function set_build_target() {
  # should this be conditional?
  CMD="${CMD} -e \"odie_images_dir=$(realpath $_arg_target)/\" "
}


if [[ $ARG = "push" ]]; then
  # push uses slurps all the YAMLs from a directory and pushes them into the bootstrap registry
  # - images_source - the location of the files
  # - images_target - the location on the registry VM for the images
  # - host_target assume this is happening on the registry
  # - image_manifests - an array of fully qualified YAML files of the manifest

  CMD="${CMD}push.yml  "

  #setup_host_target
  add_array_of_manifests
  add_images_source


elif [[ $ARG = "push_ocp" ]]; then
  # push_ocp wants a single file
  # - ocp_project: openshift (implicit docker_login -- not overriden)
  # - an array of image_types
  # - a single file for the manifest (base-images.yml)

  CMD="${CMD}push.yml -e ocp_project=openshift"

  #setup_host_target
  add_array_of_manifests
  add_images_source


elif [[ $ARG = "pull" ]]; then
  # pull_ocp just wants
  # - an array of image_types
  # - a single file for the manifest (base-images.yml)
  CMD="${CMD}pull.yml"
  add_image_types
  add_images_file
  add_images_source
  set_build_target




elif [[ $ARG = "import" ]]; then
  echo import
#            run_cmd ./playbooks/container_images/export-images.yml -e "config_path=${CONFIG_PATH}" -e "odie_images_dir=${OUTPUT_PATH}" -e "project_name=${PROJECT_NAME}" -e "output_name=${OUTPUT_NAME}" & spin $! "Exporting images from OCP"
elif [[ $ARG = "export" ]]; then
  echo export

#           run_cmd ./playbooks/container_images/export-images.yml -e "config_path=${CONFIG_PATH}" -e "odie_images_dir=${OUTPUT_PATH}" -e "project_name=${PROJECT_NAME}" -e "output_name=${OUTPUT_NAME}" & spin $! "Exporting images from OCP"
# odie_images_dir default typically the local 'output' it is defined in  odie.yml

elif [[ $ARG = "delta" ]] ; then
  echo delta
# ansible-playbook playbooks/container_images/pull.yml -e "odie_images_dir=`pwd`/output/delta_images" -e "images_file=`pwd`/conf/patch-images.yml" -e "{"image_types": [${PATCH_VERSION}]}" -vv

# odie_images_dir default typically the local 'output' it is defined in  odie.yml

else
  cat <<EOF
  Need to specify the operation type.

  Supported are:
  * push -> push manifests into bootstrap cluster
  * push_ocp ->  push manifests into OCP registry / imagestreams
  * pull -> from external repo into manifests

EOF
  exit 1
fi

# these are global for everyone
add_odie_versions

#-e "odie_images_dir=$_arg_source"
#  -e "{\"image_types\": [$REPOS_CSV]}"  \
#-vv

echo "Downloading: ${REPOS_CSV}"

echo $CMD
eval $CMD
