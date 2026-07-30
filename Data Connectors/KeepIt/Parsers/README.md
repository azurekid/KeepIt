# KeepIt ASIM parsers

This folder contains KQL functions for normalizing KeepIt audit logs into ASIM-compatible output.

## KeepIt AuditEvent parser

- Parser function: `vimAuditEventKeepIt`
- Source table: `KeepitAuditLogs_CL`
- ASIM schema: `AuditEvent`

The function is designed to be saved in Microsoft Sentinel as a query function and used as the source-specific KeepIt AuditEvent parser.
