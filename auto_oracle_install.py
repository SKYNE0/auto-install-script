#!/usr/bin/env python
# -*- coding: utf8 -*-

import os
import re
import sys
import time
import subprocess as sp
reload(sys)
sys.setdefaultencoding('utf-8')

# 参数的接收顺序 用户名， 密码， 仓库地址， 安装目录， 安装文件存放目录
# 测试默认值 mashaokui  fcy3I4yB  svn://192.168.50.221/soft_2018  /u01  /tmp/repository

param = {
    'close_str':u"""
# AvoidRrepeatedRewriting
SELINUX=disabled       
        """,

    'sysctl_config':u"""
# AvoidRrepeatedRewriting
fs.aio-max-nr=1048576
fs.file-max=6815744
# shmall shmax 需要按实际情况设置
kernel.shmall=1209300
kernel.shmmax=4953292800
kernel.shmmni=4096
kernel.sem=25032000100128
net.ipv4.ip_local_port_range=900065500
net.core.rmem_default=262144
net.core.rmem_max=4194304
net.core.wmem_default=262144
net.core.wmem_max=1048576    
    """,

    'limits_config':u"""
# AvoidRrepeatedRewriting
oracle  soft   nproc  2047
oracle  hard  nproc  16384
oracle  soft   nofile  1024
oracle  hard  nofile  65536
oracle  soft  stack  10240
    """,

    'pam_config': u"""
# AvoidRrepeatedRewriting
session   required   /lib64/security/pam_limits.so
    """,

    'profile_config':u"""
# AvoidRrepeatedRewriting
if [ $USER = "oracle" ]; then
  if [ $SHELL = "/bin/ksh" ]; then
    ulimit -p 16384
    ulimit -n 65536
  else
    ulimit -u 16384 -n 65536
  fi
umask 022
fi    
    """,

    'bash_profile':u"""
# AvoidRrepeatedRewriting    
export ORACLE_SID=orcl
ORACLE_BASE=/u01/app/oracle
export ORACLE_BASE
ORACLE_HOME=$ORACLE_BASE/product/11.2.0/db_home
export ORACLE_HOME
PATH=${PATH}:/usr/bin:/bin:/sbin:/usr/bin/X11:/usr/local/bin:$ORACLE_HOME/bin
PATH=${PATH}:/oracle/product/common/oracle/bin
export PATH
LD_LIBRARY_PATH=$ORACLE_HOME/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:$ORACLE_HOME/oracm/lib
LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/lib:/usr/lib:/usr/local/lib
export LD_LIBRARY_PATH
CLASSPATH=$ORACLE_HOME/JRE
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/jlib
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/rdbms/jlib
CLASSPATH=${CLASSPATH}:$ORACLE_HOME/network/jlib
export CLASSPATH
export TEMP=/tmp
export TMPDIR=/tmp
umask 022
export DISPLAY=:0.0
    """,

    'db_install':u"""
# AvoidRrepeatedRewriting  
oracle.install.option=INSTALL_DB_SWONLY 
ORACLE_HOSTNAME=localhost.localdomain                     
UNIX_GROUP_NAME=oinstall                    
INVENTORY_LOCATION=/u01/app/oracle/inventory    
SELECTED_LANGUAGES=en,zh_CN                        
ORACLE_HOME=/u01/app/oracle/product/11.2.0/db_home    
ORACLE_BASE=/u01/app/oracle                  
oracle.install.db.InstallEdition=EE                    
oracle.install.db.DBA_GROUP=dba             
oracle.install.db.OPER_GROUP=oper                 
DECLINE_SECURITY_UPDATES=true            
    """,

    'dbca':u"""
# AvoidRrepeatedRewriting
[GENERAL]
RESPONSEFILE_VERSION="11.2.0"              
OPERATION_TYPE="createDatabase"             
[CREATEDATABASE]                     
GDBNAME="orcl"                                
SID="orcl"    
INSTANCENAME="orcl"                                  
TEMPLATENAME="General_Purpose.dbc"          
MEMORYPERCENTAGE="30"      
SYSPASSWORD="oracle"                          
SYSTEMPASSWORD="oracle"                      
DATAFILEDESTINATION="/u01/app/oracle/oradata"
CHARACTERSET="AL32UTF8"                     
NATIONALCHARACTERSET="AL16UTF16"
""",

}


# flag_str 用来判断被写入的文件此前是否被写入过，避免重复改写。
flag_str = u"# AvoidRrepeatedRewriting"
#脚本接收的参数
args = sys.argv
# 全局变量 用于输出错误信息
ERROR = u""
# 格式化时间
def now():
    """
    :return: str
    """
    return time.strftime('%Y-%m-%d %H:%M:%S', time.localtime(time.time()))

# 检查脚本参数
def check_args():
    global ERROR

    if len(args) == 6:
        # 参数的接收顺序 用户名， 密码， 仓库地址， 安装目录， 安装文件存放目录
        global svn_user, svn_passwd, svn_address, ora_inst_dir, resp_dir, install_file_name
        svn_user = args[1]
        svn_passwd = args[2]
        svn_address = args[3]
        ora_inst_dir = args[4]
        resp_dir = args[5]
        install_file_name = u"p13390677_112040_Linux-x86-64_1of7.zip  p13390677_112040_Linux-x86-64_2of7.zip"
        return True
    else:
        ERROR = now(), u"\t传入参数不正确，请检查！当前参数= {}\n".format(args)
        return False

# 判断是否已经安装Oracle
def check_exist_oracle():
    global ERROR
    with open('/etc/group', 'r+') as fb:
        text = fb.read()
        if re.search('oinstall', text) or re.search('oracle', text):
            ERROR = now(), u"\t已经存在oracle用户，用户组，请检查是否已经安装oracle！\n"
            return False
        else:
            return True

# 检查内存，交换分区等是否符合要求
def check_os_hostname():
    """
    :return:bool
    """
    global ERROR
    # 检测当前系统的内存和交换空间
    result = sp.Popen(['grep MemTotal /proc/meminfo | cut -f2 -d:'], stdout=sp.PIPE, shell=True)
    ram_size = int(result.stdout.read()[0:-3])
    result = sp.Popen(['grep SwapTotal /proc/meminfo | cut -f2 -d:'], stdout=sp.PIPE, shell=True)
    swap_size = int(result.stdout.read()[0:-3])
    # RAM 最低2G， SWAP交换分区为RAM两倍
    if ram_size >= 2097152 and swap_size >= 4000000:
        # print now(), "\tRAM= {0}kb, SWAP= {1}kb,The RAM And SWAP Meet The Requirements Of Installation\n".format(ram_size, swap_size)
        return True
    else:
        ERROR = now(), u"\tRAM= {0}kb, SWAP= {1}kb,内存和交换分区不符合安装要求！\n".format(ram_size, swap_size)
        return False

# 关闭SELinux和系统防火墙
def close_selinux_firewalld():
    """
    :return: bool
    """
    global ERROR
    close_str = param['close_str']
    close = sp.call(["setenforce 0"], shell=True)
    if os.path.isfile('/etc/selinux/config'):
        with open('/etc/selinux/config', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(close_str)
    else:
        ERROR = now(), u"文件selinux/config不存在，程序异常退出！\n"
        return False

    close_firewalld_cmd = u"service iptables stop; chkconfig iptables off"

    result = sp.call([close_firewalld_cmd], shell=True)

    if result == 0:
        # print now(), "\tFirewalld Close Success!\n"
        return True
    else:
        close_firewalld_cmd = u"systemctl stop firewalld; systemctl disable firewalld"
        result = sp.call([close_firewalld_cmd], shell=True)
        if result == 0:
            # print now(), "\tFirewalld Close Success!\n"
            return True
        else:
            ERROR = now(), u"\t防火墙未正确关闭, 请检查! 错误码 = {0}\n".format(result)
            return False

# 设置静态IP，如果需要。备注: 静态IP的设置只需要更改IPADDR，GATEWAY
def set_static_ip():
    """
    :return: bool
    """
    ip_conf_dir = '/etc/sysconfig/network-scripts/ifcfg-eth0'
    static_ip_conf = param['static_ip_conf']
    if os.path.isfile(ip_conf_dir):
        with open(ip_conf_dir, 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(static_ip_conf)
                print now(), "\tStatic IP Set Success\n"
                return True
            else:
                print now(), "\tIpConfig Is Already Exist\n"
                return True
    else:
        os.makedirs('/etc/sysconfig/network-scripts/')
        with open(ip_conf_dir, 'a+') as fb:
            fb.write(static_ip_conf)
            print now(), "\tStatic IP Set Success\n"
            return True

# 配置Yum源并安装Oracle依赖
def configure_yum():
    """
    :return: bool
    """
    global ERROR
    package_install_cmd = u"yum -y install compat-libcap* compat-libstdc* gcc*  glibc-2* glibc-devel*  libgcc* libstdc* libaio* make* sysstat*  binutils* elfutils-libelf-devel.x86_64 elfutils-libelf.x86_64 tiger* unzip"
    result = sp.call([package_install_cmd], shell=True)
    if result == 0:
        # print now(), "\tOracle Dependency Package Install Success!\n"
        return True
    else:
        ERROR = now(), u"\tYUM源未正确配置, 请检查! 错误码 = {0}\n".format(result)
        return False


def get_svn_pkgs():
    global ERROR
    svn = sp.call(["yum -y install subversion"], shell=True)
    
    svn_co = "svn co --username=" + svn_user+ " --password=" + svn_passwd + "  --force --no-auth-cache \
                  --depth=empty  " + svn_address + "  " + resp_dir
    ckeck_svn = sp.call([svn_co], shell=True)
    svn_up = "cd  " + resp_dir + " && " + "svn up --username=" + svn_user +" --password=" + svn_passwd + "  --force --no-auth-cache  "+ install_file_name
    up_svn = sp.call([svn_up], shell=True)
    if ckeck_svn or up_svn:
        ERROR = now(), u"\tSVN异常, 请检查， 错误码 = {0},{1}\n".format(ckeck_svn, up_svn)
        return False
    else:
        return True

# 配置内核,登录验证，用户信息等参数
def configure_sysctl():
    """
    :return:
    """
    global ERROR
    sysctl_config = param['sysctl_config']
    # 修改系统内核参数
    if os.path.isfile('/etc/sysctl.conf'):
        with open('/etc/sysctl.conf', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(sysctl_config)

    else:
        ERROR = now(), u"\t文件/etc/sysctl.conf不存在，请检查！\n"
        return False

    limits_config = param['limits_config']
    # 设置oracle用户内核限制
    if os.path.isfile('/etc/security/limits.conf'):
        with open('/etc/security/limits.conf', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(limits_config)
    else:
        ERROR = now(), u"\t文件/etc/security/limits.conf不存在，请检查！\n"
        return False

    # 配置PAM
    if os.path.isfile('/etc/pam.d/login'):
        pam_config = param['pam_config']
        with open('/etc/pam.d/login', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(pam_config)
    else:
        ERROR = now(), u"\t文件/etc/pam.d/login不存在，请检查！\n"
        return False


    profile_config = param['profile_config']
    # 设置登陆用户环境信息
    if os.path.isfile('/etc/profile'):
        with open('/etc/profile', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(profile_config)
    else:
        ERROR = now(), u"\t文件/etc/profile不存在，请检查！\n"
        return False

    # print now(), "\tKernel And Other Configuration Completion\n"
    return True

# 创建Oracle用户,用户组,安装目录以及用户环境变量
def create_user_groups():
    """
    :return: bool
    """
    global ERROR
    with open('/etc/group', 'r+') as fb:
        text = fb.read()
        if not re.search('oinstall', text):
            cmd_list = ['groupadd  oinstall', 'groupadd  dba', 'groupadd  oper',
                        'useradd  -g  oinstall  -G dba,oper  oracle',]

            for cmd in cmd_list:
                result = sp.call([cmd], shell=True)
                if result == 0:
                    pass
                else:
                    ERROR = now(), u"\t命令 {0} 执行失败! 错误码 = {1}\n".format(cmd, result)
                    return False

            # 设置oracle用户的密码
            result = sp.Popen('passwd  oracle', stdin=sp.PIPE, shell=True)
            result.stdin.write('jiaguwen\n')
            result.stdin.write('jiaguwen\n')
        else:
            ERROR = now(), u"\tOracle用户, 用户组已经存在!\n"
            return False

    # 创建oracle用户安装目录并修改权限
    cmd_list = ["mkdir -p  " + ora_inst_dir + "/app/oracle/product/11.2.0/db_home",
                "mkdir " + ora_inst_dir + "/app/oracle/oradata",
                "mkdir " + ora_inst_dir + "/app/oracle/inventory",
                "mkdir " + ora_inst_dir + "/app/oracle/fast_recovery_area",
                "chown  -R  oracle:oinstall  "  + ora_inst_dir + "/app",
                "chmod -R 775  " + ora_inst_dir + "/app",]

    for cmd in cmd_list:
        result = sp.call([cmd], shell=True)
        if result == 0:
            pass
        else:
            ERROR = now(), u"\t命令 {0} 执行失败! 错误码 = {1}\n".format(cmd, result)
            return False

    # 配置oracle用户的环境变量
    bash_profile = param['bash_profile']
    if os.path.isfile('/home/oracle/.bash_profile'):
        with open('/home/oracle/.bash_profile', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(bash_profile)
        # .bashrc 文件也需要修改, 切换用户时自动生效
        with open('/home/oracle/.bashrc', 'a+') as fb:
            text = fb.read()
            if not re.search(flag_str, text):
                fb.write(bash_profile)
                # print now(), "\tUser, UserGroup, User Dirs, User Env Var Modification!\n"
            return True

    else:
        ERROR = now(), u"\t用户配置文件.bash_profile 不存在!\n"
        return False

# 解压安装介质
def unzip_install_file():
    """
    :return: bool
    """
    global ERROR
    # 创建安装文件解压目录
    if not os.path.exists(ora_inst_dir + "/app/11203_install/"):
        os.mkdir(ora_inst_dir + "/app/11203_install/")

    # 解压安装介质， 默认介质在/home/soft目录下。
    if not os.path.exists(ora_inst_dir + "/app/11203_install/database/"):
        unzip_cmd1 = "unzip  -o -q " + resp_dir + "/p13390677_112040_Linux-x86-64_1of7.zip  -d  " + ora_inst_dir + "/app/11203_install/;"
        unzip_cmd2 = "unzip  -o -q " + resp_dir + "/p13390677_112040_Linux-x86-64_2of7.zip  -d  " + ora_inst_dir + "/app/11203_install/;"
        result = sp.call([unzip_cmd1 + unzip_cmd2], shell=True)
        # 更改目录的所属组以及权限问题
        sp.call(['chown -R oracle:oinstall  ' + ora_inst_dir + "/app/11203_install/"], shell=True)
        sp.call(['chmod -R 775 ' + ora_inst_dir + "/app/11203_install/"], shell=True)

        if result == 0:
            # print now(), "\tUnpacked Install File Success!\n"
            return True
        else:
            ERROR = now(), u"\t安装介质解压失败!，请检查！错误码 = {0}\n".format(result)
            return False
    else:
        # print now(), "\tUnpacked Install File Already Exist!\n"
        return True

# 编辑静默安装响应文件
def edit_response_file():
    global ERROR
    # 自动替换当前主机名，默认为localhost.localdomain
    ps = sp.Popen(['hostname'], stdout=sp.PIPE, shell=True)
    output, unused_err = ps.communicate()
    if not output == u'localhost.localdomain':
        param['db_install'] = re.sub(u'localhost.localdomain', output.replace('\n', ''), param['db_install'])

    db_install = param['db_install']
    dbca = param['dbca']

    sp.call(['cp  -R  ' + ora_inst_dir + "/app/11203_install/database/response/  /home/oracle/"], shell=True)
    #配置db_install.rsp, dbca.rsp
    with open('/home/oracle/response/db_install.rsp', 'a+') as fb:
        text = fb.read()
        if not re.search(flag_str, text):
            fb.write(db_install)

    with open('/home/oracle/response/dbca.rsp', 'w+') as fb:
            fb.write(dbca)

    result = sp.call(['chown  -R  oracle:oinstall  /home/oracle/response/'], shell=True)

    if result == 0:
        # print now(), "\tResponse File modification Success!\n"
        return True
    else:
        ERROR = now(), u"\t改变响应文件属性失败，请检查！错误码 = {0}\n".format(result)
        return False

# 静默安装Oracle
def install_oracle():
    global ERROR
    install_cmd = "su oracle -c 'sh "+ ora_inst_dir + "/app/11203_install/database/runInstaller  -silent  -ignorePrereq  -showProgress  -responseFile  /home/oracle/response/db_install.rsp'"
    root_cmd = [ora_inst_dir + "/app/oracle/inventory/orainstRoot.sh", ora_inst_dir + "/app/oracle/product/11.2.0/root.sh"]
    # 添加oracle用户的环境变量， 在这里老不生效是因为，ssh连接并不等同于shell，所以下面不会生效
    sp.call(["source /home/oracle/.bash_profile"], shell=True)
    sp.call(['export DISPLAY=:0.0'], shell=True)
    # 启动oracle安装程序
    sp.call([install_cmd], shell=True)
    time.sleep(10)
    # 监听OraInstall....的oracle安装程序，该程序退出后就成功装上oracle了.
    flag = True
    while flag:
        ps = sp.Popen(['ps aux'], stdout=sp.PIPE, shell=True)
        output, unused_err = ps.communicate()
        if re.search('OraInstall', output):
            time.sleep(1)
        else:
            flag = False
    # 执行两个数据库脚本，哪个存在执行哪个.
    for sh_file in root_cmd:
        if os.path.isfile(sh_file):
            sp.call(['sh ' + sh_file], shell=True)
    if not flag:
        return True
    else:
        ERROR = now(), u"\t安装oracle数据库软件失败，请检查!\n"
        return False


def install_oracle_instance():
    global ERROR
    netca_cmd = "su - oracle -c '" + ora_inst_dir + "/app/oracle/product/11.2.0/db_home/bin/netca  /silent /responsefile /home/oracle/response/netca.rsp'"
    dbca_cmd = "su - oracle -c '" + ora_inst_dir + "/app/oracle/product/11.2.0/db_home/bin/dbca -silent -responseFile /home/oracle/response/dbca.rsp'"
    # 有时候会出现缺少libclntsh.so.11.1的文件错误，预防万一，直接复制一份过去
    cp_cmd = "su - oracle -c 'cp  " + ora_inst_dir + "/app/oracle/product/11.2.0/db_home/inventory/Scripts/ext/lib/libclntsh.so.11.1  " + ora_inst_dir + "/app/oracle/product/11.2.0/lib'"
    sp.call([cp_cmd], shell=True)

    # 创建监听程序
    sp.call([netca_cmd], shell=True)
    # 建立数据库实例
    dbca = sp.Popen([dbca_cmd],stdin=sp.PIPE, shell=True)
    # 输入SYS 密码
    dbca.stdin.write('oracle\n')
    # 输入SYSTEM 密码
    dbca.stdin.write('oracle\n')
    time.sleep(20)
    # 监听进程名为oracleorcl11g的oracle数据库实例安装程序，该程序退出后就成功装上oracle数据库实例了.
    flag = True
    while flag:
        ps = sp.Popen(['ps aux'], stdout=sp.PIPE, shell=True)
        output, unused_err = ps.communicate()
        if re.search('Doracle.installer', output):
            time.sleep(1)
        else:
            flag = False

    if not flag:
        return True
    else:
        ERROR = now(), u"\t安装oracle数据库数据库实例失败，请检查!\n"
        return False

#修改系统主机名
def change_hostname():
    global ERROR
    cmd = sp.call(['hostnamectl set-hostname  oradb'], stdout=sp.PIPE, shell=True)
    if not cmd:
        return True
    else:
        ERROR = now(), u"\t系统版本可能低于7，不支持此方式修改主机名，自动跳过！\n"
        return True


if __name__ == '__main__':
    import sys
    step_name = {
        'check_exist_oracle()': u'检查是否安装过oracle',
        'check_args()': u'检查参数',
        'check_os_hostname()': u'检查主机信息',
        'close_selinux_firewalld()': u'关闭SElinux防火墙',
        'configure_yum()': u'安装系统依赖',
        'get_svn_pkgs()': u'下载安装文件',
        'configure_sysctl()': u'配置系统参数',
        'create_user_groups()': u'建立用户,用户组',
        'unzip_install_file()': u'解压安装文件',
        'edit_response_file()': u'创建响应文件',
        'install_oracle()': u'安装oracle数据库软件',
        'install_oracle_instance()': u'安装oracle数据库实例',
        'change_hostname()': u'修改系统主机名',
    }
    func_list = ['check_exist_oracle()','check_args()','check_os_hostname()','close_selinux_firewalld()',
                 'configure_yum()','get_svn_pkgs()','configure_sysctl()', 'create_user_groups()','unzip_install_file()',
                 'edit_response_file()', 'install_oracle()','install_oracle_instance()', 'change_hostname()']
    step = []
    flag = True
    for func in func_list:
        if eval(func):
            step.append(step_name[func] + u" :已完成")
            time.sleep(2)
        else:
            flag = False
            break

    # sp.call(["clear"], stdout=sp.PIPE, shell=True)
    if flag:
        info = {'result':'SUCCESS','message': u'安装oracle数据库软件,实例完成。','step':step}
        print info
        sys.exit(0)
    else:
        error = {'result': 'Failed', 'message': ERROR, 'step': step}
        print error
        sys.exit(1)
