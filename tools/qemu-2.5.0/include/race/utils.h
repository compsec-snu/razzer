#ifndef __UTILS_H
#define __UTILS_H

static target_ulong get_phys_addr(target_ulong vaddr) {
#define TEXT_START 0xffffffff81000000
#define PHYS_START 0x01000000
    //TODO: is this alwyas true?
    return (vaddr - TEXT_START) + PHYS_START;
}

static inline uint64_t dec_val(char c) {
    if('0' <= c && c <= '9') return c - '0';
    else if('a' <= c && c <= 'f') return c - 'a' + 10;
    else {
        panic("Wrong dec_val: %c\n", c);
    }
}

static uint64_t get_reg_val(char **fmtp, struct kvm_regs *regs, int insn_size) {
    /*
	0x012345679abcdef0
  	  ================ rax (64 bits)
          	  ======== eax (32 bits)
              	  ====  ax (16 bits)
              	  ==    ah (8 bits)
                  	==  al (8 bits)
					*/
	uint64_t mask;
    uint64_t reg_val;
    int len = strlen(*fmtp);
    char last_char = *(*fmtp+len-1);

    if(**fmtp == 'r') {
        // 64bit
		mask = 0xffffffffffffffff;
        (*fmtp)++;
    } else if (**fmtp == 'e') {
        // 32bit
		mask = 0x00000000ffffffff;
        (*fmtp)++;
    } else if (last_char == 'x') {
		// 16bit
		mask = 0x000000000000ffff;
    } else if (last_char == 'l') {
		mask = 0x00000000000000ff;
	} else if (last_char == 'h') {
		mask = 0x000000000000ff00;
    } else {
        panic("Wrong reg name: %s\n", *fmtp);
    }

    if(**fmtp == 'a') {
        reg_val = regs->rax;
    } else if(**fmtp == 'b' && *(*fmtp+1) != 'p') {
        reg_val = regs->rbx;
    } else if(**fmtp == 'c') {
        reg_val = regs->rcx;
    } else if(**fmtp == 'd' && *(*fmtp+1) != 'i') {
        reg_val = regs->rdx;
    } else if(**fmtp == 's' && *(*fmtp+1) == 'i') {
        reg_val = regs->rsi;
    } else if(**fmtp == 'd' && *(*fmtp+1) == 'i') {
        reg_val = regs->rdi;
    } else if(**fmtp == 's' && *(*fmtp+1) == 'p') {
        reg_val = regs->rsp;
    } else if(**fmtp == 'b' && *(*fmtp+1) == 'p') {
        reg_val = regs->rbp;
    } else if(**fmtp == 'i' && *(*fmtp+1) == 'p') {
        reg_val = regs->rip + insn_size;
    } else if(**fmtp == '8') {
        reg_val = regs->r8;
    } else if(**fmtp == '9') {
        reg_val = regs->r9;
    } else if(**fmtp == '1' && *(*fmtp+1) == '0') {
        reg_val = regs->r10;
    } else if(**fmtp == '1' && *(*fmtp+1) == '1') {
        reg_val = regs->r11;
    } else if(**fmtp == '1' && *(*fmtp+1) == '2') {
        reg_val = regs->r12;
    } else if(**fmtp == '1' && *(*fmtp+1) == '3') {
        reg_val = regs->r13;
    } else if(**fmtp == '1' && *(*fmtp+1) == '4') {
        reg_val = regs->r14;
    } else if(**fmtp == '1' && *(*fmtp+1) == '5') {
        reg_val = regs->r15;
    } else {
        panic("Wrong reg name: %s\n", *fmtp);
    }
    *fmtp += 2;

    return reg_val & mask;
}

static uint64_t get_mem_addr(char* fmt, struct kvm_regs *regs, int insn_size) {
    //TODO: movs (mov string) class instructions
    int64_t val = 0, off = 0;
    uint64_t reg = 0, base = 0;
    bool stop = false;
    bool base_flag = false;
    char* orig __attribute__((unused)) = fmt;
    uint64_t idx = 1;

    if (*fmt == '*') {
        // Skip first asterisk for jmp
        fmt++;
    }

    if(*fmt == '%' /* register */ || *fmt == '$' /* constant */) {
        return 0;
    }

	int sign = 1;
    for(;!stop;) {
        switch(*fmt) {
			case '-':
				sign = -1;
				fmt++;
				break;
            case '0':
                if(*(fmt+1) == 'x')
                    fmt+=2; // skip 0x
            case '1':
            case '2':
            case '3':
            case '4':
            case '5':
            case '6':
            case '7':
            case '8':
            case '9':
            case 'a':
            case 'b':
            case 'c':
            case 'd':
            case 'e':
            case 'f':
                val = 0;
                while(('0' <= *fmt && *fmt <= '9') || ('a' <= *fmt && *fmt <= 'f')) {
                    val = val * 16 + dec_val(*fmt);
                    fmt++;
                }
				val *= sign;
				sign = 1;
                if(base_flag)
                    idx = val;
                break;
            case '(':
                off = val;
                val = 0;
                fmt++;
                break;
            case '%':
                fmt++;
                reg = get_reg_val(&fmt, regs, insn_size);
                break;
            case ')':
                val = base + reg * idx + off;
                fmt++;
            case '\0':
                stop = true;
                break;
            case ',':
                if(!base_flag) {
                    base = reg;
                    base_flag = true;
                }
                fmt++;
                break;
            default:
                panic("Wrong format: %s\n", orig);
                break;
        }
    }

    return val;
}

#endif
