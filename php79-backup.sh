#!/bin/bash

# Copyright:: Copyright (c) 2015 Been Kyung-yoon (http://www.php79.com/)
# License:: The MIT License (MIT)
# Version:: 1.0.0

# 로컬 풀 백업 설정
BACKUP_DIR=/backup          # 백업 보관 디렉토리
BACKUP_EXPIRES_DAYS=7       # 백업 만료 기간.   기본값 7일이 지난 백업 자동 삭제.
BACKUP_PREFIX='ServerName'  # 백업 파일명 앞에 덧붙일 이름(서버명, 사이트명 등...)
DB_USER='root'              # MySQL 사용자.  모든 디비를 백업하려면 root 계정 필요(기본값)
DB_PASS='MySQLRootPassword' # MySQL 비밀번호.
DB_HOST='localhost'         # MySQL 서버 주소.  별도 서버에 분리되지 않았다면 로컬 서버는 localhost 입력.
DB_BIN='/usr/bin'           # mysql, mysqldump 실행 파일의 경로.  기본 /usr/bin , 컴파일시 /usr/local/mysql/bin 등

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

# 백업 디렉토리가 존재할 경우에만 백업 시작
if [ ! -d $BACKUP_DIR ]; then
  php79_error "[ $BACKUP_DIR ] 백업 보관 디렉토리가 존재하지 않습니다."
  exit 1
fi


# 백업 시작
FN=`date +%Y%m%d"_"%H%M%S`
php79_info "$0 - started"


# 백업 보관 기간이 지난 백업본 삭제
#  - 수정 주의: find 명령에 -delete 옵션이 추가되어, 실제 오래된 파일이 삭제됩니다.
#  -           불가피하게 수정해야 한다면 꼭 별도 테스트를 거치셔야 합니다.
cd $BACKUP_DIR
DELETED=`find $BACKUP_DIR -maxdepth 1 -mtime +$BACKUP_EXPIRES_DAYS -type f \
-name $BACKUP_PREFIX".*.Php79Backup.sql.gz" -delete -print0`
if [ "$DELETED" != "" ]; then
  php79_info "Deleting expired backups - $DELETED"
fi
DELETED=`find $BACKUP_DIR -maxdepth 1 -mtime +$BACKUP_EXPIRES_DAYS -type f \
-name $BACKUP_PREFIX".*.Php79Backup.tgz" -delete -print0`
if [ "$DELETED" != "" ]; then
  php79_info "Deleting expired backups - $DELETED"
fi

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
  | gzip > $BACKUP_PREFIX.$FN.$db.Php79Backup.sql.gz
  if [ "$?" != "0" ]; then
    php79_error "[ $db ] mysqldump 작업이 실패하였습니다."
  fi
done

# /home 디렉토리 백업.
HOME_LIST=$(find /home/ -mindepth 1 -maxdepth 1 -type d -printf '%f\n'| grep -Ev "(lost\+found)")
for _home in $HOME_LIST
do
  tar zcf $BACKUP_PREFIX.$FN.$_home.Php79Backup.tgz /home/$_home \
  2>&1 | grep -v "tar: Removing leading"
done

# /etc/ 디렉토리 백업.
tar zcf $BACKUP_PREFIX.$FN.CONFIG.ETC.Php79Backup.tgz /etc/ \
2>&1 | grep -v "tar: Removing leading"

# /var/named/ 디렉토리 존재시에만 백업
if [ -d /var/named/ ]; then
  tar zcf $BACKUP_PREFIX.$FN.CONFIG.NAMED.Php79Backup.tgz /var/named/ \
  2>&1 | grep -v "tar: Removing leading"
fi

# 사용자 정의 백업 - 다른 디렉토리는 다음 샘플처럼 디렉토리명을 지정해서 백업을 추가하시면 됩니다.
#tar zcf $BACKUP_PREFIX.$FN.CONFIG.usr-local.Php79Backup.tgz /usr/local/ \
#2>&1 | grep -v "tar: Removing leading"

#tar zcf $BACKUP_PREFIX.$FN.CONFIG.php-modules.Php79Backup.tgz /usr/lib64/php/modules/ \
#2>&1 | grep -v "tar: Removing leading"

#tar zcf $BACKUP_PREFIX.$FN.CONFIG.php79-stack.Php79Backup.tgz /opt/php79/stack/ \
#2>&1 | grep -v "tar: Removing leading"

#
#

# 백업 완료 - 크론 데몬에서 실행되므로, 완료시 별도 메세지 출력안함.
php79_info "$0 - completed successfully"
