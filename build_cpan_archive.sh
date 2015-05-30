#!/bin/bash
# Navel Scheduler is developped by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

DIRNAME='dirname'
ECHO='echo'
TAR='tar'

prog='navel-scheduler'

dirname=$(${DIRNAME} $0)

version=${1}

if [[ -z ${version} ]] ; then
    ${ECHO} "Usage : ${0} <version>"

    exit 1
fi

${ECHO} "Building CPAN archive version ${version}"

${TAR} cvzf ${dirname}/${prog}-${version}.tar.gz ${dirname}/CPAN 1>/dev/null

RETVAL=${?}

${ECHO} ${RETVAL}

exit ${RETVAL}

#-> END
