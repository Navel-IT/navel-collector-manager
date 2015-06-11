#!/bin/bash
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

READLINK='readlink'
DIRNAME='dirname'
ECHO='echo'
WHICH='which'
MKDIR='mkdir'
CP='cp'
SED='sed'
TAR='tar'
RPMBUILD='rpmbuild'

prog='navel-scheduler'

dirname=$(${DIRNAME} $(${READLINK} -f $0))

rpm_version=${1}
rpm_release=${2}

if [[ -z ${rpm_version} || -z ${rpm_release} ]] ; then
    ${ECHO} "Usage : ${0} <version> <release>"

    exit 1
fi

${ECHO} "Building RPM archive version ${rpm_version}, release ${rpm_release}"

if [[ $(${WHICH} ${RPMBUILD}) ]] &>/dev/null ; then
    cpan_directory="${dirname}/CPAN/"
    rpm_directory="${dirname}/RPM/"

    specs_directory="${rpm_directory}/SPECS/"
    sources_directory="${rpm_directory}/SOURCES/"

    ${MKDIR} -p ${sources_directory}/usr/local/${prog} && ${CP} -r ${cpan_directory}/lib ${sources_directory}/usr/local/share/${prog} 1>/dev/null && ${CP} -r ${cpan_directory}/bin ${sources_directory}/usr/local/ 1>/dev/null

    if [[ ${?} -eq 0 ]] ; then
        pushd ${sources_directory}

        ${TAR} cvzf ${prog}.tar.gz {etc,usr,var} 1>/dev/null

        popd

        if [[ ${?} -eq 0 ]] ; then
            ${RPMBUILD} -bb --define "_topdir ${rpm_directory}" --define "_version ${rpm_version}" --define "_release ${rpm_release}" ${specs_directory}/${prog}.spec 1>/dev/null

            RETVAL=${?}

            ${ECHO} ${RETVAL}

            exit ${RETVAL}
        else
            ${ECHO} "An error occured while archiving sources into ${sources_directory}"
        fi
    else
        ${ECHO} "An error occured while copying files to ${sources_directory}"
    fi
else
    ${ECHO} "${RPMBUILD} is required for building RPM"
fi

${ECHO} ${?}

exit 1

#-> END
