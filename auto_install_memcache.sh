#!/bin/bash
red_echo ()  { echo; echo; echo -e  "\033[031;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; exit 1;}
yellow_echo ()   { echo; echo; echo -e "\033[033;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }
green_echo ()  { echo; echo; echo -e  "\033[032;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }


_install_libevent () {
    local libevent_name='libevent-2.0.21-stable.tar.gz'
    get_install_pkgs  $libevent_name

    cd $RESP_PATH
    tar zxf $libevent_name
    cd $(echo $libevent_name | cut -d . -f 1-3) || red_echo "\tERROR\t $libevent_name目录不存在，返回错误码 = $? \n"
    ./configure --prefix=/usr/local/libevent
    make && make install

    [[ $? -eq 0 ]] || red_echo "\tERROR\t libevent编译安装出错，返回错误码 = $? \n"
    green_echo "\tINFO\t libevent编译安装完成！" 

}

install_dependences () {
    yum -y install  autoconf automake libtool gcc gcc-c++ make tcl

    yum info libevent-devel
    if [[ $? -eq 0 ]]; then
        yum -y install libevent-devel
    else
        _install_libevent
    fi

    [[ $? -eq 0 ]] || red_echo "\tERROR\t YUM安装依赖出错，依赖未正确安装，返回错误码 = $? \n"
    green_echo "\tINFO\t gcc make tcl 等依赖安装完毕！" 
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

_add_profile () {

    grep "^PATH=\$PATH:$INSTALL_PATH/bin$"  /etc/profile > /dev/null 2>&1 || echo "PATH=\$PATH:$INSTALL_PATH/bin" >> /etc/profile
    grep '^export PATH$'  /etc/profile > /dev/null 2>&1 || echo "export PATH" >> /etc/profile

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Memcached用户环境变量添加完成完成！"
}


install_memcache () {

    local memcache_path=$(echo $MEMCACHE_PKGS | cut -d . -f 1-3)
    cd $RESP_PATH
    tar zxf $MEMCACHE_PKGS
    cd $memcache_path || red_echo "\tERROR\t $memcache_path目录不存在，返回错误码 = $? \n"

    green_echo "\tINFO\t 开始编译安装Memcached！" 
    ./configure --prefix=$INSTALL_PATH --with-libevent=/usr/local/libevent
    make && make install

    [[ $? -eq 0 ]] || red_echo "\tERROR\t Memcached编译安装出错，返回错误码 = $? \n"
    green_echo "\tINFO\t Memcached编译安装完成！" 

    _add_profile

    source /etc/profile

    memcached memcached -d -m 2048 -l 127.0.0.1 -p 11211 -u root -c 1024 –P /var/memcached/memcached.pid

    [[ $? -eq 0 ]] || red_echo "\tERROR\t Memcached启动失败，程序终止，返回错误码 = $? \n"
    green_echo "\tSUCCESS\t Memcached启动完成！"
}

_init_params () {

params=$(echo $@ | sed 's\{\\g' | sed 's\}\\g' )

num=$(echo $params |grep -o ': ' |wc -l)

old_ifs=$IFS

IFS=','

if [[ "$num" -eq 7 ]]; then
    for param in $params; do
        key=$(echo $param | cut -d ':' -f 1)
        value=$(echo $param | cut -d ':' -f 2-)
        value=${value#* }
        case $key in
            svn_user) SVN_USER=$value ;;

            svn_passwd) SVN_PASSWD=$value ;;

            svn_address) SVN_ADDRESS=$value ;;
        
            memcache_pkgs) MEMCACHE_PKGS=$value ;;
            
            resp_dir) RESP_PATH=${value%*/} ;;

            install_path) INSTALL_PATH=${value%*/} ;;

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
sleep 3
install_dependences 
sleep 3
get_install_pkgs $MEMCACHE_PKGS
sleep 3
install_memcache


# '{'svn_user': 'mashaokui','svn_passwd': 'fcy3I4yB','svn_address': 'svn://192.168.50.221/soft_2018','memcache_pkgs': 'memcached-1.5.5.tar.gz','resp_dir': '/tmp/resp','install_path': '/usr/local/memcached','skip_download_files': '1'}'
