# apache-traffic-server-rpm

refer https://github.com/adamxiao/apache-traffic-server-rpm

add some patch, and my configure file

build command

```
yum install rpmrebuild rpmdevtools
spectool -g -R SPECS/trafficserver.spec
rpmbuild -ba SPECS/trafficserver.spec
```
