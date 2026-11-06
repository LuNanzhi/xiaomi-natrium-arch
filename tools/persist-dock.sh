#!/bin/sh
cat > /home/arch/.xsession <<'EOF'
#!/bin/sh
# --- onboard keyboard: docked to the bottom, never self-repositioning ---
gsettings set org.onboard.window docking-enabled true
gsettings set org.onboard.window docking-edge 'bottom'
gsettings set org.onboard.window docking-shrink-workarea true
gsettings set org.onboard.window.portrait dock-width 1080
gsettings set org.onboard.window.portrait dock-height 420
gsettings set org.onboard.window.portrait dock-expand true
gsettings set org.onboard.window.landscape dock-width 1920
gsettings set org.onboard.window.landscape dock-height 420
gsettings set org.onboard.auto-show reposition-method-floating none
gsettings set org.onboard.auto-show reposition-method-docked none
gsettings set org.onboard.auto-show enabled false
exec i3
EOF
chmod 755 /home/arch/.xsession
chown arch:arch /home/arch/.xsession
echo "--- .xsession ---"
cat /home/arch/.xsession
