# $env:CC="clang"
# $Env:DEVX_LIB_PATH = "C:\DevX_SDK\lib"
# $Env:DEVX_INC_PATH = "C:\DevX_SDK\inc"

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
lib_deps = []
prog_python = import('python').find_installation('python3')
global_inc = []

if use_dpdk_pkgconfig
# work with v20.02 DPDK
  lib_deps += dependency('libdpdk', required : true, static: true) 
endif

      add_project_link_arguments('-Wl,/FORCE:MULTIPLE', language: 'c')
      add_project_link_arguments('-Wl,/WHOLEARCHIVE', language: 'c')
      add_project_link_arguments('-lmincore', language: 'c')
      add_project_link_arguments('-ladvapi32', '-lsetupapi', language: 'c')
      add_project_link_arguments('-ldbghelp', language: 'c')

  windows_libs = [
        'Ws2_32', # Resolve symbols for Winsock
        'WbemUuid',
        'Shlwapi',
        'Iphlpapi',
    ]
	windows_deps = []
    foreach w : windows_libs
        lib_deps += cc.find_library(
            w,
            required : true,
        )
    endforeach

    enable_mlx5 = true 
    if enable_mlx5
        res_lib = run_command(prog_python, '-c', 'import os; print(os.environ["DEVX_LIB_PATH"])')
        devx_lib_dir = res_lib.stdout().strip()
        mlx5devx_lib = cc.find_library('mlx5devx', dirs: devx_lib_dir, required: true, static : false)
        windows_deps += mlx5devx_lib 

	res_inc = run_command(prog_python, '-c', 'import os; print(os.environ["DEVX_INC_PATH"])')
	devx_inc_dir = res_inc.stdout().strip()
	global_inc += include_directories(devx_inc_dir)
    endif


executable('mypktgen', 'main.c',
  dependencies: lib_deps,
  #  link_whole: dpdk_lib_deps,
  include_directories : includes)

