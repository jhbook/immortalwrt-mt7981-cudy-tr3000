#!/bin/bash
#
# 按「编译设备」做差异化的源码改造
#
# 为什么单独一个脚本：diy-part2.sh 在 GitHub Actions 的循环外只执行一次，
# 而 112M / 122M 的差异（设备树里的 ubi 分区大小）必须在每台设备 make 之前生效，
# 所以放进循环内按设备名调用。
#
# 用法: ./diy-device.sh <设备名>      # 128M / 256M / 128M-Ubootmod / 122M
#
set -e

DEV="${1:-}"
DTS="target/linux/mediatek/dts/mt7981b-cudy-tr3000-v1-ubootmod.dts"

if [ ! -f "$DTS" ]; then
  echo "!! 找不到设备树 $DTS（当前目录：$(pwd)）" >&2
  exit 1
fi

case "$DEV" in
  122M|122M-Ubootmod|122m)
    # ubootmod 设备树默认 ubi = 112M（0x7000000，起始 0x5c0000）
    # 122M 变体把它扩到 flash 末尾：0x5c0000 + 0x7a40000 = 0x8000000（正好 128MiB）
    # 刷机时 U-Boot 必须选择 122M 档位建立 ubi，否则两边不一致会 boot loop
    sed -i 's/reg = <0x5c0000 0x7000000>;/reg = <0x5c0000 0x7a40000>;/' "$DTS"
    sed -i 's/model = "Cudy TR3000 v1 ubi 112M";/model = "Cudy TR3000 v1 ubi 122M";/' "$DTS"
    if ! grep -q '0x7a40000' "$DTS"; then
      echo "!! 122M 设备树改写失败，请检查上游 DTS 是否变更" >&2
      exit 1
    fi
    ;;
  112M|128M-Ubootmod|128muboot)
    # 复位回 112M：连续编译多台设备时，避免上一轮 122M 的改动残留到这一轮
    sed -i 's/reg = <0x5c0000 0x7a40000>;/reg = <0x5c0000 0x7000000>;/' "$DTS"
    sed -i 's/model = "Cudy TR3000 v1 ubi 122M";/model = "Cudy TR3000 v1 ubi 112M";/' "$DTS"
    ;;
  *)
    # 普通 64M 版 / 256M 版用的是各自的 DTS，不需要动
    ;;
esac

echo "==> [$DEV] ubi: $(grep -o 'reg = <0x[0-9a-f]* 0x[0-9a-f]*>' "$DTS" | head -1)  model: $(grep -o 'model = "[^"]*"' "$DTS" | head -1)"
