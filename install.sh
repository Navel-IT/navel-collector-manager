#!/bin/bash
# Navel Scheduler is developed by Yoann Le Garff, Nicolas Boquet and Yann Le Bras under GNU GPL v3

#-> BEGIN

#-> set vars

program_name='navel-scheduler'

supported_os=(
    'rhel'
)

program_user="${program_name}"
program_group="${program_name}"

others_files_source_prefix='SYS'

cpanminus_url='http://cpanmin.us'
cpanminus_module='App::cpanminus'

navel_base_git_repo=(
    'https://github.com/Navel-IT/navel-base.git'
)

version_regex='^[0-9]+\.[0-9]+$'
navel_base_git_repo_branch_regex='^(master|devel)$'

#-> functions

# std

f_do() {
    ${ECHO} -en "[ \033[34mDO\033[0m ] ${@}\n"
}

f_ok() {
    ${ECHO} -en "[ \033[32mOK\033[0m ] ${@}\n"
}

f_warn() {
    ${ECHO} -en "[ \033[33mWARN\033[0m ] ${@}\n"
}

f_die() {
    ${ECHO} -en "[ \033[31mDIE\033[0m ] ${1}\n"

    exit ${2}
}

f_check_binaries() {
    local binary

    for binary in ${@} ; do
        which "${binary}" &>/dev/null || return 1
    done

    return 0
}

# OS

f_os_is_rhel() {
    [[ -f /etc/redhat-release ]]
}

f_define_variables_for_rhel() {
    DIRNAME='dirname'
    READLINK='readlink'
    ECHO='echo'
    GREP='grep'
    YUM='yum'
    CURL='curl'
    PERL='perl'
    RM='rm'
    TAR='tar'
    CPANM='cpanm'
    GETENT='getent'
    USERADD='useradd'
    GROUPADD='groupadd'
    YES='yes'
    CP='/bin/cp'
    MKDIR='mkdir'
    CHMOD='chmod'
    CHKCONFIG='chkconfig'
    CHOWN='chown'

    dirname=$(${DIRNAME} $0)
    full_dirname=$(${READLINK} -f ${dirname})

    pkg_to_install_via_pkg_manager=(
        'tar'
        'curl'
        'gcc'
        'libxml2'
        'libxml2-devel'
    )

    program_home_directory="/usr/local/etc/${program_name}/"

    others_files_configuration_directory="${program_home_directory}"
    others_files_sysconfig_directory='/etc/sysconfig/'
    others_files_init_directory='/etc/init.d/'
}

# wrappers

f_match() {
    if f_os_is_rhel ; then
        ( ${ECHO} "${1}" | ${GREP} -E "${2}" &>/dev/null ) && return 0
    fi

    return 1
}

f_install_pkg() {
    if f_os_is_rhel ; then
        ${YUM} install -y ${@}
    fi
}

f_tar() {
    if f_os_is_rhel ; then
        ${TAR} ${@}
    fi
}

f_rm() {
    if f_os_is_rhel ; then
        ${RM} -f ${@}
    fi
}

f_useradd() {
    if f_os_is_rhel ; then
        ${GETENT} passwd "${1}" 1>/dev/null || ${USERADD} -rmd "${3}" -g "${2}" -s /sbin/nologin ${1}
    fi
}

f_groupadd() {
    if f_os_is_rhel ; then
        ${GETENT} group "${1}" 1>/dev/null || ${GROUPADD} -r "${1}"
    fi
}

f_cp() {
    if f_os_is_rhel ; then
        ${CP} -r ${@}
    fi
}

f_mkdir() {
    local fails=0 directory

    if f_os_is_rhel ; then
        for directory in ${@} ; do
            ( [[ -d "${directory}" ]] || ${MKDIR} -p "${directory}" ) || let fails++
        done
    fi

    return ${fails}
}

f_chmod() {
    if f_os_is_rhel ; then
        ${CHMOD} ${@}
    fi
}

f_configure_service_to_start_at_boot() {
    if f_os_is_rhel ; then
        ${CHKCONFIG} "${1}" on
    fi
}

f_chown() {
    if f_os_is_rhel ; then
        ${CHOWN} ${@}
    fi
}

#-> installation steps

f_install_step_1() {
    f_do "Installing packages ${pkg_to_install_via_pkg_manager[@]} using the package manager."

    f_install_pkg ${pkg_to_install_via_pkg_manager[@]}
}

f_install_step_2() {
    f_do "Installing ${cpanminus_module} via ${CURL}."

    ${CURL} -L "${cpanminus_url}" | ${PERL} - "${cpanminus_module}"
}

f_install_step_3() {
    cpan_archive_name="${program_name}-${program_version}.tar.gz"

    f_tar cvzf "${dirname}/${cpan_archive_name}" "${dirname}/CPAN"
}

f_install_step_4() {
    trap "f_rm '${full_dirname}/${cpan_archive_name}'" EXIT INT TERM

    f_do "Installing ${navel_base_git_repo}@${git_branch} and CPAN archive."

    ${CPANM} "${navel_base_git_repo}@${git_branch}" "${full_dirname}/${cpan_archive_name}"
}

f_install_step_5() {
    f_do "Creating group ${program_group}."

    f_groupadd "${program_group}"
}

f_install_step_6() {
    f_do "Creating user ${program_user} with home directory ${program_home_directory}."

    f_useradd "${program_user}" "${program_group}" "${program_home_directory}"
}

f_install_step_7() {
    local from="${full_dirname}/${others_files_source_prefix}/${others_files_configuration_directory}/*" to="/${others_files_configuration_directory}"

    f_do "Copying configuration files from ${from} to ${to}."

    f_cp "${from}" "${to}"
}

f_install_step_8() {
    program_run_directory="/var/run/${program_name}/"
    program_log_directory="/var/log/${program_name}/"

    f_do "Creating directories ${program_run_directory} and ${program_log_directory}."

    f_mkdir "${program_run_directory}" "${program_log_directory}"
}

f_install_step_9() {
    local from="${full_dirname}/${others_files_source_prefix}/${others_files_sysconfig_directory}/${program_name}" to="/${others_files_sysconfig_directory}/${program_name}"

    f_do "Copying sysconfig script from ${from} to ${to}."

    f_cp "${from}" "${to}"
}

f_install_step_10() {
    local from="${full_dirname}/${others_files_source_prefix}/${others_files_init_directory}/${program_name}" default_program_binary_directory="/usr/local/bin"

    to="/${others_files_init_directory}/${program_name}"

    [[ -z "${program_binary_directory}" ]] && program_binary_directory="${default_program_binary_directory}"

    f_do "Copying init script from ${from} to ${to}."

    f_cp "${from}" "${to}" && ${PERL} -p -i -e "s'${default_program_binary_directory}'${program_binary_directory}'g" "/${others_files_init_directory}/${program_name}"
}

f_install_step_11() {
    f_do "Chmoding init script for execution."

    f_chmod +x "${to}"
}

f_install_step_12() {
    f_do "Configuring service ${program_name} to start at boot."

    f_configure_service_to_start_at_boot "${program_name}"
}

f_install_step_13() {
    local program_binary_path="${program_binary_directory}/${program_name}"

    f_do "Chowning directories and files (${program_binary_path}, ${program_home_directory}, ${others_files_configuration_directory}, ${program_run_directory} and ${program_log_directory}) to ${program_user}:${program_group}."

    f_chown -R "${program_user}:${program_group}" "${program_binary_path}" "${program_home_directory}" "${others_files_configuration_directory}" "${program_run_directory}" "${program_log_directory}"
}

#-> main

for t_os in ${supported_os[@]} ; do
    if eval "f_os_is_${t_os}" ; then
        os="${t_os}"

        eval "f_define_variables_for_${os}"

        break
    fi
done

usage="Usage: ${0} -n <branch of ${navel_base_git_repo}> -v <version> [-b <directory of the binary program>]$ [-c (copy defaults configuration files)]"

while getopts 'n:v:b:c' OPT 2>/dev/null ; do
    case ${OPT} in
        n)
            git_branch=${OPTARG} ;;
        v)
            program_version=${OPTARG} ;;
        b)
            program_binary_directory=${OPTARG} ;;
        c)
            copy_configuration_file=1 ;;
        *)
            f_die "${usage}" 1 ;;
    esac
done

(
    f_match "${program_version}" "${version_regex}" &&
    f_match "${git_branch}" "${navel_base_git_repo_branch_regex}"
) || f_die "${usage}" 1

if [[ -n ${os} ]] ; then
    f_do "Installing ${program_name}."

    step_number=1

    while [[ $(type -t "f_install_step_${step_number}") == 'function' ]] ; do
        eval "f_install_step_${step_number}"

        RETVAL=${?}

        if [[ ${RETVAL} -eq 0 ]] ; then
            f_ok
        else
            f_die "The installation of ${program_name} cannot continue." ${RETVAL}
        fi

        let step_number++
    done

    f_ok "The installation of ${program_name} is done."

    exit ${RETVAL}
else
    f_die 'This OS is not supported.' 1
fi

#-> END
