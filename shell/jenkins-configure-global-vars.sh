#!/bin/bash
# SPDX-License-Identifier: EPL-1.0
##############################################################################
# Copyright (c) 2018 The Linux Foundation and others.
#
# All rights reserved. This program and the accompanying materials
# are made available under the terms of the Eclipse Public License v1.0
# which accompanies this distribution, and is available at
# http://www.eclipse.org/legal/epl-v10.html
##############################################################################
# Pulls global variable definitions out of a file.
#
# Configuration is read from $WORKSPACE/jenkins-config/global-vars-$silo.sh
#
# Requirements: lftools must be installed to /tmp/v/lftools
# Parameters:
#     jenkins_silos:  Space separated list of Jenkins silos to push global-vars
#                     configuration to. (default: jenkins)
echo "---> jenkins-configure-global-vars.sh"

GROOVY_SCRIPT_FILE="jjb/global-jjb/jenkins-admin/set_global_properties.groovy"

# shellcheck source=/tmp/v/lftools/bin/activate disable=SC1091
source "/tmp/v/lftools/bin/activate"
silos="${jenkins_silos:-jenkins}"

set -eu -o pipefail

for silo in $silos; do
    set +x  # Ensure that no other scripts add `set -x` and print passwords
    echo "Configuring $silo"

    JENKINS_URL=$(crudini --get "$HOME"/.config/jenkins_jobs/jenkins_jobs.ini "$silo" url)
    JENKINS_USER=$(crudini --get "$HOME"/.config/jenkins_jobs/jenkins_jobs.ini "$silo" user)
    JENKINS_PASSWORD=$(crudini --get "$HOME"/.config/jenkins_jobs/jenkins_jobs.ini "$silo" password)
    export JENKINS_URL
    export JENKINS_USER
    export JENKINS_PASSWORD

    global_vars="$WORKSPACE/jenkins-config/global-vars-$silo.sh"

    if [ ! -f "$global_vars" ]; then
        echo "ERROR: Configuration file $global_vars not found."
        exit 1
    fi

    mapfile -t vars < <(cat $global_vars)

    rm -f insert.txt
    for var in "${vars[@]}"; do
        # Ignore comments and blank lines
        if [[ $var == '#'* ]] || [ -z "$var" ]; then
            continue
        fi

        key=$(echo $var | cut -d\= -f1)
        value=$(echo $var | cut -d\= -f2)
        echo "    '$key': '$value'," >> insert.txt
    done

    # Insert variables and remove first occurrence of JENKINS_URL variable
    echo "-----> script.groovy"
    sed "/'JENKINS_URL'/r insert.txt" "$GROOVY_SCRIPT_FILE" \
        | sed "0,/'JENKINS_URL'/{/'JENKINS_URL'/d}" \
        > script.groovy
    cat script.groovy

    lftools jenkins groovy script.groovy
done