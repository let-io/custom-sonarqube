#!/usr/bin/env bash

set -e

. ./bin/functions.bash

add_condition_to_quality_gate()
{
    gate_id=$1
    metric_key=$2
    metric_operator=$3
    metric_errors=$4

    info  "adding S quality gate condition: ${metric_key} ${metric_operator} ${metric_errors}."

    threshold=()
    if [ "${metric_errors}" != "none" ]
    then
        threshold=("--data-urlencode" "error=${metric_errors}")
    fi

    res=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                --data-urlencode "gateId=${gate_id}" \
                --data-urlencode "metric=${metric_key}" \
                --data-urlencode "op=${metric_operator}" \
                "${threshold[@]}" \
                "${SONARQUBE_URL}/api/qualitygates/create_condition")
    if [ "$(echo "${res}" | jq '(.errors | length)')" == "0" ]
    then
        info  "metric ${metric_key} condition successfully added."
    else
        info "Failed to add ${metric_key} condition" "$(echo "${res}" | jq '.errors[].msg')"
    fi
}

create_quality_gate()
{

	gate_name=$1
    
    info  "creating quality gate."
	#Modify the quality gate name() as required
    res=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                --data-urlencode "name=${gate_name}" \
                "${SONARQUBE_URL}/api/qualitygates/create")
    if [ "$(echo "${res}" | jq '(.errors | length)')" == "0" ]
    then
        info  "successfully created quality gate... now configuring it."
    else
        info "Failed to create quality gate" "$(echo "${res}" | jq '.errors[].msg')"
    fi

    # Retrieve quality gates ID
    info  "retrieving quality gate ID."
    res=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                --data-urlencode "name=${gate_name}" \
                "${SONARQUBE_URL}/api/qualitygates/show")
    if [ "$(echo "${res}" | jq '(.errors | length)')" == "0" ]
    then
        GATEID="$(echo "${res}" |  jq -r '.id')"
        info  "successfully retrieved quality gate ID (ID=$GATEID)."
    else
        error "Failed to reach quality gate ID" "$(echo "${res}" | jq '.errors[].msg')"
    fi

    # Adding all conditions of the JSON file
    info "adding all conditions of ${gate_name}.json to the gate."
    len=$(jq '(.conditions | length)' conf/${gate_name}.json)
    custom_quality_gate=$(jq '(.conditions)' conf/${gate_name}.json)
    for i in $(seq 0 $((len - 1)))
    do
        metric=$(echo "$custom_quality_gate" | jq -r '(.['"$i"'].metric)')
        op=$(echo "$custom_quality_gate" | jq -r '(.['"$i"'].op)')
        error=$(echo "$custom_quality_gate" | jq -r '(.['"$i"'].error)')
        add_condition_to_quality_gate "$GATEID" "$metric" "$op" "$error"
    done
}

add_exclusions()
{
    res=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                --data-urlencode "key="sonar.global.exclusions"" \
                --data-urlencode "values="**/resources/**"" \
                --data-urlencode "values="**/.mvn/**"" \
                --data-urlencode "values="**/*Stub.java"" \
                --data-urlencode "values="**/test/resources/**"" \
                "${SONARQUBE_URL}/api/settings/set")

    res2=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
                --data-urlencode "key="sonar.coverage.exclusions"" \
                --data-urlencode "values="**/models/**/*"" \
                --data-urlencode "values="**/config/**/*"" \
                --data-urlencode "values="**/clients/**/*"" \
                --data-urlencode "values="**/test/**/*"" \
                --data-urlencode "values="**/resources/**/*"" \
                --data-urlencode "values="**/constants/**/*"" \
                --data-urlencode "values="**/*Exception.java"" \
                --data-urlencode "values="**/*DTO.java"" \
                --data-urlencode "values="**Application.java"" \
                --data-urlencode "values="**Enum.java"" \
                --data-urlencode "values="src/main.ts"" \
                --data-urlencode "values="**/*.spec.ts"" \
                --data-urlencode "values="**/*.test.ts"" \
                --data-urlencode "values="**/*.spec.js"" \
                --data-urlencode "values="**/*.test.js"" \
                "${SONARQUBE_URL}/api/settings/set")
    
}




# End of functions definition
# ============================================================================ #
# Start script

# Wait for SonarQube to be up
wait_sonarqube_up

# Make sure the database has not already been populated
status=$(curl -i -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
            "${SONARQUBE_URL}/api/qualitygates/list" \
    | sed -n -r -e 's/^HTTP\/.+ ([0-9]+)/\1/p')
status=${status:0:3} # remove \n
nb_qg=$(curl -su "admin:$SONARQUBE_ADMIN_PASSWORD" \
            "${SONARQUBE_URL}/api/qualitygates/list" \
    | jq '.qualitygates | map(select(.name == "S-QG")) | length')
if [ "$status" -eq 200 ] && [ "$nb_qg" -eq 1 ]
then
    # admin password has already been changed and the custom QG has already been added
    info  "The database has already been filled with custom configuration. Not adding anything."
else
    # Change admin password
    curl -su "admin:admin" \
        --data-urlencode "login=admin" \
        --data-urlencode "password=$SONARQUBE_ADMIN_PASSWORD" \
        --data-urlencode "previousPassword=admin" \
        "$SONARQUBE_URL/api/users/change_password"
    info  "admin password changed."

    # Add QG
    quality_gates=("S-QG" "M-QG" "L-QG")
    for gate in ${quality_gates[@]}; do
        create_quality_gate "$gate"
    done
    add_exclusions
fi

# Tell the user, we are ready
info "ready!"

exit 0