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
# @Copyright: luodongseu
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
    >&2 echo "Yaml parse failed!"
    exit 1
}
function errorEmptyFile
{
    >&2 echo "Yaml is empty!"
    exit 2
}
function errorKeyNotFound
{
    >&2 echo "Yaml not contains the key!"
    exit 3
}
function errorShylObject
{
    >&2 echo "Invalid Shyl object!"
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

# Combine key(k1 k2 k3) array to k1.k2.k3 joined by '.' symbol
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
    local arr_start=$(echo "${1}" | grep '^-')
    if [ "X" == "X${space_start}" -a "X" == "X${arr_start}" ];then
        # Rest _keys's value condition(and):
        #   (1) current key is start with no space
        #   (2) current key is not start with '-' symbol
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

# Use: $1: key string, like 'k1[1]'
function getKeyArrayIndex
{
    echo $(echo "${1}" | grep -o '\[\([0-9]*\)\]' | sed -e 's/\[\|\]//g')
}

# Print shyl object by line to line
function printShyl
{
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        echo "${_SHYL[i]}"
    done
}

# Prepare to load yaml, error exit will happen if no content in yaml file
function preLoadYaml
{
    # Check Shyl object values not empty first time
    # If Shyl object is empty, load yaml firstly
    if [ ${#_SHYL[*]} -eq 0 ];then
        # loadYaml2Shyl ${1}

        # Receive from stdin, then user can use pipe to give data
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
#      $3: array type (0: not an array or first in array) (1: not first in an array) (2: simple array)
#      $4: current keys
#      $5:1 value
function writeLineToFile
{
    local cur_keys=($(echo ${4}))
    local _key="${cur_keys[${2}]}"
    local _new_line=""
    for ((j=0;j<$((${2}-1));j++))
    do
        # Add blank spaces
        # Last space must be handled specially
        _new_line="${_new_line}  ";
    done

    local arr_c_index=$(getKeyArrayIndex "${_key}")
    if [ "X" != "X${arr_c_index}" ];then
        # Remove key index
        _key=${_key//\[${arr_c_index}\]/}
    fi

    if [ ${2} -gt 0 ];then
        # Last blank space
        local arr_p_index=$(getKeyArrayIndex "${cur_keys[$((${2}-1))]}")
        if [ "X" != "X${arr_p_index}" -a 0 -eq ${3} ];then
            # Complex array
            _new_line="${_new_line}- ";
        else
            _new_line="${_new_line}  ";
        fi
    fi

    if [ ${2} -eq $((${#cur_keys[*]} - 1)) ];then
        if [ "X" != "X${arr_c_index}" ];then
            # Simple array
            if [ "X0" == "X${arr_c_index}" ];then
                # Write key name when index is 0
                echo "${_new_line}${_key}: " >> ${1}
            fi
            echo "${_new_line}- ${@:5}" >> ${1}
        else
            echo "${_new_line}${_key}: ${@:5}" >> ${1}
        fi
    else
        if [ "X" == "X${arr_c_index}" -o "X0" == "X${arr_c_index}" ];then
            echo "${_new_line}${_key}: " >> ${1}
        fi
    fi
}

# Use: $1: key depth
#      $2: current keys
function checkElementIsTheFirstInArray
{
    # Check array type
    # If last key-value contains current key's parent key string, the array type is 1, which
    #   present current key is not first element of current key's parent array
    local _p_keys="${@:2:$((${1}))}"
    if [ ${#_SHYL[*]} -ge ${i} -a ${i} -gt 0 ];then
        if [[ "${_SHYL[$((${i}-1))]}" =~ "${_p_keys// /.}" ]];then
            echo "1"
        else
            echo "0"
        fi
    fi
}

####################################################################################################
# Main functions definition
####################################################################################################

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
        if [ "X" == "X$(echo "${line_str}" | grep '[^ ]')" ];then
            # Blank line filter
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
            local last_index=$(getKeyArrayIndex "${p_k}")
            if [ "X" != "X${last_index}" ];then
                _keys[$((${space_num} / 2))]="${p_k//${last_index}/$((${last_index} + 1))}"
            else
                _keys[$((${space_num} / 2))]="${p_k}[0]"
            fi
            line_str="$(echo ${line_str} | sed 's/^-//')"
            space_num=$((${space_num} + 2))
        fi

        # A string within {} symbols is a simple value of yaml
        # A key-value pair must contains ':' symbol
        local simple_value=$(echo ${line_str} | grep -v '^{' | grep ':')
        if [ "X" == "X${simple_value}" ];then
             local value=$(echo ${line_str})
             _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} ""):${value}"
        else
            local key="$(echo ${line_str} | awk -F ':' '{print $1}')"
            local value="$(echo ${line_str} | sed "s|^${key}:[ ]*||")"
            if [ "X" != "X${value}" ];then
                _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} "${key}"):${value}"
            else
                # Predict next line to check current value is null or current key is a parent key
                if [ $((cursor + 1)) -le ${file_size} ];then
                    local next_line="$(getAvailableLine ${1} $((cursor+1)))"
                    local next_line_space_num=$(getStartSpaceNum "${next_line}")
                    local arr=$(echo ${next_line} | grep '^-')

                    if [ ${next_line_space_num} -gt $((space_num + 2)) ] || [ "X" != "X${arr}" -a ${next_line_space_num} -gt ${space_num} ] ;then
                        # Yaml format error situation:
                        # Next line space num must not greater than ${space_num} num + 2
                        #   or: when next line start with '-' (as an array element) and next line space num is greater than ${space_num}
                        errorParseYaml
                    fi

                    if [ ${next_line_space_num} -ne $((space_num + 2)) -a ${next_line_space_num} -ne ${space_num} ] || [ ${next_line_space_num} -eq ${space_num} -a "X" == "X${arr}" ];then
                        # 2 condition(or) should be consider to prove current key's value is empty
                        #   (1) Next line's space num is not equal ${space_num} + 2 and not equal ${space_num}
                        #   (2) Next line's space num is equal ${space_num} but next line string is not start with '-' (present array)
                        _SHYL[${#_SHYL[*]}]="$(combineKeyPrefix ${space_num} "${key}"):"
                    fi
                fi
            fi
            refreshKeys ${space_num} "${key}"
        fi
        ((cursor += 1))
    done
}

# Query a value of yaml by key name
# Use: $1: key name, like: a.b.c
#      $2: file name
function getShylValue
{
    # 'returned' is a flag for check if found target key in _SHYL array
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
            # New value saved into _SHYL array
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
    # _keys is a collection to save the last keys of SHYL object array
    _keys=()
    for ((i=0;i<${#_SHYL[*]};i++))
    do
        local _s=($(splitByFirstMatch "${_SHYL[${i}]}" ":"))
        local _k=($(echo "${_s[0]//./ }"))
        if [ ${#_k[*]} -eq 0 ];then
            errorShylObject
        fi

        # 2 condition(and) must be considered:
        #   (1) Current key is a new structure: All key words will be wrote to file with special format
        #   (2) Current key is not a new structure: Only new key words will be wrote to fle with special format
        if [ ${#_keys[*]} -eq 0 -o "${_k[0]}" != "${_keys[0]}" ];then
            for ((ii=0;ii<${#_k[*]};ii++))
            do
                writeLineToFile ${1} ${ii} 0 "${_k[*]}" "${_s[@]:1}"
            done
        else
            # _b is a flag for if found different key word from _keys
            local _b=0
            for ((ii=0;ii<${#_k[*]};ii++))
            do
               if [ ${_b} -eq 1 -o "${_k[${ii}]}" != "${_keys[${ii}]}" ];then
                    # If found new key word, all left key words must be wrote to file
                    _b=1
                    local array_type=$(checkElementIsTheFirstInArray ${ii} ${_k[*]})
                    writeLineToFile ${1} ${ii} ${array_type} "${_k[*]}" "${_s[@]:1}"
               fi
            done
        fi
        # Set _keys to current key array
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
