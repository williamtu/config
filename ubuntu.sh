# packages for building kernel

# pwclient
curl -L https://patchwork.kernel.org/pwclient/

# for new machine and kernel

# timezone setup
timedatectl set-timezone America/Los_Angeles
timedatectl


apt-get update

apt-get install -y --no-install-recommends \
    bc                           \
    build-essential              \
    git                          \
    vim                          \
    libncurses-dev               \
    libssl-dev                   \
    wget                         \
    xz-utils ctags 		 \
    libcap-dev libelf-dev	 \
    bison flex

# for net-next/tools/
apt-get install -y gcc-multilib libc6-i386 libc6-dev-i386

# clone this repo
git clone https://github.com/williamtu/config.git

# clone net-next
git clone git://git.kernel.org/pub/scm/linux/kernel/git/davem/net-next.git
cd net-next
make olddefconfig 
make -j8 && make modules_install && make install && reboot 


apt-get -y install bison flex
git clone git://git.kernel.org/pub/scm/linux/kernel/git/shemminger/iproute2.git 
cd iproute2
make && make install

