/// <p>Structured JSON logging utility for IRISCouch (Story 9.3, NFR-O5).</p>
/// <p>Writes structured log entries to the IRIS console log (<code>cconsole.log</code>)
/// via <code>$ZU(9, "", message)</code>. All entries are JSON formatted for
/// compatibility with log aggregation systems.</p>
/// <h4>Log entry format:</h4>
/// <pre>
/// {"ts":"2026-04-14T10:30:45Z","level":"info","subsystem":"document","msg":"Document saved","data":{...}}
/// </pre>
/// <h4>Safety guarantee:</h4>
/// <p>All methods wrap in Try/Catch so logging failures never propagate to
/// callers. Logging is informational and must not affect application behavior.</p>
Class IRISCouch.Util.Log Extends %RegisteredObject
{

/// <p>Emit a structured log entry at INFO level.</p>
/// <p>Use for normal operational events: document saves, replication completions,
/// configuration changes.</p>
/// @param pSubsystem The subsystem name (e.g., "document", "replication", "system")
/// @param pMessage Human-readable log message
/// @param pData Optional %DynamicObject with additional structured data
ClassMethod Info(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("info", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at WARN level.</p>
/// <p>Use for recoverable issues that may need attention: degraded performance,
/// missing optional configuration, approaching limits.</p>
/// @param pSubsystem The subsystem name
/// @param pMessage Human-readable log message
/// @param pData Optional %DynamicObject with additional structured data
ClassMethod Warn(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("warn", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at ERROR level.</p>
/// <p>Use for errors that affect operations: failed writes, internal errors,
/// security violations.</p>
/// @param pSubsystem The subsystem name
/// @param pMessage Human-readable log message
/// @param pData Optional %DynamicObject with additional structured data
ClassMethod Error(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("error", pSubsystem, pMessage, pData)
}

/// <p>Emit a structured log entry at DEBUG level.</p>
/// <p>Only emitted when IRIS debug logging is enabled. Use for detailed
/// diagnostic information during troubleshooting.</p>
/// @param pSubsystem The subsystem name
/// @param pMessage Human-readable log message
/// @param pData Optional %DynamicObject with additional structured data
ClassMethod Debug(pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "")
{
    Do ..Emit("debug", pSubsystem, pMessage, pData)
}

/// <p>Core log emission method. Constructs a JSON log entry and writes to
/// IRIS console log via <code>$ZU(9, "", message)</code>.</p>
/// <p>Wrapped in Try/Catch — logging failures must never propagate.</p>
/// @param pLevel Log level: "info", "warn", "error", "debug"
/// @param pSubsystem The subsystem name
/// @param pMessage Human-readable log message
/// @param pData Optional %DynamicObject with additional structured data
ClassMethod Emit(pLevel As %String, pSubsystem As %String, pMessage As %String, pData As %DynamicObject = "") [ Private ]
{
    Try {
        ; Build structured JSON log entry
        Set tEntry = {}
        Do tEntry.%Set("ts", ..FormatTimestamp())
        Do tEntry.%Set("level", pLevel)
        Do tEntry.%Set("subsystem", pSubsystem)
        Do tEntry.%Set("msg", pMessage)
        If $IsObject(pData) {
            Do tEntry.%Set("data", pData)
        }
        Set tLogLine = "[IRISCouch] " _ tEntry.%ToJSON()
        ; Map level to $ZU(9) severity: 0=info, 1=warn, 2=error
        Set tSeverity = 0
        If pLevel = "warn" Set tSeverity = 1
        If pLevel = "error" Set tSeverity = 2
        ; Write to IRIS console log (cconsole.log)
        Do $ZU(9, "", tLogLine, tSeverity, 1)
    }
    Catch ex {
        ; Logging failures must never propagate — silently swallow
    }
}

/// <p>Format current timestamp in ISO 8601 UTC format.</p>
/// @return %String Timestamp like "2026-04-14T10:30:45Z"
ClassMethod FormatTimestamp() As %String [ Private ]
{
    Set tH = $ZTimestamp
    Set tDate = $ZDate($Piece(tH, ",", 1), 3)
    Set tTime = $ZTime($Piece(tH, ",", 2), 1)
    Quit tDate _ "T" _ tTime _ "Z"
}

}
