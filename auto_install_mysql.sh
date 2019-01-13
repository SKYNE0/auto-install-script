#!/bin/bash
red_echo ()  { echo; echo; echo -e  "\033[031;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; exit 1;}
yellow_echo ()   { echo; echo; echo -e "\033[033;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }
green_echo ()  { echo; echo; echo -e  "\033[032;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }

_add_user_group () {
    local user=$1
    local group=$2

    if ! id $user >/dev/null 2>&1; then
        groupadd $group
        useradd -g  $group -s /bin/false  -M $user
    else
        usermod -s /bin/false $user;
    fi

    green_echo "用户 $user 用户组 $group 已添加。"
}

_init_dirtree () {
    local paths=($INSTALL_PATH $DATA_FILE_PATH $SOCKET_PATH)

    for path in ${paths[@]}; do
        mkdir -p $path
        chown -R mysql:mysql $path
        chmod -R 755  $path
    done
    [[ $? -eq 0 ]] && green_echo "\tINFO\t $paths等目录创建完成！"

    mkdir /tmp/mysql_temp
}

_chmod_dirtree () {
    paths=($INSTALL_PATH $DATA_FILE_PATH $SOCKET_PATH)

    for path in ${paths[@]}; do
        chown -R mysql:mysql $path
        chmod -R 755  $path
    done
    [[ $? -eq 0 ]] && green_echo "\tINFO\t $paths等目录属性修改完成！"
}

_check_cmake_version () {
    local cmake_pkgs_name='cmake-3.0.2.tar.gz'
    local cmake_ver=$(yum list cmake | grep -Eo '\s2\.[0-9]+')
    if [ $cmake_ver == 2.8 ]; then
        green_echo "\tINFO\t Cmake版本高于2.8 \n"
    else
        yellow_echo  "\tINFO\t Cmake版本低于2.8，即将安装Cmake3.0版本！\n"
        rpm -qa | grep cmake | xargs rpm -e --nodeps
        get_install_pkgs $cmake_pkgs_name
        cd $RESP_PATH
        tar xf $cmake_pkgs_name
        cd $(echo $cmake_pkgs_name | cut -d . -f 1-3)
        ./configure
        make
        make install
        [[ $? -eq 0 ]] && green_echo "\tINFO\t Cmake3.0安装成功"
        [[ $? -ne 0 ]] && red_echo "\tERROR\t Cmake3.0安装失败，返回错误码 = $? \n"
    fi
}

_install_boost () {
    local boost_pkgs_name='boost_1_59_0.tar.gz'
    get_install_pkgs $boost_pkgs_name
    mkdir /usr/local/boost
    tar xf $RESP_PATH/$cmake_pkgs_name -C /usr/local/boost
    [[ $? -eq 0 ]] && green_echo "\tINFO\t Boost已经解压完毕"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t Boost安装失败，返回错误码 = $? \n"
}

_render_tpl () {
    cat > $INSTALL_PATH/my.cnf <<EOF
# The following options will be passed to all MySQL clients
[client]
default-character-set = utf8
#password    = your_password
port = 
socket = 

# Here follows entries for some specific programs

# The MySQL server
[mysqld]
character-set-server = utf8
basedir =
datadir =
port = 
socket = 
skip-external-locking
skip-name-resolve
key_buffer_size = 16M
max_allowed_packet = 64M
table_open_cache = 64
sort_buffer_size = 512K
net_buffer_length = 8K
read_buffer_size = 256K
read_rnd_buffer_size = 512K
myisam_sort_buffer_size = 8M
max_connections=1000
event_scheduler=ON
innodb_file_per_table=1
#skip-networking
[mysql]
no-auto-rehash
default-character-set = utf8
# Remove the next comment character if you are not familiar with SQL
#safe-updates
EOF

    sed -i "s#^basedir =.*#basedir = $INSTALL_PATH#;
            s#^datadir =.*#datadir = $DATA_FILE_PATH#;
            s#^port =.*#port = $PORT#;
            s#^socket =.*#socket = $SOCKET_PATH/mysql.sock#;
            "  $INSTALL_PATH/my.cnf
}


install_dependences () {
    rpm -qa | grep mysql | xargs rpm -e --nodeps
    yum clean all
    yum makecache
    yum -y install gcc gcc-c++ ncurses-devel perl make cmake autoconf
    [[ $? -eq 0 ]] && green_echo "\tINFO\t gcc gcc-c++ ncurses-devel perl make等依赖安装完毕！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t YUM安装依赖出错，依赖未正确安装，返回错误码 = $? \n"
    _check_cmake_version
    # _install_boost
}


edit_user_profile () {

    _add_user_group mysql mysql

    _init_dirtree mysql

    grep "PATH=\$PATH:$INSTALL_PATH/bin"  /etc/profile > /dev/null 2>&1 || echo "PATH=\$PATH:$INSTALL_PATH/bin" >> /etc/profile
    grep 'export PATH'  /etc/profile > /dev/null 2>&1 || echo "export PATH" >> /etc/profile

    [[ $? -eq 0 ]] && green_echo "\tINFO\t Mysql用户环境变量等修改完成！"
}

get_install_pkgs() {
    local pkgs_name=$1
    if [[ $SKIP_DOWNLOAD_FILES == 0 ]]; then 
        yellow_echo "\tSKIP\t 跳过下载安装文件$pkgs_name，无需下载！ \n"
    else
         yum -y install subversion

        if [[ -f $RESP_PATH/$MYSQL_PKGS ]]; then
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

cmake_source_code () {

    cd $RESP_PATH && tar zxf $MYSQL_PKGS -C /tmp/mysql_temp
    local mysql_path=$(echo $MYSQL_PKGS | cut -d . -f 1-3)
    cd /tmp/mysql_temp/$mysql_path || red_echo "\tERROR\t $mysql_path目录不存在，返回错误码 = $? \n"
    cmake   -DCMAKE_INSTALL_PREFIX=$INSTALL_PATH \
            -DMYSQL_UNIX_ADDR=$SOCKET_PATH/mysql.sock \
            -DDEFAULT_CHARSET=utf8 \
            -DDEFAULT_COLLATION=utf8_general_ci \
            -DWITH_EXTRA_CHARSETS:STRING=utf8,gbk \
            -DWITH_INNOBASE_STORAGE_ENGINE=1 \
            -DWITH_ARCHIVE_STORAGE_ENGINE=1 \
            -DWITH_BLACKHOLE_STORAGE_ENGINE=1 \
            -DMYSQL_DATADIR=$DATA_FILE_PATH \
            -DMYSQL_TCP_PORT=$PORT \
            -DENABLE_DOWNLOADS=1    

    #-DWITH_BOOST=/usr/local/boost
    [[ $? -eq 0 ]] && green_echo "\tINFO\t Cmake编译完成，即将开始安装MySQL！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t Cmake出错，程序终止，返回错误码 = $? \n"

    make && make install

    [[ $? -eq 0 ]] && green_echo "\tINFO\t MySQL安装完成，即将开始配置MySQL！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t MySQL安装失败，程序终止，返回错误码 = $? \n"
}

init_mysql () {
    _render_tpl

    _chmod_dirtree

    cd $INSTALL_PATH/scripts/

    ./mysql_install_db --user=mysql --datadir=$DATA_FILE_PATH --basedir=$INSTALL_PATH

    [[ $? -eq 0 ]] && green_echo "\tINFO\t MySQL初始化完成！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t MySQL初始化失败，程序终止，返回错误码 = $? \n"

    cp $INSTALL_PATH/support-files/mysql.server /etc/rc.d/init.d/mysqld

    chmod +x /etc/rc.d/init.d/mysqld

    chkconfig --add mysqld
    chkconfig mysql on

    cp -af $INSTALL_PATH/my.cnf  /etc/my.cnf

    /etc/rc.d/init.d/mysqld start  
    [[ $? -eq 0 ]] && green_echo "\tINFO\t MySQL启动完成！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t MySQL启动失败，程序终止，返回错误码 = $? \n"

    $INSTALL_PATH/bin/mysqladmin -u root password "$ROOT_PASSWD"

    [[ $? -eq 0 ]] && green_echo "\tSUCCESS\t 现在你可以使用root用户和$ROOT_PASSWD密码来登录MySQL了！"

    rm -rf /tmp/mysql_temp
}


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
        
            mysql_pkgs) MYSQL_PKGS=$value ;;
            
            resp_dir) RESP_PATH=${value%*/} ;;

            install_path) INSTALL_PATH=${value%*/} ;;

            data_file_path) DATA_FILE_PATH=${value%*/} ;;

            port) PORT=$value ;;

            socket_path) SOCKET_PATH=$value ;;

            root_passwd) ROOT_PASSWD=$value ;;

            skip_download_files) SKIP_DOWNLOAD_FILES=$value ;;

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

install_dependences
sleep 3
get_install_pkgs $MYSQL_PKGS
sleep 3
edit_user_profile
sleep 3
cmake_source_code
sleep 3
init_mysql


# '{'svn_user': 'mashaokui','svn_passwd': 'fcy3I4yB','svn_address': 'svn://192.168.50.221/soft_2018','mysql_pkgs': 'mysql-5.5.62.tar.gz','resp_dir': '/tmp/resp','install_path': '/usr/local/mysql','data_file_path': '/usr/local/mysql/data','port': '3306','socket_path': '/usr/local/mysql','root_passwd': 'mysql.Asd', 'skip_download_files': '0'}'
            


