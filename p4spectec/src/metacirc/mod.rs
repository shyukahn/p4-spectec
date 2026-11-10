//! Configured interpreter towers over AL, IL, or P4 inputs
//!
//! Each runner is prepared in the arena used by all of its calls.
//! Only the base runs natively, on an `engine` executing AL or SL,
//! a K library compiled from the base (ST-in-K),
//! or a `racket` process running a PLT Redex base (ST-in-Redex);
//! each level above is interpreted by the level below through its `protocol`.
//! Calls go down the levels (`interp`), host calls come up across each
//! `boundary`, and a P4 extern that reenters runs on the next depth.
//! `tower` builds the levels, `sim` drives them with an STF test,
//! and `run` runs a program through a tower.
//! `cover` measures the SL instruction coverage of an SL base over many P4 inputs.
//! Each backend is its own module, sharing nothing with the others:
//! `st` runs P4-SpecTec specifications (spec-meta, spec-meta-ext),
//! `k` spec-meta-k from its K library, and `redex` spec-meta-redex in `racket`.
//!
//! ```text
//! Tower
//! ├─ levels: [PreparedLevel]
//! ├─ protocols: [ProtocolKind]                          : Protocol
//! └─ Base
//!    └─ Upper                    ─lend→ UpperMut        : Extern
//!       ├─ Top                   ─lend→ TopMut
//!       └─ TowerInterpState      ─lend→ TowerInterp     : Interpreter
//!          └─ EngineStateKind    ─lend→ EngineKind      : Engine
//! ```

mod boundary;
pub mod config;
pub mod cover;
mod engine;
mod error;
mod interp;
mod k;
mod protocol;
mod redex;
mod sim;
mod st;
mod tower;

use crate::{lang::data::arena::Arena, runner, sim_plugin::dummy::Dummy};
pub use config::{BaseConfig, Repr, TowerConfig};
use std::path::PathBuf;

pub use error::Result;

pub use sim::build_simulator;
pub use tower::{Input, Script, Tower};

/// Executes a program through the configured interpreter tower.
///
/// `paths_program` are the program in the language the top level accepts:
/// one P4 program, or the sources of an AL or IL script.
pub fn run(
    config: &TowerConfig,
    includes: &[PathBuf],
    paths_program: &[PathBuf],
    options: runner::Config,
) -> Result<()> {
    let mut arena = Arena::new();
    let mut tower = Tower::build(&mut arena, config, options, Dummy)?;
    // Read the input in the language the top level accepts;
    // encoding errors propagate before entering the native base
    let input = tower.parse_input(&mut arena, includes, paths_program)?;
    let values = tower.encode_input(&mut arena, &input)?;
    tower
        .eval_input(&mut arena, &values)
        .map_err(|error| error.into_report())?;
    Ok(())
}
