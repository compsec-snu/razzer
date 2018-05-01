##############################################################################
# Copyright (c) 2013 Mark Charlebois
#               2013 Behan Webster
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to 
# deal in the Software without restriction, including without limitation the 
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or 
# sell copies of the Software, and to permit persons to whom the Software is 
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in 
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR 
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING 
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.
##############################################################################
# Build and test alternatives to VLAIS

CLANG	= ../../../toolchain/clang/clang+llvm-3.3-Ubuntu-13.04-x86_64-linux-gnu/bin/clang
GCC	= gcc -std=c11
CFLAGS	= -g -Wall

TARGET	= test-vlais

.PHONY: all test clean

OBJS		= test.o util.o
VLAIS_OBJ	= vlais-gcc.o
DIFF_OBJS	= novlais novlais1 novlais2 novlais3 novlais4
GCC_OBJS	= ${VLAIS_OBJ} ${addsuffix -gcc.o,${DIFF_OBJS}}
CLANG_OBJS	= $(addsuffix -clang.o,${DIFF_OBJS})
ALL_OBJS	= ${CLANG_OBJS} ${GCC_OBJS} ${OBJS}

### BUILD ######################################################################
all: $(TARGET)

${GCC_OBJS}: %-gcc.o: %.c util.h
	$(GCC) ${EXTRAFLAGS} -DNOVLAIS=$*_gcc -c $< -o $@

${CLANG_OBJS}: %-clang.o: %.c util.h
	$(CLANG) ${EXTRAFLAGS} -g -DNOVLAIS=$*_clang -c $< -o $@

${OBJS}: %.o: %.c util.h
	$(CLANG) ${EXTRAFLAGS} -g -c $< -o $@

$(TARGET): ${ALL_OBJS}
	$(GCC) -o $@ $^

test: $(TARGET)
	./$(TARGET)

### TIMING #####################################################################
timing.log:
	EXTRAFLAGS=-DTIMING $(MAKE) clean all >/dev/null
	./$(TARGET) | tee $@

timing.dat: timing.log
	@echo "# Filename usecs" > $@
	@sed 's/:/ /g' $< | awk '/^PASS/ { print $$2 " " $$12 }' >> $@

TIMINGSVG = "\
set terminal svg size 600,400 dynamic enhanced fname 'arial' fsize 10 mousing name 'timing' butt solid\n \
set output 'timing.svg'\n"
TIMINGPLOT = "\
set boxwidth 0.9 absolute\n \
set style fill solid 1.00 border lt -1\n \
set key inside right top vertical Right noreverse noenhanced autotitles nobox\n \
set style histogram clustered gap 1 title  offset character 0, 0, 0\n \
set datafile missing '-'\n \
set style data histograms\n \
set xtics border in scale 0,0 nomirror rotate by -45  offset character 0, 0, 0 autojustify\n \
set xtics norangelimit font ',8'\n \
set xtics ()\n \
set title 'Timing data for VLAIS alternatives (usecs)'\n \
i = 22\n \
plot 'timing.dat' u 2 title 'Diff from VLAIS', '' using 0:xticlabel(1) notitle ' '\n"

timing-graph: timing.dat
	@(echo $(TIMINGPLOT); read FOO) | gnuplot
timing.svg: timing.dat
	@echo $(TIMINGSVG) $(TIMINGPLOT) | gnuplot

### ASM ########################################################################
get-asm:
	@for FILE in ${GCC_OBJS} ; do \
		objdump --disassemble $${FILE} > $${FILE}.asm ; \
	done

### SIZE #######################################################################
textsize = `objdump -h $(1) \
		| awk --non-decimal-data '/\.text/ { printf("%d", "0x" $$3) }'`
printsize = printf "%-16s %s size:%d text:%d diff:%d\n" \
		$(1) $(2) `stat -c %s $(1)` $(3) `expr $(3) - $(4)`

OPTS	= opt-O0 opt-O1 opt-O2 opt-Os
sizes: ${OPTS}
${OPTS}: opt%:
	EXTRAFLAGS=$* $(MAKE) clean all >/dev/null
	@CMPSIZE=$(call textsize,${VLAIS_OBJ}); \
	$(call printsize,${VLAIS_OBJ},$*,$$CMPSIZE,$$CMPSIZE); \
	for FILE in ${DIFF_OBJS} ; do \
		for EXT in -gcc.o -clang.o ; do \
			SIZE=$(call textsize,$$FILE$$EXT); \
			$(call printsize,$$FILE$$EXT,$*,$$SIZE,$$CMPSIZE); \
		done; \
	done

sizes.log:
	$(MAKE) --quiet sizes > $@

textsize = echo $(1) `sed 's/:/ /g' $(2) | awk '/^'$(1)'/ {print $$6}'`

sizes.dat: sizes.log
	@(echo "# filname $(OPTS)"; \
	$(call textsize,${VLAIS_OBJ},$<); \
	for FILE in ${DIFF_OBJS} ; do \
		for EXT in -gcc.o -clang.o ; do \
			$(call textsize,$$FILE$$EXT,$<); \
		done; \
	done) > $@

SIZESVG = "\
set terminal svg size 600,400 dynamic enhanced fname 'arial' fsize 10 mousing name 'sizes' butt solid\n \
set output 'sizes.svg'\n"
SIZESPLOT = "\
set boxwidth 0.9 absolute\n \
set style fill solid 1.00 border lt -1\n \
set key inside right top vertical Right noreverse noenhanced autotitles nobox\n \
set style histogram clustered gap 1 title  offset character 0, 0, 0\n \
set datafile missing '-'\n \
set style data histograms\n \
set xtics border in scale 0,0 nomirror rotate by -45  offset character 0, 0, 0 autojustify\n \
set xtics norangelimit font ',8'\n \
set xtics ()\n \
set title 'Text Size data for VLAIS alternatives (bytes)'\n \
i = 22\n \
plot 'sizes.dat' u 4 title '-O2', '' u 5 title '-Os', '' using 0:xticlabel(1) notitle ' '\n"
#plot 'sizes.dat' u 2 title '-O0', '' u 3 title '-O1', '' u 4 title '-O2', '' u 5 title '-Os', '' using 0:xticlabel(1) notitle ' '\n"

sizes-graph: sizes.dat
	@(echo $(SIZESPLOT); read FOO) | gnuplot
sizes.svg: sizes.dat
	@echo $(SIZESVG) $(SIZESPLOT) | gnuplot
clean:
	rm -f $(TARGET) netfilter_clang netfilter_gcc *.o a.out
distclean: clean
	rm -f *.asm *.dat *.log

netfilter: netfilter_clang netfilter_gcc
netfilter_clang: netfilter.c
	${CLANG} $< -o $@

netfilter_gcc: netfilter.c
	gcc $< -o $@

