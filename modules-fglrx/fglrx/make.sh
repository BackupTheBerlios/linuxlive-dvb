#!/bin/bash
# ==============================================================
# make.sh
# (C) 2001 by ATI Technologies
# ==============================================================


# ==============================================================
# local variables and files
current_wd=`pwd`
logfile=$current_wd/make.sh.log	# DKMS uses name 'make.log', so that we need another name

# project name
MODULE=fglrx

FGL_PUBLIC=firegl
target_define=FGL_RX


# package defaults
#BEGIN-DEFAULT
#END-DEFAULT

# package custom overrides, created by installer
#BEGIN-CUSTOM
#END-CUSTOM

# vendor options

# default options
OPTIONS_HINTS=1

# sets the GCC to use to the one required by the module (if available)
function set_GCC_version () {
  #identify GCC default version major number
  GCC_MAJOR="`gcc --version | grep -o -e "(GCC) ." | cut -d " " -f 2`"

  #identify the GCC major version that compiled the kernel
  KERNEL_GCC_MAJOR="`cat /proc/version | grep -o -e "gcc version ."  | cut -d " " -f 3`"

  #see if they don't match
  if [ ${GCC_MAJOR} != ${KERNEL_GCC_MAJOR} ]; then
       #use kernel GCC version hopefully
       KERNEL_GCC="`cat /proc/version | grep -o -e "gcc version [0-9]\.[0-9]" | cut -d " " -f 3`"
       CC="gcc-${KERNEL_GCC}"

       # check if gcc version requested exists
       GCC_AVAILABLE="`${CC} --version | grep -e "(GCC)" |cut -d " " -f 3 | cut -c-3`"
    
       if [ ${GCC_AVAILABLE} != ${KERNEL_GCC} ]; then
           echo "The GCC version that is required to compile this module is version ${KERNEL_GCC}."
           echo "Please install this GCC or recompile your kernel with ${GCC_AVAILABLE}"
           exit 1
       fi
  fi
}

if [ -z "${CC}" ]; then 
	CC=gcc
	set_GCC_version
fi

# parse options
if [ "$1" = "--nohints" ]; then
  OPTIONS_HINTS=0
fi
  

# ==============================================================
# system/kernel identification
if [ -z "${uname_r}" ]; then
  uname_r=$(uname -r)
fi


# ==============================================================
# xfree and system locations                                                          
XF_ROOT=/usr/X11R6                                                                    
XF_BIN=$XF_ROOT/bin
OS_MOD=/lib/modules


# ==============================================================


# ==============================================================
# resolve commandline parameters

# (none at the moment)


# ==============================================================
# assign defaults to non-sepcified environment parameters
if [ -z "${SOURCE_PREFIX}" ]; then
  SOURCE_PREFIX=.
fi
if [ "${SOURCE_PREFIX}" != "/" ]; then
  SOURCE_PREFIX=`echo $SOURCE_PREFIX | sed -e 's,/$,,g'`
fi

if [ -z "${LIBIP_PREFIX}" ]; then
  LIBIP_PREFIX=.
fi
if [ "${LIBIP_PREFIX}" != "/" ]; then
  LIBIP_PREFIX=`echo $LIBIP_PREFIX | sed -e 's,/$,,g'`
fi


# ==============================================================
# specify defaults for include file locations

# assing default location of linux kernel headers
if [ -z "${KERNEL_PATH}" ]; then
  if [ ! -d "/lib/modules/${uname_r}" ]; then
    echo "Directory /lib/modules/${uname_r} does not exist (or is not a directory)"
    exit 1
  fi
  if [ ! -L "/lib/modules/${uname_r}/build" ]; then
    echo "Link /lib/modules/${uname_r}/build does not exist (or is not a link)"
    exit 1
  fi
  KERNEL_PATH=$(readlink -f "/lib/modules/${uname_r}/build")
  if [ ! -d "${KERNEL_PATH}" ]; then
    echo "Please install the sources for kernel version ${uname_r}"
    echo "and unpack them into directory ${KERNEL_PATH}"
    exit 1
  fi
fi

linuxincludes=${KERNEL_PATH}/include

# ==============================================================
# print a few statistics, helpful for analyzing any build failures
echo ATI module generator V 2.0 | tee $logfile
echo ========================== | tee -a $logfile
echo initializing...            | tee -a $logfile
echo "build_date ="`date`   >>$logfile
echo "uname -r ="${uname_r} >>$logfile
id       >>$logfile
echo .   >>$logfile
ls -l -d /usr/include >>$logfile
echo .   >>$logfile
cd /usr/src
ls -l .               >>$logfile
cd $current_wd
echo .   >>$logfile


# ==============================================================
# locate and verify contents of kernel include file path
if [ ! -f "${KERNEL_PATH}/.config" ];
then
  echo "kernel configuration at ${KERNEL_PATH} not found"          | tee -a $logfile
  exit 1
fi
source "${KERNEL_PATH}/.config"

# verify match with respective line in linux/version.h
# sample: #define UTS_RELEASE "2.4.0-test7"
src_file=$linuxincludes/linux/version.h
if [ ! -e $src_file ];
then
  echo "kernel includes at $linuxincludes not found or incomplete" | tee -a $logfile
  echo "file: $src_file"                                           | tee -a $logfile
  exit 1
fi
OsRelease=${uname_r}
UTS_REL_COUNT=`cat $src_file | grep UTS_RELEASE -c`
if [ $UTS_REL_COUNT -gt 1 ];
then
  kernel_release=`cat $src_file | grep UTS_RELEASE | grep \"$OsRelease\" | cut -d'"' -f2`
else
  if [ $UTS_REL_COUNT -gt 0 ];
  then
    kernel_release=`cat $src_file | grep UTS_RELEASE | cut -d'"' -f2`
  else
    # UTS-define is in external version-*.h files, i.e. linux-2.2.14-5.0-RedHat does this flaw
    kernel_release=`cat $linuxincludes/linux/version-*.h | grep UTS_RELEASE | grep \"$OsRelease\" | cut -d'"' -f2`
  fi
fi




# ==============================================================




# ==============================================================
# resolve if we are running an AGP capable kernel source tree.
# Hint: our custom module build simply relys on the header, 
# not on the kernel AGP caps to be enabled at all.

AGP=0

# verify if file linux/agp_backend.h exists
src_file=$linuxincludes/linux/agp_backend.h
if [ -e $src_file ];
then
  AGP=1
#  def_agp=-D__AGP__
  echo "file $src_file says: AGP=$AGP"                             >> $logfile
fi

if [ $AGP = 0 ]
then
  echo "assuming default: AGP=$AGP"                                >> $logfile
fi

# ==============================================================
# resolve if we are running a SMP enabled kernel

SMP=0

if [ "${CONFIG_SMP}" ]
then
  SMP=1
  echo "kernel configuration says: SMP=$SMP" >> $logfile
fi

# assume PAGE_ATTR_FIX=1
PAGE_ATTR_FIX=1

if [ $SMP = 0 ]
then
  echo "assuming default: SMP=$SMP"                                >> $logfile
fi

# act on final result
if [ ! $SMP = 0 ]
then
  smp="-SMP"
  def_smp=-D__SMP__
fi


# ==============================================================
# resolve if we are running a MODVERSIONS enabled kernel

MODVERSIONS=0

if [ "${CONFIG_MODVERSIONS}" ]
then
  MODVERSIONS=1
  echo "kernel configuration says: MODVERSIONS=$MODVERSIONS" >> $logfile
fi

if [ $MODVERSIONS = 0 ]
then
  echo "assuming default: MODVERSIONS=$MODVERSIONS"                >> $logfile
fi

# act on final result
if [ ! $MODVERSIONS = 0 ]
then
  def_modversions="-DMODVERSIONS"
fi


# ==============================================================
# check for required source and lib files

file=${SOURCE_PREFIX}/${FGL_PUBLIC}_public.c
if [ ! -e $file ];
then 
  echo "$file: required file is missing in build directory" | tee -a $logfile
  exit 1
fi
file=${SOURCE_PREFIX}/${FGL_PUBLIC}_public.h
if [ ! -e $file ];
then 
  echo "$file: required file is missing in build directory" | tee -a $logfile
  exit 1
fi

# break down OsRelease string into its components
major=`echo $OsRelease | sed -n -e s/"^\([[:digit:]]*\)\.\([[:digit:]]*\)\.\([[:digit:]]*\)\(.*\)"/"\\1"/p`
minor=`echo $OsRelease | sed -n -e s/"^\([[:digit:]]*\)\.\([[:digit:]]*\)\.\([[:digit:]]*\)\(.*\)"/"\\2"/p`
patch=`echo $OsRelease | sed -n -e s/"^\([[:digit:]]*\)\.\([[:digit:]]*\)\.\([[:digit:]]*\)\(.*\)"/"\\3"/p`
extra=`echo $OsRelease | sed -n -e s/"^\([[:digit:]]*\)\.\([[:digit:]]*\)\.\([[:digit:]]*\)\(.*\)"/"\\4"/p`

if [ "$1" = "verbose" ]
then
  echo OsRelease=$OsRelease  | tee -a $logfile
  echo major=$major          | tee -a $logfile
  echo minor=$minor          | tee -a $logfile
  echo patch=$patch          | tee -a $logfile
  echo extra=$extra          | tee -a $logfile
  echo SMP=$SMP              | tee -a $logfile
  echo smp=$smp              | tee -a $logfile
  echo AGP=$AGP              | tee -a $logfile
fi

major_minor=$major.$minor.
major_minor_grep=$major[.]$minor[.]

echo .   >>$logfile

# determine compiler version
cc_version=`${CC} -dumpversion`
cc_version_major=`echo $cc_version | cut -d'.' -f1`
cc_version_minor=`echo $cc_version | cut -d'.' -f2`

echo CC=${CC} >> $logfile
echo cc_version=$cc_version >> $logfile
if [ "$1" = "verbose" ]
then
    echo CC=${CC}
    echo cc_version=$cc_version
fi

# try to symlink the compiler matching ip-library
lib_ip_base=${LIBIP_PREFIX}/lib${MODULE}_ip.a

# remove existing symlink first
if [ -L $lib_ip_base ];
then
  # remove that symlink to create a new one in next paragraph
  rm -f ${lib_ip_base}
else
  if [ -e $lib_ip_base ];
  then
    echo "Error: the ip-library is present as some file - thats odd!" | tee -a $logfile
    # comment out the below line if you really want to use this local file
    if [ -z "${LIBIP_PREFIX}" ]; then
	    exit 1
    fi
  fi
fi

# if there is no ip-lib file then deterimine which symlink to setup
if [ ! -e $lib_ip_base ];
then
    if [ -e ${lib_ip_base}.GCC$cc_version ];
    then
        # we do have an ip-lib that exactly matches the users compiler
        ln -s ${lib_ip_base}.GCC$cc_version ${lib_ip_base}
        echo "found exact match for ${CC} and the ip-library" >> $logfile
    else
        # there is no exact match for the users compiler
        # try if we just provide a module that matches the compiler major number
        for lib_ip_major in `ls -1 ${lib_ip_base}.GCC$cc_version_major* 2>/dev/null`;
        do
            # just the last matching library does server our purposes - ease of coding
            rm -f ${lib_ip_base}
            ln -s ${lib_ip_major} ${lib_ip_base}
        done
        
        # after the loop there should be a file or a symlink or whatever
        if [ ! -e ${lib_ip_base} ]
        then
            echo "ls -l ${lib_ip_base}*" >>$logfile
            ls -l ${lib_ip_base}* 2>/dev/null >>$logfile
            echo "Error: could not resolve matching ip-library." | tee -a $logfile
            exit 1
        else
            echo "found major but not minor version match for ${CC} and the ip-library" >> $logfile
        fi
    fi
fi

# log a few stats
echo "ls -l ${lib_ip_base}"     >> $logfile
      ls -l ${lib_ip_base}      >> $logfile

# assign result (is not really a variable in current code)
core_lib=${lib_ip_base}

#echo "lib file name was resolved to: $core_lib" >> $logfile
#if [ "$1" = "verbose" ]
#then
#  echo "lib file name was resolved to: $core_lib"
#fi
#if [ ! -e $core_lib ];
#then 
#  echo "required lib file is missing in build directory" | tee -a $logfile
#  exit 1
#fi

echo .  >> $logfile


# ==============================================================
# make clean
echo cleaning... | tee -a $logfile
if [ -e ${FGL_PUBLIC}_public.o ]
then 
  rm -f ${FGL_PUBLIC}_public.o 2>&1 | tee -a $logfile
fi
if [ -e ${MODULE}.o ]
then
  rm -f ${MODULE}.o     2>&1 | tee -a $logfile
fi

if [ -e agpgart_fe.o ]
then 
  rm -f agpgart_fe.o 2>&1 | tee -a $logfile
fi
if [ -e agpgart_be.o ]
then 
  rm -f agpgart_be.o 2>&1 | tee -a $logfile
fi
if [ -e agp3.o ]
then 
  rm -f agp3.o 2>&1 | tee -a $logfile
fi
if [ -e i7505-agp.o ]
then 
  rm -f i7505-agp.o 2>&1 | tee -a $logfile
fi
if [ -e nvidia-agp.o ]
then 
  rm -f nvidia-agp.o 2>&1 | tee -a $logfile
fi

if [ -e patch/include/linux ]
then
  if [ -e patch/include/linux/highmem.h ]
  then
    rm -f patch/include/linux/highmem.h
  fi
  rmdir patch/include/linux
  rmdir patch/include
fi

if [ -e patch ]
then
  rmdir patch
fi

# ==============================================================
# apply header file patches
# suppress known warning in specific header file
patch_includes=

srcfile=${linuxincludes}/linux/highmem.h
if [ -e ${srcfile} ]
then
  echo "patching 'highmem.h'..." | tee -a $logfile
  mkdir -p patch/include/linux
  cat ${srcfile} | sed -e 's/return kmap(bh/return (char*)kmap(bh/g' >patch/include/linux/highmem.h
  patch_includes="${patch_includes} -Ipatch/include"
fi

# ==============================================================
# defines for all targets
def_for_all="-DATI_AGP_HOOK -DATI -DFGL -D${target_define} -DFGL_CUSTOM_MODULE -DPAGE_ATTR_FIX=$PAGE_ATTR_FIX"

# defines for specific os and cpu platforms
if [ "${CONFIG_MK8}" ]; then
	def_machine="-mcmodel=kernel"
fi

if [ "${CONFIG_IA64}" ]; then
        def_machine="-ffixed-r13 -mfixed-range=f12-f15,f32-f127"
fi

# determine which build system we should use
# note: we do not support development kernel series like the 2.5.xx tree
if [ $major -gt 2 ]; then
    kernel_is_26x=1
else
  if [ $major -eq 2 ]; then
    if [ $minor -gt 5 ]; then
        kernel_is_26x=1
    else
        kernel_is_26x=0
    fi
  else
    kernel_is_26x=0
  fi
fi

if [ $kernel_is_26x -eq 1 ]; then
    kmod_extension=.ko
else
    kmod_extension=.o
fi


# ==============================================================
# resolve if we are running a kernel with the new VMA API 
# that was introduced in linux-2.5.3-pre1
# or with the previous one that at least was valid for linux-2.4.x

if [ $kernel_is_26x -gt 0 ];
then
  echo "assuming new VMA API since we do have kernel 2.6.x..." | tee -a $logfile
  def_vma_api_version=-DFGL_LINUX253P1_VMA_API
  echo "def_vma_api_version=$def_vma_api_version"                   >> $logfile
else
  echo "probing for VMA API version..." | tee -a $logfile
  
  # create a helper source file and try to compile it into an objeckt file
  tmp_src_file=tmp_vmasrc.c
  tmp_obj_file_240=tmp_vma240.o
  tmp_obj_file_253=tmp_vma253.o
  tmp_log_file_240=tmp_vma240.log
  tmp_log_file_253=tmp_vma253.log
  cat > $tmp_src_file <<-begin_end
/* this is a generated file */
#define __KERNEL__
#include <linux/mm.h>

int probe_vma_api_version(void) {
#ifdef FGL_LINUX253P1_VMA_API
  struct vm_area_struct *vma;
#endif
  unsigned long from, to, size;
  pgprot_t prot;
  
  return (
    remap_page_range(
#ifdef FGL_LINUX253P1_VMA_API
      vma,
#endif
      from, to, size, prot)
    );
}
begin_end

  # check for 240 API compatibility
  ${CC} -I$linuxincludes $tmp_src_file                                -c -o $tmp_obj_file_240 &> $tmp_log_file_240
  cc_ret_vma_240=$?
  echo "cc_ret_vma_240 = $cc_ret_vma_240"                           >> $logfile
    
  # check for 253 API compatibility
  ${CC} -I$linuxincludes $tmp_src_file -DFGL_LINUX253P1_VMA_API       -c -o $tmp_obj_file_253 &> $tmp_log_file_253
  cc_ret_vma_253=$?
  echo "cc_ret_vma_253 = $cc_ret_vma_253"                           >> $logfile
    
  # classify and act on results
  # (the check is designed so that exactly one version should succeed and the rest should fail)
  def_vma_api_version=
  if [ $cc_ret_vma_240 -eq 0 ]
  then
    if [ $cc_ret_vma_253 -eq 0 ]
    then
      echo "check results are inconsistent!!!"                      | tee -a $logfile
      echo "exactly one check should work, but not multiple checks."| tee -a $logfile
      echo "aborting module build."                                 | tee -a $logfile
      exit 1
    else
      # the kernel tree does contain the 240 vma api version
      def_vma_api_version=-DFGL_LINUX240_VMA_API
    fi
  else
    if [ $cc_ret_vma_253 -eq 0 ]
    then
      # the kernel tree does contain the 253 vma api version
      def_vma_api_version=-DFGL_LINUX253P1_VMA_API
    else
      echo "check results are inconsistent!!!"                      | tee -a $logfile
      echo "none of the probed versions did succeed."               | tee -a $logfile
      echo "aborting module build."                                 | tee -a $logfile
      exit 1
    fi
  fi
  
  echo "def_vma_api_version=$def_vma_api_version"                   >> $logfile
    
  # cleanup intermediate files
  rm -f $tmp_src_file $tmp_obj_file_240 $tmp_obj_file_253 $tmp_log_file_240 $tmp_log_file_253
fi

# =============================================================
# Check if we're running a kernel version that has the SUSE 9.0 implementation of vmap
#
if [ $kernel_is_26x -gt 0 ]
then
  ## skip for 2.6.x and higher
  echo " Assuming default VMAP API" | tee -a $logfile
else
  echo "Probing for VMAP API version" | tee -a $logfile
  # create a helper source file and try to compile it into an object file
  tmp_src_file=tmp_vmapsrc.c
  tmp_obj_file=tmp_vmap.o
  tmp_log_file=tmp_vmap.log
# let's create the c file 
  cat > $tmp_src_file <<-begin_end
#define __KERNEL__
#include <linux/vmalloc.h>
int probe_vmap_version(void) {
    struct page** pages;
    int count= 0;
    vmap(pages,count);
    return 0;
}
begin_end
 
  # check for vmap API compatibility
  $CC -I$linuxincludes $tmp_src_file -c -o $tmp_obj_file &> $tmp_log_file
  gcc_ret_vmap=$?
    
    
# Check which VMAP API version it is and make define accordingly
  def_vmap_api_version=
  if [ $gcc_ret_vmap -eq 0 ]
    then
      echo "This is the vmap API used for SUSE 9.0 "  | tee -a $logfile
      def_vmap_api_version=-DFGL_LINUX_SUSE90_VMAP_API
    else
      echo "Use default vmap API"                     | tee -a $logfile
  fi
  
  # cleanup intermediate files
  rm -f $tmp_src_file $tmp_obj_file $tmp_log_file 
fi


# ==============================================================
# make agp kernel module (including object files) and check results

if [ $kernel_is_26x -gt 0 ]; then
    echo "doing Makefile based build for kernel 2.6.x and higher"   | tee -a $logfile
    V=${V:-0}
    make CC=${CC} V=${V} KDIR=${KERNEL_PATH} MODFLAGS="-DMODULE $def_for_all $def_smp $def_modversions" PAGE_ATTR_FIX=$PAGE_ATTR_FIX 2>&1 | tee -a $logfile
    res=${PIPESTATUS[0]}
    if [ $res -eq 0 ]; then
        echo "build succeeded with return value $res"               | tee -a $logfile
    else
        echo "build failed with return value $res"                  | tee -a $logfile
        exit 1
    fi
else
    echo "doing script based build for kernel 2.4.x and similar"    | tee -a $logfile
    
WARNINGS="-Wall -Wwrite-strings -Wpointer-arith -Wcast-align -Wstrict-prototypes"
if [ $cc_version_major -ge 3 ];
then
  if [ $cc_version_major -eq 3 ];
  then
    if [ $cc_version_minor -ge 3 ];
    then
      # gcc 3.3 or higher is too verbose for us when using the -Wall option
      WARNINGS="-Wwrite-strings -Wpointer-arith -Wcast-align -Wstrict-prototypes"
    fi
  else
    # gcc 3.3 or higher is too verbose for us when using the -Wall option
    WARNINGS="-Wwrite-strings -Wpointer-arith -Wcast-align -Wstrict-prototypes"
  fi
fi

#SRC=${SOURCE_PREFIX}/agpgart_fe.c
#DST=agpgart_fe.o
#echo "compiling '$SRC'..." | tee -a $logfile
#cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all -D$MODULE $def_smp $def_modversions $patch_includes -I$linuxincludes -c $SRC -o $DST"
#echo "$cc_cmd" >> $logfile
#$cc_cmd 2>&1 | tee -a $logfile
#if [ ! -e $DST ] ;
#then
#  echo "compiling failed - object file was not generated" | tee -a $logfile
#  exit 1
#fi

SRC=${SOURCE_PREFIX}/agpgart_be.c
DST=agpgart_be.o
echo "compiling '$SRC'..." | tee -a $logfile
cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all $def_machine -D$MODULE $def_smp $def_modversions $patch_includes -I$linuxincludes -c $SRC -o $DST"
echo "$cc_cmd" >> $logfile
$cc_cmd 2>&1 | tee -a $logfile
if [ ! -e $DST ] ;
then
  echo "compiling failed - object file was not generated" | tee -a $logfile
  exit 1
fi

SRC=${SOURCE_PREFIX}/agp3.c
DST=agp3.o
echo "compiling '$SRC'..." | tee -a $logfile
cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all $def_machine -D$MODULE $def_smp $def_modversions $patch_includes -I$linuxincludes -c $SRC -o $DST"
echo "$cc_cmd" >> $logfile
$cc_cmd 2>&1 | tee -a $logfile
if [ ! -e $DST ] ;
then
  echo "compiling failed - object file was not generated" | tee -a $logfile
  exit 1
fi

SRC=${SOURCE_PREFIX}/i7505-agp.c
DST=i7505-agp.o
echo "compiling '$SRC'..." | tee -a $logfile
cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all $def_machine -D$MODULE $def_smp $def_modversions $patch_includes -I$linuxincludes -c $SRC -o $DST"
echo "$cc_cmd" >> $logfile
$cc_cmd 2>&1 | tee -a $logfile
if [ ! -e $DST ] ;
then
  echo "compiling failed - object file was not generated" | tee -a $logfile
  exit 1
fi

SRC=${SOURCE_PREFIX}/nvidia-agp.c
DST=nvidia-agp.o
echo "compiling '$SRC'..." | tee -a $logfile
cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all $def_machine -D$MODULE $def_smp $def_modversions $patch_includes -I$linuxincludes -c $SRC -o $DST"
echo "$cc_cmd" >> $logfile
$cc_cmd 2>&1 | tee -a $logfile
if [ ! -e $DST ] ;
then
  echo "compiling failed - object file was not generated" | tee -a $logfile
  exit 1
fi

# we don't need the agpgart module - skip that thing
# echo "linking agp module..." | tee -a $logfile
# ld="ld -r agpgart_fe.po agpgart_be.po -o agpgart.o"
# echo "$ld" >> $logfile
# $ld 2>&1 | tee -a $logfile
# if [ ! -e ${MODULE}.o ] ;
# then
#  echo "linking failed - kernel module was not generated" | tee -a $logfile
#  exit 1
# fi
#
# echo .  >> $logfile


# ==============================================================
# make custom kernel module and check results

SRC=${SOURCE_PREFIX}/${FGL_PUBLIC}_public.c
DST=${FGL_PUBLIC}_public.o
echo "compiling '$SRC'..." | tee -a $logfile
cc_cmd="${CC} ${WARNINGS} -O2 -D__KERNEL__ -DMODULE -fomit-frame-pointer $def_for_all $def_machine -D${MODULE} $def_vma_api_version $def_vmap_api_version $def_smp $def_modversions $def_agp $patch_includes -I$linuxincludes -I$PWD -c $SRC -o $DST"
echo "$cc_cmd" >> $logfile
$cc_cmd 2>&1 | tee -a $logfile | grep -v "warning: pasting would not give a valid preprocessing token"
if [ ! -e $DST ] ;
then
  echo "compiling failed - object file was not generated" | tee -a $logfile
  exit 1
fi

echo "linking of ${MODULE} kernel module..." | tee -a $logfile
if [ ! -z "${MODULE_NAME}" ]; then 
	module_version=.${MODULE_NAME}
fi
ld="ld -r ${FGL_PUBLIC}_public.o agpgart_be.o agp3.o i7505-agp.o nvidia-agp.o $core_lib -o ${MODULE}${module_version}.o"
echo "$ld" >> $logfile
$ld 2>&1 | tee -a $logfile
if [ ! -e ${MODULE}${module_version}.o ] ;
then
  echo "linking failed - kernel module was not generated" | tee -a $logfile
  exit 1
fi

# end of `else` for $kernel_is_26x
fi

echo .  >> $logfile


# ==============================================================

# ==============================================================
# finale

echo done.
echo ==============================

if [ $OPTIONS_HINTS -ne 0 ]; then

  echo "You must copy ${MODULE}${kmod_extension} to /lib/modules/${uname_r}/misc"
  echo "and then call 'depmod -ae' in order to install the built module."
  echo ==============================

fi

#EOF
