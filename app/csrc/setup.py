
#https://pyhaya.hatenablog.com/entry/2018/11/13/215750

from setuptools import setup, Extension
import numpy
import os

machine = os.uname()[-1]

if machine == 'aarch64' :
    setup(
            name = 'sfa_extc',
            ext_modules = [
                Extension('postproc', 
                    sources =       ['postproc.cc'],
                    define_macros = [('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION'), (machine, '1')],
                    include_dirs =  [numpy.get_include()],
                    extra_compile_args = ['-g']
                    ),
                Extension('preproc', 
                    sources =       ['preproc.cc','xlnk_wrap.cc'],
                    define_macros = [('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION'), (machine, '1')],
                    include_dirs =  [numpy.get_include()],
                    extra_compile_args = ['-g'],
                    libraries = ['xrt_core']
                    ),
                ],
        )
else:
    setup(
            name = 'sfa_extc',
            ext_modules = [
                Extension('postproc', 
                    sources =       ['postproc.cc'],
                    define_macros = [('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION'), (machine, '1')],
                    include_dirs =  [numpy.get_include()],
                    extra_compile_args = ['-g']
                    ),
                Extension('preproc', 
                    sources =       ['preproc.cc'],
                    define_macros = [('NPY_NO_DEPRECATED_API', 'NPY_1_7_API_VERSION'), (machine, '1')],
                    include_dirs =  [numpy.get_include()],
                    extra_compile_args = ['-g'],
                    ),
                ],
        )
