# rsnapshot 백업 결과 확인

rsnapshot 으로 백업된 결과에 대해, 정상 백업되었는지 확인하는 과정입니다.

## 파일 갯수 및 용량 비교

/home 디렉토리를 기준으로 운영중인 디렉토리와 백업된 디렉토리를 비교하는 예제입니다.

- 운영 디렉토리 (원격 증분 백업 시, 운영 서버에 접속하셔서 실행하면 됩니다.)

```
# cd /
# echo -n 'Current directory: ' && pwd ; echo -n 'File Count: ' && find home/ -type f|wc -l ; echo -n 'File Size(MB): ' && du -ms home/
Current directory: /
File Count: 168484
File Size(MB): 1255     home/
```

- 백업 디렉토리

```
# cd /backup/.snapshots/daily.0/localhost
# echo -n 'Current directory: ' && pwd ; echo -n 'File Count: ' && find home/ -type f|wc -l ; echo -n 'File Size(MB): ' && du -ms home/
Current directory: /backup/.snapshots/daily.0/localhost
File Count: 168484
File Size(MB): 1256     home/
```


## MySQL 백업 결과 확인

간략하게 데이타베이스 목록과 데이타베이스 별로 백업이 완료된 시간만 출력해봅니다.
(1일 이내에 sql.gz 확장자를 가진 파일만 대상으로 합니다.)

```
cd /backup/.snapshots/daily.0/localhost/mysqldump
DUMP_LIST=$(find . -name '*.sql.gz' -type f -mtime -1 -print)
for _dump in $DUMP_LIST
do
  gunzip -c $_dump|head -n50|grep 'CREATE DATABASE'
  gunzip -c $_dump|tail -n1
done
```

```
CREATE DATABASE /*!32312 IF NOT EXISTS*/ `mysql` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;
-- Dump completed on 2015-11-20 17:57:24
CREATE DATABASE /*!32312 IF NOT EXISTS*/ `php79` /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci */;
-- Dump completed on 2015-11-20 17:57:24
```

> 가장 정확한 건 실제 sql.gz 파일을 열어 정상인지 직접 확인해봐야 합니다.

---

[목차](../README.md)
