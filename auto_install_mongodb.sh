#!/bin/bash
red_echo ()  { echo; echo; echo -e  "\033[031;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; exit 1;}
yellow_echo ()   { echo; echo; echo -e "\033[033;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }
green_echo ()  { echo; echo; echo -e  "\033[032;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }


_init_dirtree () {
    local paths=($INSTALL_PATH $DATA_FILE_PATH $LOGS_PATH)

    for path in ${paths[@]}; do
        mkdir -p $path
    done
    touch $LOG_PATH/mongodb.log
    [[ $? -eq 0 ]] && green_echo "\tINFO\t ${paths[@]}等目录创建完成！"
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


_render_tpl () {
    touch $INSTALL_PATH/mongodb/mongodb.conf
    cat > $INSTALL_PATH/mongodb/mongodb.conf <<EOF
#端口号
port = 
#数据目录
dbpath = 
#日志目录
logpath = 
#设置后台运行
fork = true
#日志输出方式
logappend = true
#开启认证
#auth = true
#本地ip
#bind_ip=127.0.0.1
EOF

    sed -i "s#^dbpath =.*#dbpath = $DATA_FILE_PATH#;
            s#^port =.*#port = $PORT#;
            s#^logpath =.*#logpath = $LOGS_PATH/mongodb.log#;
            "  $INSTALL_PATH/mongodb/mongodb.conf
}

edit_profile () {

    _init_dirtree mongodb

    grep "^PATH=\$PATH:$INSTALL_PATH/mongodb/bin$"  /etc/profile > /dev/null 2>&1 || echo "PATH=\$PATH:$INSTALL_PATH/mongodb/bin" >> /etc/profile
    grep '^export PATH$'  /etc/profile > /dev/null 2>&1 || echo "export PATH" >> /etc/profile

    [[ $? -eq 0 ]] && green_echo "\tINFO\t MongoDB环境变量等修改完成！"
}


init_mongodb () {
    cd $RESP_PATH && tar zxf $MONGO_PKGS -C $INSTALL_PATH
    cd $INSTALL_PATH
    local mongo_path=$(echo $MONGO_PKGS | cut -d . -f 1-3)
    if [[ -d  $INSTALL_PATH/mongodb ]]; then
        cp -r $mongo_path/*  mongodb || red_echo "\tERROR\t $mongo_path目录不存在，返回错误码 = $? \n"
    else
        mv $mongo_path  mongodb || red_echo "\tERROR\t $mongo_path目录不存在，返回错误码 = $? \n"
    fi

    _render_tpl

    $INSTALL_PATH/mongodb/bin/mongod --config $INSTALL_PATH/mongodb/mongodb.conf 
    [[ $? -eq 0 ]] && green_echo "\tINFO\t MongoDB 启动完成！"
    [[ $? -ne 0 ]] && red_echo "\tERROR\t MongoDB 启动失败，返回错误码 = $? \n" 

    cat > /etc/init.d/mongodb << EOF
#!/bin/bash
#chkconfig: 2345 80 90
#description: mongodb
start() {
    $INSTALL_PATH/mongodb/bin/mongod --config $INSTALL_PATH/mongodb/mongodb.conf  
}
stop() {
      $INSTALL_PATH/mongodb/bin/mongod --config $INSTALL_PATH/mongodb/mongodb.conf   --shutdown
}
case "\$1" in
  start)
 start
 ;;
  stop)
 stop
 ;;
  status)
  netstat -tulnp|grep mongod
  ;;
  restart)
 stop
 start
 ;;
  *)
 echo $"Usage: \$0 {start|stop|restart}"
 exit 1
esac
EOF
chkconfig --add mongodb
chmod +x  /etc/init.d/mongodb
chkconfig mongodb on
[[ $? -eq 0 ]] && green_echo "\tINFO\t 配置MongoDB管理脚本完成，现在你可以使用service来管理MongoDB了 ！"
}

_init_params () {
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
        
            mongo_pkgs) MONGO_PKGS=$value ;;
            
            resp_dir) RESP_PATH=${value%*/} ;;

            install_path) INSTALL_PATH=${value%*/} ;;

            data_file_path) DATA_FILE_PATH=${value%*/} ;;

            port) PORT=$value ;;

            logs_path) LOGS_PATH=$value ;;

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
get_install_pkgs $MONGO_PKGS
sleep 3
edit_profile
sleep 3
init_mongodb

# '{'svn_user': 'mashaokui','svn_passwd': 'fcy3I4yB','svn_address': 'svn://192.168.50.221/soft_2018','mongo_pkgs': 'mongodb-linux-x86_64-4.0.5.tgz','resp_dir': '/tmp/resp','install_path': '/usr/local/mongodb','data_file_path': '/usr/local/mongodb/data','port': '27017','logs_path': '/usr/local/mongodb/logs','skip_download_files': '1'}'

