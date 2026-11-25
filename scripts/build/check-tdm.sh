#!/bin/bash
K=/home/weng/pmos-build/kernel-src/linux-sm8250-7.2.0_git20261010
sed -n '85,125p' "$K/sound/soc/qcom/sm8250.c"
echo "-----"
sed -n '225,260p' "$K/sound/soc/qcom/sm8250.c"
echo "-----"
sed -n '300,350p' "$K/sound/soc/qcom/sm8250.c"
