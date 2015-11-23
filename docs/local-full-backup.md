# 로컬 풀 백업

일반적인 PHP 기반의 웹사이트를 위한, 소스와 MySQL/Maria 디비를 계정 단위로 자동 백업하는 방법입니다.

난이도 - 하


## 백업 스케쥴

Cron 데몬을 통해, 매일 새벽 시간대에 자동 백업됩니다.
또한 백업 설정을 통해 기본값인 7일이 지난 백업 파일을 자동 삭제합니다.


## 백업 보관 디렉토리 생성

> 모든 명령은 root 권한으로 실행합니다.

백업 보관 디렉토리가 없을 경우, 다음 명령으로 만들어 줍니다.

```
# mkdir -m 0700 /backup
```

> 주의) 백업 보관 디렉토리는 운영 디스크와는 별도의 백업 디스크로 지정해야, 운영 디스크 장애에 대비할 수 있습니다.


## 백업 스크립트 다운로드 및 Cron 스케쥴 등록

매일 새벽에 실행되도록 /etc/cron.daily 디렉토리에 백업 스크립트를 다운로드 받습니다.

```
# curl -s -o /etc/cron.daily/php79-backup https://raw.githubusercontent.com/php79/backup/master/php79-backup.sh
```

MySQL root 비밀번호가 기록되므로, 접근 권한을 제한합니다.

```
# chmod 700 /etc/cron.daily/php79-backup
```

> 다운로드만으로 백업이 매일 새벽에 실행되니, 반드시 나머지 설정을 완료하거나,
백업을 원치 않는다면 다운로드 받은 파일을 삭제해야 합니다.


## 백업 설정

백업 스크립트를 열어 백업을 저장할 공간과 디비 접속정보 등을 수정합니다.

```
# vi /etc/cron.daily/php79-backup

# 로컬 풀 백업 설정
BACKUP_DIR=/backup          # 백업 보관 디렉토리
BACKUP_EXPIRES_DAYS=7       # 백업 만료 기간.   기본값 7일이 지난 백업 자동 삭제.
BACKUP_PREFIX='ServerName'  # 백업 파일명 앞에 덧붙일 이름(서버명, 사이트명 등...)
DB_USER='root'              # MySQL 사용자.  모든 디비를 백업하려면 root 계정 필요(기본값)
DB_PASS='MySQLRootPassword' # MySQL 비밀번호.
DB_HOST='localhost'         # MySQL 서버 주소.  별도 서버에 분리되지 않았다면 로컬 서버는 localhost 입력.
DB_BIN='/usr/bin'           # mysql, mysqldump 실행 파일의 경로.  기본 /usr/bin , 컴파일시 /usr/local/mysql/bin 등
```

> BACKUP_DIR, DB_PASS 는 반드시 수정하셔야 합니다.

> mysql 이 yum 패키지로 설치되지 않은 경우, DB_BIN 를 반드시 컴파일 설치한 디렉토리로 변경해야 합니다.

> BACKUP_PREFIX 는 단순히 백업파일명을 구분하기 위한 서버이름을 변경해주시면 됩니다.

## 백업 테스트

테스트를 위해 수동으로 백업 스크립트를 실행해 봅니다.

```
# /etc/cron.daily/php79-backup
```

> Cron 데몬에서 동작하므로 백업이 정상적으로 완료된 경우, 아무런 메세지를 출력하지 않습니다.

> 에러, 경고 등이 출력된 경우 /etc/crontab 파일의 MAILTO 변수에 선언된 메일 주소로 에러를 받아볼 수 있습니다. 


## 백업 결과 확인

1. 백업 보관 디렉토리에서 백업된 파일 목록을 확인하시면 됩니다.

```
# ls -lth /backup/
total 584M
-rw-r--r-- 1 root root 9.3M Nov 18 16:08 ServerName.20151118_160755.CONFIG.ETC.Php79Backup.tgz
-rw-r--r-- 1 root root 245M Nov 18 16:08 ServerName.20151118_160755.php79.Php79Backup.tgz
-rw-r--r-- 1 root root 100K Nov 18 16:07 ServerName.20151118_160755.php79.Php79Backup.sql.gz
-rw-r--r-- 1 root root 133K Nov 18 16:07 ServerName.20151118_160755.mysql.Php79Backup.sql.gz
...
```

> 백업 파일들중 확장자가 sql.gz 인 것은 mysqldump로 만들어진 디비 백업 파일입니다.

> 꼭 압축을 풀어 디비가 정상적으로 백업되었는지 1회 확인하는 것을 권장합니다. 

2. 하루 뒤에 실제 Cron 데몬에서 자동 백업이 이루어졌는지 백업 보관 디렉토리를 한번 더 확인해보시면 정확합니다.

3. 백업 실행 과정에서의 메세지, 에러는 syslog에도 기록 됩니다.

```
# grep php79 /var/log/messages
Nov 18 17:15:06 localhost root: php79-backup info: /etc/cron.daily/php79-backup - started
Nov 18 17:15:06 localhost root: php79-backup error: mysql 접속이 실패하였습니다.
Nov 18 17:22:55 localhost root: php79-backup info: /etc/cron.daily/php79-backup - started
Nov 18 17:23:10 localhost root: php79-backup info: /etc/cron.daily/php79-backup - completed successfully
```

## 백업 보관 기간

백업된 용량과 백업 디스크의 여유 공간을 보고, 백업 설정에서 백업 보관 기간(BACKUP_EXPIRES_DAYS)을 적절히 변경하시면 됩니다.
기본값은 7일이며, 백업 용량이 계속 증가할 수 있는 점을 고려하시면 됩니다.


## 백업 스크립트 삭제

더 이상 자동 백업을 원하지 않으실 경우, 백업 스크립트를 삭제하시면 됩니다.

```
# rm /etc/cron.daily/php79-backup
```

---

[목차](../README.md)
