Day-2 Study Map (skim these before you start)

MySQL (what matters for today):

Server variables & editing config — where innodb_buffer_pool_size lives and how to change it:
“2.1.4 服务器系统变量 / 修改服务器系统变量 / 会话与全局 / sql_mode 等”.

Storage engine: InnoDB — characteristics (transactions, row locks, crash recovery) — today we rely on it:
“2.1.2.4 InnoDB 存储引擎；2.1.2.5 表空间；2.1.2.6 MVCC”.

mysqldump for backups — options, single-transaction, strategies, and restoring:
“2.3 MySQL 备份和恢复 → 2.3.3 mysqldump（常用选项、备份策略、备份/还原实践、周期性任务）”.

Binary logs (FYI) — not required today, but good context for backup consistency:
“2.2.6 二进制日志 & 2.2.7 二进制日志管理”.

(Optional, not for Day-2) Replication/HA concepts appear in the “Part 3” PDF if you’re curious:
“3.1–3.5 主从复制、GTID、MGR 等”.

MinIO (what matters for today):

What MinIO is and why we use it — S3-compatible object storage for backups:
“1 MinIO 介绍（对象存储、特点、S3 兼容）”.

Erasure Coding (conceptual) — how MinIO keeps objects safe (helpful background):
“1.4.2 纠删码 EC（工作方式、N/2 容错）”.

Deployment modes & how to deploy — single-node vs multi-node, install methods, K8s mention:
“2 MINIO 部署 → 2.1 部署模式和方法（单机/多机；包、二进制、Docker、Kubernetes）; 2.2 单机部署（示例与 systemd 服务）”.

Bucket & client (mc) — creating buckets and using the MinIO client to put objects (shown within the deployment/ops sections and examples):
“2.2 包安装 & service/env 配置示例（随后使用 mc 进行操作）”.
