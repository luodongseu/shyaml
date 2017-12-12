#!/usr/bin/env bash
#
# This script is a yaml file parser
#
# This script support follow operation:
#   1. Get whole yaml object with format output (we say Shyl object)
#   2. Query some key's value
#   3. Write a Shyl object to file
#   4. Change some key's value of a Shyl object
#
# @Copyright: luodongseu.luo@huawei.com
# @Date: 2017/12/11
#


# Parameters need
# Operation name
typeset opera_name=$1

# Definition of Shyl object
# This is a array struct object, which contains elements format by k.k.k:::v
declare -a _SHYL
declare -a _keys=()


# Error function
function errorParseYaml
{
    echo "Yaml parse failed!"
    exit 1
}
function errorEmptyFile
{
    echo "Yaml is empty!"
    exit 2
}
function errorKeyNotFound
{
    echo "Yaml not contains the key!"
    exit 3
}
function errorShylObject
{
    echo "Invalid Shyl object!"
    exit 4
}

# Use: $1: string
#      $2: split chars
# Return: An array contains two elements
function splitByFirstMatch
{
    local f="$(echo "${1}" | awk -F "${2}" '{print $1}')"
    local s="${1:$((${#f} + ${#2}))}"
    echo "${f}" "${s}"
}

# Use: $1: space num
#      $2: added key
function combineKeyPrefix
{
    local _pk=""
    if [ ${#_keys[*]} -ne 0 ];then
        _pk="${_keys[0]}"
        for ((i=1;i<$((${1}/2));i++))
        do
            _pk="${_pk}.${_keys[${i}]}"
        done
        if [ "X" != "X${2}" ];then
            echo "${_pk}.${2}"
        else
            echo "${_pk}"
        fi
    else
        echo "${2}"
    fi

}

# Use: $1: space num
function validateSpaceNum
{
    if [ $((${1} % 2)) -ne 0 ];then
        errorParseYaml
    fi
}

# Use: $1: line string
function resetKeys
{
    local space_start=$(echo "${1}" | grep '^[ ]')
    if [ "X" == "X${space_start}" ];then
        _keys=()
    fi
}

# Use: $1: space num
#      $2: added key
function refreshKeys
{
    local new_keys=()
    for ((i=0;i<${1}/2;i++))
    do
        new_keys[${i}]="${_keys[${i}]}"
    done
    new_keys[${#new_keys[*]}]="${2}"
    _keys=(${new_keys[*]})
}

# Use: $1: file name
#      $2: line num
function getAvailableLine
{
    echo "$(cat ${1} | tr -d '\r' | sed -n ${2}'p' | awk -F '#' '{print $1}')"
}

# Use: $1: line string
function getStartSpaceNum
{
    echo $(echo "${1}" | grep -o '^[ ]*' | grep -o '[ ]' | wc -l)
}

# Print shyl object by line to line
function printShyl
{
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        echo "${_SHYL[i]}"
    done
}

# Load a yaml file to shyl object
# Use: $1: filepath
function loadYaml2Shyl
{
    # Total line number of file
    local file_size=$(cat $1 | wc -l)
    local cursor=1
    while [ ${cursor} -le $((file_size+1)) ]
    do
        local line_str=$(getAvailableLine ${1} ${cursor})
        local blank_line=$(echo "${line_str}" | grep '[^ ]')
        if [ "X" == "X${blank_line}" ];then
            ((cursor += 1))
            continue
        fi

        resetKeys "${line_str}"

        local space_num=$(getStartSpaceNum "${line_str}")
        validateSpaceNum ${space_num}

        # Array handle
        local arr=$(echo ${line_str} | grep '^-')
        if [ "X" != "X${arr}" ];then
            # This is an array element
            local p_k="${_keys[$((${space_num} / 2))]}"
            local last_index=$(echo "${p_k}" | grep -o '\[\([0-9]*\)\]' | sed -e 's/\[\|\]//g')
            if [ "X" != "X${last_index}" ];then
                _keys[$((${space_num} / 2))]="${p_k//${last_index}/$((${last_index} + 1))}"
            else
                _keys[$((${space_num} / 2))]="${p_k}[0]"
            fi
            line_str="${line_str//-/ }"
            space_num=$((${space_num} + 2))
        fi

        local array_simple_value=$(echo ${line_str} | grep -v '^{' | grep ':')
        if [ "X" == "X${array_simple_value}" ];then
             local value=$(echo ${line_str})
             _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} ""):\'${value//\"/\\\"}\'"
        else
            local key="$(echo ${line_str} | awk -F ':' '{print $1}')"
            local value="$(echo ${line_str} | sed "s|^${key}:[ ]*||")"
            if [ "X" != "X${value}" ];then
                _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} "${key}"):\'${value}\'"
            else
                # Predict next line to check current value is null or current key is a parent key
                if [ $((cursor + 1)) -le ${file_size} ];then
                    local next_line="$(getAvailableLine ${1} $((cursor+1)))"
                    local arr=$(echo ${next_line} | grep '^-')
                    if [ "X" == "X${arr}" ];then
                        local next_line_space_num=$(getStartSpaceNum "${next_line}")
                        if [ ${next_line_space_num} -ne $((space_num + 2)) ];then
                            if [ ${next_line_space_num} -gt $((space_num + 2)) ];then
                                errorParseYaml
                            else
                                _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} "${key}"):"
                            fi
                        fi
                    fi
                fi
            fi
            refreshKeys ${space_num} "${key}"
        fi
        ((cursor += 1))
    done
}

# Prepare to load yaml, error exit will happen if no content in yaml file
function preLoadYaml
{
    # Check Shyl object values not empty first time
    # If Shyl object is empty, load yaml firstly
    if [ ${#_SHYL[*]} -eq 0 ];then
        # loadYaml2Shyl ${1}

        # Receive from stdin
        local i=0
        while read -t 30 s
        do
            _SHYL[${i}]="${s}"
            ((i++))
        done
    fi
    # Check Shyl object values not empty second time
    # If Shyl object is empty, error abort
    if [ ${#_SHYL[*]} -eq 0 ];then
        errorEmptyFile
    fi
}

# Use: $1: file name
#      $2: key depth
#      $3: is not first in array
#      $4: current keys
#      $5:1 value
function writeLineToFile
{
    local _new_line=""
    for ((j=0;j<$((${2}-1));j++))
    do
        _new_line="${_new_line}  ";
    done
    local cur_keys=($(echo ${4}))
    local _key="${cur_keys[${2}]}"

    local arr_c_index=$(echo "${_key}" | grep -o '\[\([0-9]*\)\]' | sed -e 's/\[\|\]//g')
    if [ "X" != "X${arr_c_index}" ];then
        _key=${_key//\[${arr_c_index}\]/}
    fi

    if [ ${2} -gt 0 ];then
        local arr_p_index=$(echo "${cur_keys[$((${2}-1))]}" | grep -o '\[\([0-9]*\)\]' | sed -e 's/\[\|\]//g')
        if [ "X" != "X${arr_p_index}" -a "X" == "X${3}" ];then
            _new_line="${_new_line}- ";
        else
            _new_line="${_new_line}  ";
        fi
    fi

    if [ ${2} -eq $((${#cur_keys[*]} - 1)) ];then
        echo "${_new_line}${_key}: ${@:5}" >> ${1}
    else
        echo "${3}"
        echo "${_new_line}${_key}: " >> ${1}
    fi
}

# Query a value of yaml by key name
# Use: $1: key name, like: a.b.c
#      $2: file name
function getShylValue
{
    local returned=0
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        local _s=($(splitByFirstMatch "${_SHYL[i]}" ":"))
        if [ "X${_s[0]}" == "X${1}" ];then
            echo ${_s[1]:1}
            returned=1
            break
        fi
    done
    if [ ${returned} -ne 1 ];then
        errorKeyNotFound
    fi
}

# Change value of the yaml key
# Use: $1: key name, like: a.b.c
#      $2: new value
#      $3: file name
# Return: All key-values of yaml
function setShylValue
{
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        local _s=($(splitByFirstMatch "${_SHYL[${i}]}" ":"))
        if [ "X${_s[0]}" == "X${1}" ];then
            _SHYL[i]="${_s[0]}:${2}"
            break
        fi
    done
}

# Save a shyl object to file
# Use: $1: file name
#      $read: Shyl object
function saveShyl2Yaml
{
    > ${1}
    _keys=()
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        local _s=($(splitByFirstMatch "${_SHYL[${i}]}" ":"))
        local _k=($(echo "${_s[0]//./ }"))

        local _p_keys="${_k[*]:0:$((${#_k[*]}-1))}"
        local is_not_first=""
        if [ ${#_SHYL[*]} -ge ${i} -a ${i} -gt 0 ];then
            if [[ "${_SHYL[$((${i}-1))]}" =~ "${_p_keys// /.}" ]];then
                is_not_first="1"
            fi
        fi
        if [ ${#_k[*]} -eq 0 ];then
            errorShylObject
        fi
        if [ ${#_keys[*]} -eq 0 -o "${_k[0]}" != "${_keys[0]}" ];then
            for ((ii=0;ii<${#_k[*]};ii++))
            do
                writeLineToFile ${1} ${ii} "${is_not_first}" "${_k[*]}" "${_s[@]:1}"
            done
        else
            # Additional
            local _b=0
            for ((ii=0;ii<${#_k[*]};ii++))
            do
               if [ ${_b} -eq 1 -o "${_k[${ii}]//\[[0-9]*\]/}" != "${_keys[${ii}]//\[[0-9]*\]/}" ];then
                    _b=1
                    writeLineToFile ${1} ${ii} "${is_not_first}" "${_k[*]}" "${_s[@]:1}"
               fi
            done
        fi
        _keys=(${_k[*]})
    done
}

case "${opera_name}" in
    loadYaml2Shyl)
    # Get whole yaml object with format output (we say Shyl object)
    # Use: load demo.yaml
    # Return: Shyl object
    loadYaml2Shyl "${2}"
    printShyl
    ;;
    getShylValue)
    # Query some key's value of a Shyl object
    # Use: getValue key1.key2.key3 < Shyl
    # Return: A string
    preLoadYaml
    getShylValue "${2}"
    ;;
    getValueByYaml)
    # Query some key's value of a Shyl object
    # Use: getValue key1.key2.key3 demo.yaml
    # Return: A string
    loadYaml2Shyl "${3}"
    getShylValue "${2}"
    ;;
    setShylValue)
    # Change some key's value of a Shyl object
    # Use: setValue key1.key2.key3 value1 < Shyl
    preLoadYaml
    setShylValue "${2}" "${3}"
    printShyl
    ;;
    saveShyl2Yaml)
    # Write a Shyl object to file
    # Use: save demo2.yaml < Shyl1
    preLoadYaml
    saveShyl2Yaml "${2}"
    ;;
esac