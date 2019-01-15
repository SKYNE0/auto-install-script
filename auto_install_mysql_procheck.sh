#!/bin/bash

check_user () {
    grep mysql /etc/group  > /dev/null 2>&1  
    if [[ $? -eq 0 ]]; then
        $user='True'
    else
        $user='False'
    fi
}

check_install_path () {

    if [[ -f "$INSTALL_PATH" ]]; then
        $install_path='True'
    else
        $install_path='False'
    fi
}

check_data_path () {

    if [[ -f "$DATA_FILE_PATH" ]]; then
        $data_path='True'
    else
        $data_path='False'
    fi
}

check_my_cnf () {
    if [[ -f /etc/my.cnf ]]; then
        $my_conf='True'
    else
        $my_conf='False'
    fi
}

check_yum () {
    yum info gcc gcc-c++ ncurses-devel perl make cmake autoconf > /dev/null 2>&1  
    if [[ $? -eq 0 ]]; then
        $yum='True'
    else
        $yum='False'
    fi
}


params=$(echo $@ | sed 's\{\\g' | sed 's\}\\g' )

num=$(echo $params |grep -o ': ' |wc -l)

old_ifs=$IFS

IFS=','

if [[ "$num" -eq 10 ]]; then
    for param in $params; do
        key=$(echo $param | cut -d ':' -f 1)
        value=$(echo $param | cut -d ':' -f 2-)
        value=${value#* }
        case $key in
            svn_user) SVN_USER=$value ;;

            svn_passwd) SVN_PASSWD=$value ;;

            svn_address) SVN_ADDRESS=$value ;;
        
            mysql_pkgs) MYSQL_PKGS=$value ;;
            
            resp_dir) RESP_PATH=${value%*/} ;;

            install_path) INSTALL_PATH=${value%*/} ;;

            data_file_path) DATA_FILE_PATH=${value%*/} ;;

            port) PORT=$value ;;

            socket_path) SOCKET_PATH=$value ;;

            root_passwd) ROOT_PASSWD=$value ;;

            *) red_echo "\tERROR\t 接收到未知参数key = $key\n"
                exit 1
                ;;
        esac
    done    
else
    red_echo "\tERROR\t参数个数错误, 当前参数为 = $@！\n"
    exit 1
fi

IFS=$old_ifs