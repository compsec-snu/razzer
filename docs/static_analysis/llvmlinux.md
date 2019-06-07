# LLVM Linux

The purpose of LLVM Linux in this project is to extract all bitcode
files for each C source code.

## Kernel Modfication

We modified a Linux source code for a few reasons.

1. At the time of this project, LLVM/Clang doesn't support ASM-GOTO
and can't build a Linux kernel. LLVM now has merged ASM-GOTO so
hopefully, we may be able to build a Linux kernel with LLVM/Clang.
[1](https://www.phoronix.com/scan.php?page=news_item&px=LLVM-Asm-Goto-Merged)

2. To be specific with SVF, there is a few requirement to analyze a
   source code.
  1. Memory allocation/free functions should be external function.
  2. Pointer-to-Int and Int-to-Pointer case should be avoided.
  3. SVF can't handle assembly code, which is expressed in inline
     assembler expression.
   
As a consequence, LLVM Linux will fail to build the entire kernel
binary. It is okay if .bc files for files under interests and
built-in.bc for each subdirectory (e.g., drivers/built-in.bc,
net/built-in.bc) is built.

