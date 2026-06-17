#!/bin/bash
# ============================================================
# OpenList 安装脚本 - JDBox/OpenWrt ARMv7l 适配版
# 用法: bash /opt/install-openlist.sh install|update|uninstall
# 持久化: /opt/openlist + /opt/etc/init.d/openlist + UCI
# ============================================================
RED='\e[1;31m'; GREEN='\e[1;32m'; YELLOW='\e[1;33m'
BLUE='\e[1;34m'; CYAN='\e[1;36m'; RES='\e[0m'
# ── 架构检测（用 case 替代关联数组，兼容 ash/busybox） ──
get_arch() {
    case "$(command -v arch >/dev/null 2>&1 && arch || uname -m)" in
        x86_64)      echo "amd64" ;;
        aarch64)     echo "arm64" ;;
        armv7l)      echo "armv7l" ;;
        armv8l)      echo "arm64" ;;
        loongarch64) echo "loong64" ;;
        *)           echo "UNKNOWN" ;;
    esac
}
ARCH=$(get_arch)
# ── armv7l 下载文件名特殊 ──
dl_file() {
    [ "$ARCH" = "armv7l" ] && echo "openlist-linux-musleabihf-armv7l.tar.gz" || echo "openlist-linux-musl-$ARCH.tar.gz"
}
# ── 常量 ──
INSTALL_PATH="/opt/openlist"
VERSION_FILE="$INSTALL_PATH/.version"
GH_PROXY="https://ghfast.top/"
GH_DL="${GH_PROXY}https://github.com/OpenListTeam/OpenList/releases/latest/download"
MANAGER_PATH="/opt/sbin/openlist-manager"
CMD_LINK="/opt/bin/openlist"
# ── 基础检查 ──
[ "$(uname -s)" != "Linux" ] && { echo -e "${RED}仅支持 Linux${RES}"; exit 1; }
[ "$(id -u)" != "0" ] && { echo -e "${RED}需要 root${RES}"; exit 1; }
[ "$ARCH" = "UNKNOWN" ] && { echo -e "${RED}不支持 $(uname -m)${RES}"; exit 1; }
command -v curl >/dev/null 2>&1 || { echo -e "${RED}请安装 curl${RES}"; exit 1; }
# ── 服务函数 ──
svc() { /etc/init.d/openlist "$@" 2>/dev/null; }
svc_active() { svc running && return 0; pidof openlist >/dev/null 2>&1; }
# ── 下载（3次重试） ──
download() {
    local n=0 w=2
    while [ $n -lt 3 ]; do
        curl -L --connect-timeout 15 --retry 3 "$1" -o "$2" && [ -s "$2" ] && return 0
        n=$((n+1)); [ $n -lt 3 ] && { echo -e "${YELLOW}重试 $((n+1))...${RES}"; sleep $w; w=$((w+2)); }
    done
    echo -e "${RED}下载失败${RES}"; return 1
}
# ── 磁盘检查 ──
chk_space() {
    local ts=$(df /tmp 2>/dev/null | awk 'NR==2{print $4}')
    local is=$(df /opt 2>/dev/null | awk 'NR==2{print $4}')
    if [ -n "$ts" ] && [ -n "$is" ] && { [ $ts -lt 51200 ] || [ $is -lt 51200 ]; }; then
        echo -e "${RED}空间不足${RES}"
        echo -e "  /tmp: $(df -h /tmp | awk 'NR==2{print $4}')"
        echo -e "  /opt: $(df -h /opt | awk 'NR==2{print $4}')"
        [ ! -t 0 ] && exit 1
        read -p "继续？[y/N]: " c; [ "$c" != "y" ] && [ "$c" != "Y" ] && exit 1
    fi
}
# ── 代理询问 ──
ask_proxy() {
    echo -e "${GREEN}当前代理：${GH_PROXY}${RES}"
    echo -e "${YELLOW}Enter=默认  none=取消  或输入自定义${RES}"
    read -p "代理: " p
    case "$p" in
        none|NONE) GH_DL="https://github.com/OpenListTeam/OpenList/releases/latest/download" ;;
        "") ;;
        *) GH_DL="${p}https://github.com/OpenListTeam/OpenList/releases/latest/download" ;;
    esac
}
# ═══════════════════════════════════════════════
#  安装
# ═══════════════════════════════════════════════
do_install() {
    local cur=$(pwd)
    ask_proxy
    # 准备目录
    mkdir -p "$(dirname "$INSTALL_PATH")"
    [ -f "$INSTALL_PATH/openlist" ] && { echo "已安装，请用 update"; exit 0; }
    rm -rf "$INSTALL_PATH" 2>/dev/null; mkdir -p "$INSTALL_PATH"
    # 下载
    local f=$(dl_file)
    echo -e "\n${GREEN}下载 $f ...${RES}"
    echo -e "${BLUE}${GH_DL}/${f}${RES}"
    download "${GH_DL}/${f}" "/tmp/openlist.tar.gz" || exit 1
    # 解压
    tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/" || { echo -e "${RED}解压失败${RES}"; rm -f /tmp/openlist.tar.gz; exit 1; }
    [ ! -f "$INSTALL_PATH/openlist" ] && { echo -e "${RED}未找到二进制${RES}"; rm -f /tmp/openlist.tar.gz; exit 1; }
    chmod +x "$INSTALL_PATH/openlist"
    # 生成初始密码（必须在 INSTALL_PATH 执行，data/ 与 openlist 同目录）
    cd "$INSTALL_PATH"
    local info=$("$INSTALL_PATH/openlist" admin random 2>&1)
    local ADMIN_USER=$(echo "$info" | grep "username:" | sed 's/.*username://;s/ //g')
    local ADMIN_PASS=$(echo "$info" | grep "password:" | sed 's/.*password://;s/ //g')
    cd "$cur"
    # 版本记录
    local ver=$("$INSTALL_PATH/openlist" version 2>&1 | grep "^Version:" | sed 's/Version://;s/ //g' | grep . || echo "beta")
    echo "$ver" > "$VERSION_FILE"
    date '+%Y-%m-%d %H:%M:%S' >> "$VERSION_FILE"
    rm -f /tmp/openlist*
    echo -e "${GREEN}二进制安装完成${RES}"
    # ── 创建持久化 init 脚本 ──
    echo -e "${GREEN}创建 init 脚本...${RES}"
    cat >/opt/etc/init.d/openlist << 'X'
#!/bin/sh /etc/rc.common
START=99; STOP=10; USE_PROCD=1
PROG=/opt/openlist/openlist; WORK_DIR=/opt/openlist
SRC=/opt/etc/init.d/openlist; DST=/etc/init.d/openlist
_heal(){ [ ! -f "$DST" ] || [ "$SRC" -nt "$DST" ] && { cp "$SRC" "$DST"; chmod +x "$DST"; logger -t openlist "healed"; }; }
boot(){ _heal; /etc/init.d/openlist enable 2>/dev/null; start; }
start_service(){ _heal; [ ! -x "$PROG" ] && { logger -t openlist "no binary"; return 1; }; logger -t openlist "start";
  procd_open_instance; procd_set_param command /bin/sh -c "cd $WORK_DIR && exec $PROG server";
  procd_set_param respawn 3600 5 60; procd_set_param pidfile /var/run/openlist.pid;
  procd_set_param stdout 1; procd_set_param stderr 1; procd_close_instance; }
stop_service(){ logger -t openlist "stop"; killall openlist 2>/dev/null; }
reload_service(){ stop; start; }
X
    chmod +x /opt/etc/init.d/openlist
    # ── 复制到 /etc/init.d/ 立即可用 ──
    cp /opt/etc/init.d/openlist /etc/init.d/openlist
    chmod +x /etc/init.d/openlist
    /etc/init.d/openlist enable 2>/dev/null
    # ── UCI 注册（zaiecplugin 自动发现） ──
    uci set jd_plugin.openlist=plugin
    uci set jd_plugin.openlist.version="$ver"
    uci set jd_plugin.openlist.pin='openlist'
    uci set jd_plugin.openlist.plugin_type='tool'
    uci set jd_plugin.openlist.upgrade='0'
    uci commit jd_plugin
    echo -e "${GREEN}init 脚本已完成${RES}"
    echo -e "  /opt/etc/init.d/openlist  ← 持久化"
    echo -e "  UCI jd_plugin.openlist    ← zaiecplugin 自动发现"
    # ── CLI 软链接 ──
    mkdir -p /opt/bin /opt/sbin
    cp "$0" "$MANAGER_PATH" 2>/dev/null
    chmod +x "$MANAGER_PATH" 2>/dev/null
    ln -sf "$MANAGER_PATH" "$CMD_LINK"
    # ── 启动 ──
    echo -e "${GREEN}启动服务...${RES}"
    /etc/init.d/openlist restart 2>/dev/null
    sleep 2
    # ── 输出 ──
    clear
    local lip=$(ip addr show 2>/dev/null | grep -w inet | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1 | head -n1)
    local pip=$(curl -s4 --connect-timeout 3 ip.sb 2>/dev/null || echo "无法获取")
    echo -e "┌──────────────────────────────────────┐"
    echo -e "│  OpenList 安装成功！                 │"
    echo -e "│  版本: $ver"
    echo -e "│  局域网: http://${lip}:5244/"
    echo -e "│  公网:   http://${pip}:5244/"
    echo -e "│  配置: $INSTALL_PATH/data/"
    [ -n "$ADMIN_USER" ] && echo -e "│  账号: $ADMIN_USER"
    [ -n "$ADMIN_PASS" ] && echo -e "│  密码: $ADMIN_PASS"
    echo -e "└──────────────────────────────────────┘"
    echo -e "\n${YELLOW}防火墙: iptables -I INPUT -p tcp --dport 5244 -j ACCEPT${RES}"
    echo -e "${GREEN}管理: openlist${RES}（先执行: export PATH=\$PATH:/opt/bin）"
    exit 0
}
# ═══════════════════════════════════════════════
#  更新
# ═══════════════════════════════════════════════
do_update() {
    [ ! -f "$INSTALL_PATH/openlist" ] && { echo -e "${RED}未安装${RES}"; exit 1; }
    echo -e "${GREEN}更新 OpenList...${RES}"
    ask_proxy
    # 版本检查
    local latest=$(curl -s --connect-timeout 10 "https://api.github.com/repos/OpenListTeam/OpenList/releases/latest" 2>/dev/null | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | grep . || echo "beta")
    if [ "$latest" != "beta" ]; then
        local cur_ver=""; [ -f "$VERSION_FILE" ] && cur_ver=$(head -n1 "$VERSION_FILE")
        [ "$cur_ver" = "$latest" ] && { echo -e "${GREEN}已是最新 ($cur_ver)${RES}"; return 0; }
        GH_DL="${GH_DL/latest/download/$latest}"
    fi
    svc stop; killall openlist 2>/dev/null
    cp "$INSTALL_PATH/openlist" /tmp/openlist.bak
    local f=$(dl_file)
    download "${GH_DL}/${f}" "/tmp/openlist.tar.gz" || { mv /tmp/openlist.bak "$INSTALL_PATH/openlist"; svc start; exit 1; }
    tar zxf /tmp/openlist.tar.gz -C "$INSTALL_PATH/" || { mv /tmp/openlist.bak "$INSTALL_PATH/openlist"; svc start; rm -f /tmp/openlist.tar.gz; exit 1; }
    chmod +x "$INSTALL_PATH/openlist"
    local ver=$("$INSTALL_PATH/openlist" version 2>&1 | grep "^Version:" | sed 's/Version://;s/ //g' | grep . || echo "$latest")
    echo "$ver" > "$VERSION_FILE"; date '+%Y-%m-%d %H:%M:%S' >> "$VERSION_FILE"
    rm -f /tmp/openlist.tar.gz /tmp/openlist.bak
    svc start
    echo -e "${GREEN}更新完成: $ver${RES}"
}
# ═══════════════════════════════════════════════
#  卸载
# ═══════════════════════════════════════════════
do_uninstall() {
    [ ! -f "$INSTALL_PATH/openlist" ] && { echo -e "${RED}未安装${RES}"; exit 1; }
    echo -e "${RED}将删除所有数据！${RES}"
    read -p "确认卸载？[y/N]: " c
    [ "$c" != "y" ] && [ "$c" != "Y" ] && exit 0
    svc stop; killall openlist 2>/dev/null
    svc disable 2>/dev/null
    crontab -l 2>/dev/null | grep -v "openlist" | crontab - 2>/dev/null
    rm -rf "$INSTALL_PATH"
    rm -f /etc/init.d/openlist /opt/etc/init.d/openlist "$MANAGER_PATH" "$CMD_LINK"
    uci delete jd_plugin.openlist 2>/dev/null; uci commit jd_plugin 2>/dev/null
    echo -e "${GREEN}已卸载${RES}"; exit 0
}
# ═══════════════════════════════════════════════
#  状态
# ═══════════════════════════════════════════════
do_status() {
    echo -e "${GREEN}── OpenList 状态 ──${RES}"
    if svc_active; then echo -e "  服务: ${GREEN}运行中${RES}"; else echo -e "  服务: ${RED}已停止${RES}"; fi
    [ -f "$VERSION_FILE" ] && echo -e "  版本: $(head -n1 "$VERSION_FILE")"
    netstat -tlnp 2>/dev/null | grep -q ":5244" && echo -e "  端口: ${GREEN}5244${RES}" || echo -e "  端口: ${RED}未监听${RES}"
    df -h /opt 2>/dev/null | awk 'NR==2{printf "  /opt: %s/%s\n", $3, $2}'
    [ -f "/opt/etc/init.d/openlist" ] && echo -e "  持久化: ${GREEN}✓${RES}" || echo -e "  持久化: ${RED}✗${RES}"
    uci get jd_plugin.openlist 2>/dev/null >/dev/null && echo -e "  UCI: ${GREEN}✓${RES}" || echo -e "  UCI: ${RED}✗${RES}"
}
# ═══════════════════════════════════════════════
#  密码
# ═══════════════════════════════════════════════
do_passwd() {
    [ ! -f "$INSTALL_PATH/openlist" ] && { echo -e "${RED}未安装${RES}"; return 1; }
    echo -e "1)随机  2)设置  3)日志提取  4)重置DB  0)返回"
    read -p "选择: " c
    case "$c" in
        1) cd "$INSTALL_PATH"; ./openlist admin random ;;
        2) read -p "新密码: " p; cd "$INSTALL_PATH"; ./openlist admin set "$p" ;;
        3) logread 2>/dev/null | grep -i "password" | tail -5 ;;
        4) read -p "输入 RESET: " cf
           [ "$cf" = "RESET" ] && { svc stop; mv "$INSTALL_PATH/data" "$INSTALL_PATH/data.bak.$(date +%Y%m%d%H%M%S)" 2>/dev/null; mkdir -p "$INSTALL_PATH/data"; svc start; sleep 2; cd "$INSTALL_PATH"; ./openlist admin random; } || echo "取消" ;;
    esac
}
# ═══════════════════════════════════════════════
#  菜单
# ═══════════════════════════════════════════════
menu() {
    echo -e "\n${CYAN}OpenList 管理 (JDBox适配)${RES}\n"
    echo -e " ${GREEN}1${RES})安装  ${GREEN}2${RES})更新  ${GREEN}3${RES})卸载"
    echo -e " ${GREEN}4${RES})状态  ${GREEN}5${RES})密码"
    echo -e " ${GREEN}6${RES})启动  ${GREEN}7${RES})停止  ${GREEN}8${RES})重启"
    echo -e " ${GREEN}0${RES})退出"
    read -p "选择: " c
    case "$c" in
        1) chk_space; do_install ;;
        2) do_update ;;
        3) do_uninstall ;;
        4) do_status ;;
        5) do_passwd ;;
        6) svc start; echo -e "${GREEN}已启动${RES}" ;;
        7) svc stop; echo -e "${GREEN}已停止${RES}" ;;
        8) svc restart; echo -e "${GREEN}已重启${RES}" ;;
        0) exit 0 ;;
    esac
}
# ═══════════════════════════════════════════════
#  入口
# ═══════════════════════════════════════════════
case "$1" in
    install)   chk_space; do_install ;;
    update)    do_update ;;
    uninstall) do_uninstall ;;
    status)    do_status ;;
    passwd)    do_passwd ;;
    start)     svc start ;;
    stop)      svc stop ;;
    restart)   svc restart ;;
    "")
        while true; do menu; echo; read -s -n1 -p "按任意键继续..."; clear; done ;;
    *) echo "用法: bash $0 [install|update|uninstall|status|start|stop|restart]" ;;
esac