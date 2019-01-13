#!/bin/bash

function check_exist_weblogic() {
    cat /etc/group |grep weblogic
    if [[ $? -eq 0 ]]; then
        ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tweblogic用户，用户组已经存在，可能已经安装过weblogic\n")
        echo $ERROR >> $log_file
        echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
        exit 1
    else
        echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tweblogic用户，用户组不存在，继续安装！\n" >> $log_file
    fi
}

function check_yum() {
    yum -y install compat-libcap1 compat-libstdc++ gcc gcc-c++ glibc-devel libaio-devel libstdc++-devel ksh numactl numactl-devel motif motif-devel
    if [[ $? -eq 0 ]]; then
        echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tyum源正常，依赖已经安装！\n" >> $log_file
    else
        ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tyum源不正常，依赖未正确安装，返回错误码 = $? \n")
        echo $ERROR >> $log_file
        echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
        exit 1
    fi

}

function get_install_pkgs() {
    yum -y install subversion

    svn co --username=${svn_user} --password=${svn_passwd}  --force --no-auth-cache \
                  --depth=empty  ${svn_address}  ${resp_dir}

    cd ${resp_dir} && svn up --username=${svn_user} --password=${svn_passwd}  --force --no-auth-cache ${jdk_file}  ${weblogic_file}
    
    if [[ $? -eq 0 ]]; then
        echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tSVN正常，安装文件已经安装！\n" >> $log_file
    else
        ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tSVN出现问题，安装文件未正确下载，返回错误码 = $? \n")
        echo $ERROR >> $log_file
        echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
        exit 1
    fi
}

function install_jdk() {
    if [[ ! -d "${jdk_path}/jdk1.8.0_121" ]]; then
        mkdir -p ${jdk_path}
        tar -zxf ${resp_dir}/${jdk_file}  -C  ${jdk_path}

        if [[ $? -eq 0 ]]; then
            echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tJDK安装文件解压完毕！\n" >> $log_file
        else
            ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tJDK安装文件解压出现问题，返回错误码 = $? \n")
            echo $ERROR >> $log_file
            echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
            exit 1
        fi

        cat >> /etc/profile <<EOF
export JAVA_HOME=${jdk_path}/jdk1.8.0_121
export JAVA_BIN=${jdk_path}/jdk1.8.0_121/bin
export PATH=\$PATH:\$JAVA_HOME/bin
export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export JAVA_HOME JAVA_BIN PATH CLASSPATH
EOF
        source /etc/profile
    else
        echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tJDK已经存在，无需安装！\n" >> $log_file
    fi
}


function create_response_file() {

groupadd -g 530 weblogic
useradd -g weblogic -G weblogic -d /home/weblogic/ weblogic
chown -R weblogic:weblogic /home/weblogic/
if [[ $? -eq 0 ]]; then
    echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tweblogic响应文件，用户用户组创建完毕！\n" >> $log_file
else
    ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tweblogic响应文件，用户用户组创建出现问题，返回错误码 = $?\n")
    echo $ERROR >> $log_file
    echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
    exit 1
fi

mkdir -p ${weblogic_path}/response/
cat > ${weblogic_path}/response/wls.rsp <<EOF
[ENGINE]
Response File Version=1.0.0.0.0
[GENERIC]
ORACLE_HOME=${weblogic_path}/oracle
INSTALL_TYPE=WebLogic Server
MYORACLESUPPORT_USERNAME=
MYORACLESUPPORT_PASSWORD=<SECURE VALUE>
DECLINE_SECURITY_UPDATES=true
SECURITY_UPDATES_VIA_MYORACLESUPPORT=false
PROXY_HOST=
PROXY_PORT=
PROXY_USER=
PROXY_PWD=<SECURE VALUE>
COLLECTOR_SUPPORTHUB_URL=
EOF

cat > ${weblogic_path}/response/oraInst.loc <<EOF
inventory_loc=${weblogic_path}/oraInventory
inst_group=weblogic
EOF


cat >> /etc/profile <<EOF
export MW_HOME=${weblogic_path}/oracle
export WLS_HOME=\$MW_HOME/wlserver
export WL_HOME=\$WLS_HOME
EOF

cat > /home/weblogic/.bash_profile <<EOF
# .bash_profile
# Get the aliases and functions
if [ -f ~/.bashrc ]; then
        . ~/.bashrc
fi
# User specific environment and startup programs
PATH=\$PATH:\$HOME/bin
export PATH
export JAVA_HOME=${jdk_path}/jdk1.8.0_121
export JAVA_BIN=${jdk_path}/jdk1.8.0_121/bin
export PATH=\$PATH:\$JAVA_HOME/bin
export CLASSPATH=.:\$JAVA_HOME/lib/dt.jar:\$JAVA_HOME/lib/tools.jar
export JAVA_HOME JAVA_BIN PATH CLASSPATH
export MW_HOME=${weblogic_path}/oracle
export WLS_HOME=\$MW_HOME/wlserver
export WL_HOME=\$WLS_HOME
export TEMP=/tmp
export TMPDIR=/tmp
umask 022
EOF

cat > /home/weblogic/.bashrc <<EOF
# .bashrc
# Source global definitions
if [ -f /etc/bashrc ]; then
        . /etc/bashrc
fi
# User specific aliases and functions
EOF

source /etc/profile
}


function install_weblogic_domain() {

chown -R weblogic:weblogic ${weblogic_path}
su - weblogic -c "${jdk_path}/jdk1.8.0_121/bin/java -jar ${resp_dir}/${weblogic_file} -silent -responseFile ${weblogic_path}/response/wls.rsp  -invPtrLoc ${weblogic_path}/response/oraInst.loc"

if [[ $? -eq 0 ]]; then
    echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tweblogic软件安装完毕！\n" >> $log_file
else
    ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tweblogic软件安装出现问题，返回错误码 = $?\n")
    echo $ERROR >> $log_file
    echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
    exit 1
fi

# 创建域
cat > ${weblogic_path}/response/create_domain.rsp <<EOF
read template from "${weblogic_path}/oracle/wlserver/common/templates/wls/wls.jar";
set JavaHome "${jdk_path}/jdk1.8.0_121/";
set ServerStartMode "dev";
find Server "AdminServer" as AdminServer;
set AdminServer.ListenAddress "";
set AdminServer.ListenPort "${listen_port}"; 
find User "${wlc_user}" as u1;
set u1.password "${wlc_passwd}";
write domain to "${weblogic_path}/oracle/user_projects/domains/base_domain/";
EOF

su - weblogic -c "sh ${weblogic_path}/oracle/wlserver/common/bin/config.sh \
    -mode=silent -silent_script=${weblogic_path}/response/create_domain.rsp \
    -logfile=${weblogic_path}/response/creat_domain.log"

if [[ $? -eq 0 ]]; then
    echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tweblogic域部署完毕！\n" >> $log_file
else
    ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tweblogic域部署出现问题，返回错误码 = $?\n")
    echo $ERROR >> $log_file
    echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
    exit 1
fi

su - weblogic -c "sh ${weblogic_path}/oracle/wlserver/server/bin/setWLSEnv.sh"
su - weblogic -c "cd  ${weblogic_path}/oracle/user_projects/domains/base_domain/bin && nohup ./startWebLogic.sh &"

if [[ $? -eq 0 ]]; then
    echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tINFO\tweblogic域启动完毕！\n" >> $log_file
    echo {\'result\': \'Success\', \'message\': \'weblogic软件，域安装部署完毕\'}
    exit 0
else
    ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\tweblogic域启动出现问题，返回错误码 = $?！\n")
    echo $ERROR >> $log_file
    echo {\'result\': \'Failed\', \'message\': \'$ERROR\'}
    exit 1
fi

}


log_file="/var/log/auto_install_weblogic.log"

params=$(echo $1 | sed 's\{\\g' | sed 's\}\\g' )

num=$(echo $params |grep -o ': ' |wc -l)

old_ifs=$IFS

IFS=','

if [[ "$num" -eq 11 ]]; then
    for param in $params; do
        key=$(echo $param | cut -d ':' -f 1)
        value=$(echo $param | cut -d ':' -f 2-)
        value=${value#* }
        case $key in
            svn_user) svn_user=$value ;;

            svn_passwd) svn_passwd=$value ;;

            svn_address) svn_address=$value ;;

            jdk_file) jdk_file=$value ;;

            weblogic_file) weblogic_file=${value%*/} ;;
            
            weblogic_path) weblogic_path=${value%*/} ;;

            jdk_path) jdk_path=${value%*/} ;;

            resp_dir) resp_dir=${value%*/} ;;

            listen_port) listen_port=$value ;;

            wlc_user) wlc_user=$value ;;

            wlc_passwd) wlc_passwd=$value ;;

            *) ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\t 接收到未知参数key = $key\n")
                echo $ERROR >> $log_file
                echo {\'result\': \'Failed\', \'message\': \'$ERROR\' }
                exit 1
                ;;
        esac
    done    
else
    ERROR=$(echo -e `date +"%Y-%m-%d %H:%M:%S"` "\tERROR\t参数个数错误, 当前参数为 = $@！\n")
    echo $ERROR >> $log_file
    echo {\'result\': \'Failed\', \'message\': \'$ERROR\' }
    exit 1
fi

IFS=$old_ifs

check_exist_weblogic
check_yum
get_install_pkgs
install_jdk
create_response_file
install_weblogic_domain


