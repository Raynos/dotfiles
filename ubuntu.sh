# Set the launcher to auto hide
gsettings set org.gnome.shell.extensions.dash-to-dock intellihide false
gsettings set org.gnome.shell.extensions.dash-to-dock dock-fixed false
gsettings set org.gnome.shell.extensions.dash-to-dock autohide true


# Set the number of workspace to 4x4
# dconf write /org/compiz/profiles/unity/plugins/core/vsize 4;
# dconf write /org/compiz/profiles/unity/plugins/core/hsize 4;

# Set ubuntu tree wallpaper as background
dconf write /org/gnome/desktop/background/picture-uri "'file:///home/raynos/projects/dotfiles/ubuntu-wallpaper.jpg'";


wget https://github.com/mzur/gnome-shell-wsmatrix/releases/download/v7.3/wsmatrix@martin.zurowietz.de.zip
mkdir -p ~/.local/share/gnome-shell/extensions/wsmatrix@martin.zurowietz.de
unzip wsmatrix@martin.zurowietz.de.zip -d ~/.local/share/gnome-shell/extensions/wsmatrix@martin.zurowietz.de
rm wsmatrix@martin.zurowietz.de.zip

gnome-extensions enable wsmatrix@martin.zurowietz.de
gnome-extensions prefs wsmatrix@martin.zurowietz.de
