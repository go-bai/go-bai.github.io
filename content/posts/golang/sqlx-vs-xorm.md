---
title: "sqlx vs xorm"
date: 2024-03-09T10:49:09+08:00
draft: false
toc: true
tags: [golang,sqlx,golang,database,sql]
---

## 初始化演示环境

### 使用docker部署

部署的当前时间最新版本`postgres:16.2`

```bash
docker run -d --name pgsql \
  -e POSTGRES_USER=admin \
  -e POSTGRES_PASSWORD=passwd \
  -e POSTGRES_DB=testdb \
  -p 15432:5432 \
  postgres:16.2
```

### 使用`psql`连接

```bash
docker exec -it pgsql psql -U admin -d testdb
```

### 初始化`user`,`vps`和`host`表

```sql
CREATE TABLE "user" (
    id bigserial PRIMARY KEY,
    username VARCHAR(255) NOT NULL,
    password VARCHAR(255) NOT NULL
);
CREATE TABLE "host" (
    id bigserial PRIMARY KEY,
    hostname VARCHAR(255) NOT NULL
);
CREATE TABLE "vps" (
    id bigserial PRIMARY KEY,
    user_id bigint NOT NULL,
    host_id bigint NOT NULL,
    name VARCHAR(255) NOT NULL,
    sys_disk jsonb NOT NULL DEFAULT '{}'
);
```

### 查看创建出的表

```bash
testdb=# \z
                                 Access privileges
 Schema |    Name     |   Type   | Access privileges | Column privileges | Policies
--------+-------------+----------+-------------------+-------------------+----------
 public | host        | table    |                   |                   |
 public | host_id_seq | sequence |                   |                   |
 public | user        | table    |                   |                   |
 public | user_id_seq | sequence |                   |                   |
 public | vps         | table    |                   |                   |
 public | vps_id_seq  | sequence |                   |                   |
(6 rows)

testdb=# \d user
                                     Table "public.user"
  Column  |          Type          | Collation | Nullable |             Default
----------+------------------------+-----------+----------+----------------------------------
 id       | bigint                 |           | not null | nextval('user_id_seq'::regclass)
 username | character varying(255) |           | not null |
 password | character varying(255) |           | not null |
Indexes:
    "user_pkey" PRIMARY KEY, btree (id)

testdb=# \d host
                                     Table "public.host"
  Column  |          Type          | Collation | Nullable |             Default
----------+------------------------+-----------+----------+----------------------------------
 id       | bigint                 |           | not null | nextval('host_id_seq'::regclass)
 hostname | character varying(255) |           | not null |
Indexes:
    "host_pkey" PRIMARY KEY, btree (id)

testdb=# \d vps
                                     Table "public.vps"
  Column  |          Type          | Collation | Nullable |             Default
----------+------------------------+-----------+----------+---------------------------------
 id       | bigint                 |           | not null | nextval('vps_id_seq'::regclass)
 user_id  | bigint                 |           | not null |
 host_id  | bigint                 |           | not null |
 name     | character varying(255) |           | not null |
 sys_disk | jsonb                  |           | not null | '{}'::jsonb
Indexes:
    "vps_pkey" PRIMARY KEY, btree (id)
```

### 初始化数据

```sql
-- 插入用户数据
INSERT INTO "user" (username, password) VALUES
    ('user1', 'password1'),
    ('user2', 'password2');

-- 插入主机数据
INSERT INTO "host" (hostname) VALUES
    ('host1'),
    ('host2');

-- user1 在 host1 上创建一个 VPS
INSERT INTO "vps" (user_id, host_id, name, sys_disk) VALUES
    ((SELECT id FROM "user" WHERE username = 'user1'), (SELECT id FROM host WHERE hostname = 'host1'), 'vps_user1_host1', '{"disk_size": 50}');

-- user2 在 host1 上创建一个 VPS
INSERT INTO "vps" (user_id, host_id, name, sys_disk) VALUES
    ((SELECT id FROM "user" WHERE username = 'user2'), (SELECT id FROM host WHERE hostname = 'host1'), 'vps_user2_host1', '{"disk_size": 60}');

-- user1 在 host2 上创建一个 VPS
INSERT INTO "vps" (user_id, host_id, name, sys_disk) VALUES
    ((SELECT id FROM "user" WHERE username = 'user1'), (SELECT id FROM host WHERE hostname = 'host2'), 'vps_user1_host2', '{"disk_size": 70}');

-- user2 在 host2 上创建一个 VPS
INSERT INTO "vps" (user_id, host_id, name, sys_disk) VALUES
    ((SELECT id FROM "user" WHERE username = 'user2'), (SELECT id FROM host WHERE hostname = 'host2'), 'vps_user2_host2', '{"disk_size": 80}');
```

## 关于 `database/sql`

`database/sql`提供了操作SQL数据库的通用接口, 需要结合`database driver`同时使用, 这里是一些[驱动列表](https://go.dev/wiki/SQLDrivers)

使用用例可以看[官方wiki](https://go.dev/wiki/SQLInterface)

## 关于 `sqlx`

## 关于 `xorm`

## 使用场景对比

### 前情提要

使用

### 场景一: upsert/inster/update

插入结构体时, `nil`值类型字段会被怎么处理?

如何指定只插入某些字段

### 场景二: get/select

#### 分页查询并获取总行数`SelectAndCount`

### 场景三: 获取插入行的id

### 场景四: 连表查询

### 场景五: sql日志和trace

### 场景六: 

### 一些注意点

1. xorm

#### 

## 对比总结

经过使用`sqlx`来应对日常开发对我来说也是比较顺手的, 可以意识到一些使用`xorm`注意不到的点, 比如
