# 원격 증분 백업

운영 서버와 백업 장비가 분리된 경우, 백업 장비에서 원격으로 운영 서버의 데이타를 백업받는 방법입니다.
[로컬 증분 백업](local-incremental-backup.md)에서 사용한 rsnapshot 에서 원격 설정만 추가하여 사용할 수 있습니다.

원격 백업의 가장 큰 장점은 백업 장비에서만 운영 서버에 접근할 수 있고, 운영 서버에선 백업 장비로 접근할 수 없습니다.
따라서 운영 서버가 랜섬웨어 등의 악의적인 공격으로 백업을 포함한 모든 데이타가 유실되더라도,
백업 장비는 피해를 입지 않아 복구가 가능한 장점이 있습니다.

특히 백업 장비는 운영 서버와 달리, 공인 IP가 필요 없으며 공유기 등의 NAT 네트워크안이라도 문제없습니다.

`주의) [운영 서버]에서 실행할 작업과 [백업 장비]에서 실행할 작업이 각각 나뉘어 있습니다.`

난이도 - 상


## [운영 서버] MySQL 백업 스크립트 설치

운영 서버내에 MySQL 백업 스크립트를 먼저 설치해야, 백업 장비에서 MySQL 백업본을 원격 백업할 수 있습니다.

운영 서버에서 MySQL 백업을 저장할 디렉토리를 만듭니다.

```
# mkdir -m 0700 -p /home/.mysql-backup
```

백업 보관 디렉토리로 이동합니다.

```
# cd /home/.mysql-backup
```

백업 보관 디렉토리에 백업 스크립트를 다운로드 받습니다.

```
# curl -s -o php79-remote-mysql-backup.sh https://raw.githubusercontent.com/php79/backup/master/php79-remote-mysql-backup.sh
```

MySQL root 비밀번호가 기록되므로, 접근 권한을 제한합니다.

```
# chmod 700 php79-remote-mysql-backup.sh
```

백업 스크립트를 열어 디비 접속정보 등을 수정합니다.

```
# vi php79-remote-mysql-backup.sh

# rsnapshot 원격 증분 백업시, MySQL 백업 설정
DB_USER='root'              # MySQL 사용자.  모든 디비를 백업하려면 root 계정 필요(기본값)
DB_PASS='MySQLRootPassword' # MySQL 비밀번호.
DB_HOST='localhost'         # MySQL 서버 주소.  별도 서버에 분리되지 않았다면 로컬 서버는 localhost 입력.
DB_BIN='/usr/bin'           # mysql, mysqldump 실행 파일의 경로.  기본 /usr/bin , 컴파일시 /usr/local/mysql/bin 등
```

> DB_PASS 는 반드시 수정하셔야 합니다.

> mysql 이 yum 패키지로 설치되지 않은 경우, DB_BIN 를 반드시 컴파일 설치한 디렉토리로 변경해야 합니다.

MySQL 백업이 정상적으로 이루어지는지 테스트해봅니다.

```
# ./php79-remote-mysql-backup.sh
# ls -lth

total 140K
-rw-r--r-- 1 root root  534 Nov 20 16:00 php79.sql.gz
-rw-r--r-- 1 root root 133K Nov 20 16:00 mysql.sql.gz

# gunzip -c *.sql.gz|more

-- MySQL dump 10.15  Distrib 10.0.21-MariaDB, for Linux (x86_64)
Ctrl + C
```


## [백업 장비] 백업 보관 디렉토리 생성

> 모든 명령은 root 권한으로 실행합니다.

백업 보관 디렉토리가 없을 경우, 다음 명령으로 만들어 줍니다.

```
# mkdir -m 0700 -p /backup/.snapshots
```

> 주의) 백업 보관 디렉토리는 운영 디스크와는 물리적으로 분리된 백업 디스크를 사용하셔야, 운영 디스크의 물리적인 장애에 대비할 수
 있습니다.


## [백업 장비] rsnapshot 설치

> 모든 명령은 root 권한으로 실행합니다.

먼저 CentOS 의 확장 저장소인 [EPEL](https://fedoraproject.org/wiki/EPEL)을 설치합니다.

```
# yum -y install epel-release
```

rsync 기반의 증분 백업 패키지인 rsnapshot 을 설치합니다.

```
# yum -y install rsnapshot
```


## [백업 장비] rsnapshot 권장 설정 다운로드

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

## [백업 장비] rsnapshot 원격 백업 설정

로컬 백업과 원격 백업은 /etc/rsnapshot.conf 설정 파일에서 백업할 디렉토리, MySQL 백업 부분만 다릅니다.
또한 1개 백업 장비에서 로컬 백업과 다른 서버들의 원격 백업도 함께 진행할 수 있습니다.

만약 백업 전용 장비로서, 로컬 백업이 불필요하다면 `# LOCALHOST` 부분의 backup, backup_script를 모두 주석처리(#)하시면 됩니다.

다음은 운영 서버가 192.168.0.101, 192.168.0.102 2대인 경우의 설정 예제입니다.

```
# vi /etc/rsnapshot.conf

# php79: 백업 보관 디렉토리
snapshot_root	/backup/.snapshots/

### LOCALHOST
# php79: 로컬에서 백업할 디렉토리를 설정합니다.
#  - 주의) 2개 이상의 인자값은 탭(tab)키로 구분해야 하며, 공백(space)키로 구분하면 에러가 발생합니다.
backup	/etc/	localhost/


### REMOTE
# server1 - ip: 192.168.0.101, ssh port: 22
backup_script	/usr/bin/ssh root@192.168.0.101 "/home/.mysql-backup/php79-remote-mysql-backup.sh"	server1/.remote-mysql-backup
backup	root@192.168.0.101:/home/	server1/	+rsync_long_args=--bwlimit=4096
backup	root@192.168.0.101:/etc/	server1/	+rsync_long_args=--bwlimit=4096
#backup	root@192.168.0.101:/usr/local/	server1/	+rsync_long_args=--bwlimit=4096
#backup	root@192.168.0.101:/opt/	server1/	+rsync_long_args=--bwlimit=4096
backup	root@192.168.0.101:/root/	server1/	+rsync_long_args=--bwlimit=4096
#backup	root@192.168.0.101:/var/named/	server1/	+rsync_long_args=--bwlimit=4096
backup	root@192.168.0.101:/var/lib/mysql/	server1/	+rsync_long_args=--bwlimit=4096

# server2 - ip: 192.168.0.102, ssh port: 2222
backup_script	/usr/bin/ssh root@192.168.0.102 "/home/.mysql-backup/php79-remote-mysql-backup.sh"	server2/.remote-mysql-backup
backup	root@192.168.0.102:/home/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
backup	root@192.168.0.102:/etc/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
#backup	root@192.168.0.102:/usr/local/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
#backup	root@192.168.0.102:/opt/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
backup	root@192.168.0.102:/root/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
#backup	root@192.168.0.102:/var/named/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
backup	root@192.168.0.102:/var/lib/mysql/	server2/	+rsync_long_args=--bwlimit=4096,+ssh_args=-p 2222
```

> `+rsync_long_args=--bwlimit=4096`: 운영 장비의 디스크 I/O, 네트워크 대역폭을 고려하여, 최대 4MB/s 속도로 백업합니다.

> `+ssh_args=-p 2222`: 운영 장비의 SSH 접속포트가 2222처럼 22가 아닐 경우, 별도로 선언해주어야 합니다.

> 192.168.0.101, 192.168.0.102 는 임의로 정한 서버 IP 이므로, 실제 운영 서버 IP로 변경하셔야 합니다.


설정 파일에 문제가 없는지 테스트합니다.

```
# rsnapshot configtest
Syntax OK
```


### [백업 장비] 운영 서버로 SSH 접속시, 비밀번호 입력 생략 처리

백업은 자동으로 이루어지므로, 운영 서버로 SSH 접속시마다 비밀번호를 입력할 수 없습니다.
따라서 백업 장비 root 계정의 공개키(id_rsa.pub)를 생성하여, 운영 서버 root 계정의 접근 허용키(authorized_keys)에 등록합니다.

먼저 백업 장비 root 계정의 공개키가 생성되어 있는지 확인합니다.

```
# ls -l  ~/.ssh/id_rsa.pub
ls: cannot access /root/.ssh/id_rsa.pub: No such file or directory
```

생성된 공개키가 없다면 다음 명령으로 생성해주어야 합니다.
3가지 확인은 모두 엔터만 누르시면 됩니다.
 - 저장 경로는 기본값 사용
 - 기본값, 비밀키 접근시 비밀번호 생략 처리

```
# ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa):
Enter passphrase (empty for no passphrase):
Enter same passphrase again:
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
ac:f8:1e:6d:14:ab:cf:cf:be:60:a6:75:77:cc:90:74 root@localhost.localdomain
The key's randomart image is:
+--[ RSA 2048]----+
|                 |
|                 |
|        .   . E  |
|       . o . o   |
|        S   o    |
|     . =     +   |
|    . + B . . +  |
|     . X + . .   |
|     .+ oo=.     |
+-----------------+
```

백업 장비 root 계정의 공개키(id_rsa.pub)를 운영 서버로 전송합니다.
 - 최초 접속시 접근 허용을 묻는 질문에 yes
 - 운영 서버의 root 비밀번호를 1회 입력하면, 운영 서버의 /root/.ssh/authorized_keys 에 공개키가 등록됩니다.

```
# ssh-copy-id root@192.168.0.101
The authenticity of host '192.168.0.101 (192.168.0.101)' can't be established.
RSA key fingerprint is ec:dd:9a:c7:bc:52:23:ad:e4:4c:bb:a4:4b:18:2c:49.
Are you sure you want to continue connecting (yes/no)? yes
Warning: Permanently added '192.168.0.101' (RSA) to the list of known hosts.
root@192.168.0.101's password:

Number of key(s) added: 1

Now try logging into the machine, with:   "ssh 'root@192.168.0.101'"
and check to make sure that only the key(s) you wanted were added.
```

> 참고) ssh port 22가 아닐 경우, `ssh-copy-id -p 2222 root@192.168.0.101`형태로 -p 옵션을 추가해야 합니다.

이제 비밀번호없이 백업 장비에서 운영 서버로 접근해서, IP를 확인하면 됩니다.

```
# ssh root@192.168.0.101
# ip -4 addr|grep -P 'eno|eth'
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc pfifo_fast state UP qlen 1000
    inet 192.168.0.101/24 brd 192.168.0.255 scope global eth0
```

> 참고) 운영 서버에선 백업 장비에 접근하면 안되므로, 운영 서버쪽에선 추가로 진행하실 작업이 없습니다.

> 참고2) 만약 백업 장비 root 계정의 비밀키(id_rsa)가 사고로 유출되는 등, 운영 서버로의 접근 허용을 취소하려면 운영 서버의
/root/.ssh/authorized_keys 에 등록된 백업 장비 공개키를 삭제해주시면 됩니다.


## [백업 장비] rsnapshot 백업 테스트

먼저 실제로 백업하지 않고, 백업시 사용되는 명령어만 확인해 봅니다.

```
# rsnapshot -t daily
...
mkdir -m 0755 -p /backup/.snapshots/daily.0/ 
/usr/bin/rsync -a --delete --numeric-ids --relative --delete-excluded /etc \
    /backup/.snapshots/daily.0/localhost/ 
...
```


실제로 백업하고, 백업 결과를 확인해 봅니다.  단, 데이타 용량이 많다면 서비스에 영향을 미칠 수 있으므로 생략해야 합니다.

```
# rsnapshot daily
```

> Cron 데몬에서 동작하므로 백업이 정상적으로 완료된 경우, 아무런 메세지를 출력하지 않습니다.


## [백업 장비] rsnapshot 백업 결과 확인

백업 보관 디렉토리에서 백업된 파일 목록을 확인하시면 됩니다.

```
# ls -lth /backup/.snapshots/
total 4.0K
drwxr-xr-x. 4 root root 36 Nov 20 00:22 daily.0
# ls -lth /backup/.snapshots/daily.0/server1/
total 16K
dr-xr-x---. 10 root root 4.0K Nov 20 00:17 root
drwxr-xr-x. 83 root root 8.0K Nov 20 00:08 etc
drwxr-xr-x.  3 root root   16 Oct 15 01:23 var
drwxr-xr-x.  4 root root   26 Oct 15 01:21 opt
drwxr-xr-x.  3 root root   18 Oct  7 04:48 usr
```

> 백업된 날짜별로 디렉토리가 다음처럼 구분됩니다.

```
daily.0 - 최근 일단위 백업
daily.1 - 하루 전 일단위 백업
weekly.0 - 최근 주단위 백업
monthly.0 - 최근 월단위 백업
```

> home/.mysql-backup 디렉토리에서 확장자가 sql.gz 인 것은 mysqldump로 만들어진 디비 백업 파일입니다.
> 꼭 압축을 풀어 디비가 정상적으로 백업되었는지 1회 확인하는 것을 권장합니다.


백업 로그를 통해서도, 에러 여부를 확인할 수 있습니다.

```
# tail -n50 /var/log/rsnapshot
...
[20/Nov/2015:13:30:12] /usr/bin/rsnapshot daily: started
...
[20/Nov/2015:13:32:19] /usr/bin/rsnapshot daily: completed successfully
```

> 운영 서버에서 실행되는 `php79-remote-mysql-backup.sh`의 로그는 운영 서버에서 확인하셔야 합니다.

```
# grep php79 /var/log/messages
Nov 20 17:37:48 localhost root: php79-backup info: /home/.mysql-backup/php79-remote-mysql-backup.sh - started
Nov 20 17:37:48 localhost root: php79-backup info: /home/.mysql-backup/php79-remote-mysql-backup.sh - completed successfully
```


## [백업 장비] rsnapshot 백업 스케쥴 등록

/etc/cron.d 에 백업 스케쥴을 다운로드 받으면, 매일/매주/매월 백업이 자동 실행됩니다.

```
# curl -s -o /etc/cron.d/php79-rsnapshot https://raw.githubusercontent.com/php79/backup/master/cron.d/php79-rsnapshot
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
