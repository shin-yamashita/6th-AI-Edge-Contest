load("//tensorflow/lite:build_def.bzl", "tflite_copts")
load("//tensorflow/lite/tools/evaluation/tasks:build_def.bzl", "task_linkopts")

package(
    default_visibility = [
        "//visibility:public",
    ],
    licenses = ["notice"],
)

cc_library(
    name = "dummy_delegate",
    srcs = [
        "dummy_delegate.cc",
    ],
    hdrs = [
        "dummy_delegate.h",
    ],
    deps = [
        "//tensorflow/lite/c:common",
        "//tensorflow/lite/delegates/utils:simple_delegate",
    ],
)

cc_library(
    name = "my_delegate",
    srcs = [
        "MyDelegate.cc",
        "Conv2D.cc",
        "tfacc_u8.cc", 
        "xlnk_wrap.cc",
    ],
    defines = select({
        ":u96_build":  ["ULTRA96"],
        ":x86_build": ["X86_64"],
        "//conditions:default": ["X86_64"],
    }),
    hdrs = [
    	"dummy_delegate.h",
       "tfacc_u8.h",
       "Conv2D.h",
    ],
    deps = [
        "//tensorflow/lite/kernels/internal:common",
        "//tensorflow/lite/kernels/internal:tensor",
        "//tensorflow/lite/c:common",
        "//tensorflow/lite/c:c_api",
        "//tensorflow/lite/delegates/utils:simple_delegate",
    ],
)

cc_binary(
    name = "dummy_external_delegate.so",
    srcs = [
        "external_delegate_adaptor.cc",
    ],
    linkshared = 1,
    linkstatic = 1,
    linkopts = select({
#        ":u96_build": ["-lcma"],
        ":u96_build": ["-lxrt_core"],
        ":x86_build": [""],
        "//conditions:default": [""],
    }),
    deps = [
#        ":dummy_delegate",
        ":my_delegate",
        "//tensorflow/lite/c:common",
        "//tensorflow/lite/tools:command_line_flags",
        "//tensorflow/lite/tools:logging",
    ],
)

config_setting(
    name = "u96_build",
    values = {"define": "aarch64=1"},
)
config_setting(
    name = "x86_build",
    values = {"define": "x86_64=1"},
)
