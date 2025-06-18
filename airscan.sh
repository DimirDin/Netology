#!/bin/bash

# Проверка прав root
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root. Use sudo." >&2
    exit 1
fi

# Проверка минимального количества аргументов
if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <PREFIX> <INTERFACE> [SUBNET] [HOST]" >&2
    echo "Example: $0 192.168 eth0 10 20" >&2
    exit 1
fi

PREFIX="$1"
INTERFACE="$2"
SUBNET_ARG="$3"
HOST_ARG="$4"

# Регулярные выражения для валидации
REGEX_IP_OCTET="^([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5])$"
REGEX_PREFIX="^([0-9]{1,3})\.([0-9]{1,3})$"

# Функция проверки и вывода ошибки
validate_arg() {
    local arg_name="$1"
    local arg_value="$2"
    local regex="$3"
    local error_msg="$4"
    
    if [[ ! "$arg_value" =~ $regex ]]; then
        echo "$error_msg" >&2
        exit 1
    fi
}

# Проверка PREFIX (специальная обработка для двух октетов)
if [[ ! "$PREFIX" =~ $REGEX_PREFIX ]]; then
    echo "Invalid PREFIX format. Must be two octets (e.g., 192.168)." >&2
    exit 1
fi

# Проверка каждого октета в PREFIX
IFS='.' read -ra OCTETS <<< "$PREFIX"
for octet in "${OCTETS[@]}"; do
    if [[ ! "$octet" =~ $REGEX_IP_OCTET ]]; then
        echo "Invalid octet value in PREFIX: $octet" >&2
        exit 1
    fi
done

# Проверка SUBNET и HOST
[[ -n "$SUBNET_ARG" ]] && validate_arg "SUBNET" "$SUBNET_ARG" "$REGEX_IP_OCTET" "Invalid SUBNET. Must be 0-255."
[[ -n "$HOST_ARG" ]] && validate_arg "HOST" "$HOST_ARG" "$REGEX_IP_OCTET" "Invalid HOST. Must be 0-255."

# Функция сканирования IP
scan_ip() {
    local ip="$1"
    echo "[*] IP: $ip"
    arping -c 3 -i "$INTERFACE" "$ip" 2>/dev/null
}

# Определение диапазонов сканирования
if [[ -n "$SUBNET_ARG" && -n "$HOST_ARG" ]]; then
    scan_ip "${PREFIX}.${SUBNET_ARG}.${HOST_ARG}"
elif [[ -n "$SUBNET_ARG" ]]; then
    for host in {1..255}; do
        scan_ip "${PREFIX}.${SUBNET_ARG}.${host}"
    done
else
    for subnet in {1..255}; do
        for host in {1..255}; do
            scan_ip "${PREFIX}.${subnet}.${host}"
        done
    done
fi

