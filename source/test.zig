//! This file references all test cases from every other module. Thus, it acts
//! as the entry point to a full test suite for this project.
//!
//! It can be used to run the test suite by running `zig test source/test.zig`.

test {
    // For any 'containers' (e.g. a struct or an `@import`) that are referenced
    // inside a test like this, all test cases inside that container will be
    // detected and run (except for any which are nested more deeply inside
    // a sub-container).
    //
    // Thus, to run all test cases from each module, we simply `@import` them
    // here and ignore the result.

    _ = @import("rules.zig");
    _ = @import("model.zig");
}
