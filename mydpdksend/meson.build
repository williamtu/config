# $env:CC="clang"
# .\meson59.exe --reconfigure build -Dpkg_config_path=C:\temp\dpdk\lib\pkgconfig\
# ninja -C build

project('example', 'c', 
   default_options: ['buildtype=debug', 'default_library=static'])

cc = meson.get_compiler('c')
includes = []
includes += include_directories('.')

#dpdk_lib_path = 'c:\\temp\dpdk'
#dpdk_inc_path = dpdk_lib_path + '\include'
#includes += include_directories(dpdk_inc_path)


use_dpdk_pkgconfig = true
dpdk_lib_deps = []

if use_dpdk_pkgconfig
  dpdk_lib_deps = dependency('libdpdk', required : true, static: true) 
endif

executable('mypktgen', 'main.c',
  dependencies: dpdk_lib_deps,
  #  link_whole: dpdk_lib_deps,
  include_directories : includes)

