#!/bin/bash
# GitHub SSH 密钥配置脚本

echo "=== GitHub SSH 密钥配置向导 ==="
echo ""

# 检查是否已有密钥
if [ -f ~/.ssh/id_ed25519 ]; then
    echo "✅ 检测到现有 SSH 密钥"
    echo ""
    echo "你的公钥是："
    echo "----------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    echo ""
    echo "请复制上面的公钥，然后："
    echo "1. 访问 https://github.com/settings/keys"
    echo "2. 点击 'New SSH key'"
    echo "3. 粘贴公钥"
    echo "4. 点击 'Add SSH key'"
else
    echo "⚠️  未检测到 SSH 密钥，正在生成..."
    echo ""
    
    # 生成新密钥
    ssh-keygen -t ed25519 -C "clawchat@server" -f ~/.ssh/id_ed25519 -N ""
    
    echo ""
    echo "✅ SSH 密钥已生成！"
    echo ""
    echo "你的公钥是："
    echo "----------------------------------------"
    cat ~/.ssh/id_ed25519.pub
    echo "----------------------------------------"
    echo ""
    echo "请复制上面的公钥，然后："
    echo "1. 访问 https://github.com/settings/keys"
    echo "2. 点击 'New SSH key'"
    echo "3. 粘贴公钥"
    echo "4. 点击 'Add SSH key'"
fi

echo ""
echo "配置完成后，测试连接："
echo "  ssh -T git@github.com"
echo ""
echo "然后就可以推送了："
echo "  cd /root/.openclaw/workspace/projects/openclaw-connect-app"
echo "  git push origin main"
