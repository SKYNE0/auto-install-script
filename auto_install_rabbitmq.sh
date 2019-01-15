#!/bin/bash
red_echo ()  { echo; echo; echo -e  "\033[031;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; exit 1;}
yellow_echo ()   { echo; echo; echo -e "\033[033;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }
green_echo ()  { echo; echo; echo -e  "\033[032;1m `date +"%Y-%m-%d %H:%M:%S"` \t\t $@\033[0m"; }



yum_install_pkgs () {
    green_echo "\tINFO\t 开始安装Erlang和RabbitMq！"

    # yum install xmlto gcc gcc-c++ kernel-devel m4 ncurses-devel openssl-devel  \
    # unixODBC-devel wxBase wxGTK wxGTK-gl perl epel-release socat  -y 
    # [[ $? -eq 0 ]] || red_echo "\tERROR\t 安装依赖失败，返回错误码 = $? \n"
    cd $RESP_PATH

    yum install $ERLANG_PKGS -y  ||  red_echo "\tERROR\t 安装Erlang失败，返回错误码 = $? \n"
    yum install $RABBITMQ_PKGS -y  ||  red_echo "\tERROR\t 安装RabbitMq失败，返回错误码 = $? \n"

    green_echo "\tINFO\t Erlang和RabbitMq安装完成！"

}

get_install_pkgs () {
    local pkgs_name=$@
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

_init_dirtree () {
    if [[ -d $MNESIA_PATH/rabbitmq/mensia ]]; then 
        green_echo "\tINFO\t $MNESIA_PATH已经存在！"
        chown  -R rabbitmq:rabbitmq  $MNESIA_PATH /rabbitmq
    else
        mkdir -p $MNESIA_PATH/rabbitmq/mensia
        chown  -R rabbitmq:rabbitmq  $MNESIA_PATH/rabbitmq
    fi
}

init_rabbitmq () {
    green_echo "\tINFO\t 开始配置RabbitMq，初始化RabbitMq！"

    cd /etc/rabbitmq

    cat > rabbitmq.config << EOF
[
    {rabbit, [
        {loopback_users, []}
    ]}
].
EOF
    cat > rabbitmq-env.conf << EOF
NODENAME=rabbit@$(hostname)
RABBITMQ_NODE_PORT=$PORT
CONFIG_FILE=/etc/rabbitmq
MNESIA_BASE=$MNESIA_PATH/rabbitmq/mensia
LOG_BASE=/var/log/rabbitmq
ENABLED_PLUGINS_FILE=/etc/rabbitmq/enabled_plugins
EOF
    cat > enabled_plugins << EOF
[rabbitmq_management,rabbitmq_management_agent].
EOF

service rabbitmq-server start || red_echo "\tERROR\t RabbitMq启动失败，返回错误码 = $? \n" 
green_echo "\tINFO\t RabbitMq已经成功启动！"

rabbitmqctl add_user "$USER" "$PASSWD" || red_echo "\tERROR\t 添加用户$USER失败，返回错误码 = $? \n" 
rabbitmqctl set_user_tags $USER administrator
rabbitmqctl delete_user guest
if [[ $? -eq 0 ]]; then
    green_echo "\tSUCCESS\t 现在你可以使用$USER用户和$PASSWD密码来登录http://IP:15672来访问管理RabbitMq了，Tips：Guest用户已经被删除！"
else
    red_echo "\tERROR\t RabbitMq添加用户失败，返回错误码 = $? \n" 
fi

}

init_params () {
    green_echo "\tINFO\t 开始解析所接收参数！"

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
            
                erlang_pkgs) ERLANG_PKGS=$value ;;

                rabbitmq_pkgs) RABBITMQ_PKGS=$value ;;

                user) USER=$value ;;

                passwd) PASSWD=$value ;;

                mensia_path) MNESIA_PATH=${value%*/} ;;
                
                resp_dir) RESP_PATH=${value%*/} ;;

                port) PORT=$value ;;

                skip_download_files) SKIP_DOWNLOAD_FILES=$value ;;

                *) red_echo "\tERROR\t 接收到未知参数key = $key\n" ;;
            esac
        done    
    else
        red_echo "\tERROR\t参数个数错误, 当前参数为 = $@！\n"
    fi

    IFS=$old_ifs

}

init_params $@
get_install_pkgs  $ERLANG_PKGS  $RABBITMQ_PKGS
sleep 3
yum_install_pkgs
sleep 3
_init_dirtree rabbitmq
sleep 3
init_rabbitmq

# '{'svn_user': 'mashaokui','svn_passwd': 'fcy3I4yB','svn_address': 'svn://192.168.50.221/soft_2018','erlang_pkgs': 'erlang-19.3.6.4-1.el7.centos.x86_64.rpm','rabbitmq_pkgs': 'rabbitmq-server-3.7.0-1.el7.noarch.rpm','resp_dir': '/tmp/resp','mensia_path': '/var/lib/','user': 'admin','passwd': 'admin.Asd','port': '5672','skip_download_files': '1'}'




