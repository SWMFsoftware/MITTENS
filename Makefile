# Copyright (C) 2002 Regents of the University of Michigan, 
# portions used with permission 
# For more information, see http://csem.engin.umich.edu/tools/swmf

DEFAULT_TARGET = MITTENS
DEFAULT_EXE    = MITTENS.exe

default : ${DEFAULT_TARGET}

include Makefile.def
include Makefile.conf

# Menu of make options
help:
	@echo ' '
	@echo '  You can "make" the following:'
	@echo ' '
	@echo '    <default> ${DEFAULT_TARGET} in stand alone mode'
	@echo ' '
	@echo '    help          (show makefile option list)'
	@echo '    install       (install MITTENS)'
	@echo ' '
	@echo '    LIB           (Component library libSP for SWMF)'
	@echo '    MITTENS       (make MITTENS.exe)'
	@echo '    NOMPI         (NOMPI library for compilation without MPI)'
	@echo ' '
	@echo '    rundir        (create run directory for standalone or SWMF)'
	@echo '    rundir RUNDIR=run_test (create run directory run_test)'
	@echo ' '
	@echo '    test          (run all tests)'
	@echo ' '
	@echo '    clean         (remove temp files like: *~ *.o etc)'
	@echo '    distclean     (equivalent to ./Config.pl -uninstall)'

# This target is needed for Config.pl
install:

LIB:    install
	cd src;          make LIB
	cd srcInterface; make LIB

MITTENS:
	cd ${SHAREDIR}; ${MAKE} LIB
	cd ${EMPIRICALCRDIR}; ${MAKE} LIB
	cd ${TIMINGDIR}; ${MAKE} LIB
	cd src; ${MAKE} LIB
	cd src; ${MAKE} MITTENS

NOMPI:
	cd util/NOMPI/src; make LIB

COMPONENT = PT

rundir:
	mkdir -p ${RUNDIR}/PT
	cd ${RUNDIR}/PT; \
		mkdir restartIN restartOUT IO2; \
		ln -s ${PTDIR}/Param .
	@(if [ "$(STANDALONE)" != "NO" ]; then \
		touch ${DIR}/share/JobScripts/job._TMP_${MACHINE}; \
		touch ${DIR}/share/JobScripts/_TMP_.${MACHINE}.pl; \
		cp ${DIR}/share/JobScripts/job.*${MACHINE}* ${RUNDIR}/; \
		cp ${DIR}/share/JobScripts/*.${MACHINE}.pl ${RUNDIR}/; \
		rm -f ${RUNDIR}/*_TMP_* ${DIR}/share/JobScripts/*_TMP_*; \
		cp -f Param/PARAM.in.MITTENS ${RUNDIR}/PARAM.in; \
		touch ${RUNDIR}/core; chmod 444 ${RUNDIR}/core; \
		cd ${RUNDIR}; ln -s ${BINDIR}/${DEFAULT_EXE} .; \
		cp ${PTDIR}/Param/seed.in seed.in ; \
	fi);

clean:  
	@(if [ -r "Makefile.conf" ]; then \
		cd src; make clean; \
		cd ../srcInterface; make clean; \
	fi)

distclean: 
	./Config.pl -uninstall

allclean:
	cd src; $(MAKE) distclean
	cd srcInterface; $(MAKE) distclean

TESTDIR   = run_test
NPROCTEST = 4
BLESS     = NO

test:
	rm -f test*.diff
	${MAKE} test_shock
	${MAKE} test_shock_append TESTDIR=run_test_append
	ls -l test*.diff

### Shock acceleration test: frozen-seed 100 s analytic-shock (DSA) run
### compared against the blessed reference in data/output/test_shock/.
### Input data is unpacked from data/input/test_shock/MH_data_shock.tgz.
### Uses exactly NPROCTEST ranks (rank count changes seeds, particle counts
### and results).
test_shock:
	@echo "test_shock_compile..." > test_shock.diff
	${MAKE} MITTENS
	@echo "test_shock_rundir..." >> test_shock.diff
	${MAKE} test_shock_rundir
	@echo "test_shock_run..." >> test_shock.diff
	${MAKE} test_shock_run
	@echo "test_shock_check..." >> test_shock.diff
	${MAKE} test_shock_check

test_shock_rundir:
	rm -rf ${TESTDIR}
	${MAKE} rundir RUNDIR=${TESTDIR} STANDALONE=YES PTDIR=`pwd`
	cp -f Param/PARAM.in.test.shock ${TESTDIR}/PARAM.in
	cd ${TESTDIR}; tar xzf ${MYDIR}/data/input/test_shock/MH_data_shock.tgz

test_shock_run:
	-cd ${TESTDIR}; mpiexec -n ${NPROCTEST} ./MITTENS.exe > runlog 2>&1
	@# mpiexec exit code is ignored: MPI teardown may abort spuriously (macOS
	@# OFI bug); test_shock_check verifies MITTENS.SUCCESS and the output diffs

# To update the blessed reference after a verified intentional change:
#   make test_shock BLESS=YES
test_shock_check:
	@rm -f test_shock.diff
	@if [ ! -f ${TESTDIR}/MITTENS.SUCCESS ]; then \
		echo "run did not complete (no MITTENS.SUCCESS)" > test_shock.diff; \
		ls -l test_shock.diff; exit 1; fi
	cd ${TESTDIR}/PT/IO2; cat \
		distfunc_time_1 distfunc_time_50 distfunc_time_100 \
		acceleration_time.dat > test_shock.outs
	-@(${SCRIPTDIR}/DiffNum.pl -BLESS=${BLESS} -t -r=1e-12 \
		${TESTDIR}/PT/IO2/test_shock.outs \
		data/output/test_shock/test_shock.ref.gz \
		> test_shock.diff)
	@ls -l test_shock.diff
	@if [ -s test_shock.diff ]; then \
		echo "PT/MITTENS test_shock FAILED (see test_shock.diff)"; exit 1; \
	else echo "PT/MITTENS test_shock PASSED"; fi

### Same as test_shock, but the per-time MH data files are concatenated in
### time into a single MH_data_001_001.out read with #APPENDMHDATA. The
### per-time files and MH_data.lst are removed, so only the appended file can
### be read. The results must reproduce the test_shock reference, so this
### test never blesses it.
test_shock_append:
	@echo "test_shock_append_compile..." > test_shock_append.diff
	${MAKE} MITTENS
	@echo "test_shock_append_rundir..." >> test_shock_append.diff
	${MAKE} test_shock_append_rundir
	@echo "test_shock_append_run..." >> test_shock_append.diff
	${MAKE} test_shock_run
	@echo "test_shock_append_check..." >> test_shock_append.diff
	${MAKE} test_shock_append_check

test_shock_append_rundir:
	rm -rf ${TESTDIR}
	${MAKE} rundir RUNDIR=${TESTDIR} STANDALONE=YES PTDIR=`pwd`
	cp -f Param/PARAM.in.test.shock.append ${TESTDIR}/PARAM.in
	cd ${TESTDIR}; tar xzf ${MYDIR}/data/input/test_shock/MH_data_shock.tgz
	cd ${TESTDIR}/MH_data_shock; \
		for Tag in `cat MH_data.lst`; do \
			cat MH_data_001_001_$${Tag}.out || exit 1; \
		done > MH_data_001_001.out && \
		rm -f MH_data_001_001_time_*.out MH_data.lst

test_shock_append_check:
	@rm -f test_shock_append.diff
	@if [ ! -f ${TESTDIR}/MITTENS.SUCCESS ]; then \
		echo "run did not complete (no MITTENS.SUCCESS)" \
			> test_shock_append.diff; \
		ls -l test_shock_append.diff; exit 1; fi
	cd ${TESTDIR}/PT/IO2; cat \
		distfunc_time_1 distfunc_time_50 distfunc_time_100 \
		acceleration_time.dat > test_shock_append.outs
	-@(${SCRIPTDIR}/DiffNum.pl -t -r=1e-12 \
		${TESTDIR}/PT/IO2/test_shock_append.outs \
		data/output/test_shock/test_shock.ref.gz \
		> test_shock_append.diff)
	@ls -l test_shock_append.diff
	@if [ -s test_shock_append.diff ]; then \
		echo "PT/MITTENS test_shock_append FAILED" \
			"(see test_shock_append.diff)"; exit 1; \
	else echo "PT/MITTENS test_shock_append PASSED"; fi

RUNDIRLOC = run

rundirloc:
	rm -rf ${RUNDIRLOC}
	$(MAKE) rundir STANDALONE=YES PTDIR=`pwd` RUNDIR=${RUNDIRLOC}
