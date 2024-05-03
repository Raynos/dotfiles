# create projects folder
set -e
# set -x

if [ ! -e ~/projects ]; then
    mkdir ~/projects
fi

if [ ! -e ~/.extra ]; then
    touch ~/.extra
fi

echo ""
echo "Configuring git email & name"

# Configure git
if ( ! git config --global user.email 1>/dev/null ); then
    echo " - Setting global user.email"
    read -p "Please enter email: " email
    git config --global user.email "$email"
fi

if ( ! grep 'git config --global user.email' 1>/dev/null 2>/dev/null ~/.extra ); then
    echo " - Storing global user.email in ~/.extra"
    echo "git config --global user.email '$email'" >> ~/.extra
fi

if ( ! git config --global user.name 1>/dev/null ); then
    echo " - Setting global user.name"
    read -p "Please enter username: " username
    git config --global user.name "$username"
fi

if ( ! grep 'git config --global user.name' 1>/dev/null 2>/dev/null ~/.extra ); then
    echo " - Storing global user.name in ~/.extra"
    echo "git config --global user.name '$username'" >> ~/.extra
fi

echo ""
echo "Checking curl"

if ( hash curl 2>/dev/null ); then
    echo " - Already installed curl"
else
    echo " - Fetching curl"
    sudo apt-get install curl
fi

echo ""
echo "Checking make"

if ( hash make 2>/dev/null ); then
    echo " - Already installed make"
else
    echo " - Fetching make"
    sudo apt-get install make
fi

echo ""
echo "Checking htop"

if ( hash htop 2>/dev/null ); then
    echo " - Already installed htop"
else
    echo " - Fetching htop"
    sudo apt-get install htop
fi

echo ""
echo "Checking jq"

if ( hash jq 2>/dev/null ); then
    echo " - Already installed jq"
else
    echo " - Fetching jq"
    sudo apt-get install jq
fi

echo ""
echo "Checking vim"

if ( hash vim 2>/dev/null ); then
    echo " - Already installed vim"
else
    echo " - Fetching vim"
    sudo apt-get install vim
fi

echo ""
echo "Checking rupa/z"

# install z
if [ ! -e ~/projects/z ]; then
    echo " - Fetching rupa/z"
    cd ~/projects
    git clone git@github.com:rupa/z
else
    echo " - Already installed rupa/z"
fi

echo ""
echo "Checking creationix/nvm"

if [ ! -e ~/projects/nvm ]; then
    echo " - Fetching creationix/nvm"
    cd ~/projects
    git clone git@github.com:creationix/nvm
    . ./nvm/nvm.sh
else
    echo " - Already installed creationix/nvm"
fi


echo ""
echo "Checking node@18.16.1"

if [ "$(node -v 2>/dev/null)" != "v18.16.1" ]; then
    echo " - Fetching node@18.16.1"
    . ~/projects/nvm/nvm.sh
    nvm install v18.16.1
    nvm use v18.16.1
else
    echo " - Already installed node@18.16.1";
fi


echo ""
echo "Checking Chrome"

if ( hash google-chrome 2>/dev/null ); then
    echo " - Already installed Chrome"
else
    echo " - Fetching Chrome"
    wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    sudo apt-get install libappindicator1
    sudo dpkg -i google-chrome*.deb
    sudo apt-get -f install
fi

echo ""
echo "Checking vs code"

if ( hash code 2>/dev/null ); then
    echo " - Already installed vs code"
else
    echo " - Fetching vs code"

    sudo apt-get install wget gpg
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
    sudo install -D -o root -g root -m 644 packages.microsoft.gpg /etc/apt/keyrings/packages.microsoft.gpg
    sudo sh -c 'echo "deb [arch=amd64,arm64,armhf signed-by=/etc/apt/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
    rm -f packages.microsoft.gpg


    sudo apt install apt-transport-https
    sudo apt update
    sudo apt install code # or code-insiders
fi

echo ""
echo "Checking terminator"

if ( hash terminator 2>/dev/null ); then
    echo " - Already installed Terminator"
else
    echo " - Fetching terminator"
    sudo apt-get install terminator
fi

echo ""
echo "Checking pygmentize"

if ( hash pygmentize 2>/dev/null ); then
    echo " - Already installed pygmentize"
else
    echo " - Fetching pygmentize"
    sudo apt-get install python3 -pygments
fi

echo ""
echo "Checking go"

if ( hash go 2>/dev/null ); then
    echo " - Already installed go"
else
    echo " - Fetching go"
    wget https://storage.googleapis.com/golang/go1.20.5.linux-amd64.tar.gz
    sudo tar -C /usr/local -xzf go1.20.5.linux-amd64.tar.gz
fi


echo ""
echo "Checking graphviz"

if ( hash dot 2>/dev/null ); then
    echo " - Already installed graphviz"
else
    echo " - Fetching graphviz"
    sudo apt-get install graphviz
fi

echo ""
echo "Checking github/hub"

if ( hash hub 2>/dev/null ); then
    echo " - Already installed github/hub"
else
    echo " - Fetching hub"
    wget https://github.com/github/hub/releases/download/v2.14.2/hub-linux-amd64-2.14.2.tgz
    tar -C ~/projects -xzf hub-linux-amd64-2.14.2.tgz
    mv ~/projects/hub-linux-amd64-2.14.2 ~/projects/hub
    ln -s ~/projects/hub/bin/hub ~/bin/hub
fi

echo ""
echo "Checking g++"

if ( hash g++ 2>/dev/null ); then
    echo " - Already installed g++"
else 
    echo " - Fetching g++"
    sudo apt-get install g++
fi

# echo ""
# echo "Checking nano"

# function __install_nano() {
#     echo " - Fetching nano"
#     sudo apt-get install libncurses5-dev
#     cd ~/projects
#     wget "http://www.nano-editor.org/dist/v2.3/nano-2.3.2.tar.gz"
#     tar -zxvf nano-2.3.2.tar.gz
#     cd nano-2.3.2
#     ./configure
#     make
#     sudo make install
#     cd ..
#     rm nano-2.3.2.tar.gz
# }

# if ( hash nano 2>/dev/null ); then
#     if ( nano -V | grep "2.3.2" 1>/dev/null ); then
#         echo " - Already installed nano"
#     else 
#         __install_nano
#     fi
# else
#     __install_nano
# fi


echo ""
echo "Install node"

if ( which /usr/local/bin/node 1>/dev/null ); then
    echo " - Already installed node"
else
    echo " - Fetching node"
    cd ~/projects
    if [ ! -e ~/projects/node ]; then
        git clone git@github.com:nodejs/node
    fi
    cd node
    git checkout v20.12.2
    ./configure
    make -j 5
    sudo make install
    cd ..
fi


echo ""
echo "All finished"
