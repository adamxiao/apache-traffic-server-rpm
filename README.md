# apache-traffic-server-rpm

refer https://pkgs.org/download/trafficserver

add some patch, and my configure file

build command

```
yum install rpmrebuild rpmdevtools
yum-builddep SPECS/trafficserver.spec
spectool -C ./SOURCES -g SPECS/trafficserver.spec
rpmbuild --define '_topdir %{getenv:PWD}' -ba SPECS/trafficserver.spec
```
