all:
	rpmbuild --define '_topdir $(PWD)' -ba ./SPECS/trafficserver.spec
