@tool
class_name Log

const LOGLEVEL = LogLevel.Trace

enum LogLevel {
	Error,
	Warn,
	Info,
	Debug,
	Trace,
}


static func LOG(message, level: LogLevel = LogLevel.Info) -> void:
	if level > LOGLEVEL:
		return
	match level:
		LogLevel.Error:
			push_error(message)
		LogLevel.Warn:
			push_warning(message)
		_:
			print(message)


static func INFO(message) -> void:
	LOG(message, LogLevel.Info)


static func WARN(message) -> void:
	LOG(message, LogLevel.Warn)


static func ERROR(message) -> void:
	LOG(message, LogLevel.Error)


static func DEBUG(message) -> void:
	LOG(message, LogLevel.Debug)


static func TRACE(message) -> void:
	LOG(message, LogLevel.Trace)
