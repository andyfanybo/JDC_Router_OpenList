# OpenList 安装管理脚本

一个为 JDBox/OpenWrt ARMv7l 路由器优化的 **OpenList** 完整安装、更新和管理脚本。

## 📋 功能概览

这个脚本提供了 OpenList 在 OpenWrt 路由器上的全生命周期管理：

| 功能 | 说明 |
|------|------|
| **安装** | 自动下载、解压、配置 OpenList 二进制文件 |
| **更新** | 检查最新版本并无缝升级（保留数据） |
| **卸载** | 完全清除所有文件和配置 |
| **状态** | 显示运行状态、版本、端口、磁盘占用等 |
| **密码管理** | 随机生成/设置管理员密码、查看日志、重置数据库 |
| **服务控制** | 启动、停止、重启服务 |

## 🚀 快速开始

### 前置要求

- Linux 系统（支持 OpenWrt）
- 需要 **root** 权限
- 已安装 `curl`
- 磁盘空间：`/tmp` 和 `/opt` 各至少 50MB

### 安装方式

#### 方式1：直接运行安装
```bash
bash install-openlist.sh install
```

#### 方式2：交互式菜单
```bash
bash /opt/install-openlist.sh
```
然后选择菜单选项：
```
1) 安装  2) 更新  3) 卸载
4) 状态  5) 密码
6) 启动  7) 停止  8) 重启
0) 退出
```

#### 方式3：命令行直接执行
```bash
bash install-openlist.sh [命令]
```

## 📖 完整命令列表

| 命令 | 功能 |
|------|------|
| `install` | 安装 OpenList |
| `update` | 更新到最新版本 |
| `uninstall` | 卸载 OpenList |
| `status` | 查看运行状态 |
| `passwd` | 管理管理员密码 |
| `start` | 启动服务 |
| `stop` | 停止服务 |
| `restart` | 重启服务 |

## 🏗️ 安装结构

安装完成后的目录结构：

```
/opt/
├── openlist/                      # 主程序目录
│   ├── openlist                   # 二进制文件
│   └── data/                      # 数据存储
├── etc/init.d/openlist            # 持久化启动脚本
├── bin/openlist                   # CLI 命令软链接
└── sbin/openlist-manager          # 管理脚本副本

/etc/init.d/openlist               # 系统启动脚本（副本）

UCI 配置：jd_plugin.openlist       # zaiecplugin 自动发现
```

## 🌐 访问方式

安装完成后，通过以下地址访问 OpenList 管理界面：

- **局域网访问**：`http://<路由器IP>:5244/`
- **公网访问**：`http://<公网IP>:5244/`

## 🔐 初始登录

安装时会自动生成随机管理员账号和密码，输出格式如下：

```
┌──────────────────────────────────────┐
│  OpenList 安装成功！                 │
│  版本: v1.0.0                        │
│  局域网: http://192.168.1.1:5244/   │
│  公网:   http://1.2.3.4:5244/       │
│  配置: /opt/openlist/data/          │
│  账号: admin                         │
│  密码: xxxxxxxxxxxxx                │
└──────────────────────────────────────┘
```

## 🛡️ 防火墙配置

如需公网访问，请添加防火墙规则：

```bash
iptables -I INPUT -p tcp --dport 5244 -j ACCEPT
```

OpenWrt 用户可在 Web 界面配置或编辑 `/etc/config/firewall`。

## 🔧 高级密码操作

运行 `bash install-openlist.sh passwd` 进入密码管理菜单：

```
1) 随机生成     - 随机生成新密码
2) 设置         - 手动设置密码
3) 日志提取     - 从系统日志查看之前的密码
4) 重置数据库   - 清除所有配置并重新初始化
0) 返回         - 返回上级菜单
```

## 🔄 更新机制

**更新命令**：
```bash
bash install-openlist.sh update
```

**特点**：
- 自动检查 GitHub 最新版本
- 保留已有数据和配置
- 更新失败自动回滚备份
- 对比版本号避免重复更新

## ⚙️ 架构支持

脚本自动检测 CPU 架构并下载对应版本：

| 架构 | 文件名 |
|------|--------|
| x86_64 | `openlist-linux-musl-amd64.tar.gz` |
| ARM64 | `openlist-linux-musl-arm64.tar.gz` |
| ARMv7l | `openlist-linux-musleabihf-armv7l.tar.gz` ⭐ |
| ARMv8l | `openlist-linux-musl-arm64.tar.gz` |
| LoongArch | `openlist-linux-musl-loong64.tar.gz` |

## 🌍 下载代理

脚本内置 GitHub 加速代理 `https://ghfast.top/`。

**更换代理**：
```bash
# 安装时会提示输入代理
代理: https://你的代理地址/
```

**使用官方源**：
```bash
代理: none
```

## 📊 状态检查

查看服务状态和系统信息：

```bash
bash install-openlist.sh status
```

**输出示例**：
```
── OpenList 状态 ──
  服务: 运行中
  版本: v1.0.0
  端口: 5244
  /opt: 25M/100M
  持久化: ✓
  UCI: ✓
```

## ⚠️ 故障排查

### 下载失败

- 检查网络连接
- 尝试更换 DNS：`8.8.8.8` 或 `1.1.1.1`
- 更换下载代理

### 磁盘空间不足

显示可用空间并询问是否继续：
```
/tmp: 20M  ← 需要至少 50M
/opt: 30M  ← 需要至少 50M
继续？[y/N]:
```

### 服务无法启动

检查二进制文件权限和依赖：
```bash
ls -la /opt/openlist/openlist
ldd /opt/openlist/openlist
```

### 忘记管理员密码

方法1 - 从日志提取：
```bash
bash install-openlist.sh passwd
# 选择 3) 日志提取
```

方法2 - 重置数据库：
```bash
bash install-openlist.sh passwd
# 选择 4) 重置DB
# 输入 RESET 确认
```

## 📝 版本追踪

每次安装/更新都会记录版本信息：

```bash
cat /opt/openlist/.version
```

**输出示例**：
```
v1.0.0
2024-06-17 14:32:15
```

## 🔨 管理脚本别名

安装后可设置环境变量使用 `openlist` 命令：

```bash
export PATH=$PATH:/opt/bin
openlist status
openlist restart
```

## 📦 与 zaiecplugin 集成

脚本自动在 UCI 中注册 OpenList 配置，zaiecplugin 可自动发现并管理：

```bash
uci get jd_plugin.openlist.version
```

## 🗑️ 完整卸载

运行卸载命令会删除：
- `/opt/openlist/` 全目录（包括数据）
- `/etc/init.d/openlist` 和 `/opt/etc/init.d/openlist`
- UCI 配置信息
- 所有定时任务

```bash
bash install-openlist.sh uninstall
```

## ⚡ 特殊特性

- ✅ **兼容 ash/busybox** - 不依赖 bash 关联数组
- ✅ **自动愈合** - 启动时检查脚本是否更新，自动同步到 `/etc/init.d/`
- ✅ **进程守护** - 使用 procd 自动重启崩溃的服务
- ✅ **持久化存储** - 支持系统重启后自动恢复
- ✅ **彩色输出** - 易于识别操作状态
- ✅ **重试机制** - 下载失败自动重试（最多3次）

## 📄 许可证

遵循 OpenList 原始项目的许可证。

## 🔗 相关资源

- [OpenList GitHub](https://github.com/OpenListTeam/OpenList)
- [OpenWrt 官网](https://openwrt.org/)
- [JDBox 社区](https://github.com/search?q=JDBox)

---

**脚本版本**：基于 OpenList 最新版本
