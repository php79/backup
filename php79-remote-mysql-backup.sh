#!/bin/bash

# Copyright:: Copyright (c) 2015 Been Kyung-yoon (http://www.php79.com/)
# License:: The MIT License (MIT)
# Version:: 0.9.0

# rsnapshot 원격 증분 백업시, MySQL 백업 설정
DB_USER='root'              # MySQL 사용자.  모든 디비를 백업하려면 root 계정 필요(기본값)
DB_PASS='MySQLRootPassword' # MySQL 비밀번호.
DB_HOST='localhost'         # MySQL 서버 주소.  별도 서버에 분리되지 않았다면 로컬 서버는 localhost 입력.
DB_BIN='/usr/bin'           # mysql, mysqldump 실행 파일의 경로.  기본 /usr/bin , 컴파일시 /usr/local/mysql/bin 등

#  주의) 본 스크립트는 rsnapshot 전용으로, 백업 실행시 현재 디렉토리에서 *sql.gz 백업을 지우고 있습니다.
#   따라서, [로컬 풀 백업](docs/local-full-backup.md)을 원하실 경우 php79-backup.sh 를 사용해야 합니다.

# 메세지/로그 - 에러
function php79_error
{
  echo "error: $1"
  logger "php79-backup error: $1"
}

# 메세지/로그 - 정보
function php79_info
{
  # Cron 데몬에서 실행되므로, 정보는 화면에 출력하지 않음.
  logger "php79-backup info: $1"
}

# mysql, mysqldump 경로 확인
if [ ! -f $DB_BIN/mysql ]; then
  php79_error "[ $DB_BIN/mysql ] 파일이 존재하지 않습니다."
  exit 1
fi

if [ ! -f $DB_BIN/mysqldump ]; then
  php79_error "[ $DB_BIN/mysqldump ] 파일이 존재하지 않습니다."
  exit 1
fi

# 백업 시작
php79_info "$0 - started"

# 백업 보관 디렉토리
BACKUP_DIR=`dirname $0`          

# 이전 MySQL 백업 삭제
rm -f $BACKUP_DIR/*.sql.gz

# MySQL 백업
DB_LIST=$($DB_BIN/mysql -u $DB_USER --password=$DB_PASS -h $DB_HOST -e "SHOW DATABASES;" | grep -Ev "(Database|information_schema|performance_schema)")
if [ "$?" != "0" ]; then
  php79_error "mysql 접속이 실패하였습니다."
  php79_error "[command] $DB_BIN/mysql -u $DB_USER --password=**** -h $DB_HOST -e \"SHOW DATABASES;\""
  #exit 1 # 디비 접속 장애시에도, /home 등 나머지는 백업 진행되어야 함.
fi
for db in $DB_LIST
do
  $DB_BIN/mysqldump -u $DB_USER --password=$DB_PASS -h $DB_HOST \
  --default-character-set=utf8 --opt --skip-lock-tables --single-transaction -Q -B $db \
  | gzip > $BACKUP_DIR/$db.sql.gz
  if [ "$?" != "0" ]; then
    php79_error "[ $db ] mysqldump 작업이 실패하였습니다."
  fi
done


# 백업 완료 - 크론 데몬에서 실행되므로, 완료시 별도 메세지 출력안함.
php79_info "$0 - completed successfully"
