# Kernel modification

SVF requires a few modification to analyze a kernel.

## Memory allocation functions

SVF has a list of memory allocation functions in
`lib/Util/ExtAPI.cpp`, and when SVF faces a external function, it
checks that the external function is in the list. If so, SVF thinks it
is a memory allcation function. To handle memory allocation functions
in a kernel (e.g., kmalloc/kmem_cache_alloc...), they should be a
external function. We modifies a kernel to make them external
function.

## Pointer-to-Int cast and Int-to-Pointer cast

If a pointer is casted to integer, SVF thinks the integer points to
nothing. So SVF discards all points-to information for that variable.
In a Linux kernel, there are a lot of this kind of pointer-to-int
casting. The `__to_fd()` function called by the `fdget()` function is
an example. To work around this, we modifies the kernel source code
not to cast a pointer type to integer type.

https://github.com/SVF-tools/SVF/issues/26

## Handling assmebly code

SVF analyzes a kernel based on LLVM IR. So assembly codes which are
represented as a inline assembler in LLVM IR can't be analyzed. Mostly
used assembly code in a Linux kernel is `current` pointer. We modifies
the current pointer implementaion, so current pointer always points to
`init_task`. Of course it is broken and can't be booted up. But it is
okay in the view point of static analysis.
