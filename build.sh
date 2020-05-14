#!/bin/sh

set -e
set -x
PLUGIN_NAME=`echo ${TRAVIS_REPO_SLUG} | cut -d'/' -f2`
PLUGIN_VERSION=${TRAVIS_BRANCH}

BUNDLER_CMD="bundle"
# XXX workaround build failure of the box
if [ -f /usr/local/etc/pkg/repos/local.conf ]; then
    sudo rm -f /usr/local/etc/pkg/repos/local.conf
fi
if which yum; then
    TOOLCHAINS="autoconf automake binutils bison flex gcc gcc-c++ gettext libtool make patch pkgconfig"
    sudo yum install -y epel-release centos-release-scl
    sudo yum install -y git rh-ruby25-ruby-devel rh-ruby25-devel jq rh-ruby25-rubygem-bundler ${TOOLCHAINS}
fi
if which pkg; then
    sudo pkg install -y devel/git lang/ruby26 devel/ruby-gems textproc/jq sysutils/rubygem-bundler
fi
if which apt-get; then
    sudo apt-get update
    sudo apt-get install -y git ruby-dev jq ruby-bundler
fi
if which pkg_add; then
    sudo pkg_add git jq ruby25-bundler
    BUNDLER_CMD="bundle25"
fi

ansible -m setup localhost | sed -e 's/^localhost | SUCCESS =>//' | jq '.ansible_facts' > ansible_facts

JQ_FLAGS="--raw-output"
JQ="jq ${JQ_FLAGS}"

# CentOS, Ubuntu, etc
ANSIBLE_DISTRIBUTION=`${JQ} '.ansible_distribution' ansible_facts`
# 7.8, 18.04. etc
ANSIBLE_DISTRIBUTION_VERSION=`${JQ} '.ansible_distribution_version' ansible_facts`
# x86_64, amd64, etc
ANSIBLE_ARCHITECTURE=`${JQ} '.ansible_architecture' ansible_facts`
# sensu-plugins-http_6.0.0_CentOS_7.8_x86_64, sensu-plugins-http_6.0.0_Ubuntu_18.04_amd64
ARCHIVE_FILE_NAME="${PLUGIN_NAME}_${PLUGIN_VERSION}_${ANSIBLE_DISTRIBUTION}_${ANSIBLE_DISTRIBUTION_VERSION}_${ANSIBLE_ARCHITECTURE}"
ARCHIVE_FILE_EXT=".tar.gz"

mkdir work
tee work/Gemfile <<__EOF__
source 'https://rubygems.org'
gem "${PLUGIN_NAME}", git: "https://github.com/${TRAVIS_REPO_SLUG}", ref: "${TRAVIS_BRANCH}"
__EOF__

(
    cd work
    ${BUNDLER_CMD} install --path=lib/ --binstubs=bin/ --standalone
)
tar -czf ${ARCHIVE_FILE_NAME}${ARCHIVE_FILE_EXT} -C work .
