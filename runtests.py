import sys
import os, os.path
import shutil
import subprocess
import platform
if platform.python_version() < "2.5":
    def check_call(*args, **kwargs):
        ret=subprocess.call(*args,**kwargs)
        if ret != 0: 
            cmd = kwargs.get('args',args[0])
            raise Exception("command '%s' returned %s" %(cmd, ret))
    subprocess.check_call = check_call
from distutils.sysconfig import get_config_var
here = os.getcwd()
parts = [
"hello",
"many_libs",
"arraytest",
"inherit",
"rawexample",
"testdll",
"deimos_unittests",
"pyind",
"pyd_unittests",
"d_and_c",
]
use_parts = set()
exe_ext = get_config_var("EXE")
verz_maj = int(platform.python_version_tuple()[0])
if verz_maj == 3 or verz_maj == 2:
    import optparse
    oparser = optparse.OptionParser()
    oparser.add_option("-b", action="store_true", dest="use_build")
    oparser.add_option('-C',"--compiler", dest="compiler")
    oparser.add_option('-c',"--clean", action="store_true",dest="clean")
    oparser.add_option('-g','--debug',action="store_true",dest="debug")
    (opts, args) = oparser.parse_args()
else:
    assert 0
if args:
    for arg in args:
        if arg in parts:
            use_parts.add(arg)
else:
    for arg in parts:
        use_parts.add(arg)
if opts.use_build:
    build = os.path.abspath(os.path.join("build","lib"));
    old_path = os.getenv("PYTHONPATH")
    if not os.path.exists(build):
        subprocess.check_call([sys.executable, "setup.py", "build"]);
    print ("using build: %r" % build)
    os.putenv("PYTHONPATH", build)
def check_exe(cmd):
    subprocess.check_call([os.path.join(".",cmd + exe_ext)])
def remove_exe(cmd):
    if os.path.exists(cmd + exe_ext):
        os.remove(cmd+exe_ext)
def pydexe():
    try:
        cmds = [sys.executable, "setup.py", "pydexe"]
        if opts.compiler:
            cmds.append("--compiler="+opts.compiler)
        if opts.debug:
            cmds.append("-g")
        subprocess.check_call(cmds)
    except:
        import os
        print (os.getcwd())
        raise
def check_py(scrpt):
    subprocess.check_call([sys.executable, scrpt])
def pybuild():
    cmds = [sys.executable, "setup.py", "build"]
    if opts.compiler:
        cmds.append("--compiler="+opts.compiler)
    subprocess.check_call(cmds)
try:
    os.chdir("examples")
    if "deimos_unittests" in use_parts:
        os.chdir("deimos_unittests")
        exes = ["link", "object_"]
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
            for exe in exes: remove_exe(exe)
        else:
            pydexe()
            for exe in exes:
                check_exe(exe)
        os.chdir("..")
    if "pyind" in use_parts:
        os.chdir("pyind")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
            remove_exe("pyind")
        else:
            pydexe()
            pyind = "pyind"
            if verz_maj == 3:
                pyind = "pyind3"
            check_exe(pyind)
        os.chdir("..")
    if "pyd_unittests" in use_parts:
        os.chdir("pyd_unittests")
        exes = ["class_wrap", "def", "embedded", "make_object", 
                "pydobject", "struct_wrap", "const", "typeinfo", "func_wrap"
                ]
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
            for exe in exes:
                remove_exe(exe)
        else:
            pydexe()
            for exe in exes:
                print (exe)
                check_exe(exe)
        os.chdir("..")
    if "hello" in use_parts:
        os.chdir("hello")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("..")
    if "many_libs" in use_parts:
        os.chdir("../tests/many_libs")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("../../examples")
    if "arraytest" in use_parts:
        os.chdir("arraytest")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("..")
    if "inherit" in use_parts:
        os.chdir("inherit")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("..")
    if "rawexample" in use_parts:
        os.chdir("rawexample")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("..")
    if "testdll" in use_parts:
        os.chdir("testdll")
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            check_py("test.py")
        os.chdir("..")
    if "d_and_c" in use_parts:
        os.chdir("misc/d_and_c")
        print ("cwd: ", os.getcwd())
        if opts.clean:
            if os.path.exists("build"): shutil.rmtree("build")
        else:
            pybuild()
            #check_py("test.py")
        os.chdir("..")
finally:
    if opts.use_build and old_path is not None:
        os.putenv("PYTHONPATH", old_path)

    