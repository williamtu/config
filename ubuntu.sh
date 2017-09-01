# packages for building kernel

# pwclient
curl -L https://patchwork.kernel.org/pwclient/

# for new machine and kernel

apt-get update && apt-get -y upgrade &&        \
    apt-get install -y --no-install-recommends \
    bc                           \
    build-essential              \
    git                          \
    vim                          \
    libncurses-dev               \
    libssl-dev                   \
    wget                         \
    xz-utils ctags 

# clone this repo
git clone https://github.com/williamtu/config.git

# clone net-next
git clone git://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git
cd net-next
make olddefconfig 
make -j8 && make modules_install && make install && reboot 


