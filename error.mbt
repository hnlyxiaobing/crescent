///|
/// Error type for I/O operations such as file reads or writes.
#derive(Debug)
pub suberror IOError

///|
pub extend IOError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Error type for network-related failures such as connection errors.
#derive(Debug)
pub suberror NetworkError

///|
pub extend NetworkError with @moonbitlang/core/debug.Debug::{to_repr}

///|
/// Error type for execution failures such as subprocess errors.
#derive(Debug)
pub suberror ExecError

///|
pub extend ExecError with @moonbitlang/core/debug.Debug::{to_repr}
