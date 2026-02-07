#!/bin/bash
# 打包项目文件，方便下载到本地

echo "=== 打包 ClawChat 项目 ==="

# 创建临时目录
TEMP_DIR="/tmp/clawchat_package"
rm -rf $TEMP_DIR
mkdir -p $TEMP_DIR

# 复制所有需要的文件
echo "正在复制文件..."
cp -r lib $TEMP_DIR/
cp -r docs $TEMP_DIR/
cp -r test $TEMP_DIR/
cp pubspec.yaml $TEMP_DIR/
cp analysis_options.yaml $TEMP_DIR/
cp README.md $TEMP_DIR/
cp LICENSE $TEMP_DIR/
cp .gitignore $TEMP_DIR/
cp PROGRESS_REPORT.md $TEMP_DIR/
cp QUICKSTART.md $TEMP_DIR/
cp HOW_TO_PUSH.md $TEMP_DIR/

# 创建压缩包
PACKAGE_NAME="clawchat_$(date +%Y%m%d_%H%M%S).tar.gz"
cd /tmp
tar -czf $PACKAGE_NAME clawchat_package/

echo ""
echo "✅ 打包完成！"
echo ""
echo "文件位置: /tmp/$PACKAGE_NAME"
echo "文件大小: $(du -h /tmp/$PACKAGE_NAME | cut -f1)"
echo ""
echo "下载到本地后，解压并复制到你的 ClawChat 仓库目录"
