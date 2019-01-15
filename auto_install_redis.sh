#!/bin/bash
red_echo ()  { echo; echo; echo -e  "\033[031;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; exit 1;}
yellow_echo ()   { echo; echo; echo -e "\033[033;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }
green_echo ()  { echo; echo; echo -e  "\033[032;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }

install_dependences () {
    yum clean all
    yum makecache
    yum -y install gcc make tcl
    [[ $? -eq 0 ]] && green_echo "\tINFO\t gcc make tcl 等依赖安装完毕！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t YUM安装依赖出错，依赖未正确安装，返回错误码 = $? \n"
}


_init_dirtree () {
    local paths=($INSTALL_PATH $DATA_FILE_PATH)

    for path in ${paths[@]}; do
        green_echo $path
        mkdir -p $path
        chmod -R 755  $path
    done
    mkdir /tmp/redis_temp
    [[ $? -eq 0 ]] && green_echo "\tINFO\t ${paths[@]}等目录创建完成！"
}

_chmod_dirtree () {
    local paths=($INSTALL_PATH $DATA_FILE_PATH)

    for path in ${paths[@]}; do
        chmod -R 755  $path
    done
    [[ $? -eq 0 ]] && green_echo "\tINFO\t ${paths[@]}等目录属性修改完成！"
}

_render_tpl () {

    sed -i "s#^port 6379#port $PORT#;
            s#^timeout 0#timeout $TIME_OUT#;
            s#^daemonize no#daemonize yes#;
            s#^pidfile /var/run/redis_6379.pid#pidfile $PID_FILE#;
            s#^dir ./#dir $DATA_FILE_PATH#;
            "  $INSTALL_PATH/etc/redis.conf 
}

get_install_pkgs () {
    local pkgs_name=$1
    if [[ $SKIP_DOWNLOAD_FILES == 0 ]]; then 
        yellow_echo "\tSKIP\t 跳过下载安装文件$pkgs_name，无需下载！ \n"
    else
         yum -y install subversion

        if [[ -f $RESP_PATH/$pkgs_name ]]; then
            green_echo "\tINFO\t 安装文件已存在，无需下载！ \n"
        else
            svn co --username=${SVN_USER} --password=${SVN_PASSWD}  --force --no-auth-cache \
                  --depth=empty  ${SVN_ADDRESS}  ${RESP_PATH}
            cd ${RESP_PATH} && svn up --username=${SVN_USER} --password=${SVN_PASSWD}  --force --no-auth-cache $pkgs_name
        fi
        [[ $? -eq 0 ]] && green_echo "\tINFO\t $pkgs_name安装文件已经下载完毕！"
        [[ $? -ne 0 ]] && red_echo "\tERROR\t SVN出现问题，$pkgs_name安装文件未正确下载，返回错误码 = $? \n"   
    fi

}

make_source_code () {

    _init_dirtree

    cd $RESP_PATH && tar zxf $REDIS_PKGS -C /tmp/redis_temp
    local redis_path=$(echo $REDIS_PKGS | cut -d . -f 1-3)
    cd /tmp/redis_temp/$redis_path || red_echo "\tERROR\t $redis_path目录不存在，返回错误码 = $? \n"

    make && make test

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Redis编译完成，即将开始安装Redis！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t Redis编译失败，程序终止，返回错误码 = $? \n"

    make install PREFIX=$INSTALL_PATH  test

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Redis安装完成，即将开始配置Redis！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t Redis安装失败，程序终止，返回错误码 = $? \n"
}

add_profile () {

    grep "^PATH=\$PATH:$INSTALL_PATH/bin$"  /etc/profile > /dev/null 2>&1 || echo "PATH=\$PATH:$INSTALL_PATH/bin" >> /etc/profile
    grep '^export PATH$'  /etc/profile > /dev/null 2>&1 || echo "export PATH" >> /etc/profile

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Redis用户环境变量添加完成完成！"
}


init_redis () {

    local redis_path=$(echo $REDIS_PKGS | cut -d . -f 1-3)
    cd /tmp/redis_temp/$redis_path
    mkdir $INSTALL_PATH/etc
    cp redis.conf  $INSTALL_PATH/etc/

    _render_tpl
    _chmod_dirtree

    $INSTALL_PATH/bin/redis-server  $INSTALL_PATH/etc/redis.conf

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Redis启动完成！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t Redis启动失败，程序终止，返回错误码 = $? \n"

    echo  $INSTALL_PATH/bin/redis-server  $INSTALL_PATH/etc/redis.conf  >> /etc/rc.local

    chmod 755 /etc/rc.local

    add_profile

    [[ $? -eq 0 ]] && green_echo "\tSUCCESS\t 现在你可以使用Redis了！"

    rm -rf /tmp/redis_temp
}

_init_params () {

params=$(echo $@ | sed 's\{\\g' | sed 's\}\\g' )

num=$(echo $params |grep -o ': ' |wc -l)

old_ifs=$IFS

IFS=','

if [[ "$num" -eq 11 ]]; then
    for param in $params; do
        key=$(echo $param | cut -d ':' -f 1)
        value=$(echo $param | cut -d ':' -f 2-)
        value=${value#* }
        case $key in
            svn_user) SVN_USER=$value ;;

            svn_passwd) SVN_PASSWD=$value ;;

            svn_address) SVN_ADDRESS=$value ;;
        
            redis_pkgs) REDIS_PKGS=$value ;;
            
            resp_dir) RESP_PATH=${value%*/} ;;

            install_path) INSTALL_PATH=${value%*/} ;;

            data_file_path) DATA_FILE_PATH=${value%*/} ;;

            port) PORT=$value ;;

            time_out) TIME_OUT=$value ;;

            pid_file) PID_FILE=$value ;;

            skip_download_files) SKIP_DOWNLOAD_FILES=$value ;;

            *) red_echo "\tERROR\t 接收到未知参数key = $key\n" ;;
        esac
    done    
else
    red_echo "\tERROR\t参数个数错误, 当前参数为 = $@！\n"
fi

IFS=$old_ifs
}

_init_params $@

install_dependences

get_install_pkgs $REDIS_PKGS

make_source_code

init_redis


# '{'svn_user': 'mashaokui','svn_passwd': 'fcy3I4yB','svn_address': 'svn://192.168.50.221/soft_2018','redis_pkgs': 'redis-3.2.9.tar.gz','resp_dir': '/tmp/resp','install_path': '/usr/local/redis','data_file_path': '/usr/local/redis/data','port': '6379','pid_file': '/var/run/redis.pid','time_out': '300','skip_download_files': '1'}'
