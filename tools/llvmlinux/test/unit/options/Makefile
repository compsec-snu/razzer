CLANG36=../../../toolchain/clang/head/install/bin/clang
CLANG35=clang
WARNINGS = no-error no-unused-variable no-common no-unused-but-set-variable 
FLAGS = no-delete-null-pointer-checks conserve-stack delete-null-pointer-checks no-inline-functions-called-once
OTHER = -mgeneral-regs-only -Qunused-arguments
YES="    supported"
NO ="    unsupported"

all: warnings flags other

warnings:
	@echo "#### Warnings ####"
	@echo "  --- Clang 3.6 ---"
	@$(foreach opt,$(WARNINGS),echo "  -W$(opt): " && ${CLANG36} -Werror -W$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "  --- Clang 3.5 ---"
	@$(foreach opt,$(WARNINGS),echo "  -W$(opt): " && ${CLANG35} -Werror -W$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "  --- gcc ---"
	@$(foreach opt,$(WARNINGS),echo "  -W$(opt): " && gcc -Werror -W$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)

flags:
	@echo "#### Flags ####"
	@echo "  --- Clang 3.6 ---"
	@$(foreach opt,$(FLAGS),echo "  -f$(opt): " && ${CLANG36} -f$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "  --- Clang 3.5 ---"
	@$(foreach opt,$(FLAGS),echo "  -f$(opt): " && ${CLANG35} -f$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "  --- gcc ---"
	@$(foreach opt,$(FLAGS),echo "  -f$(opt): " && gcc -f$(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)

other:
	@echo "#### Other ####"
	@echo "  --- Clang 3.6 ---"
	@$(foreach opt,$(OTHER),echo "  $(opt): " && ${CLANG36} $(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "  --- Clang 3.5 ---"
	@$(foreach opt,$(OTHER),echo "  $(opt): " && ${CLANG35} $(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
	@echo "--- gcc ---"
	@$(foreach opt,$(OTHER),echo "  $(opt): " && gcc $(opt) -E test.c -o /dev/null 2>/dev/null && echo ${YES} || echo ${NO};)
