#================================================================================
# Code from toplevel kernel Makefile
ifeq ($(shell $(CC) -v 2>&1 | grep -c "clang version"), 1)
COMPILER := clang
else
COMPILER := gcc
endif

#================================================================================
# Passed in as a variable
include $(KBUILD)

#================================================================================
# Test results: 4 possible test output.
# rule: # gcc/Kbuild.incude clang/Kbuild.incude gcc/Kbuild.patched clang/Kbuild.patched
# All 4 need to be correct for the rule to PASS. Otherwise FAIL.

#================================================================================
# These numbers may change as gcc and clang gets updated
cc-version: # 0408 0402 0408 0402
	@echo $(call cc-version,)

#================================================================================
# Testing for supported flags, these should not be blank for both clang and gcc:
cc-disable-warning-error: # -Wno-error -Wno-error -Wno-error -Wno-error
	@echo $(call cc-disable-warning,error,)
cc-disable-warning-unused-variable: # -Wno-unused-variable -Wno-unused-variable -Wno-unused-variable -Wno-unused-variable
	@echo $(call cc-disable-warning,unused-variable,)
cc-option-fno-common: # -fno-common -fno-common -fno-common -fno-common
	@echo $(call cc-option,-fno-common,)

#================================================================================
# Testing for unsupported flags, these should be blank for both clang and gcc:
cc-option-unsupported-flag-foo: # '' -ffoo '' ''
	@echo $(call cc-option,-ffoo,)
cc-option-unsupported-warning-bar: # '' -Wbar '' ''
	@echo $(call cc-option,-Wbar,)

#================================================================================
# Testing for unsupported clang flags, these should be blank for clang, not for gcc:
cc-disable-warning-unused-but-set-variable: # -Wno-unused-but-set-variable -Wno-unused-but-set-variable -Wno-unused-but-set-variable ''
	@echo $(call cc-disable-warning,unused-but-set-variable,)
cc-option-no-delete-pointer-checks: # -fno-delete-null-pointer-checks -fno-delete-null-pointer-checks -fno-delete-null-pointer-checks ''
	@echo $(call cc-option,-fno-delete-null-pointer-checks,)
cc-option-conserve-stack: # -fconserve-stack -fconserve-stack -fconserve-stack ''
	@echo $(call cc-option,-fconserve-stack,)
cc-option-delete-null-pointer-checks: # -fdelete-null-pointer-checks -fdelete-null-pointer-checks -fdelete-null-pointer-checks ''
	@echo $(call cc-option,-fdelete-null-pointer-checks,)
cc-option-no-inline-functions-called-once: # -fno-inline-functions-called-once -fno-inline-functions-called-once -fno-inline-functions-called-once ''
	@echo $(call cc-option,-fno-inline-functions-called-once,)
mgeneral-regs-only: # -mgeneral-regs-only -mgeneral-regs-only -mgeneral-regs-only -mgeneral-regs-only
	@echo $(call cc-option,-fmgeneral-regs-only,)

#================================================================================
# Testing for unsupported clang gcc, these should be blank for gcc, not for clang:
cc-option-unused-argument: # '' -Qunused-arguments '' -Qunused-arguments
	@echo $(call cc-option,-Qunused-arguments,)
as-option-unused-as-argument: # '' -Qunused-arguments '' -Qunused-arguments
	@echo $(call as-option,-Qunused-arguments,)

