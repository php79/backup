# 로컬 증분 백업

증분 백업 솔루션인 rsnapshot 을 사용하여, 소스와 디비를 증분 백업하는 방법입니다.

난이도 - 중


## rsnapshot 소개

rsnapshot은 rsync 기반이지만, 영리하게 백업 단위(일,주,월)로 같은 파일은 hard link 를 사용합니다.
즉, 백업본이 일단위 7개, 주단위 4개, 월 단위 3개로 14개 파일로 존재하지만,
hard link 덕분에 실제 용량은 1개만 차지하게 됩니다.

즉 대용량 증분 백업, 로컬&원격 백업에 적합한 솔루션입니다.

rsnapshot - http://rsnapshot.org/


## 백업 스케쥴

Cron 데몬을 활용하여 별도 정의된 시간(매일, 매주, 매월)에 자동 백업되고, 
지정된 보관 기간만큼 보관하고 이후 백업 데이타는 자동 삭제 됩니다.


## 백업 보관 디렉토리 생성

> 모든 명령은 root 권한으로 실행합니다.

백업 보관 디렉토리가 없을 경우, 다음 명령으로 만들어 줍니다.

```
# mkdir -m 0700 -p /backup/.snapshots
```

> 주의) 백업 보관 디렉토리는 운영 디스크와는 물리적으로 분리된 백업 디스크를 사용하셔야, 운영 디스크의 물리적인 장애에 대비할 수
 있습니다.


## MySQL 백업 스크립트 설치

백업 보관 디렉토리로 이동합니다.

```
# cd /backup/.snapshots
```

백업 보관 디렉토리에 백업 스크립트를 다운로드 받습니다.

```
# curl -s -o php79-mysql-backup.sh https://raw.githubusercontent.com/php79/backup/master/php79-mysql-backup.sh
```

> 주의) [로컬 풀 백업](local-full-backup.md)처럼 /etc/cron.daily 디렉토리에 다운받으시면 됩니다.
 왜냐하면 rsnapshot 과 별도로 중복 백업이 이루어질 수 있기 때문입니다.


MySQL root 비밀번호가 기록되므로, 접근 권한을 제한합니다.

```
# chmod 700 php79-mysql-backup.sh
```

백업 스크립트를 열어 디비 접속정보 등을 수정합니다.

```
# vi php79-mysql-backup.sh

# rsnapshot 로컬 증분 백업시, MySQL 백업 설정
DB_USER='root'              # MySQL 사용자.  모든 디비를 백업하려면 root 계정 필요(기본값)
DB_PASS='MySQLRootPassword' # MySQL 비밀번호.
DB_HOST='localhost'         # MySQL 서버 주소.  별도 서버에 분리되지 않았다면 로컬 서버는 localhost 입력.
DB_BIN='/usr/bin'           # mysql, mysqldump 실행 파일의 경로.  기본 /usr/bin , 컴파일시 /usr/local/mysql/bin 등
```

> DB_PASS 는 반드시 수정하셔야 합니다.

> mysql 이 yum 패키지로 설치되지 않은 경우, DB_BIN 를 반드시 컴파일 설치한 디렉토리로 변경해야 합니다.

MySQL 백업이 정상적으로 이루어지는지 테스트해봅니다.

```
# mkdir php79-tmp && cd php79-tmp
# ../php79-mysql-backup.sh
# ls -lth

total 140K
-rw-r--r-- 1 root root  534 Nov 20 16:00 php79.sql.gz
-rw-r--r-- 1 root root 133K Nov 20 16:00 mysql.sql.gz

# gunzip -c *.sql.gz|more

-- MySQL dump 10.15  Distrib 10.0.21-MariaDB, for Linux (x86_64)
Ctrl + C

# rm -f *.sql.gz && cd .. && rmdir php79-tmp
```


## rsnapshot 설치

> 모든 명령은 root 권한으로 실행합니다.

먼저 CentOS 의 확장 저장소인 [EPEL](https://fedoraproject.org/wiki/EPEL)을 설치합니다.

```
yum -y install epel-release
```

rsync 기반의 증분 백업 패키지인 rsnapshot 을 설치합니다.

```
yum -y install rsnapshot
```


## rsnapshot 권장 설정 다운로드

서버 OS 버전에 따라 설정 파일이 다르니, 먼저 OS 버전을 확인하세요.

```
# cat /etc/centos-release
CentOS release 6.7 (Final)
```

기존 설정 파일의 이름을 변경하여 보관해 둡니다.

```
# mv /etc/rsnapshot.conf /etc/rsnapshot.conf.ori
```

- CentOS 6 기준 다운로드

```
# curl -s -o /etc/rsnapshot.conf https://raw.githubusercontent.com/php79/backup/master/centos6/rsnapshot.conf
```

- CentOS 7 기준 다운로드

```
# curl -s -o /etc/rsnapshot.conf https://raw.githubusercontent.com/php79/backup/master/centos7/rsnapshot.conf
```


## rsnapshot 로컬 백업 설정

rsnapshot 설정 파일을 열어, 백업 보관 디렉토리 및 대상 디렉토리를 수정합니다.

```
# vi /etc/rsnapshot.conf

# php79: 백업 보관 디렉토리
snapshot_root	/backup/.snapshots/

### LOCALHOST
# php79: 로컬에서 백업할 디렉토리를 설정합니다.
#  - 주의) 2개 이상의 인자값은 탭(tab)키로 구분해야 하며, 공백(space)키로 구분하면 에러가 발생합니다.
backup	/home/	localhost/
backup	/etc/	localhost/
#backup	/usr/local/	localhost/
#backup	/opt/	localhost/
backup	/root/	localhost/
#backup	/var/named/	localhost/
backup	/var/lib/mysql/	localhost/

# php79: MySQL 백업 스크립트
backup_script	/backup/.snapshots/php79-mysql-backup.sh	localhost/mysqldump/
```

> 백업 보관 디렉토리가 /backup 이 아닐 경우, 반드시 수정이 필요합니다.
> 백업해야할 대상 디렉토리가 /hosting, /disk 등의 추가 파티션이 존재할 경우, 반드시 추가 입력해야 합니다.

`수정 주의) "snapshot_root	/backup/.snapshots/"" 처럼 2개 이상의 인자값은 탭(tab)키로 구분해야 하며,
공백(space)키로 구분하면 에러가 발생합니다.`

설정 파일에 문제가 없는지 테스트합니다.

```
# rsnapshot configtest
Syntax OK
```


## rsnapshot 백업 테스트

먼저 실제로 백업하지 않고, 백업시 사용되는 명령어만 확인해 봅니다.

```
# rsnapshot -t daily
...
mkdir -m 0755 -p /backup/.snapshots/daily.0/
/usr/bin/rsync -a --delete --numeric-ids --relative --delete-excluded /home \
    /backup/.snapshots/daily.0/localhost/
...
```


실제로 백업하고, 백업 결과를 확인해 봅니다.  단, 데이타 용량이 많다면 서비스에 영향을 미칠 수 있으므로 생략해야 합니다.

```
# rsnapshot daily
```

> Cron 데몬에서 동작하므로 백업이 정상적으로 완료된 경우, 아무런 메세지를 출력하지 않습니다.


## rsnapshot 백업 결과 확인

백업 보관 디렉토리에서 백업된 파일 목록을 확인하시면 됩니다.

```
# ls -lth /backup/.snapshots/
total 4.0K
drwxr-xr-x 3 root root 4.0K Nov 20 13:32 daily.0
# ls -lth /backup/.snapshots/daily.0/localhost/
total 20K
drwxr-xr-x  2 root root 4.0K Nov 20 13:32 mysqldump
drwxr-xr-x 83 root root 4.0K Nov 20 12:33 etc
dr-xr-x--- 10 root root 4.0K Nov 19 17:08 root
drwxr-xr-x  3 root root 4.0K Oct 15 17:23 var
drwxr-xr-x  3 root root 4.0K Oct  7 20:50 home
```

> 백업된 날짜별로 디렉토리가 다음처럼 구분됩니다.

```
daily.0 - 최근 일단위 백업
daily.1 - 하루 전 일단위 백업
weekly.0 - 최근 주단위 백업
monthly.0 - 최근 월단위 백업
```

> mysqldump 디렉토리에서 확장자가 sql.gz 인 것은 mysqldump로 만들어진 디비 백업 파일입니다.
> 꼭 압축을 풀어 디비가 정상적으로 백업되었는지 1회 확인하는 것을 권장합니다.


백업 로그를 통해서도, 에러 여부를 확인할 수 있습니다.

```
# tail -n50 /var/log/rsnapshot
...
[20/Nov/2015:13:30:12] /usr/bin/rsnapshot daily: started
...
[20/Nov/2015:13:32:19] /usr/bin/rsnapshot daily: completed successfully
```


## rsnapshot 백업 스케쥴 등록

/etc/cron.d 에 백업 스케쥴을 다운로드 받으면, 매일/매주/매월 백업이 자동 실행됩니다.

```
# curl -s -o /etc/cron.d/php79-rsnapshot https://raw.githubusercontent.com/php79/backup/master/php79-rsnapshot
```

백업 시작 시간은 아래 파일을 열어 변경하기만 하면 됩니다.  다음 백업부터 적용됩니다.
 - 일단위 : 매일 새벽 4시 5분
 - 주단위 : 매주 일요일 새벽 3시 5분
 - 월단위 : 4주 단위로, 새벽 2시 5분

```
# vi /etc/cron.d/php79-rsnapshot

#5  */4 *  *  * root    /usr/bin/rsnapshot hourly
5   4   *  *  * root    /usr/bin/rsnapshot daily
5   3   *  *  1 root    /usr/bin/rsnapshot weekly
5   2   1  *  * root    /usr/bin/rsnapshot monthly
```

> 주의) 백업 시작 시간은 월단위 > 주단위 > 일단위 순서대로 실행되어야 합니다.


하루 뒤에 "rsnapshot 백업 결과 확인"을 통해 백업 스케쥴이 정상 동작하는지 확인하면, 모든 작업이 완료됩니다.


### rsnapshot 테스트시 주의사항

- 실제 백업이 된 상태에서 rsnapshot daily 를 여러번 실행하면, 오래된 백업이 순차적으로 사라지게 되므로 주의해야 합니다.


## rsnapshot 삭제

더 이상 자동 백업을 원하지 않으실 경우, 백업 스크립트를 삭제하시면 됩니다.

```
# yum erase rsnapshot
# rm -f /etc/cron.d/php79-rsnapshot
```

---

[목차](../README.md)
