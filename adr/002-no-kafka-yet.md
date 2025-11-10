# ADR-002: Why skip Kafka in MVP

We start with a MySQL-backed queue table to minimize cognitive and operational load.
Kafka can be swapped in later for higher throughput, replay, and decoupling once the demo baseline is solid.
