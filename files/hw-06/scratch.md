# Конспект по выполнению задания

## Запуск контейнеров

### MySQL DB01
    docker run -d -p 3306:3306 \
    --network=mysql \
    -v DB01-mysql:/var/lib/mysql \
    --mount type=bind,src=./files,dst=/files \
    --mount type=bind,src=./configs,dst=/etc/mysql/conf.d \
    --env-file .env \
    --name DB01-mysql-8.0.45 \
    mysql:8.0.45-debian

### MySQL DB02
    docker run -d -p 3307:3306 \
    --network=mysql \
    -v DB02-mysql:/var/lib/mysql \
    --mount type=bind,src=./files,dst=/files \
    --mount type=bind,src=./configs,dst=/etc/mysql/conf.d \
    --env-file .env \
    --name DB02-mysql-8.0.45 \
    mysql:8.0.45-debian

### MySQL DB03
    docker run -d -p 3308:3306 \
    --network=mysql \
    -v DB03-mysql:/var/lib/mysql \
    --mount type=bind,src=./files,dst=/files \
    --mount type=bind,src=./configs,dst=/etc/mysql/conf.d \
    --env-file .env \
    --name DB03-mysql-8.0.45 \
    mysql:8.0.45-debian

### PostgreSQL DB01
    docker run -d -p 5433:5432 \
    --network=postgre \
    -v DB01-postgre:/var/lib/postgresql \
    --mount type=bind,src=./files,dst=/files \
    --env-file .env \
    --name DB01-postgre-18 \
    postgres:18-bookworm

## Работа с дампами и репликацией

### Создание дампа
    mysqldump --all-databases --source-data --single-transaction > source_data.db

### Импорт дампа в контейнер
    docker exec -t DB02-mysql-8.0.45 sh -c 'mysql -u root -p"$MYSQL_ROOT_PASSWORD" < /files/source_data.db'

### Настройка конфигурации
    echo -e "[mysqld] \nserver-id=3" > /etc/mysql/conf.d/10-main.cnf

### Настройка репликации (старый синтаксис)
    CHANGE MASTER TO MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=157;

### Настройка репликации (новый синтаксис)
    CHANGE REPLICATION SOURCE TO
        SOURCE_HOST='DB01-mysql-8.0.45',
        SOURCE_USER='repl',
        SOURCE_PASSWORD='password',
        SOURCE_LOG_FILE='recorded_log_file_name',
        SOURCE_LOG_POS=recorded_log_position,
        SOURCE_AUTO_POSITION = 1,
        Get_Source_public_key=1;

### Пример настройки
    CHANGE REPLICATION SOURCE TO
        SOURCE_HOST='mysql-8.0.45',
        SOURCE_USER='repl',
        SOURCE_PASSWORD='password',
        SOURCE_LOG_FILE='binlog.000016',
        SOURCE_LOG_POS=157;

## Параметры конфигурации

### Основной файл для master
    [mysqld]
    server-id=1
    report_host=DB01-mysql-8.0.45
    gtid_mode=ON
    enforce_gtid_consistency=ON
    log_bin=binlog
    disabled_storage_engines="MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY"
    log_replica_updates=ON
    binlog_checksum=CRC32
    lower_case_table_names=1

### Настройки только для чтения на реплике
    [mysqld]
    server-id=2
    read_only = ON
    super_read_only = ON
    gtid_mode=ON
    enforce_gtid_consistency=ON

## Полезные команды проверки

    SHOW VARIABLES LIKE 'require_secure_transport';
    SHOW VARIABLES LIKE 'have_ssl';
    SHOW VARIABLES LIKE 'Caching%';
    SHOW VARIABLES LIKE 'default%';

    SELECT plugin, authentication_string FROM mysql.user WHERE `User` = 'repl';

    SHOW COLUMNS FROM actor FROM sakila_test;

    USE sakila_test;
    SELECT * FROM actor ORDER BY actor_id DESC LIMIT 10;

    INSERT INTO actor (actor_id, first_name, last_name, last_update) VALUES (201, 'test', 'test', '2026-04-18 21:00:00');

## Процедура генерации нагрузки
    DELIMITER $$
    CREATE PROCEDURE generate_load()
    BEGIN
        DECLARE v_id INT DEFAULT 202;
        DECLARE v_name VARCHAR(45);
        WHILE TRUE DO
            SET v_name = CONCAT('test', v_id);
            INSERT INTO actor (actor_id, first_name, last_name, last_update)
            VALUES (v_id, v_name, 'load_test', NOW());
            SET v_id = v_id + 1;
            DO SLEEP(30);
            IF v_id > 300 THEN
                DELETE FROM actor WHERE actor_id BETWEEN 202 AND 300;
                SET v_id = 202;
            END IF;
        END WHILE;
    END$$
    DELIMITER ;

## GTID и анонимные транзакции
    SELECT @@GLOBAL.gtid_executed;
    SELECT @@GLOBAL.GTID_OWNED;
    SHOW STATUS LIKE 'Ongoing_anonymous_transaction_count';
    SHOW BINARY LOGS;
    SHOW BINLOG EVENTS;
    FLUSH LOGS;
    PURGE BINARY LOGS TO 'binlog.000020';

## Групповая репликация

### Конфигурация для групповой репликации
    plugin_load_add='group_replication.so'
    plugin-load-add='mysql_clone.so'
    disabled_storage_engines="MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY"
    group_replication_group_name="c2062b54-41d7-11f1-bda3-baf33d20d4db"
    group_replication_start_on_boot=off
    group_replication_local_address= "DB01-mysql-8.0.45:33061"
    group_replication_group_seeds= "DB01-mysql-8.0.45:33061,DB02-mysql-8.0.45:33061,DB03-mysql-8.0.45:33061"
    group_replication_bootstrap_group=off

### Дополнительные требования для групповой репликации
    disabled_storage_engines="MyISAM,BLACKHOLE,FEDERATED,ARCHIVE,MEMORY"
    log_replica_updates=ON
    binlog_checksum=CRC32
    gtid_mode=ON
    enforce_gtid_consistency=ON
    lower_case_table_names=1
    binlog_transaction_dependency_tracking=WRITESET

### Для режима Multi-Primary
    transaction-isolation=READ-COMMITTED
    group_replication_enforce_update_everywhere_checks=ON

### Настройка канала восстановления
    CHANGE REPLICATION SOURCE TO
        SOURCE_USER='repl',
        SOURCE_PASSWORD='password'
        FOR CHANNEL 'group_replication_recovery';

    START GROUP_REPLICATION;

### Управление групповой репликацией
    SELECT group_replication_set_as_primary('member_id');
    SELECT group_replication_switch_to_multi_primary_mode();
    SELECT group_replication_switch_to_single_primary_mode();
    SELECT * FROM performance_schema.replication_group_members;
    SELECT PLUGIN_NAME, PLUGIN_STATUS FROM INFORMATION_SCHEMA.PLUGINS WHERE PLUGIN_NAME = 'clone' OR PLUGIN_NAME = 'group_replication';
    INSTALL PLUGIN clone SONAME 'mysql_clone.so';

## PostgreSQL

### Список всех баз данных
    SELECT datname FROM pg_database;

### Создание чистой базы данных (шаблон `template0`)
    CREATE DATABASE task2 TEMPLATE template0;

### Таблица `users`
    CREATE TABLE users (
        id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        login VARCHAR(50) NOT NULL UNIQUE,
        password TEXT NOT NULL,
        created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
    );

### Наполнение таблицы `users`
    INSERT INTO users (login, password)
    SELECT 'user_' || i, md5(random()::text)
    FROM generate_series(1, 20) AS i;

### Таблица `books`
    CREATE TABLE books (
        id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        title TEXT NOT NULL,
        publication_year SMALLINT NOT NULL
    );

### Наполнение таблицы `books`
    INSERT INTO books (title, publication_year) VALUES
        ('Война и мир', 1869),
        ('Преступление и наказание', 1866),
        ('Мастер и Маргарита', 1967),
        ('1984', 1949),
        ('Улисс', 1922),
        ('Великий Гэтсби', 1925),
        ('Гарри Поттер и философский камень', 1997),
        ('Властелин колец: Братство кольца', 1954),
        ('Гордость и предубеждение', 1813),
        ('Моби Дик', 1851),
        ('Анна Каренина', 1877),
        ('Над пропастью во ржи', 1951),
        ('Три товарища', 1936),
        ('Сто лет одиночества', 1967),
        ('Лолита', 1955),
        ('Дон Кихот', 1605),
        ('Гамлет', 1603),
        ('Фауст', 1808),
        ('Божественная комедия', 1320),
        ('Декамерон', 1353);

### Таблица `store`
    CREATE TABLE store (
        id INT PRIMARY KEY GENERATED ALWAYS AS IDENTITY,
        name TEXT NOT NULL,
        city TEXT NOT NULL
    );

### Наполнение таблицы `store`
    INSERT INTO store (name, city) VALUES
        ('Читай-город', 'Москва'),
        ('Буквоед', 'Санкт-Петербург'),
        ('Мир книг', 'Новосибирск'),
        ('Лабиринт', 'Екатеринбург'),
        ('Дом книги', 'Казань'),
        ('Академкнига', 'Нижний Новгород'),
        ('Книжный клуб', 'Челябинск'),
        ('Читай-город', 'Самара'),
        ('Буквоед', 'Омск'),
        ('Мир книг', 'Ростов-на-Дону'),
        ('Лабиринт', 'Уфа'),
        ('Дом книги', 'Красноярск'),
        ('Академкнига', 'Пермь'),
        ('Книжный клуб', 'Воронеж'),
        ('Читай-город', 'Волгоград'),
        ('Буквоед', 'Москва'),
        ('Мир книг', 'Санкт-Петербург'),
        ('Лабиринт', 'Новосибирск'),
        ('Дом книги', 'Екатеринбург'),
        ('Книжный клуб', 'Казань');

### Создание дампа PostgreSQL
    pg_dump task2 > DB.task2-pg