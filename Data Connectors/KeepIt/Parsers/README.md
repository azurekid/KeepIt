# KeepIt ASIM AuditEvent parser documentation

## Overview

This document describes the KeepIt source-specific ASIM parser function named vimAuditEventKeepIt.

- Parser function: vimAuditEventKeepIt
- Source table: KeepitAuditLogs_CL
- Output schema: ASIM AuditEvent

The parser normalizes KeepIt audit records to a source-agnostic shape so detections and hunting queries can reuse common AuditEvent fields.

## Data flow

1. The Function App ingests KeepIt records into KeepitAuditLogs_CL.
2. TimeGenerated in KeepitAuditLogs_CL is populated from EventStartTime by the DCR transform.
3. The parser reads KeepitAuditLogs_CL and maps raw columns into ASIM AuditEvent fields.

## Parser parameters

This parser is now defined as a no-argument function: vimAuditEventKeepIt().

Apply filters after invoking the function in your query.

## Column mapping

Raw source to ASIM mapping:

- TimeGenerated -> TimeGenerated
- user or account (with fallback to token or username) -> ActorUsername
- ipaddress -> SrcIpAddr
- account or connector -> TargetObject
- method -> EventOriginalType
- event -> EventMessage
- acl, connector, method, metadata, uploadtime -> AdditionalFields

Derived fields:

- EventType is inferred from event text using keyword matching.
- EventResult is inferred from event text. Failure keywords map to Failure, all other values map to Success.
- EventSeverity is Low for Failure and Informational otherwise.
- ActorUsername uses a fallback chain: user -> account -> token -> username.
- ActorUsernameType is inferred by simple pattern matching:
  - contains @ -> UPN
  - otherwise Unknown

## Function definition and usage

Save the parser query from the file vimAuditEventKeepIt.kql as a function in Microsoft Sentinel with the name vimAuditEventKeepIt.

Example usage:

- No filters:
  vimAuditEventKeepIt()

- Last 24 hours:
  vimAuditEventKeepIt()
  | where TimeGenerated >= ago(24h)

- Failed events only:
  vimAuditEventKeepIt()
  | where TimeGenerated >= ago(7d)
  | where EventResult == "Failure"

- Specific source IP prefix:
  vimAuditEventKeepIt()
  | where TimeGenerated >= ago(1d)
  | where has_any_ipv4_prefix(SrcIpAddr, dynamic(["10.10."]))

## Validation checklist

- KeepitAuditLogs_CL contains records.
- TimeGenerated reflects event time, not ingestion time.
- uploadtime reflects ingestion time.
- vimAuditEventKeepIt returns expected ActorUsername, SrcIpAddr, EventType, and EventResult values.

## Troubleshooting

- If TimeGenerated equals uploadtime for all rows, verify the Function App payload includes EventStartTime and the DCR transform sets TimeGenerated from EventStartTime.
- If parser returns no results, validate downstream query filters and table data freshness.
- If EventType classification is too generic, tune keyword logic in vimAuditEventKeepIt.kql.
