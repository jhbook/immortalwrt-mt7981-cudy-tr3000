#!/usr/bin/env bash
#
# 本地编译 Cudy TR3000 (MT7981) ImmortalWrt 固件
# 流程与 .github/workflows/openwrt-builder.yml 完全一致，只是把 GitHub Actions 换成本机/服务器
#
# 用法:
#   ./local-build.sh                 # 编译 256M（默认）
#   ./local-build.sh 128M            # 编译 128M（普通 64M ubi 布局）
#   ./local-build.sh 128M-Ubootmod   # 编译 ubootmod 112M 布局
#   ./local-build.sh 122M            # 编译 ubootmod 122M 布局
#   ./local-build.sh all             # 依次编译 256M / 128M / 128M-Ubootmod / 122M
#
# 可选环境变量:
#   WORKDIR=$HOME/openwrt-build  源码与产物目录（默认 $HOME/openwrt-build）
#   JOBS=8                       并行任务数（默认 nproc，16G 内存建议不超过 8）
#   SKIP_DEPS=1                  跳过 apt 安装依赖
#   NO_CCACHE=1                  不使用 ccache
#
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/padavanonly/immortalwrt-mt798x-6.6}"
REPO_BRANCH="${REPO_BRANCH:-openwrt-24.10-6.6}"
WORKDIR="${WORKDIR:-$HOME/openwrt-build}"
SRC="$WORKDIR/openwrt"
JOBS="${JOBS:-$(nproc)}"
CCACHE_MAXSIZE="${CCACHE_MAXSIZE:-5G}"

# diy-part1.sh / diy-part2.sh 里引用了 $GITHUB_WORKSPACE，这里指向本仓库目录
export GITHUB_WORKSPACE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '\n\033[1;32m==> %s\033[0m\n' "$*"; }
die() { printf '\n\033[1;31m!! %s\033[0m\n' "$*" >&2; exit 1; }

[ -f "$GITHUB_WORKSPACE/config/256m.config" ] || die "请在本仓库根目录运行（找不到 config/256m.config）"

# ---------- 1. 依赖 ----------
install_deps() {
  [ "${SKIP_DEPS:-0}" = "1" ] && { log "SKIP_DEPS=1，跳过依赖安装"; return; }
  command -v apt-get >/dev/null || die "本脚本的依赖安装仅支持 Debian/Ubuntu，请手动安装 OpenWrt 编译依赖"
  log "安装编译依赖（需要 sudo）"
  sudo -E apt-get -qq update
  sudo -E apt-get -qq install -y --no-install-recommends \
    ack antlr3 asciidoc autoconf automake autopoint binutils bison build-essential bzip2 ccache clang cmake cpio \
    curl device-tree-compiler ecj fastjar flex gawk gettext gcc-multilib g++-multilib git gnutls-dev gperf haveged \
    help2man intltool lib32gcc-s1 libc6-dev-i386 libelf-dev libglib2.0-dev libgmp3-dev libltdl-dev libmpc-dev \
    libmpfr-dev libncurses-dev libpython3-dev libreadline-dev libssl-dev libtool libyaml-dev libz-dev lld llvm \
    lrzsz mkisofs msmtp nano ninja-build p7zip p7zip-full patch pkgconf python3 python3-pip python3-ply \
    python3-docutils python3-pyelftools qemu-utils re2c rsync scons squashfs-tools subversion swig texinfo \
    uglifyjs upx-ucl unzip vim wget xmlto xxd zlib1g-dev zstd
}

# ---------- 2. 源码 ----------
clone_source() {
  mkdir -p "$WORKDIR"
  if [ -d "$SRC/.git" ]; then
    log "源码已存在，跳过 clone: $SRC"
  else
    log "克隆源码 $REPO_URL ($REPO_BRANCH) 到 $SRC"
    git clone "$REPO_URL" -b "$REPO_BRANCH" --single-branch --filter=blob:none "$SRC"
  fi
}

# ---------- 3. diy 脚本 + feeds ----------
prepare() {
  cd "$SRC"
  chmod +x "$GITHUB_WORKSPACE/diy-part1.sh" "$GITHUB_WORKSPACE/diy-part2.sh"
  log "diy-part1.sh（feeds 更新前）"
  "$GITHUB_WORKSPACE/diy-part1.sh"
  log "更新并安装 feeds"
  # 单个 feed 更新失败（如 GitHub TLS 抖动）不该中断整轮编译：本地已有 feed 副本可继续用
  ./scripts/feeds update -a || log "⚠ 部分 feed 更新失败（网络抖动），改用本地已有副本继续"
  ./scripts/feeds install -a
  log "diy-part2.sh（feeds 安装后：默认主题 Argon + 南大软件源）"
  "$GITHUB_WORKSPACE/diy-part2.sh"

  # 校验关键改动是否落地
  grep -q 'mirror.nju.edu.cn' include/version.mk && log "✔ include/version.mk 已指向 mirror.nju.edu.cn" || log "⚠ 未在 include/version.mk 找到南大源"
  grep -q 'luci-theme-argon' feeds/luci/collections/luci-light/Makefile && log "✔ luci-light 集合默认主题已改为 argon" || log "⚠ luci-light 集合未改写"
  [ -f package/base-files/files/etc/uci-defaults/99-luci-theme-argon ] && log "✔ 99-luci-theme-argon 已写入" || log "⚠ 99-luci-theme-argon 缺失"
  [ -d package/luci-app-run ] && log "✔ luci-app-run 已就位" || log "⚠ luci-app-run 未找到"
}

# ---------- 4. 编译单个设备 ----------
build_device() {
  local dev="$1" cfg
  case "$dev" in
    256M)            cfg="config/256m.config" ;;
    128M)            cfg="config/128m.config" ;;
    128M-Ubootmod|128muboot) cfg="config/128muboot.config" ;;
    122M|122M-Ubootmod|122m) cfg="config/122m.config" ;;
    *) die "未知设备 '$dev'，可选：256M / 128M / 128M-Ubootmod / 122M / all" ;;
  esac
  [ -f "$GITHUB_WORKSPACE/$cfg" ] || die "找不到 $cfg"

  cd "$SRC"
  log "加载 $cfg 并 make defconfig"
  cp -f "$GITHUB_WORKSPACE/$cfg" .config
  make defconfig

  # 112M / 122M 的区别只在设备树的 ubi 分区大小，每台设备编译前都要重新设置一遍
  chmod +x "$GITHUB_WORKSPACE/diy-device.sh"
  "$GITHUB_WORKSPACE/diy-device.sh" "$dev"

  # config 里 CONFIG_CCACHE_DIR="/workdir/.ccache" 是 GitHub Actions 的路径，
  # 本地没有 /workdir 且根目录不可写，会导致 host 工具链全线失败：
  #   ccache: error: Failed to create directory /workdir/.ccache/lock: Permission denied
  #   configure: error: cannot compute suffix of object files: cannot compile
  if grep -q '^CONFIG_CCACHE_DIR=' .config; then
    sed -i "s|^CONFIG_CCACHE_DIR=.*|CONFIG_CCACHE_DIR=\"${CCACHE_DIR:-$HOME/.cache/ccache}\"|" .config
    log "✔ CONFIG_CCACHE_DIR 已改为 $(sed -n 's/^CONFIG_CCACHE_DIR="\(.*\)"/\1/p' .config)"
  fi

  # OpenWrt 里有两个开关会把整套 host Rust 工具链拖进来（rustc 要从源码 bootstrap：
  # 8 核约 2 小时、额外 10G+ 磁盘），本地编译默认把它们关掉来绕开 Rust：
  #   1) CONFIG_PACKAGE_libopenssl-afalg_sync —— afalg_engine（Rust 写的 OpenSSL AF_ALG engine）
  #   2) CONFIG_RUBY_ENABLE_YJIT             —— ruby 的 YJIT 要 rustc（ruby 本体仍照常编译）
  # 想按云端配置原样完整编译（会编 Rust）用 SKIP_RUST=0 ./local-build.sh 128M
  if [ "${SKIP_RUST:-1}" = "1" ]; then
    if grep -q '^CONFIG_PACKAGE_libopenssl-afalg_sync=y' .config; then
      sed -i 's/^CONFIG_PACKAGE_libopenssl-afalg_sync=y/# CONFIG_PACKAGE_libopenssl-afalg_sync is not set/' .config
      log "✔ 已关闭 libopenssl-afalg_sync（不再需要 Rust 工具链）"
    fi
    if grep -q '^CONFIG_RUBY_ENABLE_YJIT=y' .config; then
      sed -i 's/^CONFIG_RUBY_ENABLE_YJIT=y/# CONFIG_RUBY_ENABLE_YJIT is not set/' .config
      log "✔ 已关闭 RUBY_ENABLE_YJIT（不再需要 Rust 工具链；ruby 本体不受影响）"
    fi
  fi

  # 确认 argon / luci-app-run 没被 defconfig 丢掉
  if grep -q '^CONFIG_PACKAGE_luci-theme-argon=y' .config; then
    log "✔ .config 中 luci-theme-argon=y"
  else
    log "⚠ .config 中 luci-theme-argon 不是 y，请检查 luci feed 是否含该主题"
  fi
  if grep -q '^CONFIG_PACKAGE_luci-app-run=y' .config; then
    log "✔ .config 中 luci-app-run=y"
  else
    log "⚠ .config 中 luci-app-run 不是 y（包可能未被识别）"
  fi

  log "下载源码包 make download -j$JOBS"
  make download -j"$JOBS"

  local CC_ARGS=()
  if [ "${NO_CCACHE:-0}" != "1" ] && command -v ccache >/dev/null; then
    ccache --set-config=max_size="$CCACHE_MAXSIZE" >/dev/null 2>&1 || true
    CC_ARGS=(CC="ccache gcc" CXX="ccache g++")
    log "使用 ccache 加速（上限 $CCACHE_MAXSIZE）"
  fi

  log "开始编译 [$dev]  -j$JOBS"
  if ! make -j"$JOBS" "${CC_ARGS[@]}"; then
    log "多线程失败，改用单线程 V=s 重试"
    make -j1 V=s
  fi

  # 112M 与 122M 共用同一个 profile，生成的固件文件名完全相同，必须按变体重命名后再收集
  local suffix=""
  case "$dev" in
    128M-Ubootmod|128muboot) suffix="-ubootmod-112m" ;;
    122M|122M-Ubootmod|122m) suffix="-ubootmod-122m" ;;
  esac
  mkdir -p "$GITHUB_WORKSPACE/firmware_collection"
  find bin/targets -name '*sysupgrade.bin' | while read -r f; do
    base="$(basename "$f")"
    [ -n "$suffix" ] && base="${base/-ubootmod-/${suffix}-}"
    cp -f "$f" "$GITHUB_WORKSPACE/firmware_collection/$base"
    log "  → $base"
  done
  log "[$dev] 编译完成，产物已复制到 $GITHUB_WORKSPACE/firmware_collection/"
}

# ---------- main ----------
install_deps
clone_source
prepare

case "${1:-256M}" in
  all) for d in 256M 128M 128M-Ubootmod 122M; do build_device "$d"; done ;;
  *)   build_device "${1:-256M}" ;;
esac

log "全部完成"
ls -lh "$GITHUB_WORKSPACE/firmware_collection/" 2>/dev/null || true
