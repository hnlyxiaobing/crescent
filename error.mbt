///|
/// Error type for I/O operations such as file reads or writes.
pub suberror IOError derive(Debug)

///|
pub extend IOError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Error type for network-related failures such as connection errors.
pub suberror NetworkError derive(Debug)

///|
pub extend NetworkError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Error type for execution failures such as subprocess errors.
pub suberror ExecError derive(Debug)

///|
pub extend ExecError with @moonbitlang/core/debug.Debug::{to_repr}
