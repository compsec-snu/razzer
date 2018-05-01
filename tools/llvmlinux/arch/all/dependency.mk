##############################################################################
# Copyright (c) 2012 Behan Webster
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

DEBDEP		+= build-essential git patch quilt sparse time bc wget zip
DEBDEP_32	+= libc6:i386 libncurses5:i386
DEBDEP_EXTRAS	+= sparse

RPMDEP		+= gcc git make patch quilt zip
RPMDEP_EXTRAS	+= sparse

##############################################################################
isdeb		= if [ -f /etc/debian_version ] ; then
isrpm		= elif [ -f /etc/redhat-release -o -f /etc/SuSE-release ] ; then

isredhat	= if [ -f /etc/redhat-release ] ; then
issuse		= elif [ -f /etc/SuSE-release ] ; then

otherwise	= else echo $(1); fi

PKGSYS		:= $(shell \
	$(call isdeb) echo deb; \
	$(call isrpm) echo rpm; \
	$(call otherwise,unkown))

PACKAGER	:= $(shell \
	$(call isredhat) echo yum; \
	$(call issuse) echo zypper; \
	$(call otherwise,unknown))

DEPLISTSTATE	= state/build-dep
DEPLIST		= $(shell \
	$(call isdeb) echo ${DEBDEP} ${DEBDEP_32}; \
	$(call isrpm) echo ${RPMDEP} ${RPMDEP_32}; \
	fi)

TARGETS		+= build-dep build-dep-check build-dep-install
HELP_TARGETS	+= build-dep-help

##############################################################################
build-dep-help:
	@echo
	@echo "These are the make targets for the build dependency:"
	@echo "* make build-dep-list     - List package dependencies"
	@echo "* make build-dep[-check]  - See whether build dependencies are installed"
	@echo "* make build-dep-install  - Install missing build dependencies"

##############################################################################
oneperline	= echo ${1} | sed -e 's/ /\n/g' | sort -u
deplistupdate	= [ ! -d $(dir ${1}) ] || $(call oneperline,${DEPLIST}) > ${1}
deplistdiff	= $(call oneperline,${1}) | diff ${2} - | awk '/>/ {print $$2}'
NEWDEPS		= $(shell if [ -f ${DEPLISTSTATE} ] ; then $(call deplistdiff,${DEPLIST},${DEPLISTSTATE}) ; \
			else $(call oneperline,${DEPLIST}) ; fi)

##############################################################################
build-dep-list:
	@$(call oneperline,${DEPLIST})
build-dep-list-new:
	@$(call oneperline,${NEWDEPS})
build-dep-check build-dep: build-dep-check-${PKGSYS}
	-@$(MAKE) build-dep-check-${PKGSYS}-extras
	@$(call banner,Checking build dependencies)
	@$(call deplistupdate,${DEPLISTSTATE})
	@echo "All build dependencies were found"
build-dep-install: build-dep-install-${PKGSYS}
	-@$(MAKE) build-dep-install-${PKGSYS}-extras
	@$(call deplistupdate,${DEPLISTSTATE})
${DEPLISTSTATE}:
	@make -s build-dep-check

##############################################################################
build-dep-check-unkown:
	@echo "This build system doesn't know how check for dependencies on this platform"
build-dep-install-unkown:
	@echo "This build system doesn't know how to install packages for this platform"

DEPMSG		= "Missing build dependencies:"
DEPMSG_32	= "You likely need to install..."
DEPMSG_EXTRAS	= "Not necessary. But you may want..."

##############################################################################
check_foreign_arch = dpkg --print-architecture | egrep -q '^amd64$$' \
		&& ( dpkg --print-foreign-architectures | egrep -q '^i386$$' \
		|| (echo "You need to: 'sudo dpkg --add-architecture i386'"; false ) ) || true
debdep	= $(call check_foreign_arch); \
	DEBS=`dpkg -l $(1) 2>/dev/null | awk '/^[pu]/ {print $$2}'; \
	dpkg -l $(1) 2>&1 >/dev/null | awk '{print $$6}'` ; \
	[ -z "$$DEBS" ] || ( echo "$(2)"; echo "  sudo apt-get install" $$DEBS ; false )
build-dep-check-deb:
    # @$(call debdep,${DEBDEP},${DEPMSG})
build-dep-check-deb-extras:
    # @$(call debdep,${DEBDEP_32},${DEPMSG})
build-dep-install-deb:
	@[ -n "${DEPLIST}" ] && sudo apt-get install ${DEPLIST} || echo "Already installed"
build-dep-install-deb-extras:
	@[ `uname -p | grep -c 64` -eq 0 ] || $(call debdep,${DEBDEP_32},${DEPMSG_32})
	@$(call debdep,${DEBDEP_EXTRAS},${DEPMSG_EXTRAS}) || true

##############################################################################
rpmdep	= RPMS=`rpm -q $(1) | awk '/is not installed/ {print $$2}'` ; \
	[ -z "$$RPMS" ] || ( echo "$(2)"; echo "  sudo ${PACKAGER} install" $$RPMS; false )
build-dep-check-rpm:
	@$(call rpmdep,${RPMDEP},${DEPMSG})
build-dep-check-rpm-extras:
	@$(call rpmdep,${RPMDEP_32},${DEPMSG})
build-dep-install-rpm:
	[ -n "${DEPLIST}" ] && sudo ${PACKAGER} install ${DEPLIST} || echo "Already installed"
build-dep-install-rpm-extras:
	@[ `uname -p | grep -c 64` -eq 0 ] || $(call rpmdep,${RPMDEP_32},${DEPMSG_32})
	@$(call rpmdep,${RPMDEP_EXTRAS},${DEPMSG_EXTRAS}) || true

##############################################################################
# Deprecated
build-dep-old:
	@$(call isdeb) \
		$(call debdep,${DEBDEP},${DEPMSG}) ; \
		[ `uname -p | grep -c 64` -eq 0 ] || $(call debdep,${DEBDEP_32},${DEPMSG_32}) ; \
		$(call debdep,${DEBDEP_EXTRAS},${DEPMSG_EXTRAS}) || true ; \
	$(call isrpm) \
		rpm -q $(RPMDEP) >/dev/null 2>&1 || ( echo "sudo $(PACKAGER) install $(RPMDEP)"; false ) ; \
	$(call otherwise,"This build system doesn't know how check for dependencies on this platform")

##############################################################################
# Deprecated
build-dep-install-old:
	@$(call isdeb) \
		sudo apt-get install ${DEBDEP}; \
	$(call isrpm) \
		sudo ${PACKAGER} install ${RPMDEP}; \
	$(call otherwise,"This build system doesn't know how to install packages for this platform")

