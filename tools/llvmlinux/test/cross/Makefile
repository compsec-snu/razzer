all: bin/test1-cs bin/testcxx-cs bin/test1-linaro bin/testcxx-linaro

bin/test1-cs: test1.c bin
	../../arch/arm/toolchain/codesourcery/bin/arm-eabi-gcc -static -integrated-as -o $@ test1.c

bin/testcxx-cs: testcxx.cpp bin
	../../arch/arm/toolchain/codesourcery/bin/arm-eabi-g++ -static -integrated-as -o $@ testcxx.cpp

bin/test1-linaro: test1.c bin
	../../arch/arm/toolchain/linaro/bin/arm-eabi-gcc -static -integrated-as -o $@ test1.c

bin/testcxx-linaro: testcxx.cpp bin
	../../arch/arm/toolchain/linaro/bin/arm-eabi-g++ -static -integrated-as -o $@ testcxx.cpp

bin:
	mkdir -p bin

clean:
	rm -rf bin
