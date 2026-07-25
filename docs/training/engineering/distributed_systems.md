---
title: Distributed Systems
description: Distributed Systems for Inkorporated.
tags: [enterprise]
---

# Distributed Systems Concepts


**What's on this page**

- Core content for this topic in the Inkorporated enterprise OS.
- Practical guidance, roles, or standards as applicable.

**What this enables**

- Consistent enterprise operations and decision-making.
- Shared language for humans and cyborg AI agents.

## Overview
Understanding distributed systems is critical for building scalable, reliable applications at our scale.

## Core Concepts

### CAP Theorem
* **Consistency**: Every read receives the most recent write or an error.
* **Availability**: Every request receives a (non-error) response, without the guarantee that it contains the most recent write.
* **Partition Tolerance**: The system continues to operate despite an arbitrary number of messages being dropped (or delayed) by the network between nodes.

### PACELC Theorem
An extension of CAP that states in case of network partitioning (P) in a distributed computer system, one has to choose between availability (A) and consistency (C) (as per the CAP theorem), but else (E), even when the system is running normally in the absence of partitions, one has to choose between latency (L) and consistency (C).

## Sharding Strategies
* **Key-Based Sharding**: Distributing data based on a hash of a key.
* **Range-Based Sharding**: Distributing data based on ranges of key values.
* **Directory-Based Sharding**: Using a lookup table to find the shard.

## Consistency Models
* **Strong Consistency**: Sequential consistency.
* **Eventual Consistency**: If no new updates are made to a given data item, eventually all accesses to that item will return the last updated value.
