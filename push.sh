#!/bin/bash
# ClawChat 代码推送脚本
# 在本地机器上运行此脚本来推送代码到 GitHub

echo "=== ClawChat 代码推送脚本 ==="
echo ""

# 检查是否在正确的目录
if [ ! -d ".git" ]; then
    echo "❌ 错误：当前目录不是 Git 仓库"
    echo "请先克隆仓库："
    echo "  git clone https://github.com/inteye/ClawChat.git"
    exit 1
fi

echo "✅ 检测到 Git 仓库"
echo ""

# 显示当前状态
echo "=== 当前状态 ==="
git status
echo ""

# 显示远程仓库
echo "=== 远程仓库 ==="
git remote -v
echo ""

# 拉取最新代码（如果有）
echo "=== 拉取远程更新 ==="
git pull origin main --rebase
echo ""

# 推送代码
echo "=== 推送代码到 GitHub ==="
git push origin main

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ 代码推送成功！"
    echo ""
    echo "查看你的仓库："
    echo "  https://github.com/inteye/ClawChat"
else
    echo ""
    echo "❌ 推送失败"
    echo ""
    echo "可能的原因："
    echo "1. 需要配置 GitHub 认证"
    echo "2. 网络连接问题"
    echo "3. 权限不足"
    echo ""
    echo "解决方法："
    echo "1. 配置 SSH 密钥: https://docs.github.com/en/authentication/connecting-to-github-with-ssh"
    echo "2. 或使用 Personal Access Token"
    echo "3. 或使用 GitHub Desktop"
fi
